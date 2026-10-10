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

# twakeOrganizationMember schema (twakeOrganizationId, twakeOrganizationRole)
if ! ldapsearch -x -H "$URI" -D "$CONFIG_DN" -w "$CONFIG_PW" -b cn=Subschema -s base -LLL \
    objectClasses | grep -q "NAME 'twakeOrganizationMember'"; then
  echo "Adding the twakeOrganizationMember schema"
  ldapadd -x -H "$URI" -D "$CONFIG_DN" -w "$CONFIG_PW" -f /schema/05-twake-organization.ldif
fi

# workplace FQDN of the demo users, exported as the workplaceFqdn OIDC claim
for USER in user1 user2 user3; do
  DN="uid=${USER},ou=users,${LDAP_BASE_DN}"
  ENTRY=$(ldapsearch -x -H "$URI" -D "$BIND_DN" -w "$BIND_PW" -b "$DN" -s base -LLL \
    objectClass workspaceUrl 2>/dev/null || true)
  [ -n "$ENTRY" ] || continue
  if echo "$ENTRY" | grep -q '^workspaceUrl:'; then
    continue
  fi
  echo "Setting workspaceUrl on $DN"
  {
    echo "dn: $DN"
    echo "changetype: modify"
    if ! echo "$ENTRY" | grep -qi '^objectClass: twakeUser$'; then
      echo "add: objectClass"
      echo "objectClass: twakeUser"
      echo "-"
    fi
    echo "add: workspaceUrl"
    echo "workspaceUrl: ${USER}.${BASE_DOMAIN}"
  } | ldapmodify -x -H "$URI" -D "$BIND_DN" -w "$BIND_PW"
done

# Organization mode: every account belongs to ORGANIZATION_ID, exported as the
# org_id OIDC claim (Twake Space and Twake Tasks refuse users without it).
# user1 owns it.
for USER in $(ldapsearch -x -H "$URI" -D "$BIND_DN" -w "$BIND_PW" -b "ou=users,${LDAP_BASE_DN}" \
    -s one -LLL uid | sed -n 's/^uid: //p'); do
  DN="uid=${USER},ou=users,${LDAP_BASE_DN}"
  ENTRY=$(ldapsearch -x -H "$URI" -D "$BIND_DN" -w "$BIND_PW" -b "$DN" -s base -LLL \
    objectClass twakeOrganizationId 2>/dev/null || true)
  [ -n "$ENTRY" ] || continue
  if echo "$ENTRY" | grep -q "^twakeOrganizationId: ${ORGANIZATION_ID}\$"; then
    continue
  fi
  ROLE=member
  [ "$USER" = user1 ] && ROLE=owner
  echo "Putting $DN in the organization ${ORGANIZATION_ID} ($ROLE)"
  {
    echo "dn: $DN"
    echo "changetype: modify"
    if ! echo "$ENTRY" | grep -qi '^objectClass: twakeOrganizationMember$'; then
      echo "add: objectClass"
      echo "objectClass: twakeOrganizationMember"
      echo "-"
    fi
    echo "replace: twakeOrganizationId"
    echo "twakeOrganizationId: ${ORGANIZATION_ID}"
    echo "-"
    echo "replace: twakeOrganizationRole"
    echo "twakeOrganizationRole: ${ROLE}"
  } | ldapmodify -x -H "$URI" -D "$BIND_DN" -w "$BIND_PW"
done
