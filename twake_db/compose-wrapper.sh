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
  echo "Processing ldap configuration..."
  envsubst '$BASE_DOMAIN $LDAP_BASE_DN' < ldap/bootstrap/users.ldif.template > ldap/bootstrap/users.ldif

  # Check if file was created
  if [ ! -f "ldap/bootstrap/users.ldif" ]; then
    echo "Failed to create configuration file"
    exit 1
  fi

fi


# Pass all arguments to docker compose
sudo docker compose --env-file ../.env "$@"