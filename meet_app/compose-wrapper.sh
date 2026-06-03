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
envsubst '$LIVEKIT_USE_EXTERNAL_IP' < ./config/livekit.yaml.template > config/livekit.yaml

# Check if files were created
if [ ! -f "config/nginx.conf" ] || [ ! -f "config/livekit.yaml" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
fi

# Pass all arguments to docker compose
sudo docker compose --env-file ../.env "$@"