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

  if [ ! -f "traefik/ssl/twake-server.pem" ] || [ ! -f "traefik/ssl/root-ca.crt" ]; then
    echo "Creating certs..."
    ./generate-cert.sh
    CERTS_REGENERATED=true
  fi
fi


sudo docker compose -p twake-auth --env-file ../.env "$@"

if [ "${CERTS_REGENERATED:-}" = "true" ]; then
  echo "Certs were regenerated, restarting reverse-proxy..."
  sudo docker compose -p twake-auth --env-file ../.env restart reverse-proxy
fi

if [ "$ACTION" != "up" ]; then
  exit 0
fi

echo "⏳ Waiting for LemonLDAP to be healthy (timeout 5 min)..."
ELAPSED=0
MAX_WAIT=300
while [ "$ELAPSED" -lt "$MAX_WAIT" ]; do
  STATUS=$(sudo docker inspect \
    --format='{{if .State.Health}}{{.State.Health.Status}}{{end}}' \
    "lemonldap-ng" 2>/dev/null || echo "starting")

  case "$STATUS" in
    healthy)
      echo "✔ LemonLDAP is healthy"
      break
      ;;
    unhealthy)
      echo "❌ LemonLDAP is unhealthy. Check logs: docker logs lemonldap-ng"
      exit 1
      ;;
    ""|starting)
      echo "… LemonLDAP status: starting (${ELAPSED}s / ${MAX_WAIT}s)"
      sleep 5
      ELAPSED=$((ELAPSED + 5))
      ;;
    *)
      echo "… LemonLDAP status: $STATUS (${ELAPSED}s / ${MAX_WAIT}s)"
      sleep 5
      ELAPSED=$((ELAPSED + 5))
      ;;
  esac
done

if [ "$ELAPSED" -ge "$MAX_WAIT" ]; then
  echo "❌ Timeout: LemonLDAP did not become healthy in ${MAX_WAIT}s. Check: docker logs lemonldap-ng"
  exit 1
fi

sudo docker exec lemonldap-ng bash -c "/usr/share/lemonldap-ng/bin/rotateOidcKeys" || true
