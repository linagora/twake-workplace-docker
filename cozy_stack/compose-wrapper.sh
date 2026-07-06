#!/bin/bash
# compose-wrapper.sh
set -e

ACTION="$1"
# Load environment variables
set -a
source ../.env
set +a

# pick_default returns the path of the *.local.yaml override if it exists,
# else the committed default file. Lets operators override the cozy default
# context (feature flags, sharing trust) per deployment without modifying
# tracked files.
pick_default() {
  local name="$1"
  if [ -f "config/${name}.local.yaml" ]; then
    echo "config/${name}.local.yaml"
  else
    echo "config/${name}.yaml"
  fi
}

# splice replaces a marker line in the rendered cozy.yaml with the contents
# of $2, indented by $3 spaces. Both the template and the spliced files go
# through envsubst for $BASE_DOMAIN expansion. The body is passed through
# ENVIRON rather than awk's -v so backslashes in operator overrides are not
# interpreted as escape sequences during assignment.
splice() {
  local marker="$1" file="$2" indent="$3"
  local pad
  pad=$(printf '%*s' "$indent" '')
  SPLICE_BODY=$(envsubst '$BASE_DOMAIN' < "$file" | sed "s/^/${pad}/")
  export SPLICE_BODY
  awk -v m="$marker" 'BEGIN{r=ENVIRON["SPLICE_BODY"]} $0 == m {print r; next} {print}' \
    config/cozy.yaml > config/cozy.yaml.tmp
  unset SPLICE_BODY
  mv config/cozy.yaml.tmp config/cozy.yaml
}

if [ "$ACTION" = "up" ] || [ "$ACTION" = "render" ]; then
  echo "Processing configuration..."
  envsubst '$BASE_DOMAIN' < ./config/cozy.yaml.template > config/cozy.yaml

  flags_file=$(pick_default default-flags)
  sharing_file=$(pick_default default-sharing)
  echo "  flags:   $flags_file"
  echo "  sharing: $sharing_file"
  splice '__DEFAULT_FLAGS__'   "$flags_file"   6
  splice '__DEFAULT_SHARING__' "$sharing_file" 6

  # cozy-stack runs inside the container as a non-root uid (3552). The bind-
  # mounted config has to be readable by it regardless of the host operator's
  # umask, so force a sane mode after the splice.
  chmod 644 config/cozy.yaml

  if [ "$ACTION" = "render" ]; then exit 0; fi
fi


# Pass all arguments to docker compose. When a dev app is requested, merge the
# dev-app overlay (bind mount + serve --dev). Unset => base stack, unchanged.
COMPOSE_FILES="-f docker-compose.yml"
if [ -n "${COZY_DEV_APP_SLUG:-}" ]; then
  if [ -z "${COZY_DEV_APP_BUILD:-}" ]; then
    echo "❌ COZY_DEV_APP_SLUG is set but COZY_DEV_APP_BUILD (abs path to app build/) is empty" >&2
    exit 1
  fi
  echo "▶ Dev app override: ${COZY_DEV_APP_SLUG} <- ${COZY_DEV_APP_BUILD}"
  COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.dev-app.yml"
fi
# shellcheck disable=SC2086
sudo docker compose --env-file ../.env $COMPOSE_FILES "$@"
