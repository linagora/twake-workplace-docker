#!/bin/bash
# Creates a demo space in Twake Space, as ldap-rest and the Mail side service
# would in a B2B Twake Workplace:
#   1. the organization in Twake Space's database, mail and chat on (the public
#      ldap-rest has no organization route for Twake Space to read it from);
#   2. a team mailbox in TMail (webadmin), its members the space's;
#   3. twake.space.created on the `space` exchange: Twake Tasks creates the
#      project and tells Twake Space;
#   4. com.twake.mail.space.provisioned.v1 on `activity`, with the root
#      mailbox of the team mailbox: the Mail tab frames its facade.
#
# Usage: ./seed-space.sh "Space name" [admin [member...]]
#   ./seed-space.sh "Demo"                  # user1 admin, user2 editor
#   ./seed-space.sh "Roadmap" user2 user1 user3
# The demo users must be in the organization (ldap-ensure, ORGANIZATION_ID).
set -euo pipefail

cd "$(dirname "$0")"
set -a
# shellcheck disable=SC1091
. ../.env
set +a

NAME="${1:?Usage: $0 \"Space name\" [admin [member...]]}"
shift
[ $# -gt 0 ] || set -- user1 user2
ADMIN=$1
shift
MEMBERS=("$@")

ORG="${ORGANIZATION_ID:?ORGANIZATION_ID missing from .env}"
SPACE_ID=$(uuidgen)
NOW=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
# Team mailbox name: the space name, lower case, letters and digits
TEAM=$(echo "$NAME" | iconv -f utf-8 -t ascii//TRANSLIT | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')
TEAM="space-${TEAM:-demo}"

webadmin() {
  docker exec tmail-backend curl -sf -X "$1" "http://localhost:8000$2"
}

# A member of the space, as ldap-rest describes it, from the LDAP
member() {
  local uid=$1 role=$2 entry
  entry=$(docker exec ldap ldapsearch -x -H ldap://localhost \
    -D "cn=admin,${LDAP_BASE_DN}" -w admin \
    -b "uid=${uid},ou=users,${LDAP_BASE_DN}" -s base -LLL \
    entryUUID mail givenName sn twakeOrganizationId)
  local org
  org=$(echo "$entry" | awk '/^twakeOrganizationId:/ {print $2}')
  [ "$org" = "$ORG" ] || { echo "ERROR: $uid is not in the organization $ORG" >&2; exit 1; }
  jq -cn --arg uuid "$(echo "$entry" | awk '/^entryUUID:/ {print $2}')" \
    --arg username "$uid" \
    --arg email "$(echo "$entry" | awk '/^mail:/ {print $2}')" \
    --arg firstName "$(echo "$entry" | sed -n 's/^givenName: //p')" \
    --arg lastName "$(echo "$entry" | sed -n 's/^sn: //p')" \
    --arg role "$role" \
    '{uuid: $uuid, username: $username, email: $email, firstName: $firstName, lastName: $lastName, role: $role}'
}

publish() {
  local exchange=$1 key=$2 id=$3 body=$4
  docker exec rabbitmq rabbitmqadmin publish exchange="$exchange" \
    routing_key="$key" payload="$body" \
    properties="{\"message_id\":\"$id\",\"content_type\":\"application/json\"}" >/dev/null
}

echo "==> Organization $ORG in Twake Space (mail and chat on)"
docker exec postgres psql -q -U postgres -d twake_space -c \
  "INSERT INTO organizations (organization_id, domain, mail_available, chat_available)
   VALUES ('$ORG', '$MAIL_DOMAIN', true, true)
   ON CONFLICT (organization_id) DO UPDATE SET mail_available = true, chat_available = true"

members=$(member "$ADMIN" admin) || exit 1
for uid in "${MEMBERS[@]}"; do
  editor=$(member "$uid" editor) || exit 1
  members="$members
$editor"
done
members_json=$(echo "$members" | jq -sc .)

echo "==> Team mailbox $TEAM@$MAIL_DOMAIN"
webadmin PUT "/domains/$MAIL_DOMAIN/team-mailboxes/$TEAM" >/dev/null
for uid in $(echo "$members_json" | jq -r '.[].email'); do
  webadmin PUT "/domains/$MAIL_DOMAIN/team-mailboxes/$TEAM/members/$uid" >/dev/null
done
MAILBOX_ID=$(webadmin GET "/domains/$MAIL_DOMAIN/team-mailboxes/$TEAM/mailboxes" \
  | jq -r --arg team "$TEAM" '.[] | select(.mailboxName == $team) | .mailboxId')
[ -n "$MAILBOX_ID" ] || { echo "ERROR: no root mailbox for $TEAM" >&2; exit 1; }

echo "==> Space \"$NAME\" ($SPACE_ID)"
publish space twake.space.created "seed-$SPACE_ID" "$(jq -cn \
  --arg org "$ORG" --arg id "$SPACE_ID" --arg name "$NAME" --arg now "$NOW" \
  --argjson members "$members_json" \
  '{organizationId: $org, id: $id, name: $name, members: $members, groups: [], timestamp: $now}')"

echo "==> Mail resource: root mailbox $MAILBOX_ID"
publish activity com.twake.mail.space.provisioned.v1 "seed-mail-$SPACE_ID" "$(jq -cn \
  --arg org "$ORG" --arg space "$SPACE_ID" --arg mailbox "$MAILBOX_ID" --arg now "$NOW" \
  '{specversion: "1.0", id: ("mail-space-provisioned-" + $space), source: "twake://mail",
    type: "com.twake.mail.space.provisioned.v1", time: $now, twakeorg: $org,
    datacontenttype: "application/json",
    data: {space_id: $space, resource: {kind: "mailbox", id: $mailbox}}}')"

printf '==> Waiting for the Tasks project'
for _ in $(seq 1 30); do
  project=$(docker exec postgres psql -tA -U postgres -d twake_space -c \
    "SELECT resource_id FROM space_resources WHERE space_id = '$SPACE_ID' AND kind = 'project'" 2>/dev/null || true)
  [ -n "$project" ] && break
  printf '.'; sleep 2
done
echo " ${project:-not yet (see docker logs twake-tasks-backend)}"
echo "OK: https://space.${BASE_DOMAIN}/spaces/$SPACE_ID"
