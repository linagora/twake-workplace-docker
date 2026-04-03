#!/bin/bash
# compose-wrapper.sh
set -e

# Detect whether sudo is needed for docker (on macOS Docker Desktop, it's not)
if [ -z "$SUDO" ]; then
  if docker info &>/dev/null; then SUDO=""; else SUDO="sudo"; fi
fi

ACTION="$1"
# Load environment variables
set -a
source ../.env
set +a
if [ "$ACTION" = "up" ]; then
# Process configuration
  echo "Processing ldap configuration..."
  envsubst '$BASE_DOMAIN $LDAP_BASE_DN' < ldap/bootstrap/users.ldif.template > ldap/bootstrap/users.ldif

  # Check if file was created
  if [ ! -f "ldap/bootstrap/users.ldif" ]; then
    echo "Failed to create configuration file"
    exit 1
  fi

fi


# Pass all arguments to docker compose
${SUDO} docker compose --env-file ../.env "$@"