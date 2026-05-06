#!/bin/bash
# compose-wrapper.sh
set -e

command -v jq >/dev/null || {
  echo "ERR: jq is required by this wrapper. Install: sudo apt-get install -y jq (Debian/Ubuntu) or equivalent." >&2
  exit 1
}
command -v envsubst >/dev/null || {
  echo "ERR: envsubst is required by this wrapper. Install: sudo apt-get install -y gettext-base (Debian/Ubuntu) or equivalent." >&2
  exit 1
}

ACTION="$1"

# Load environment variables
set -a
source ../.env
set +a

# render_lmconf — produce twake_auth/config/lmConf-1.json from the right
# template based on AUTH_MODE. Called directly when ACTION=render (so
# operators can iterate on .env without restarting the stack), and as the
# first step of ACTION=up.
render_lmconf() {
  echo "Processing LemonLDAP configuration..."

  # Pick template based on AUTH_MODE.
  #   LDAP            (default) — internal LDAP backend handles login + attrs
  #   OpenIDConnect   — external SSO handles login, LDAP still serves attrs
  AUTH_MODE="${AUTH_MODE:-LDAP}"
  case "$AUTH_MODE" in
    LDAP)
      TEMPLATE=./config/lmConf-1.json.ldap.template
      ENVSUBST_VARS='$BASE_DOMAIN $LDAP_BASE_DN'
      ;;
    OpenIDConnect)
      TEMPLATE=./config/lmConf-1.json.oidc.template
      # Only structural fields go through envsubst. Client credentials are
      # spliced in with jq below so JSON-meaningful chars in OIDC_CLIENT_*
      # (quotes, backslashes, dollars) don't corrupt the rendered file.
      ENVSUBST_VARS='$BASE_DOMAIN $LDAP_BASE_DN $OIDC_OP_NAME'
      : "${OIDC_OP_NAME:?OIDC_OP_NAME required when AUTH_MODE=OpenIDConnect}"
      : "${OIDC_OP_DISCOVERY_URL:?OIDC_OP_DISCOVERY_URL required when AUTH_MODE=OpenIDConnect}"
      : "${OIDC_CLIENT_ID:?OIDC_CLIENT_ID required when AUTH_MODE=OpenIDConnect}"
      : "${OIDC_CLIENT_SECRET:?OIDC_CLIENT_SECRET required when AUTH_MODE=OpenIDConnect}"
      ;;
    *)
      echo "Unknown AUTH_MODE: $AUTH_MODE (expected LDAP or OpenIDConnect)"
      exit 1
      ;;
  esac

  envsubst "$ENVSUBST_VARS" < "$TEMPLATE" > config/lmConf-1.json

  if [ ! -f "config/lmConf-1.json" ]; then
    echo "Failed to create configuration file"
    exit 1
  fi

  # OpenIDConnect: fetch the OP discovery document and splice it into
  # oidcOPMetaDataJSON.<OP_NAME>. Lemonldap-ng expects that field to be a
  # JSON-encoded *string* (the discovery doc serialised), so we use jq to
  # do the encoding correctly regardless of what the OP returns.
  if [ "$AUTH_MODE" = "OpenIDConnect" ]; then
    echo "Fetching OIDC discovery document from $OIDC_OP_DISCOVERY_URL..."
    if ! DISCOVERY=$(curl -fsSL "$OIDC_OP_DISCOVERY_URL"); then
      echo "❌ Failed to fetch $OIDC_OP_DISCOVERY_URL — check network reachability and the URL." >&2
      exit 1
    fi
    if ! echo "$DISCOVERY" | jq -e . >/dev/null 2>&1; then
      echo "❌ Response from $OIDC_OP_DISCOVERY_URL is not valid JSON." >&2
      exit 1
    fi
    jq --arg op "$OIDC_OP_NAME" \
       --argjson disc "$DISCOVERY" \
       --arg cid "$OIDC_CLIENT_ID" \
       --arg csecret "$OIDC_CLIENT_SECRET" \
       '.oidcOPMetaDataJSON[$op] = ($disc | tostring)
        | .oidcOPMetaDataOptions[$op].oidcOPMetaDataOptionsClientID = $cid
        | .oidcOPMetaDataOptions[$op].oidcOPMetaDataOptionsClientSecret = $csecret' \
       config/lmConf-1.json > config/lmConf-1.json.tmp
    mv config/lmConf-1.json.tmp config/lmConf-1.json
  fi
  echo "✔ config/lmConf-1.json generated (AUTH_MODE=$AUTH_MODE)"
}

render_dnsmasq() {
  echo "Processing dnsmasq configuration..."
  envsubst '$BASE_DOMAIN' < ./config/dnsmasq.conf.template > config/dnsmasq.conf
  echo "✔ config/dnsmasq.conf generated"
}

if [ "$ACTION" = "render" ]; then
  render_lmconf
  render_dnsmasq
  exit 0
fi

if [ "$ACTION" = "up" ]; then
  render_lmconf
  render_dnsmasq

  if [ "${CERT_MODE:-self-signed}" = "letsencrypt" ] || \
     [ ! -f "traefik/ssl/twake-server.pem" ] || [ ! -f "traefik/ssl/root-ca.crt" ]; then
    echo "Creating certs..."
    ./generate-cert.sh
    CERTS_REGENERATED=true
  fi
fi


sudo docker compose --env-file ../.env "$@"

if [ "${CERTS_REGENERATED:-}" = "true" ]; then
  echo "Certs were regenerated, restarting reverse-proxy..."
  sudo docker compose --env-file ../.env restart reverse-proxy
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
