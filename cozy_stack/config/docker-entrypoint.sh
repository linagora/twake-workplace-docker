#!/bin/sh
set -eu



echo "=========================================================================="
echo "Starting $0, $(date)"
echo "=========================================================================="
echo "=========================================================================="

# --- Add custom CA certificates ---
echo ">>> Adding custom CA certificates..."
if [ -f /usr/local/share/ca-certificates/root-ca.crt ]; then
    update-ca-certificates
fi
# ----------------------------------

# Prepare stepping down from root to applicative user with chosen UID/GID
USER_ID=${LOCAL_USER_ID:-3552}
GROUP_ID=${LOCAL_GROUP_ID:-3552}
getent group cozy >/dev/null 2>&1 || \
    groupadd -g "${GROUP_ID}" -o cozy
getent passwd cozy >/dev/null 2>&1 || \
    useradd --shell /bin/bash -u "${USER_ID}" -g cozy -o -c "Cozy Stack user" -d /var/lib/cozy -m cozy
chown -R cozy: /var/lib/cozy

# Generate passphrase if missing
if [ ! -f /etc/cozy/cozy-admin-passphrase ]; then
  if [ -z "${COZY_ADMIN_PASSPHRASE:-}" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "COZY_ADMIN_PASSPHRASE not set."
    echo "Using random Cozy admin passphrase !!!"
    COZY_ADMIN_PASSPHRASE="$(tr -dc '[:alpha:]' </dev/urandom | fold -w 12 | head -n 1)"
    echo "COZY_ADMIN_PASSPHRASE set to ${COZY_ADMIN_PASSPHRASE}"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  fi
  echo "Generating /var/lib/cozy/cozy-admin-passphrase..."
  COZY_ADMIN_PASSPHRASE="${COZY_ADMIN_PASSPHRASE}" cozy-stack -c /dev/null config passwd /etc/cozy/cozy-admin-passphrase
  chown cozy: /etc/cozy/cozy-admin-passphrase
  chmod u=r,og= /etc/cozy/cozy-admin-passphrase
fi

# Generate vault keys if needed
if [ ! -f /etc/cozy/vault.enc ] || [ ! -f /etc/cozy/vault.dec ]; then
  cozy-stack -c /dev/null config gen-keys /etc/cozy/vault
  chown cozy: /etc/cozy/vault.enc /etc/cozy/vault.dec
  chmod u=rw,og= /etc/cozy/vault.enc /etc/cozy/vault.dec
fi

# Start postfix if required
if [ "${START_EMBEDDED_POSTFIX:-}" = "true" ]; then
  # Set-up dns resolution in postfix chroot at runtime and start postfix
  [ ! -d /var/spool/postfix/etc ] && mkdir -p /var/spool/postfix/etc
  cp /etc/resolv.conf /var/spool/postfix/etc
  chown -R postfix /var/spool/postfix/etc
  postfix start
fi

if echo "$@" | grep -q "cozy-stack "; then
  # Refuse to start on an unrendered or half-rendered config. cozy.yaml is
  # bind-mounted verbatim, so a file still carrying the render placeholders
  # breaks the stack: __DEFAULT_ markers make cozy-stack fail to parse the
  # config, and an empty BASE_DOMAIN (e.g. https://auth./) produces a stack
  # that boots but has broken OIDC login. The host wrapper guards its own
  # render, but a bare `docker compose up` bypasses it; this is the last line
  # of defense. See docs/cozy-defaults.md ("Resetting a polluted stack").
  CONFIG=/etc/cozy/cozy.yaml
  if [ ! -f "${CONFIG}" ]; then
    echo "FATAL: ${CONFIG} is missing. Render it with cozy_stack/compose-wrapper.sh before starting." >&2
    exit 1
  fi
  if grep -q '__DEFAULT_' "${CONFIG}"; then
    echo "FATAL: ${CONFIG} still contains __DEFAULT_ markers (config was not rendered through compose-wrapper.sh)." >&2
    exit 1
  fi
  if grep -q '${BASE_DOMAIN}' "${CONFIG}"; then
    echo "FATAL: ${CONFIG} still contains a literal \${BASE_DOMAIN} (render did not substitute the domain)." >&2
    exit 1
  fi
  if grep -Eq 'https://[a-z0-9-]*\./' "${CONFIG}"; then
    echo "FATAL: ${CONFIG} has an empty BASE_DOMAIN (e.g. https://auth./); re-render with ../.env loaded." >&2
    exit 1
  fi

  # Ensure CouchDB is ready if running an applicative subcommand
  echo "Waiting for CouchDB to be available..."
  wait-for-it.sh -h "${COUCHDB_HOST}" -p "${COUCHDB_PORT}" -t 60

  echo "Init CouchDB databases, nothing will happen if they already exists..."
  for db in _users _replicator; do
    curl -sSL -X PUT --user "${COUCHDB_USER}:${COUCHDB_PASSWORD}" "${COUCHDB_PROTOCOL}://${COUCHDB_HOST}:${COUCHDB_PORT}/${db}" || ( echo "Failed to create database ${db}"; exit 1 )
  done

  # Then run the command itself as applicative user
  echo "Now running CMD with UID ${USER_ID} and GID ${GROUP_ID}"
  exec gosu cozy "$@"
else
  # Otherwise run the command as root
  exec "$@"
fi
