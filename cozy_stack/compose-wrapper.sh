#!/bin/bash
# compose-wrapper.sh
set -e

ACTION="$1"
# Load environment variables
set -a
source ../.env
set +a
if [ "$ACTION" = "up" ]; then
 # Process configuration
 echo "Processing configuration..."
 envsubst '$BASE_DOMAIN' < ./config/cozy.yaml.template > config/cozy.yaml

 # Check if file was created
 if [ ! -f "config/cozy.yaml" ]; then
    echo "Failed to create configuration file"
    exit 1
 fi
fi


# Pass all arguments to docker compose
sudo docker compose --env-file ../.env "$@"