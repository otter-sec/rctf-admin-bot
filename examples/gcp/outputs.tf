output "submit_url" {
  value       = google_cloud_run_service.submit.status[0].url
  description = "Public Cloud Run URL for submissions"
}

output "submit_name" {
  value       = google_cloud_run_service.submit.name
  description = "Name of Cloud Run service for submissions"
}

output "submit_id" {
  value       = google_cloud_run_service.submit.id
  description = "ID of Cloud Run service for submissions"
}
