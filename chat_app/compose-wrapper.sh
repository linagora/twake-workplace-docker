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
# Synapse's runtime data dir, kept off the tracked tree so synapse-init's chown
# never rewrites repo file ownership. custom_template_directory must pre-exist.
mkdir -p ./synapse/data/templates
envsubst '$BASE_DOMAIN' < ./synapse/wellknownclient.conf.template > ./synapse/wellknownclient.conf
envsubst '$BASE_DOMAIN' < ./synapse/wellknownserver.conf.template > ./synapse/wellknownserver.conf
envsubst '$BASE_DOMAIN' < ./chat/config.json.template > ./chat/config.json
envsubst '$BASE_DOMAIN $LDAP_BASE_DN' < ./tom/config.yaml.template > ./tom/config.yaml
envsubst '$BASE_DOMAIN $RABBITMQ_USER $RABBITMQ_PASSWORD' < ./tom-bridge/config.yaml.template > ./tom-bridge/config.yaml
# The application service tokens are generated once and kept: Synapse and the
# bridge must agree on them across restarts.
if [ ! -f ./tom-bridge/registration.yaml ]; then
  TOM_BRIDGE_AS_TOKEN=$(openssl rand -hex 32) TOM_BRIDGE_HS_TOKEN=$(openssl rand -hex 32) \
    envsubst '$TOM_BRIDGE_AS_TOKEN $TOM_BRIDGE_HS_TOKEN' < ./tom-bridge/registration.yaml.template > ./tom-bridge/registration.yaml
fi
# The Twake Space backend shares these tokens through the root .env; Synapse
# loads its registration only when they are set (Chat tab of Twake Space)
envsubst '$TWAKE_SPACE_MATRIX_AS_TOKEN $TWAKE_SPACE_MATRIX_HS_TOKEN' < ./synapse/twake-space-registration.yaml.template > ./synapse/twake-space-registration.yaml
export TWAKE_SPACE_APPSERVICE=""
if [ -n "${TWAKE_SPACE_MATRIX_AS_TOKEN:-}" ]; then
  TWAKE_SPACE_APPSERVICE="  - /config/twake-space-registration.yaml"
fi
envsubst '$BASE_DOMAIN $LDAP_BASE_DN $TWAKE_SPACE_APPSERVICE' < ./synapse/homeserver-postgres.yaml.template > ./synapse/homeserver-postgres.yaml

# Check if file was created
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
if [ ! -f "./tom/config.yaml" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
if [ ! -f "./tom-bridge/config.yaml" ] || [ ! -f "./tom-bridge/registration.yaml" ]; then
    echo "Failed to create configuration file"
    exit 1
fi

fi

# Pass all arguments to docker compose
sudo docker compose --env-file ../.env "$@"