#!/bin/bash
set -e

ACTION="$1"

# Load environment variables
set -a
source ../.env
set +a

if [ "$ACTION" = "up" ]; then
# Process configuration
echo "Processing configuration..."
envsubst '$BASE_DOMAIN $LDAP_BASE_DN' < ./synapse/.env.template > ./synapse/.env
envsubst '$BASE_DOMAIN $LDAP_BASE_DN' < ./synapse/homeserver-postgres.yaml.template > ./synapse/homeserver-postgres.yaml
envsubst '$BASE_DOMAIN' < ./synapse/wellknownclient.conf.template > ./synapse/wellknownclient.conf
envsubst '$BASE_DOMAIN' < ./synapse/wellknownserver.conf.template > ./synapse/wellknownserver.conf
envsubst '$BASE_DOMAIN' < ./chat/config.json.template > ./chat/config.json

# Ensure homeserver.yaml has the generated content (avoids empty file issue with overlapping volume mounts)
cp ./synapse/homeserver-postgres.yaml ./synapse/homeserver.yaml

# Check if file was created
if [ ! -f "./synapse/.env" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
if [ ! -f "./synapse/homeserver-postgres.yaml" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
if [ ! -f "./synapse/wellknownclient.conf" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
if [ ! -f "./synapse/wellknownserver.conf" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
if [ ! -f "./chat/config.json" ]; then
    echo "Failed to create configuration file"
    exit 1
fi

fi

# Pass all arguments to docker compose
sudo docker compose --env-file ../.env "$@"

# 🚨 Everything below is UP-only
if [ "$ACTION" != "up" ]; then
  exit 0
fi

sudo docker exec chat_app-synapse-1 update-ca-certificates
