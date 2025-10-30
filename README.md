# rctf-admin-bot

A scalable service for client-side web CTF challenges

## Quick Start

Please see https://rctf.osec.io/running_a_successful_ctf/deploying_challenges/#admin-bot

## Deployment

1. Create a [`config.js` file](#challenge-configuration) and a [`Dockerfile`](https://github.com/otter-sec/rctf-admin-bot/blob/master/examples/image/Dockerfile)
2. Build and push the image to your desired Docker registry
3. Deploy the image using the appropriate deployment files [here](https://github.com/otter-sec/rctf-admin-bot/tree/main/examples)

For user attachments, the `image/` deployment can be included instead of having to integrate admin bot directly into the challenge's source code. This
also has the side benefit of matching exactly how the remote's admin bot functions.

## Challenge Configuration

The [`config.js` file](https://github.com/otter-sec/rctf-admin-bot/blob/master/examples/image/config.js) must export a `Map` named `challenges`.

The key of each entry is its challenge ID. To submit a URL to the admin bot, visit `/<challenge id>`.

The value of each entry is an object with properties:

* `name`: the display name of the challenge
* `restrict_domains`: see below for a more in-depth explanation
* `timeout`: the timeout in milliseconds for each admin bot visit
* `handler`: a function which returns a `Promise` and accepts the submitted URL and a [Puppeteer `BrowserContext`](https://pptr.dev/#?show=api-class-browsercontext)
* `urlRegex` (optional): a regex to check the URL against (default: `/^https?:\/\//`)

To prevent cookie tossing (and other cheeses) from another vulnerable challenge on the same domain, we also support providing the
`restrict_domains` option, where one can provide a list of domains and their subdomains that should be accessible. Any subdomain of a domain that is not part of the list will automatically
fail.  For example, if all challenges are hosted under `example.com`, one can restrict access to only the challenge-specific subdomain `one.example.com` with the following configuration:
```js
    restrict_domains: {
        'example.com': ['one.example.com']
    }
```
Behind the scenes, the --proxy-pac-url flag is used to tell browser how the restricted URLs should be handled.

Additionally, to mitigate possible Chrome vulnerabilities, JIT/WebAssembly is disabled. The base image provided by this repository is automatically
updated weekly to keep up to date with patches.
