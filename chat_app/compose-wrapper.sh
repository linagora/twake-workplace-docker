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
if [ "${TOM_BRIDGE_SPACES:-}" = true ]; then
  envsubst '$BASE_DOMAIN $ORGANIZATION_ID' < ./tom-bridge/spaces.yaml.template >> ./tom-bridge/config.yaml
fi
# The application service tokens are generated once and kept: Synapse and the
# bridge must agree on them across restarts. The rest of the registration is
# rendered again on every up.
export BASE_DOMAIN_REGEX="${BASE_DOMAIN//./\\.}"
if [ -f ./tom-bridge/registration.yaml ]; then
  TOM_BRIDGE_AS_TOKEN=$(sed -n 's/^as_token: *"\(.*\)"$/\1/p' ./tom-bridge/registration.yaml)
  TOM_BRIDGE_HS_TOKEN=$(sed -n 's/^hs_token: *"\(.*\)"$/\1/p' ./tom-bridge/registration.yaml)
  if [ -z "$TOM_BRIDGE_AS_TOKEN" ] || [ -z "$TOM_BRIDGE_HS_TOKEN" ]; then
    echo "No as_token/hs_token found in tom-bridge/registration.yaml: fix it, or delete it to get new tokens"
    exit 1
  fi
else
  TOM_BRIDGE_AS_TOKEN=$(openssl rand -hex 32)
  TOM_BRIDGE_HS_TOKEN=$(openssl rand -hex 32)
fi
export TOM_BRIDGE_AS_TOKEN TOM_BRIDGE_HS_TOKEN
envsubst '$TOM_BRIDGE_AS_TOKEN $TOM_BRIDGE_HS_TOKEN $BASE_DOMAIN_REGEX' < ./tom-bridge/registration.yaml.template > ./tom-bridge/registration.yaml
# The Twake Space backend shares these tokens through the root .env; Synapse
# loads its registration only when they are set (Chat tab of Twake Space)
envsubst '$TWAKE_SPACE_MATRIX_AS_TOKEN $TWAKE_SPACE_MATRIX_HS_TOKEN $BASE_DOMAIN_REGEX' < ./synapse/twake-space-registration.yaml.template > ./synapse/twake-space-registration.yaml
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