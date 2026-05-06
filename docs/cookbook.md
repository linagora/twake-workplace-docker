# Operator cookbook

Command-first reference for the things you do most often. For the why and the deeper walkthroughs, follow the cross-references back into the topic-specific docs.

All `docker exec` commands assume the host. Wrap with `ssh <host> '<command>'` if you're remote and replace `docker` with `sudo docker` if your operator user is not in the docker group. The snippets below reference these from the repo's `.env`:

```bash
set -a; source .env; set +a
HOST=https://ldap-rest.${BASE_DOMAIN}
TOKEN=${LDAP_REST_ADMIN_TOKEN}
```

## Listing state

**SCIM users** (everything ldap-rest serves):

```bash
curl -k -sS -H "Authorization: Bearer $TOKEN" "$HOST/scim/v2/Users" \
  | jq -r '.Resources[] | "\(.id)\t\(.userName)\t\(.emails[0].value)"'
```

**Cozy instances**:

```bash
docker exec -e COZY_ADMIN_PASSPHRASE=admin cozyt cozy-stack instances ls
```

`--json` on that command gives the full attributes including `oidc_id` and `context`. Useful when sharing breaks and you suspect a wrong context or a missing `oidc_id`.

**Effective feature flags for one instance** (what the cozy frontend actually reads):

```bash
DOMAIN=<user>.<BASE_DOMAIN>
TOKEN=$(docker exec -e COZY_ADMIN_PASSPHRASE=admin cozyt cozy-stack instances token-app "$DOMAIN" home)
docker exec cozyt curl -sS -H "Authorization: Bearer $TOKEN" -H "Host: $DOMAIN" \
  http://localhost:8080/settings/flags | jq '.data.attributes'
```

Anything wrapped as `[{"ratio":1,"value":...}]` instead of a bare value means the flag is in the wrong YAML shape; see [`cozy-defaults.md`](cozy-defaults.md).

**Sharing docs in an instance** (what the recipient actually has):

```bash
PREFIX=$(docker exec cozyt cozy-stack instances ls --json \
  | jq -r --arg d "$DOMAIN" 'select(.domain==$d).prefix')
docker exec couchdb curl -sS -u admin:password "http://localhost:5984/${PREFIX}%2Fio-cozy-sharings/_all_docs?include_docs=true" \
  | jq '.rows[].doc | select(._id | startswith("_design") | not) | {id: ._id, drive: .drive, owner: .owner, members: [.members[]? | {email, status, instance}]}'
```

## Cleaning up

`SCIM DELETE` removes the LDAP entry but does not destroy the cozy instance. A subsequent `POST` for the same `userName` re-attaches to the existing instance. For a real reset, do both.

**Delete one user end-to-end**:

```bash
docker exec -e COZY_ADMIN_PASSPHRASE=admin cozyt cozy-stack instances destroy \
  <userName>.<BASE_DOMAIN> --force

curl -k -sS -X DELETE -H "Authorization: Bearer $TOKEN" \
  "$HOST/scim/v2/Users/<userName>"
```

**Wipe every imported user** (keeps `admin` and any pre-existing dev users):

```bash
# 1. destroy cozy instances for the users in your import file
for u in $(jq -r '.[].userName' scripts/users.json); do
  docker exec -e COZY_ADMIN_PASSPHRASE=admin cozyt cozy-stack instances destroy \
    "${u}.${BASE_DOMAIN}" --force 2>/dev/null
done

# 2. SCIM-delete the same set
for u in $(jq -r '.[].userName' scripts/users.json); do
  curl -k -sS -X DELETE -H "Authorization: Bearer $TOKEN" \
    -o /dev/null -w "$u %{http_code}\n" "$HOST/scim/v2/Users/$u"
done
```

To reimport, see [`scim-import.md`](scim-import.md).

**Destroy orphan cozy instances** (instances whose SCIM user no longer exists):

```bash
docker exec -e COZY_ADMIN_PASSPHRASE=admin cozyt cozy-stack instances ls \
  | awk '{print $1}' \
  | while read d; do echo "$d"; done   # eyeball, then destroy the ones you don't want
```

## RabbitMQ

**Queue depth and consumers**:

```bash
docker exec rabbitmq rabbitmqctl list_queues name messages consumers
```

You expect `0` messages on `stack.user.created` and `1` consumer (cozy-stack). Anything in the dead-letter queues (`auth.dlq`, `b2b.dlq`) is a hard failure that exhausted retries.

**Inspect dead-letter content** without consuming:

```bash
docker exec rabbitmq rabbitmqadmin \
  --username="$RABBITMQ_USER" --password="$RABBITMQ_PASSWORD" \
  get queue=auth.dlq count=5 ackmode=ack_requeue_true
```

`ack_requeue_true` puts messages back so you can fix the underlying issue and retry. Do not purge a DLQ unless you know the messages are stale.

**See the bindings of an exchange**:

```bash
docker exec rabbitmq rabbitmqctl list_bindings | grep -E '^auth|^b2b'
```

## Debugging

**Sharing was created but the recipient doesn't see it.** Check the email-fallback path. If you see `sendmail` jobs queued, the direct cozy-to-cozy PUT failed silently and the code fell through to email:

```bash
docker logs --since 10m cozyt 2>&1 \
  | grep -E 'msg=' \
  | grep -iE 'sendmail|sharing-trust|trusted|auto-accept|enqueue' \
  | grep -vE 'io.cozy|sharings-by|response: '
```

The PUT failure is most often the host hairpin path being broken; see [`operations.md`](operations.md). Cozy-stack's `safehttp` will not connect to private IPs, so the recipient hostname must resolve to the host's public IP and the host must accept that loopback.

**OIDC login error.** The user-visible "Error during authentication with OpenID Provider" hides the real message. Tail lemonldap and reproduce the login:

```bash
docker logs -f lemonldap-ng 2>&1 | grep -iE 'oidc|openid|jwks|token|sub|nonce|state|error|warn'
```

Common patterns and recovery in [`external-oidc.md`](external-oidc.md).

**`user.created` stuck in DLQ after import.** Symptoms in `cozyt`:

```bash
docker logs --since 5m cozyt 2>&1 | grep -E 'user\.created.*(missing|nack|skipping passphrase)'
```

`missing passphrase hash` means the cozy-stack version is below `1.6.50-rc1` and doesn't honour `disable_password_authentication: true`. See [`operations.md`](operations.md) for the version floor.

**Cross-cozy network reachability** (does the sharing PUT path work):

```bash
docker exec cozyt curl -sS -o /dev/null -w "%{http_code} %{time_total}\n" \
  --max-time 5 https://<other-user>.<BASE_DOMAIN>/
```

A 3xx in well under a second means the path works. A connect timeout means the host firewall or routing is rejecting the docker-bridge to host-public-IP loopback; sharing will silently fall back to email and stay broken.

## Reload without a full restart

**Reload cozy.yaml** after editing the template, default-flags, or default-sharing files:

```bash
cd cozy_stack && ./compose-wrapper.sh render
docker restart cozyt
```

**Reload lemonldap config** after editing `.env` (AUTH_MODE, OIDC settings):

```bash
cd twake_auth && ./compose-wrapper.sh render
docker compose --env-file ../.env stop lemonldap
docker compose --env-file ../.env rm -fv lemonldap
docker compose --env-file ../.env up -d lemonldap
```

The `rm -fv` is required because lemonldap caches its rendered config inside the container as `lmConf-2.json` and prefers it over the bind mount until removed.

**Reload ldap-rest** (image bump or env change):

```bash
cd twake_auth
docker compose --env-file ../.env up -d --force-recreate ldap-rest
```
