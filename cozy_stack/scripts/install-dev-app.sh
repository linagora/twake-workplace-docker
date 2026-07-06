#!/usr/bin/env bash
# install-dev-app.sh — install a locally-built cozy-web app into a provisioned
# instance from the bind-mounted /app/<slug> (see docker-compose.dev-app.yml).
# Idempotent: installs only if the app is not already present on the instance.
# In `serve --dev` the mounted build is served live, so rebuilds need no reinstall.
set -euo pipefail

CONTAINER="cozyt"
SLUG=""
DOMAIN=""
DRY_RUN=0

USAGE="usage: install-dev-app.sh --slug <slug> --domain <userName>.<BASE_DOMAIN> [--container cozyt] [--dry-run]"

while [ $# -gt 0 ]; do
  case "$1" in
    --slug) [ $# -ge 2 ] || { echo "$USAGE" >&2; exit 1; }; SLUG="$2"; shift 2 ;;
    --domain) [ $# -ge 2 ] || { echo "$USAGE" >&2; exit 1; }; DOMAIN="$2"; shift 2 ;;
    --container) [ $# -ge 2 ] || { echo "$USAGE" >&2; exit 1; }; CONTAINER="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$SLUG" ] || [ -z "$DOMAIN" ]; then
  echo "$USAGE" >&2
  exit 1
fi

# Guard against shell-metacharacter injection into the nested `sh -c` below:
# slug and domain must be simple identifiers.
case "$SLUG" in *[!a-zA-Z0-9_-]*) echo "invalid --slug '$SLUG' (allowed: a-z A-Z 0-9 _ -)" >&2; exit 1 ;; esac
case "$DOMAIN" in *[!a-zA-Z0-9.-]*) echo "invalid --domain '$DOMAIN' (allowed: a-z A-Z 0-9 . -)" >&2; exit 1 ;; esac

INSTALL_CMD="cozy-stack apps show '$SLUG' --domain '$DOMAIN' >/dev/null 2>&1 || cozy-stack apps install '$SLUG' 'file:///app/$SLUG' --domain '$DOMAIN'"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "docker exec $CONTAINER sh -c \"$INSTALL_CMD\""
  exit 0
fi

echo "▶ Installing dev app '$SLUG' into $DOMAIN (idempotent)"
docker exec "$CONTAINER" sh -c "$INSTALL_CMD"
echo "✔ Dev app '$SLUG' present on $DOMAIN"
