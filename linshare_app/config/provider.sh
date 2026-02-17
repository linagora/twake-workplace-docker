#!/bin/bash
set -euo pipefail

echo "Using BASE_DOMAIN: ${BASE_DOMAIN:-NOT SET}"
# Configuration
BASE_URL="https://admin-linshare.${BASE_DOMAIN}/linshare/webservice/rest/admin/v5"

echo "⏳ Waiting for LinShare admin API to be ready..."

until curl -sk -o /dev/null -w "%{http_code}" \
  -u "root@localhost.localdomain:adminlinshare" \
  "$BASE_URL/domains" | grep -qE "200|401|403"; do
  echo "… admin API not ready yet"
  sleep 5
done

echo "✔ LinShare admin API is ready"


# Create TOPDOMAIN
echo "Creating TOPDOMAIN..."
TOPDOMAIN_RESPONSE=$(curl -s -kv -u "root@localhost.localdomain:adminlinshare" "$BASE_URL/domains" \
  -H "accept: application/json, text/plain, */*" \
  -H "content-type: application/json" \
  --data-raw '{"name":"top1","parent":{"name":"LinShareRootDomain","uuid":"LinShareRootDomain"},"type":"TOPDOMAIN"}')

echo "TOPDOMAIN Response:"
echo "$TOPDOMAIN_RESPONSE"

# Extract the domain UUID from the response
DOMAIN_UUID=$(echo "$TOPDOMAIN_RESPONSE" | jq -r '.uuid')
echo "Created TOPDOMAIN with UUID: $DOMAIN_UUID"

#Create OIDC Provider for the domain
echo "Creating OIDC Provider..."
OIDC_RESPONSE=$(curl -s -kv -u "root@localhost.localdomain:adminlinshare" "$BASE_URL/domains/$DOMAIN_UUID/user_providers" \
  -H "accept: application/json, text/plain, */*" \
  -H "content-type: application/json" \
  --data-raw '{"type":"OIDC_PROVIDER","domainDiscriminator":"domain_discriminator"}')

echo "OIDC Provider Response:"
echo "$OIDC_RESPONSE"
