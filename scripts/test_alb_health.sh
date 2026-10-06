#!/bin/bash
# Shell script to test ALB endpoints using curl
set -e

if [ -z "$1" ]; then
  echo "Usage: ./test_alb_health.sh <ALB_DNS_NAME>"
  echo "Example: ./test_alb_health.sh savitara-dev-alb-1234.us-east-1.elb.amazonaws.com"
  exit 1
fi

ALB_HOST="$1"

echo "=========================================================="
echo " Testing Application Endpoints: $ALB_HOST"
echo "=========================================================="

echo -e "\n1. Testing HTTP to HTTPS 301 Redirect:"
curl -s -o /dev/null -w "HTTP Response Code: %{http_code}\nRedirect Target: %{redirect_url}\n" "http://${ALB_HOST}/health"

echo -e "\n2. Testing HTTPS /health Endpoint:"
curl -k -s "https://${ALB_HOST}/health" | jq . || curl -k -s "https://${ALB_HOST}/health"

echo -e "\n3. Testing HTTPS / Root Architecture Endpoint:"
curl -k -s "https://${ALB_HOST}/" | jq . || curl -k -s "https://${ALB_HOST}/"

echo -e "\n4. Testing HTTPS /db-check Database Endpoint:"
curl -k -s "https://${ALB_HOST}/db-check" | jq . || curl -k -s "https://${ALB_HOST}/db-check"

echo -e "\n5. Testing HTTPS /info Metadata Endpoint:"
curl -k -s "https://${ALB_HOST}/info" | jq . || curl -k -s "https://${ALB_HOST}/info"

echo -e "\nVerification completed successfully!"
