# B2C accounts and the demo organization

The stack holds two kinds of accounts:

- B2C accounts belong to no organization. user1, user2 and user3 are B2C. They
  have Drive and Twake Tasks; Twake Space refuses them (HTTP 403).
- The accounts of the demo organization, twakeDemo, have Drive, Twake Tasks and
  Twake Space.

## The demo organization

- Its id is `ORGANIZATION_ID` in `.env`, `twakedemo` by default. Use lowercase
  letters and digits only: cozy-stack refuses a hyphen in an instance name and
  compares the id with the instance name as is.
- An account belongs to it when its login starts with the id. The rule applies
  in LDAP (`twakeOrganizationId`, exported by LemonLDAP as the `org_id` claim)
  and in cozy-stack (the instance's `org_id`). Write logins in lowercase:
  ldap-rest matches them in any case but gives cozy-stack the id as written.
- The account named exactly `twakedemo` holds the organization instance, where
  the organization's shared drives live. It is no member in LDAP, so Twake Space
  does not list it.
- `twakedemo1` owns the organization; the other accounts are members.

`scripts/seed-organization.sh` creates the organization once the stack is up:

```bash
./wrapper.sh up -d --drive
scripts/seed-organization.sh
```

Each account's password is its login:

- `twakedemo1`, `twakedemo2`, `twakedemo3` on `https://<login>.twake.local`;
- `twakedemo`, the organization's own account.

## Add an account

A B2C account, with a login that does not start with the organization id:

```bash
scripts/twake users add alice --email alice@twake.local \
  --given-name Alice --family-name Martin --password alice
```

A member of the organization, with a login that starts with it:

```bash
scripts/twake users add twakedemo4 --email twakedemo4@twake.local \
  --given-name "Demo 4" --family-name twakeDemo --password twakedemo4
(cd twake_db && ./compose-wrapper.sh run --rm ldap-ensure)
scripts/twake flags set twakedemo4 drive.shared-drive.enabled=true
```

cozy-stack gets the organization when the account is created. LDAP gets it from
`ldap-ensure`, which also runs on every `up`. Until then, the account has no
`org_id` claim.

cozy-stack reaches the organization's instances through Traefik, with one
`extra_hosts` entry per instance in `cozy_stack/docker-compose.yml`, from
`twakedemo` to `twakedemo3`. Add `"twakedemo4.${BASE_DOMAIN}:172.27.0.100"`
there for twakedemo4 to receive shared drives.

## Groups and shared drives

- A shared drive created on the organization instance is an organization
  drive. The Drive feature flag `drive.shared-drive.enabled` is set on the
  organization's instances only.
- cozy-stack takes the group events of the `b2b` exchange on
  `stack.b2b.group.lifecycle`, with its dead letter queue
  `stack.dead.letter.b2b.group.lifecycle`. Nothing in this stack publishes them
  yet: publish one by hand to create a group or change its members.

  ```bash
  docker exec rabbitmq rabbitmqadmin publish exchange=b2b routing_key=b2b.group.created payload='{
    "timestamp": "2026-11-18T09:00:00Z", "organizationId": "twakedemo",
    "id": "marketing", "name": "Marketing", "createdAt": "2026-11-18T09:00:00Z",
    "members": [{"username": "twakedemo2", "email": "twakedemo2@twake.local",
                 "workplaceFqdn": "twakedemo2.twake.local"}]}'
  ```

  `b2b.group.member.added` and `b2b.group.member.removed` take the same
  `organizationId`, `id` and `members`.
- A drive shared with a group reaches its members, and a member added to or
  removed from the group later gains or loses it, through the `share-group`
  worker. The other `share-*` workers stay off.
- `COZY_CENTRALIZED_ORG_DIRECTORY` in `.env` is `true`: the organization's
  contacts and groups live on the organization instance only, and a member
  added to a group later gets the group's drives. With `false`, each member
  instance keeps a copy, but a member added later only gets an invitation.
  cozy-stack's own docs advise `false` while the sharing dialog reads the local
  contacts: with `true`, a member's sharing dialog may not list colleagues.

## A stack provisioned before this layout

Before this layout, `ldap-ensure` put every account in `twake-demo` in LDAP, and
every instance ldap-rest created got `COZY_ORG_ID` (`twp-docker`, then
`twpdocker`). `.env` is tracked: a pull replaces both values unless you changed
them. Nothing already written in LDAP or cozy-stack changes.

To keep such a stack running as before, set back in `.env`:

- `ORGANIZATION_ID=twake-demo` and your former `COZY_ORG_ID`. An instance keeps
  the `org_id` it was created with and cozy-stack cannot change it, so new
  instances join the organization of the old ones, and Twake Space and the
  Matrix spaces of tom-bridge keep `twake-demo`.
- `COZY_CENTRALIZED_ORG_DIRECTORY=false`. That organization has no
  organization instance, and with the directory centralized cozy-stack does not
  sync a new member's contact: its `user.created` ends in the dead letter
  queue.

No login starts with `twake-demo`, so new accounts get no LDAP organization,
hence no Twake Space. user1, user2 and user3 keep theirs. To make them B2C,
remove it (`-c` goes on past an account that has none):

```bash
. ./.env
for u in user1 user2 user3; do
  printf 'dn: uid=%s,ou=users,%s\nchangetype: modify\ndelete: twakeOrganizationId\n-\ndelete: twakeOrganizationRole\n\n' \
    "$u" "$LDAP_BASE_DN"
done | docker exec -i ldap ldapmodify -c -x -H ldap://localhost -D "cn=admin,$LDAP_BASE_DN" -w admin
```
