#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ACTION="$1"

# Load environment variables
set -a
source ../.env
set +a

if [ "$ACTION" = "up" ]; then
  echo "Processing configuration..."
  envsubst '$BASE_DOMAIN $TOKEN_ENCRYPTION_KEY' < config/config.yaml.template > config/config.yaml

  if [ ! -f "config/config.yaml" ]; then
    echo "Failed to create configuration file"
    exit 1
  fi
fi

sudo -E BASE_DOMAIN="$BASE_DOMAIN" TOKEN_ENCRYPTION_KEY="$TOKEN_ENCRYPTION_KEY" \
  docker compose --env-file ../.env "$@"
