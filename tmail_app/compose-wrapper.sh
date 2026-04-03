#!/bin/bash
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
echo "Processing configuration..."
envsubst '$BASE_DOMAIN' < config/smtpserver.xml.template > config/smtpserver.xml
envsubst '$BASE_DOMAIN $LDAP_BASE_DN' < config/usersrepository.xml.template > config/usersrepository.xml
envsubst '$BASE_DOMAIN' < config/domainlist.xml.template > config/domainlist.xml
envsubst '$BASE_DOMAIN' < config/jmap.properties.template > config/jmap.properties
envsubst '$BASE_DOMAIN' < config/mailetcontainer.xml.template > config/mailetcontainer.xml
envsubst '$BASE_DOMAIN' < tmail-web-conf/.env.template > tmail-web-conf/.env

# Check if file was created
if [ ! -f "config/smtpserver.xml" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
if [ ! -f "config/usersrepository.xml" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
if [ ! -f "config/domainlist.xml" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
if [ ! -f "config/jmap.properties" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
if [ ! -f "config/mailetcontainer.xml" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
if [ ! -f "tmail-web-conf/.env" ]; then
    echo "Failed to create configuration file"
    exit 1
fi
fi

# Pass all arguments to docker compose
${SUDO} docker compose --env-file ../.env "$@"