# scripts

## `scim-import-users.sh` — bulk-import users via SCIM

The full Twake provisioning pipeline (LDAP entry, cozy instance, RabbitMQ event for cozy-stack) hangs off a single SCIM `POST /scim/v2/Users` call against the `ldap-rest` service. This script reads a JSON file describing one or more users and fires that call for each entry, so a deployment can be seeded — or an external IDM can drive batch imports — without writing any glue.

### Why not just `cozy-stack instances add`?

`cozy-stack instances add` only creates the cozy instance. SCIM creation is the one path that also produces the LDAP entry and emits the `auth/user.created` event the rest of the stack listens for. Going through SCIM keeps LDAP, cozy-stack, and any other consumer (org contact sync, …) in sync.

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

### What you should see after a successful run

- `cozy-stack instances ls` lists a new instance per imported user, status `onboarded`
- `cozy-stack apps ls --domain <user>.${BASE_DOMAIN}` shows the apps from `DM_COZY_APPS`
- The `stack.user.created` queue on RabbitMQ shows zero pending messages and a live consumer; `auth.dlq` does not grow

If `auth/user.created` lands in the dead-letter queue, the message detail in `cozyt`'s logs explains which field cozy-stack rejected — typically a configuration mismatch (context name, missing settings) rather than a script bug.
