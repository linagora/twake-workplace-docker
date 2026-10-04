#!/bin/sh
# Brings an existing LDAP up to date. The osixia bootstrap (schema/ and
# bootstrap/) only runs on an empty volume, so what was added later is applied
# here, idempotently.
set -eu

URI=ldap://ldap
BIND_DN="cn=admin,${LDAP_BASE_DN}"
BIND_PW=admin
CONFIG_DN=cn=admin,cn=config
CONFIG_PW=config

# twakeUser schema (workspaceUrl)
if ! ldapsearch -x -H "$URI" -D "$CONFIG_DN" -w "$CONFIG_PW" -b cn=Subschema -s base -LLL \
    objectClasses | grep -q "NAME 'twakeUser'"; then
  echo "Adding the twakeUser schema"
  ldapadd -x -H "$URI" -D "$CONFIG_DN" -w "$CONFIG_PW" -f /schema/03-twake-user.ldif
fi

# twakeInstance schema (twakeCreatedEventAt), required by ldap-rest's twake/instances
if ! ldapsearch -x -H "$URI" -D "$CONFIG_DN" -w "$CONFIG_PW" -b cn=Subschema -s base -LLL \
    objectClasses | grep -q "NAME 'twakeInstance'"; then
  echo "Adding the twakeInstance schema"
  ldapadd -x -H "$URI" -D "$CONFIG_DN" -w "$CONFIG_PW" -f /schema/04-twake-instance.ldif
fi

# Accounts written before twake/instances lack the classes its writes need, and
# ldap-rest only repairs the classes its flat schema declares for ou=users
for OC in twakeUser twakeInstance; do
  ldapsearch -x -H "$URI" -D "$BIND_DN" -w "$BIND_PW" -b "ou=users,${LDAP_BASE_DN}" \
    -s one -LLL -o ldif-wrap=no "(!(objectClass=${OC}))" 1.1 \
    | awk -v oc="$OC" '/^dn::? /{print; print "changetype: modify"; print "add: objectClass"; print "objectClass: " oc; print ""}' \
    | ldapmodify -x -H "$URI" -D "$BIND_DN" -w "$BIND_PW"
done

# workplace FQDN of the demo users, exported as the workplaceFqdn OIDC claim
for USER in user1 user2 user3; do
  DN="uid=${USER},ou=users,${LDAP_BASE_DN}"
  ENTRY=$(ldapsearch -x -H "$URI" -D "$BIND_DN" -w "$BIND_PW" -b "$DN" -s base -LLL \
    workspaceUrl 2>/dev/null || true)
  [ -n "$ENTRY" ] || continue
  if echo "$ENTRY" | grep -q '^workspaceUrl:'; then
    continue
  fi
  echo "Setting workspaceUrl on $DN"
  {
    echo "dn: $DN"
    echo "changetype: modify"
    echo "add: workspaceUrl"
    echo "workspaceUrl: ${USER}.${BASE_DOMAIN}"
  } | ldapmodify -x -H "$URI" -D "$BIND_DN" -w "$BIND_PW"
done
