#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f config/config.yaml.template ]; then
  envsubst < config/config.yaml.template > config/config.yaml
fi

sudo docker compose --env-file ../.env "$@"
