# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Twake Workplace Docker is a multi-service Docker Compose infrastructure for the Twake Workplace platform. It integrates communication (Matrix/Synapse chat), file sharing (LinShare), document editing (OnlyOffice), calendaring, email (TMail/JMAP), video conferencing (LiveKit + Django), and a personal cloud (Cozy Stack) behind a unified SSO layer (LemonLDAP::NG) and reverse proxy (Traefik).

## Commands

### Master orchestration (root level)
```bash
./wrapper.sh up -d                     # Start all services in dependency order
./wrapper.sh down                      # Stop all services in reverse order
./wrapper.sh up twake_db -d            # Start a specific component
./wrapper.sh up twake_auth lemonldap   # Start a specific service within a component
./wrapper.sh --help                    # Show usage
```

### Per-component pattern
Each app directory has a `compose-wrapper.sh` that sources the root `.env`, runs `envsubst` on config templates, then calls `docker compose`.
```bash
cd <app_dir> && ./compose-wrapper.sh up -d
```

### Chat app (Node.js monorepo in `chat_app/`)
```bash
npm run build          # Build all packages (Lerna + Nx)
npm run test           # Jest tests
npm run lint           # ESLint
npm run lint-fix       # ESLint autofix
npm run format:check   # Prettier check
npm run format:fix     # Prettier fix
npm run dev            # Watch + nodemon
```

## Architecture

### Startup order (enforced by `wrapper.sh`)
1. `twake_db` -- PostgreSQL, MongoDB, CouchDB, OpenLDAP, Valkey, Cassandra, MinIO, RabbitMQ
2. `twake_auth` -- Traefik (fixed IP 172.27.0.100), LemonLDAP::NG (SSO/OIDC), Docker Socket Proxy
3. `drive_app` -- Personal cloud platform
4. `onlyoffice_app` -- Document server
5. `visio_app` -- LiveKit + Django backend
6. `calendar_app` -- Calendar service
7. `chat_app` -- Matrix Synapse + Tom Server (requires lemonldap-ng healthy)
8. `mail_app` -- JMAP email (requires lemonldap-ng healthy)

### Networking
- All services share `twake-network` (172.27.0.0/16, must be created manually before first run)
- Traefik is the single entry point at 172.27.0.100
- Domain: `*.twake.local` (requires `/etc/hosts` entries -- see README.md)
- Self-signed CA in `twake_auth/traefik/ssl/root-ca.pem` (must be trusted in browser/OS)

### Configuration pattern
- Root `.env` defines `BASE_DOMAIN`, `LDAP_BASE_DN`, `MAIL_DOMAIN`
- Each app's `compose-wrapper.sh` uses `envsubst` to generate configs from `.template` files
- No hardcoded domains -- everything derives from `.env`

### Chat app monorepo (`chat_app/packages/`)
Lerna/Nx monorepo with 11 workspaces. Key packages:
- `tom-server` -- Main identity/vault server (Express.js)
- `matrix-identity-server` -- Matrix identity service
- `federated-identity-service` -- Federation support
- Supporting packages: `crypto`, `logger`, `amqp-connector`, `db`, `utils`, `config-parser`, `common-settings`, `matrix-resolve`

Node 18.20.8, TypeScript 4.9.5, Jest + Supertest for tests.

### Root docker-compose.yaml
The root `docker-compose.yaml` uses the Compose `include` directive to aggregate sub-projects. However, the `wrapper.sh` script is the primary way to manage services (handles dependency ordering and health checks).

## Test credentials
| URL | Login | Password |
|---|---|---|
| `https://user1.twake.local` | `user1` | `user1` |
| `https://user2.twake.local` | `user2` | `user2` |
| `https://user3.twake.local` | `user3` | `user3` |
