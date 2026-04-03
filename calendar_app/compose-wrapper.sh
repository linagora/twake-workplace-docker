#!/bin/bash
# compose-wrapper.sh

set -e

ACTION="$1"

# Load environment variables
set -a
source ../.env
set +a
set -euo pipefail

if [ "$ACTION" = "up" ]; then
# Process configuration
echo "Processing configuration..."
envsubst '$BASE_DOMAIN $MAIL_DOMAIN' < ./conf-side-service/configuration.properties.template > ./conf-side-service/configuration.properties
envsubst '$BASE_DOMAIN' < ./frontend/account/openpaas.js.template > ./frontend/account/openpaas.js
envsubst '$BASE_DOMAIN' < ./frontend/calendar/openpaas.js.template > ./frontend/calendar/openpaas.js
envsubst '$BASE_DOMAIN' < ./frontend/contacts/openpaas.js.template > ./frontend/contacts/openpaas.js
envsubst '$BASE_DOMAIN' < ./frontend/env.js.template > ./frontend/env.js

# Check if file was created
if [ ! -f "./conf-side-service/configuration.properties" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
if [ ! -f "./frontend/account/openpaas.js" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
if [ ! -f "./frontend/calendar/openpaas.js" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
if [ ! -f "./frontend/contacts/openpaas.js" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
if [ ! -f "./frontend/env.js" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
fi


# Pass all arguments to docker compose
sudo docker compose -p twake-calendar --env-file ../.env "$@"

# 🚨 Everything below is UP-only
if [ "$ACTION" != "up" ]; then
  exit 0
fi

CONTAINER="tcalendar-side-service"
CA_ALIAS="twake-root-ca"
CA_FILE="/usr/local/share/ca-certificates/root-ca.crt"

echo "⏳ Waiting for $CONTAINER to start..."

# Wait indefinitely until container is running
until [ "$(sudo docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo "missing")" = "running" ]; do
  sleep 7
done

echo "✔ $CONTAINER is running, importing CA..."

# Idempotent import: only adds if alias does not exist
sudo docker exec "$CONTAINER" bash -c "
  keytool -list -keystore \$JAVA_HOME/lib/security/cacerts \
    -storepass changeit -alias $CA_ALIAS >/dev/null 2>&1 || \
  keytool -importcert -trustcacerts \
    -keystore \$JAVA_HOME/lib/security/cacerts \
    -storepass changeit \
    -alias $CA_ALIAS \
    -file $CA_FILE \
    -noprompt
"

echo "▶ Restarting $CONTAINER to apply changes..."
sudo docker restart "$CONTAINER"