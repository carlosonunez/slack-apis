# slack-apis

A collection of Slack functions that I use for various things. These are needed
ever since Slack deprecated token-based authentication in favor of OAuth 2.0.

## How to run

### Local

1. Start the webserver: `docker-compose run --rm webserver`
2. Run your function against `localhost`

   ```sh
   curl -X PUT --data '{ "status": "Hello" }' http://localhost/v1/update_status?key=$key
   ```
