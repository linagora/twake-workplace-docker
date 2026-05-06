# SCIM import: worked example

End-to-end run of the bulk user import against a deployed stack. Assumes the stack is up, `.env` populated, and the cozy-stack version is at least `1.6.50-rc1` (see [operations.md](operations.md)).

## 1. Prepare `users.json`

Each entry needs a valid `userName`, given/family name, and email. The `userName` becomes the cozy instance subdomain and (in OIDC mode) must match the OP's `sub` claim for that user.

```json
[
  {
    "userName": "alice",
    "givenName": "Alice",
    "familyName": "DURAND",
    "email": "alice@example.org"
  },
  {
    "userName": "bob",
    "givenName": "Bob",
    "familyName": "MARTIN",
    "email": "bob@example.org"
  }
]
```

`userName` must be a valid DNS label: lowercase letters, digits, hyphens, no leading or trailing hyphen, ≤63 chars. The script rejects the whole batch if any entry fails this check.

## 2. Run the import

```bash
./scripts/scim-import-users.sh scripts/users.json
```

To target a remote deployment without changing `.env`:

```bash
LDAP_REST_HOST=https://ldap-rest.example.org ./scripts/scim-import-users.sh scripts/users.json
```

Use `--dry-run` to print the SCIM bodies without sending anything.

A clean run looks like:

```
→ Importing 2 user(s) from scripts/users.json
  target: https://ldap-rest.example.org/scim/v2/Users

  alice                    ... OK (201)
  bob                      ... OK (201)

Done: 2 created, 0 failed
```

`409 uniqueness` means the user already exists in LDAP; `4xx` other than 409 is a real failure, with the response body printed inline.

## 3. Verify each layer

The import touches LDAP, cozy-stack, and RabbitMQ. Check all three.

**LDAP.** The SCIM list shows the new entries:

```bash
curl -k -sS -H "Authorization: Bearer $LDAP_REST_ADMIN_TOKEN" \
  https://ldap-rest.example.org/scim/v2/Users | jq -r '.Resources[] | "\(.id)\t\(.userName)"'
```

**Cozy instances.** One per imported user, status `onboarded`:

```bash
docker exec cozyt cozy-stack instances ls
```

For each instance, `oidc_id` should equal the `userName`:

```bash
docker exec cozyt cozy-stack instances ls --json | jq 'select(.oidc_id != null) | {domain, oidc_id}'
```

**Cozy-stack consumed the events.** Tail the cozyt log around the import. You want a `skipping passphrase update` line per user (the OIDC bypass) and a `created organization contact` line for each cross-instance pairing:

```bash
docker logs --since 5m cozyt 2>&1 | grep -E "user\.created|skipping passphrase|organization contact|nacking"
```

A failed message ends with `nacking message`; on `1.6.50-rc1+` the only common nack is `organization has no instances`, which only fires if the instance lookup races the consumer (rare and self-healing on the next message).

**RabbitMQ queues drained:**

```bash
docker exec rabbitmq rabbitmqctl list_queues name messages consumers \
  | grep -E 'stack\.user\.created|auth\.dlq'
```

`messages` should be 0 and `consumers` ≥ 1. Anything in `auth.dlq` is a hard failure: the message landed in the dead-letter queue after exhausting retries.

## 4. Login flow (when AUTH_MODE=OpenIDConnect)

Open `https://<userName>.<BASE_DOMAIN>` in an incognito window. The flow is OP login → LemonLDAP callback → cozy redirect → instance home. If you see "Error during authentication with OpenID Provider", read [external-oidc.md](external-oidc.md).

## Cleanup

`SCIM DELETE` removes the LDAP entry but does not destroy the cozy instance. A subsequent `POST` for the same `userName` re-attaches to the existing instance, which can leave `oidc_id` set to a stale value. For a real reset:

```bash
# delete via SCIM (clears LDAP)
curl -k -sS -X DELETE -H "Authorization: Bearer $LDAP_REST_ADMIN_TOKEN" \
  https://ldap-rest.example.org/scim/v2/Users/alice

# destroy the cozy instance
docker exec cozyt cozy-stack instances destroy alice.example.org --force
```

Then re-import.
