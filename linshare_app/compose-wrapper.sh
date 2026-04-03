#!/bin/bash
set -e

# Detect whether sudo is needed for docker (on macOS Docker Desktop, it's not)
if [ -z "$SUDO" ]; then
  if docker info &>/dev/null; then SUDO=""; else SUDO="sudo"; fi
fi

ACTION="$1"

set -a
source ../.env
set +a

BACKEND_CONTAINER="linshare_backend"
PROVIDER_SCRIPT="./config/provider.sh"

if [ "$ACTION" = "up" ]; then
  echo "Processing configuration..."

  envsubst '$BASE_DOMAIN' \
    < config/backend/linshare.extra.properties.template \
    > config/backend/linshare.extra.properties

  envsubst '$BASE_DOMAIN' \
    < config/user-ui/config.js.template \
    > config/user-ui/config.js
fi

# Always call compose
${SUDO} docker compose --env-file ../.env "$@"

# 🚨 Everything below is UP-only
if [ "$ACTION" != "up" ]; then
  exit 0
fi

# ---- Wait for backend to be healthy ----
echo "⏳ Waiting for backend container to become healthy..."

while true; do
  STATUS=$(${SUDO} docker inspect \
    --format='{{if .State.Health}}{{.State.Health.Status}}{{end}}' \
    "$BACKEND_CONTAINER" 2>/dev/null || echo "starting")

  case "$STATUS" in
    healthy)
      echo "✔ Backend is healthy"
      break
      ;;
    unhealthy)
      echo "❌ Backend is unhealthy"
      exit 1
      ;;
    ""|starting)
      echo "… backend status: starting"
      sleep 7
      ;;
    *)
      echo "… backend status: $STATUS"
      sleep 7
      ;;
  esac
done

# ---- Run provider bootstrap ----
echo "🚀 Running OIDC provider bootstrap..."
export BASE_DOMAIN 
bash "$PROVIDER_SCRIPT"