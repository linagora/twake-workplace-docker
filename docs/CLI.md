# twake CLI

Operator CLI for the Twake Workplace POC. One entry point for the day-to-day tasks.

```
scripts/twake <command> [subcommand] [args...]
```

Run `--help` on any command or subcommand for the same content this file covers.

## What the CLI needs to run

The CLI needs **environment variables**, not necessarily a file. It loads the repo's `.env` if it exists (convenience for the deployed POC), then each command checks the specific variables it requires. So either of these works:

- A populated `.env` at the repo root (the default).
- The required variables exported in your shell. Useful when running against a remote stack from your laptop without copying the file.
- A mix — the script sources `.env` first, exported vars override.

What's actually required, per command:

| Command | Variables it reads | Tools |
| --- | --- | --- |
| `preflight` | `BASE_DOMAIN`, `LDAP_REST_ADMIN_TOKEN`, `COZY_ADMIN_PASSPHRASE`, `RABBITMQ_USER`, `RABBITMQ_PASSWORD` (presence-only — preflight just verifies they're set) | `jq`, `curl`, `docker` |
| `users add` | `LDAP_REST_ADMIN_TOKEN`, `BASE_DOMAIN` | `jq`, `curl` |
| `users destroy` | `LDAP_REST_ADMIN_TOKEN`, `BASE_DOMAIN` | `jq`, `curl` |
| `users list` | `LDAP_REST_ADMIN_TOKEN`, `BASE_DOMAIN`, `COZY_ADMIN_PASSPHRASE` | `jq`, `curl`, `docker` |
| `flags show` / `set` / `unset` | `BASE_DOMAIN`, `COZY_ADMIN_PASSPHRASE` | `jq`, `docker` |
| `mq tap` | `RABBITMQ_USER`, `RABBITMQ_PASSWORD` | `jq`, `docker` |

If a required variable is missing the CLI exits 1 with a message naming the variable.

## Commands

### `preflight` — host sanity check

```
scripts/twake preflight [--no-color]
```

Verifies tooling (`jq`, `curl`, `docker`, `docker compose`, daemon reachable), `.env` presence, required env vars, `net.ipv4.ip_forward`, UFW forward policy (only when active), wildcard DNS for `${BASE_DOMAIN}`, hairpin reachability.

Exit 0 on no FAIL, 1 on any FAIL. WARN does not affect the exit code.

### `users add` — provision a SCIM user

```
scripts/twake users add <userName> [flags] [--dry-run]
scripts/twake users add --file <path>   [--dry-run]
```

`<userName>` must be a valid DNS label — lowercase letters, digits, hyphens, no leading/trailing hyphen, ≤63 chars. It becomes the cozy instance subdomain `<userName>.${BASE_DOMAIN}`.

In file mode the file is **one SCIM User object or an array**. Every SCIM attribute (extension URNs, addresses, custom claims) is forwarded to ldap-rest verbatim. Each entry is either:
- a full SCIM User (anything with a `schemas` field), or
- a shorthand combining `userName`, `givenName`, `familyName`, `email`, `active`, plus any extra top-level SCIM fields merged onto the synthesized body.

Per-field flags (only valid with positional `<userName>`):

| Flag | Effect |
| --- | --- |
| `--email VALUE` | Sets `emails[0].value` (`primary: true`) |
| `--display-name VALUE` | Sets `displayName` |
| `--given-name VALUE` | Sets `name.givenName` |
| `--family-name VALUE` | Sets `name.familyName` |
| `--phone VALUE` | Sets `phoneNumbers[0].value` (`primary: true`) |
| `--locale VALUE` | Sets `preferredLanguage` |
| `--title VALUE` | Sets `title` |
| `--password VALUE` | Sets the SCIM `password`, written to LDAP `userPassword` (see below) |
| `--inactive` | Sets `active: false` (default is `true`) |
| `--dry-run` | Print SCIM body for each entry (password masked as `***`) without POSTing |

#### Passwords and login

Whether a user needs a password depends on `AUTH_MODE` (set in `.env`):

- **`LDAP`** (default): LemonLDAP authenticates by binding against the directory, so an account with no `userPassword` **cannot log in**. Pass `--password` (or a top-level `password` in file mode) so the user can authenticate. `users add` prints a warning when no password is given in this mode.
- **`OpenIDConnect`**: the external IdP owns credentials and the LDAP password is ignored. `users add` warns if you pass one.

For this to work, ldap-rest maps the SCIM `password` to LDAP `userPassword` via `DM_SCIM_USER_MAPPING` (wired in `twake_auth/docker-compose.yml`); without that mapping the default SCIM schema silently drops the field. The bootstrapped demo users (`user1`…`user3`) already carry passwords.

> **Security caveat.** This slapd stores `userPassword` in **cleartext** (it does not hash on write), and the mapping is **bidirectional**: `GET /scim/v2/Users` returns the stored `password`, so anyone holding `LDAP_REST_ADMIN_TOKEN` can read every user's password, and `slapcat`/LDAP backups contain them in the clear. `users list` does not print passwords, but it does fetch them. Treat the admin token and LDAP data volume as secrets. Do not reuse a real/shared password here.

Exit 0 if every POST returned 2xx, 1 otherwise.

### `users destroy` — tear down user(s)

```
scripts/twake users destroy <userName> [<userName> ...] [--yes] [--dry-run]
scripts/twake users destroy --file <path>                [--yes] [--dry-run]
```

Calls `DELETE /scim/v2/Users/<userName>` on ldap-rest, which tears down the LDAP entry **and** the cozy instance. `204` = destroyed, `404` = already gone (both treated as success).

In file mode only the `userName` field of each entry is read.

| Flag | Effect |
| --- | --- |
| `--yes`, `-y` | Skip the confirmation prompt |
| `--dry-run` | List targets without sending anything |

Refuses to run unattended without `--yes`. Exit 0 if every user was destroyed (or already gone), 1 otherwise.

### `users list` — joined SCIM × cozy view

```
scripts/twake users list [--json] [--orphans]
```

Surfaces orphans on either side. Cozy instances are filtered to `${BASE_DOMAIN}` so reports on a host that previously served other contexts stay focused.

| Status | Meaning |
| --- | --- |
| `ok` | Present on both sides |
| `scim_only` | LDAP entry exists, no cozy instance — provisioning failed silently; check `auth.dlq` and cozyt logs |
| `cozy_only` | Cozy instance exists, no LDAP entry — stale tenant from a past import that bypassed the destroy flow |

| Flag | Effect |
| --- | --- |
| `--json` | Emit the joined records as JSON instead of a table |
| `--orphans` | Show only rows where `status != ok` |

Always exits 0 (read-only).

### `flags show` — display effective feature flags

```
scripts/twake flags show <userName>
scripts/twake flags show --all
```

Output merges instance overrides on top of context flags on top of defaults — i.e. what the cozy frontend actually reads.

`--all` iterates every instance under `${BASE_DOMAIN}`.

### `flags set` — upsert per-instance overrides

```
scripts/twake flags set <userName> KEY=VALUE [KEY=VALUE ...]
scripts/twake flags set --all      KEY=VALUE [KEY=VALUE ...]
```

Each `VALUE` is parsed as JSON when possible, falling back to a JSON string for plain words:

| Input | Stored as |
| --- | --- |
| `flag=true` | `true` (boolean) |
| `flag=42` | `42` (number) |
| `flag=hello` | `"hello"` (string, auto-quoted) |
| `flag=null` | `null` (cozy-stack interprets this as "remove this flag") |
| `flag='[1,2,3]'` | `[1, 2, 3]` (array) |
| `flag='"hi"'` | `"hi"` (explicitly-quoted string) |

Exit 0 if every instance was updated, 1 otherwise.

### `flags unset` — remove per-instance overrides

```
scripts/twake flags unset <userName> KEY [KEY ...]
scripts/twake flags unset --all      KEY [KEY ...]
```

Removes the override (cozy-stack falls back to the context / default value).

### `mq tap` — live RabbitMQ message stream

```
scripts/twake mq tap <exchange> [routing_key] [--interval N] [--batch N]
scripts/twake mq tap --auth     [routing_key] [--interval N] [--batch N]
scripts/twake mq tap --b2b      [routing_key] [--interval N] [--batch N]
```

Declares a temporary auto-delete queue, binds it to `<exchange>` with `<routing_key>`, and pretty-prints every message that flows through. Real consumers (cozy-stack, b2b consumers) are unaffected — we bind a fresh queue.

| Flag | Default | Effect |
| --- | --- | --- |
| `--auth` | — | Alias for the `auth` exchange |
| `--b2b` | — | Alias for the `b2b` exchange |
| `<routing_key>` | `#` | Bind pattern (`#` = every message) |
| `--interval N` | `1` | Poll every N seconds |
| `--batch N` | `20` | Max messages per poll |

Caveats: ~1s latency (polled, not pushed); no history replay; the temp queue self-destructs on Ctrl-C and after 10 minutes of inactivity even if the trap is bypassed.

## Environment

| Variable | Default | Used by |
| --- | --- | --- |
| `ENV_FILE` | `<repo>/.env` | every command |
| `LDAP_REST_HOST` | `https://ldap-rest.${BASE_DOMAIN}` | `users add`, `users destroy`, `users list` |
| `COZY_CONTAINER` | `cozyt` | `users list`, `flags *` |
| `RABBITMQ_CONTAINER` | `rabbitmq` | `mq tap` |
| `PROBE_LABEL` | `__preflight` | `preflight` |
| `NO_COLOR` | unset | every command (disables ANSI colors when set) |

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success |
| `1` | Runtime failure (HTTP error, missing tool, invalid input) |
| `2` | Usage error (unknown flag, missing required arg, mutually-exclusive flags) |
