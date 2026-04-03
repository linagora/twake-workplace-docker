# Twake Token Manager

The Twake Token Manager is an inter-service token broker for the Twake.ai Digital Workplace. It centralizes OAuth token management across all platform services (Mail, Calendar, Drive, Chat) and exposes a unified proxy API through **umbrella tokens**.

## Table of Contents

- [Overview](#overview)
- [Functional Description](#functional-description)
- [Architecture](#architecture)
- [Umbrella Tokens](#umbrella-tokens)
- [Service Connectors](#service-connectors)
- [Security Model](#security-model)
- [Getting Started](#getting-started)
- [API Reference](#api-reference)

## Overview

In the Twake.ai platform, each service (TMail, Cozy Drive, Calendar, Matrix Chat) has its own authentication and token system. This creates a challenge for:

- **Automation scripts** that need to interact with multiple services
- **Third-party integrations** that require cross-service access
- **Administrators** who need visibility and control over access tokens

The Token Manager solves this by acting as a **centralized token vault and proxy**. Users authenticate once via the platform's SSO (LemonLDAP::NG), then the Token Manager handles per-service OAuth flows, token storage, automatic refresh, and revocation.

```
                         +--------------------+
                         |   LemonLDAP::NG    |
                         |   (SSO / OIDC)     |
                         +--------+-----------+
                                  |
                    OIDC token    |
                                  v
+----------+            +--------------------+            +----------------+
|  Client  |--umbrella->|   Token Manager    |--bearer--->|  TMail (JMAP)  |
|  (curl,  |  token     |                    |  token     +----------------+
|  script, |            |  - Token vault     |
|  app)    |            |  - Auto-refresh    |--bearer--->+----------------+
+----------+            |  - Proxy           |  token     |  Cozy Drive    |
                        |  - Audit log       |            +----------------+
                        +--------------------+
                                  |           \--bearer-->+----------------+
                                  |             token     |  Calendar      |
                                  |                       +----------------+
                                  |
                                  \--bearer-------------->+----------------+
                                    token                 |  Matrix Chat   |
                                                          +----------------+
```

## Functional Description

### For Users

The Token Manager web interface allows users to:

- **Create service tokens**: Initiate an OAuth consent flow for a specific Twake service. Once consent is granted, the token is stored encrypted and managed automatically.
- **Create umbrella tokens**: Generate a single token that grants access to multiple services through the proxy API.
- **Monitor token status**: See which services have active tokens, when they expire, and when they were last used.
- **Revoke tokens**: Immediately revoke access to one or all services.
- **View audit log**: See a timeline of all token operations (creation, refresh, proxy usage, revocation).

### For Administrators

Administrators (members of the `token-manager-admins` OIDC group) can:

- **View all users and their tokens**: Search by email, see token counts and statuses.
- **Bulk revoke tokens**: Select multiple users and revoke their tokens at once (e.g., for offboarding).
- **Configure service settings**: Adjust auto-refresh behavior, token validity, and refresh margins per service.
- **Audit all activity**: View the global audit log across all users and services.

### For Developers and Integrators

The REST API and TypeScript SDK allow programmatic access:

- **SDK**: `TwakeTokenManager` class for Node.js applications
- **CLI**: Command-line tool for token management
- **Proxy API**: Use an umbrella token to call any Twake service without managing individual tokens

## Architecture

### Components

```
token_manager/
  src/
    api/
      server.ts               # Fastify app, route registration
      config.ts                # YAML config parsing
      routes/
        tokens.ts              # Service token CRUD endpoints
        umbrella.ts            # Umbrella token endpoints
        proxy.ts               # Transparent proxy handler
        health.ts              # Health check
      services/
        token-service.ts       # Token lifecycle (create, refresh, revoke)
        umbrella-service.ts    # Umbrella token operations
        crypto.ts              # AES-256-GCM encrypt/decrypt
        refresh-worker.ts      # Background refresh scheduler (BullMQ)
      middleware/
        auth.ts                # OIDC JWT validation
        tenant.ts              # Multi-tenant resolution
      connectors/
        cozy-drive.ts          # Cozy custom OAuth2
        tmail.ts               # TMail OIDC
        calendar.ts            # Calendar OIDC
        matrix.ts              # Matrix SSO + login token
    sdk/
      index.ts                 # TypeScript SDK client
    cli/
      index.ts                 # CLI tool
  frontend/                    # Next.js web interface
    app/
      tokens/page.tsx          # User token management
      dashboard/page.tsx       # Stats overview
      audit/page.tsx           # Personal audit log
      admin/                   # Admin pages (users, audit, config)
  prisma/
    schema.prisma              # Database models
  config/
    config.yaml.template       # Service configuration
  docker-compose.yml           # API + Frontend containers
```

### Data Model

The Token Manager uses PostgreSQL with the following schema:

| Table | Purpose |
|-------|---------|
| **Tenant** | Multi-tenant isolation (one per domain) |
| **ServiceToken** | Per-user, per-service encrypted OAuth tokens (access + refresh) |
| **UmbrellaToken** | Cross-service proxy tokens (stored hashed) |
| **PendingAuth** | Temporary OAuth state during consent flows (TTL: 10 min) |
| **AuditLog** | All token operations with user, service, action, IP, timestamp |

### Container Setup

The Token Manager runs as two Docker containers:

| Container | Port | Role |
|-----------|------|------|
| `token-manager-api` | 3100 | Fastify REST API + proxy |
| `token-manager-frontend` | 3000 | Next.js web interface |

Both are routed through Traefik:
- `https://token-manager.{BASE_DOMAIN}` : Frontend UI
- `https://token-manager-api.{BASE_DOMAIN}` : API endpoints

## Umbrella Tokens

The umbrella token is the central concept of the Token Manager. It is a **unified bearer token** that provides scoped access to multiple Twake services through a single credential.

### How it works

```
1. User authenticates via SSO (OIDC)
         |
         v
2. User creates service tokens
   (one OAuth consent per service)
         |
         v
3. User creates umbrella token
   selecting which services to include
         |
         v
4. Token Manager returns: twt_<48-char hex>
   (shown once, stored hashed in DB)
         |
         v
5. Client uses umbrella token with proxy API:

   curl -H "Authorization: Bearer twt_abc123..." \
     https://token-manager-api.twake.local/api/v1/proxy/twake-mail/jmap \
     -d '{"using":["urn:ietf:params:jmap:core","urn:ietf:params:jmap:mail"], ...}'
         |
         v
6. Token Manager:
   a. Hashes token, looks up in DB
   b. Checks scopes include "twake-mail"
   c. Finds ServiceToken for this user + service
   d. Decrypts the real access token
   e. Proxies the request to TMail with the real token
   f. Returns response to client
   g. Logs the operation in audit trail
```

### Token format

- Prefix: `twt_` (Twake Token)
- Payload: 48 hexadecimal characters (24 random bytes)
- Example: `twt_a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6`
- Storage: SHA-256 hash in database (the raw token cannot be recovered)
- Default TTL: 24 hours

### Available scopes

| Scope | Service | Protocol |
|-------|---------|----------|
| `twake-mail` | TMail | JMAP over HTTPS |
| `twake-drive` | Cozy Drive | Cozy Files API |
| `twake-calendar` | Calendar | CalDAV/WebDAV |
| `twake-chat` | Matrix Chat | Matrix Client-Server API |

### Proxy endpoint

```
{METHOD} /api/v1/proxy/{service}/{path}
Authorization: Bearer twt_...
```

The proxy transparently forwards the request to the target service, injecting the real access token. It supports all HTTP methods including WebDAV verbs (PROPFIND, REPORT, MKCALENDAR) for CalDAV compatibility.

## Service Connectors

Each Twake service uses a different authentication flow. The Token Manager abstracts these differences behind a unified connector interface.

| Service | Connector | Auth Flow | Refresh |
|---------|-----------|-----------|---------|
| **TMail** | OIDC | Authorization Code + PKCE via LemonLDAP | Refresh token grant |
| **Calendar** | OIDC | Authorization Code + PKCE via LemonLDAP | Refresh token grant |
| **Cozy Drive** | Custom OAuth2 | Dynamic client registration + Authorization Code | Refresh token grant |
| **Matrix Chat** | SSO | Redirect to Synapse SSO, login token exchange | Matrix refresh endpoint |

### Token lifecycle

1. **Creation**: User initiates consent flow. If the service requires user interaction (consent screen), the backend returns a redirect URL. After consent, the callback endpoint exchanges the authorization code for access + refresh tokens.

2. **Storage**: Tokens are encrypted with AES-256-GCM (random IV + auth tag) and stored in PostgreSQL. The encryption key is a 32-byte secret (`TOKEN_ENCRYPTION_KEY`).

3. **Auto-refresh**: A BullMQ worker runs every 5 minutes and refreshes tokens that will expire within 15 minutes (both intervals are configurable). If refresh fails after retries, the token is marked `REFRESH_FAILED`.

4. **Revocation**: Tokens can be revoked via the API or UI. The Token Manager attempts best-effort revocation at the source service, then marks the token as `REVOKED` in the database.

## Security Model

| Measure | Implementation |
|---------|---------------|
| **Token encryption at rest** | AES-256-GCM with random 12-byte IV and auth tag |
| **Umbrella token storage** | SHA-256 hash only (raw token shown once at creation) |
| **OAuth PKCE** | Code challenge (S256) for all OIDC flows |
| **CSRF protection** | Random state parameter validated in OAuth callbacks |
| **Short-lived state** | PendingAuth entries expire after 10 minutes |
| **OIDC JWT validation** | Tokens verified against LemonLDAP JWKS endpoint |
| **Admin access control** | Requires `token-manager-admins` group in OIDC claims |
| **Audit trail** | All operations logged with user, service, action, IP |
| **Scoped proxy access** | Umbrella tokens checked against declared scopes per request |

## Getting Started

### Prerequisites

The Token Manager is included in the Twake.AI Kickstart stack. Make sure the following services are running:

- `twake-db` (PostgreSQL, Redis/Valkey)
- `twake-auth` (LemonLDAP::NG, Traefik)

### DNS configuration

Add to your `/etc/hosts`:

```
127.0.0.1  token-manager.twake.local token-manager-api.twake.local
```

### Start the Token Manager

```bash
sudo ./wrapper.sh up token_manager -d
```

### Access the web interface

Open https://token-manager.twake.local and log in with one of the test accounts:

| Login | Password | Role |
|-------|----------|------|
| `user1` | `user1` | Admin (member of `token-manager-admins`) |
| `user2` | `user2` | Standard user |
| `user3` | `user3` | Standard user |

### Create your first umbrella token

1. Log in to https://token-manager.twake.local
2. Click **Create Token**
3. Select **Umbrella Token**
4. Choose the services you want to access (e.g., `twake-mail`, `twake-drive`)
5. Optionally give it a name
6. Click **Create**
7. **Copy the token** (it is shown only once)

### Test with curl

#### List emails via the proxy (JMAP)

```bash
UMBRELLA_TOKEN="twt_<your-token>"

curl -sk "https://token-manager-api.twake.local/api/v1/proxy/twake-mail/jmap" \
  -H "Authorization: Bearer $UMBRELLA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
    "methodCalls": [
      ["Mailbox/get", {"accountId": "<account-id>"}, "0"]
    ]
  }'
```

#### List files in Cozy Drive via the proxy

```bash
curl -sk "https://token-manager-api.twake.local/api/v1/proxy/twake-drive/files/io.cozy.files.root-dir" \
  -H "Authorization: Bearer $UMBRELLA_TOKEN" \
  -H "Accept: application/vnd.api+json"
```

#### List calendars via CalDAV proxy

```bash
curl -sk "https://token-manager-api.twake.local/api/v1/proxy/twake-calendar/calendars" \
  -X PROPFIND \
  -H "Authorization: Bearer $UMBRELLA_TOKEN" \
  -H "Content-Type: application/xml" \
  -H "Depth: 1" \
  -d '<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:displayname/>
  </d:prop>
</d:propfind>'
```

#### Introspect an umbrella token

```bash
curl -sk "https://token-manager-api.twake.local/api/v1/umbrella-token/introspect" \
  -H "Authorization: Bearer <oidc-token>" \
  -H "Content-Type: application/json" \
  -d '{"umbrella_token": "twt_<your-token>"}'
```

## API Reference

### Authentication

All API endpoints (except `/health` and `/oauth/callback/*`) require an OIDC Bearer token from LemonLDAP::NG:

```
Authorization: Bearer <oidc-access-token>
```

Proxy endpoints accept an umbrella token instead:

```
Authorization: Bearer twt_<umbrella-token>
```

### Service Tokens

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/tokens` | Create a service token (triggers OAuth consent if needed) |
| `GET` | `/api/v1/tokens` | List all service tokens for a user |
| `GET` | `/api/v1/tokens/:service` | Get token details for a specific service |
| `POST` | `/api/v1/tokens/refresh` | Force refresh a service token |
| `DELETE` | `/api/v1/tokens/:service` | Revoke a service token |
| `DELETE` | `/api/v1/tokens` | Revoke all tokens for a user |

### Umbrella Tokens

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/umbrella-token` | Create an umbrella token with selected scopes |
| `GET` | `/api/v1/umbrella-tokens` | List active umbrella tokens |
| `POST` | `/api/v1/umbrella-token/introspect` | Validate and inspect a token |
| `DELETE` | `/api/v1/umbrella-token/:token` | Revoke an umbrella token |

### Proxy

| Method | Endpoint | Description |
|--------|----------|-------------|
| `*` | `/api/v1/proxy/:service/*` | Proxy any request to a Twake service |

### Admin

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/admin/users` | List all users with token counts |
| `GET` | `/api/v1/admin/tokens` | List all tenant tokens |
| `GET` | `/api/v1/admin/audit` | Global audit log |
| `GET` | `/api/v1/admin/config` | View service configuration |
| `PUT` | `/api/v1/admin/config` | Update service configuration |
| `DELETE` | `/api/v1/admin/users/bulk-revoke` | Bulk revoke tokens for multiple users |
