#!/bin/bash
# Seeds the demo organization, twakeDemo (ORGANIZATION_ID in .env):
#   1. the account named after the organization, which holds its organization
#      instance, then three members, each with its login as password;
#   2. their LDAP organization (the org_id claim), as ldap-ensure sets it on
#      every up;
#   3. the shared drives feature flag on their instances.
# Run it once the stack is up (./wrapper.sh up -d --drive at least). Accounts
# that already exist are left as they are.
set -euo pipefail

cd "$(dirname "$0")/.."
set -a
# shellcheck disable=SC1091
. ./.env
set +a

ORG="${ORGANIZATION_ID:?ORGANIZATION_ID missing from .env}"
EXISTING=$(scripts/twake users list)

add() {
  if grep -qw -- "$1" <<<"$EXISTING"; then
    echo "✔ $1 already exists"
    return
  fi
  scripts/twake users add "$1" --email "$1@${BASE_DOMAIN}" \
    --given-name "$2" --family-name "$3" --password "$1"
}

# The organization instance first: a member's user.created looks it up
add "$ORG" twakeDemo Organization
for n in 1 2 3; do
  add "$ORG$n" "Demo $n" twakeDemo
done

(cd twake_db && ./compose-wrapper.sh run --rm ldap-ensure)

for login in "$ORG" "${ORG}1" "${ORG}2" "${ORG}3"; do
  scripts/twake flags set "$login" drive.shared-drive.enabled=true
done
