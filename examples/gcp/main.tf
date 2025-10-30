terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.58.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

resource "google_project_service" "services" {
  for_each = toset([
    "run.googleapis.com"
  ])

  service = each.value
  disable_on_destroy = false # leave the service enabled
}

resource "google_pubsub_topic" "topic" {
  name = var.prefix
}

resource "google_cloud_run_service" "submit" {
  name     = "${var.prefix}-submit"
  location = var.region

  template {
    spec {
      containers {
        image = var.image
        resources {
          limits = {
            memory = "128Mi"
            cpu    = "1"
          }
        }
        args = ["submit"]
        env {
          name  = "APP_PUBSUB_TOPIC"
          value = google_pubsub_topic.topic.name
        }
        dynamic "env" {
          for_each = range(var.recaptcha == null ? 0 : 2)
          content {
            name  = env.key == 0 ? "APP_RECAPTCHA_SITE" : "APP_RECAPTCHA_SECRET"
            value = env.key == 0 ? var.recaptcha.site : var.recaptcha.secret
          }
        }
      }
      timeout_seconds      = 10
      service_account_name = google_service_account.submit.account_id
    }
    metadata {
      annotations = merge({
        "autoscaling.knative.dev/maxScale" = var.submit_max_scale
      }, var.submit_annotations)
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.services
  ]
}

resource "google_cloud_run_service_iam_binding" "submit" {
  service  = google_cloud_run_service.submit.name
  location = google_cloud_run_service.submit.location
  role     = "roles/run.invoker"
  members = [
    "allUsers",
  ]

  depends_on = [
    google_project_service.services
  ]
}

resource "google_service_account" "submit" {
  account_id = "${var.prefix}-submit"
}

resource "google_pubsub_topic_iam_binding" "submit" {
  topic = google_pubsub_topic.topic.name
  role  = "roles/pubsub.publisher"
  members = [
    "serviceAccount:${google_service_account.submit.email}",
  ]
}

resource "google_cloud_run_service" "visit" {
  name     = "${var.prefix}-visit"
  location = var.region

  template {
    spec {
      containers {
        image = var.image
        resources {
          limits = {
            memory = "1Gi"
            cpu    = "1"
          }
        }
        args = ["visit"]
      }
      container_concurrency = 5
      timeout_seconds       = 70
      service_account_name  = google_service_account.visit.account_id
    }
    metadata {
      annotations = merge({
        "autoscaling.knative.dev/maxScale" = var.visit_max_scale
      }, var.visit_annotations)
    }
  }
  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "internal"
      "run.googleapis.com/minScale" = var.visit_min_scale
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.services
  ]
}

resource "google_service_account" "visit" {
  account_id = "${var.prefix}-visit"
}

resource "google_service_account" "invoke" {
  account_id = "${var.prefix}-invoke"
}

data "google_project" "project" {}
resource "google_service_account_iam_binding" "invoke" {
  service_account_id = google_service_account.invoke.id
  role               = "roles/iam.serviceAccountTokenCreator"
  members = [
    "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com",
  ]
}

resource "google_cloud_run_service_iam_binding" "invoke" {
  service  = google_cloud_run_service.visit.name
  location = google_cloud_run_service.visit.location
  role     = "roles/run.invoker"
  members = [
    "serviceAccount:${google_service_account.invoke.email}"
  ]
}

resource "google_pubsub_subscription" "visit" {
  name                       = "${google_pubsub_topic.topic.name}-visit"
  topic                      = google_pubsub_topic.topic.name
  message_retention_duration = "3600s"
  ack_deadline_seconds       = 80
  push_config {
    push_endpoint = google_cloud_run_service.visit.status[0].url
    oidc_token {
      service_account_email = google_service_account.invoke.email
    }
  }
  expiration_policy {
    ttl = ""
  }
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }
}
