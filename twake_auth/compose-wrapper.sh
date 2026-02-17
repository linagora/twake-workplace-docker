#!/bin/bash
# compose-wrapper.sh
set -e

ACTION="$1"

# Load environment variables
set -a
source ../.env
set +a

if [ "$ACTION" = "up" ]; then
  echo "Processing LemonLDAP configuration..."
  envsubst '$BASE_DOMAIN $LDAP_BASE_DN' \
    < ./config/lmConf-1.json.template \
    > config/lmConf-1.json

  if [ ! -f "config/lmConf-1.json" ]; then
    echo "Failed to create configuration file"
    exit 1
  fi

  echo "Creating certs..."
  ./generate-cert.sh
fi


sudo docker compose --env-file ../.env "$@"

if [ "$ACTION" != "up" ]; then
  exit 0
fi

while true; do
  STATUS=$(sudo docker inspect \
    --format='{{if .State.Health}}{{.State.Health.Status}}{{end}}' \
    "lemonldap-ng" 2>/dev/null || echo "starting")

  case "$STATUS" in
    healthy)
      echo "✔ Lemonldap is healthy"
      break
      ;;
    unhealthy)
      echo "❌ Lemonldap is unhealthy"
      exit 1
      ;;
    ""|starting)
      echo "… Lemonldap status: starting"
      sleep 4
      ;;
    *)
      echo "… Lemonldap status: $STATUS"
      sleep 4
      ;;
  esac
done

sudo docker exec lemonldap-ng bash -c "/usr/share/lemonldap-ng/bin/rotateOidcKeys" || true
