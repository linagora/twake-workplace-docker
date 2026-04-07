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
envsubst '$BASE_DOMAIN' < ./config/nginx.conf.template > config/nginx.conf

# Check if file was created
if [ ! -f "config/nginx.conf" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
fi

# Pass all arguments to docker compose
sudo docker compose -p twake-visio --env-file ../.env "$@"