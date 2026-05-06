#!/usr/bin/env bash
# Import users into LDAP via the ldap-rest SCIM 2.0 endpoint.
#
# Reads a JSON array from the file you pass as the first argument and POSTs
# each entry to /scim/v2/Users. The cozyProvision plugin picks up the SCIM
# create hook, provisions the cozy instance, then publishes auth/user.created
# on RabbitMQ for cozy-stack to consume.
#
# Usage:
#   scripts/scim-import-users.sh <path/to/users.json> [--dry-run]
#
# Each entry in the JSON array can be either:
#   - a full SCIM User object (with `schemas`), passed through verbatim, or
#   - a shorthand: { "userName", "givenName", "familyName", "email", "active" }
#     plus any extra top-level fields (displayName, title, phoneNumbers, …)
#     which get merged onto the synthesized SCIM body.
#
# Environment overrides:
#   ENV_FILE         — alternate .env path (default: <repo>/.env)
#   LDAP_REST_HOST   — alternate ldap-rest URL (default: https://ldap-rest.${BASE_DOMAIN})
#
# See scripts/users.example.json for a worked example.

set -euo pipefail

usage() {
  sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env}"

DRY_RUN=0
INPUT=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    -*)        echo "ERR: unknown option: $arg" >&2; usage >&2; exit 2 ;;
    *)
      [[ -n "$INPUT" ]] && { echo "ERR: only one input file expected" >&2; usage >&2; exit 2; }
      INPUT="$arg" ;;
  esac
done

if [[ -z "$INPUT" ]]; then
  echo "ERR: missing input file" >&2
  usage >&2
  exit 2
fi

[[ -f "$ENV_FILE" ]] || { echo "ERR: .env not found at $ENV_FILE" >&2; exit 1; }
[[ -f "$INPUT" ]]    || { echo "ERR: input file not found: $INPUT" >&2; exit 1; }
command -v jq >/dev/null || { echo "ERR: jq is required. Install: sudo apt-get install -y jq (Debian/Ubuntu) or equivalent." >&2; exit 1; }

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a
: "${LDAP_REST_ADMIN_TOKEN:?missing in .env}"
: "${BASE_DOMAIN:?missing in .env}"

HOST="${LDAP_REST_HOST:-https://ldap-rest.${BASE_DOMAIN}}"

count=$(jq 'length' "$INPUT")

# userName becomes the cozy instance subdomain. Stricter than cozy-stack's own
# check because underscores, dots, and uppercase break traefik / lemonldap
# elsewhere in the stack.
slug_re='^[a-z0-9](([a-z0-9-]*[a-z0-9])?)$'
invalid=()
i=0
while IFS= read -r uname; do
  if [[ -z "$uname" ]]; then
    invalid+=("entry #$i: missing userName")
  elif (( ${#uname} > 63 )); then
    invalid+=("$uname: longer than 63 chars")
  elif ! [[ "$uname" =~ $slug_re ]]; then
    invalid+=("$uname: not a valid DNS label (lowercase letters, digits, hyphens; no leading/trailing hyphen)")
  fi
  i=$((i + 1))
done < <(jq -r '.[].userName // ""' "$INPUT")
if (( ${#invalid[@]} > 0 )); then
  echo "ERR: invalid userName(s), nothing imported:" >&2
  printf '  - %s\n' "${invalid[@]}" >&2
  exit 1
fi

echo "→ Importing $count user(s) from $INPUT"
echo "  target: $HOST/scim/v2/Users"
[[ $DRY_RUN -eq 1 ]] && echo "  (dry-run: no requests will be sent)"
echo

ok=0; fail=0
for i in $(seq 0 $((count - 1))); do
  # Build the SCIM body. Three modes, in priority order:
  #   1. Entry already has `schemas` -> pass through verbatim.
  #   2. Otherwise, expand the shorthand keys (userName/givenName/familyName/
  #      email/active) into a SCIM body, then merge any extra top-level fields
  #      from the entry on top (displayName, title, phoneNumbers, externalId,
  #      preferredLanguage, custom extension URNs, ...). The user's explicit
  #      `name` / `emails` override the synthesized ones if both are present.
  body=$(jq -c --arg idx "$i" '
    .[($idx | tonumber)] as $e |
    if ($e | has("schemas")) then $e
    else
      ({
        schemas: ["urn:ietf:params:scim:schemas:core:2.0:User"],
        userName: $e.userName,
        name: { givenName: ($e.givenName // ""), familyName: ($e.familyName // "") },
        emails: (if $e.email then [{ value: $e.email, primary: true }] else [] end),
        active: ($e.active // true)
      }) as $base |
      ($e | del(.userName, .givenName, .familyName, .email, .active)) as $extra |
      $base + $extra
    end
  ' "$INPUT")

  uname=$(jq -r '.userName' <<<"$body")
  printf "  %-24s ... " "$uname"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "(dry-run)"
    jq . <<<"$body" | sed 's/^/      /'
    continue
  fi

  tmp=$(mktemp)
  http=$(curl -k -sS -o "$tmp" -w "%{http_code}" \
    -X POST "$HOST/scim/v2/Users" \
    -H "Authorization: Bearer $LDAP_REST_ADMIN_TOKEN" \
    -H "Content-Type: application/scim+json" \
    -d "$body" || echo "000")

  if [[ "$http" =~ ^2 ]]; then
    echo "OK ($http)"
    ok=$((ok+1))
  else
    echo "FAIL ($http)"
    sed 's/^/      /' "$tmp"; echo
    fail=$((fail+1))
  fi
  rm -f "$tmp"
done

echo
if [[ $DRY_RUN -eq 0 ]]; then
  echo "Done: $ok created, $fail failed"
  [[ $fail -eq 0 ]]
fi
