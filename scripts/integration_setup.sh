#!/usr/bin/env bash
source $(dirname "$0")/helpers/shared_secrets.sh
set -e

get_api_gateway_endpoint() {
  >&2 echo "INFO: Getting integration test API Gateway endpoint."
  remove_secret 'endpoint_name'

  endpoint_url=$(serverless info --stage develop | \
    grep -E 'http.*\/ping' | \
    sed 's/.*\(http.*\)\/ping/\1/' | \
    tr -d $'\r')
  if test -z "$endpoint_url"
  then
    >&2 echo "ERROR: We couldn't find a deployed endpoint."
    exit 1
  fi
  export API_GATEWAY_URL="$endpoint_url"
  write_secret "$endpoint_url" "endpoint_name"
}

get_api_gateway_endpoint
