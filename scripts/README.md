# scripts

A single operator CLI: [`twake`](./twake). One entry point for every routine task — host preflight, SCIM user lifecycle, drift report, RabbitMQ tap.

```bash
scripts/twake --help                  # overview
scripts/twake <command> --help        # help for one command
scripts/twake <command> <sub> --help  # help for a subcommand
```

## Commands

| Command | Purpose |
| --- | --- |
| `preflight` | Pre-boot host check: tooling, UFW forward, ip_forward, wildcard DNS, hairpin reachability. |
| `users add` | Provision a SCIM user (and its cozy instance). Positional, flag-based, or `--file` (single object or array, all SCIM attributes supported). |
| `users destroy` | Tear down user(s) end-to-end: SCIM DELETE plus cozy instance. |
| `users list` | Joined view of SCIM users × cozy instances; surfaces orphans on either side. |
| `flags show` | Display the effective feature flags on an instance (or `--all`). |
| `flags set` | Upsert per-instance flag overrides on one user (or `--all`). |
| `flags unset` | Remove per-instance flag overrides. |
| `mq tap` | Live tap on a RabbitMQ exchange — see messages without disturbing real consumers. |

Every subcommand has its own `--help` with usage, flags, environment overrides, and exit codes. For a single-page reference of the whole CLI see [`docs/CLI.md`](../docs/CLI.md).

## Conventions

- Reads `.env` from the repo root. Override the path with `ENV_FILE=...`.
- Runs under `set -euo pipefail`.
- Destructive operations (`users destroy`) require an explicit `--yes` for non-interactive use; everything else is read-only or additive.
- Prerequisites (`jq`, `curl`, `docker`) are checked at command time and produce an actionable install hint if missing.

## Worked examples

The end-to-end SCIM import walkthrough lives in [`docs/scim-import.md`](../docs/scim-import.md). Day-to-day debugging recipes are in [`docs/cookbook.md`](../docs/cookbook.md).

## Input files

`users.example.json` is a sample input file accepted by both `users add --file` and `users destroy --file`. Each entry is either a SCIM `User` object (anything with a `schemas` field, passed through verbatim) or a shorthand combining `userName`, `givenName`, `familyName`, `email`, `active`, plus any extra top-level SCIM fields you want merged onto the synthesized body.

`userName` must be a valid DNS label (lowercase letters, digits, hyphens, no leading or trailing hyphen, ≤63 chars) because it becomes the cozy instance subdomain `<userName>.${BASE_DOMAIN}`. Slugs that match a stack service subdomain (e.g. `chat`, `mail`, `auth`) are also rejected to avoid traefik routing collisions; the list is derived at runtime from the `Host(...)` rules in compose files, so it stays in sync as services come and go.
