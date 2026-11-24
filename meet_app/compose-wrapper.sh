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
envsubst '$LIVEKIT_USE_EXTERNAL_IP $LIVEKIT_API_KEY $LIVEKIT_API_SECRET' <./config/livekit.yaml.template > config/livekit.yaml

# Check if files were created
if [ ! -f "config/nginx.conf" ] || [ ! -f "config/livekit.yaml" ]; then
    echo "Failed to create configuration file"
    exit 1
fi

# Python 3.13 (the backend's Drive upload) rejects a CA without keyUsage, which
# the self-signed root lacks: re-sign it with the same key and subject, so the
# server certificate it issued still verifies.
SSL_DIR=../twake_auth/traefik/ssl
if [ "${CERT_MODE:-self-signed}" = "letsencrypt" ]; then
    cp "$SSL_DIR/root-ca.crt" config/root-ca.crt
else
    openssl x509 -in "$SSL_DIR/root-ca.pem" -signkey "$SSL_DIR/root-ca.key" \
      -days 3650 -sha256 -clrext \
      -extfile <(printf "basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\nsubjectKeyIdentifier=hash") \
      -out config/root-ca.crt
fi
fi

# Pass all arguments to docker compose
sudo docker compose --env-file ../.env "$@"