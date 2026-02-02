#!/bin/bash
# compose-wrapper.sh
set -e

ACTION="$1"

# Load environment variables
set -a
source ../.env
set +a

if [ "$ACTION" = "up" ]; then
  echo "Processing LemonLDAP configuration..."
  envsubst '$BASE_DOMAIN $LDAP_BASE_DN' \
    < ./config/lmConf-1.json.template \
    > config/lmConf-1.json

  if [ ! -f "config/lmConf-1.json" ]; then
    echo "❌ Failed to create configuration file"
    exit 1
  fi

  echo "Creating certs..."
  ./generate-cert.sh
fi


sudo docker compose --env-file ../.env "$@"