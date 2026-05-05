# scripts

## `scim-import-users.sh` — bulk-import users via SCIM

The full Twake provisioning pipeline (LDAP entry, cozy instance, RabbitMQ event for cozy-stack) hangs off a single SCIM `POST /scim/v2/Users` call against the `ldap-rest` service. This script reads a JSON file describing one or more users and fires that call for each entry, so a deployment can be seeded — or an external IDM can drive batch imports — without writing any glue.

### Prerequisites

- A reachable `ldap-rest` service (deployed by `twake_auth/docker-compose.yml`)
- `jq` and `curl` on the host running the script
- The repo's `.env` populated — the script reads `LDAP_REST_ADMIN_TOKEN` and `BASE_DOMAIN` from it

### Usage

```bash
cp scripts/users.example.json scripts/users.json   # then edit
scripts/scim-import-users.sh scripts/users.json
```

`--dry-run` prints the SCIM body for each entry without sending anything — useful for sanity-checking your input file before hitting the live endpoint.

By default the script targets `https://ldap-rest.${BASE_DOMAIN}`. To point it at a different deployment (e.g. a remote staging environment) without touching `.env`:

```bash
LDAP_REST_HOST=https://ldap-rest.staging.example.org scripts/scim-import-users.sh users.json
```

### Input format

Each entry in the JSON array can be either:

- a **shorthand** with the common keys (`userName`, `givenName`, `familyName`, `email`, `active`), plus any extra top-level SCIM attributes (`displayName`, `phoneNumbers`, `title`, custom extension URNs, …) which get merged onto the synthesized body, or
- a **full SCIM User** (anything with a `schemas` field), passed through verbatim.

See `scripts/users.example.json` for a worked example covering both modes. `userName` is the only field that is always required — it becomes the cozy instance subdomain (`<userName>.${BASE_DOMAIN}`).

### Verifying a run

A successful import is observable from the running stack — no extra tooling needed.

Cozy instances list (each imported user should appear, status `onboarded`):

```bash
docker exec cozyt cozy-stack instances ls
```

Apps installed on a given instance (matches `DM_COZY_APPS` from `twake_auth/docker-compose.yml`):

```bash
docker exec cozyt cozy-stack apps ls --domain <user>.${BASE_DOMAIN}
```

RabbitMQ — the cozy-stack consumer queue should drain to zero with a live consumer; the dead-letter queue should stay empty:

```bash
docker exec rabbitmq rabbitmqadmin list queues name messages consumers \
  | grep -E 'stack\.user\.created|auth\.dlq'
```

If `auth/user.created` lands in the dead-letter queue, `cozyt`'s logs identify which field cozy-stack rejected — typically a configuration mismatch (context name, missing settings) rather than a script bug:

```bash
docker logs cozyt --since 5m 2>&1 | grep -i 'user.created'
```
