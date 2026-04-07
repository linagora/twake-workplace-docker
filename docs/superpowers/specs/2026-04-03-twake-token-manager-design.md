# Twake Token Manager — Design Spec

**Date**: 2026-04-03
**Status**: Approved
**PRD source**: `twake-token-manager-prd.md` (v0.2)
**Scope**: v0.1 + v0.2 (MVP + Token Umbrella)

---

## 1. Overview

Twake Token Manager is an inter-service token broker for the Twake Workplace ecosystem. It centralizes OAuth2/OIDC token lifecycle management for all Twake services behind a unified API. Two complementary modes are exposed:

- **Granular mode**: one token per service, direct access
- **Umbrella mode**: single opaque token mapping to multiple service tokens, with transparent proxying

### Design decisions

| Decision | Choice | Rationale |
|---|---|---|
| Architecture | Service Broker with pluggable connectors | Clean separation per auth protocol, testable in isolation |
| Source code | All in-repo, `token_manager/` directory | Kickstart repo for prototyping, single package |
| PostgreSQL | Shared `twake_db/postgres`, dedicated `token_manager` DB | Reuse existing infra, minimize containers |
| Redis/Valkey | Shared `visio-valkey` | BullMQ queue for refresh cron |
| Encryption key | `TOKEN_ENCRYPTION_KEY` in root `.env` | Consistent with repo's env pattern |
| Service connectors | All 4 from day one (Drive, Mail, Calendar, Chat) | Full coverage, validate architecture breadth |
| Frontend | Separate Next.js container on `token-manager.twake.local` | Decoupled from API |
| API | Fastify container on `token-manager-api.twake.local` | Dedicated subdomain |
| Multi-tenant | Code ready, 1 tenant `twake.local` bootstrapped | Sufficient for prototype |
| Code organization | Single npm package `token_manager/src/{api, sdk, cli}` | Simpler than monorepo for iteration |

---

## 2. Project Structure

```
token_manager/
├── compose-wrapper.sh
├── docker-compose.yml
├── Dockerfile.api
├── Dockerfile.frontend
├── package.json
├── tsconfig.json
├── prisma/
│   └── schema.prisma
├── config/
│   ├── config.yaml.template
│   └── init-db.sql
├── src/
│   ├── api/
│   │   ├── server.ts
│   │   ├── routes/
│   │   │   ├── tokens.ts
│   │   │   ├── umbrella.ts
│   │   │   └── proxy.ts
│   │   ├── connectors/
│   │   │   ├── interface.ts
│   │   │   ├── cozy-drive.ts
│   │   │   ├── tmail.ts
│   │   │   ├── matrix.ts
│   │   │   └── calendar.ts
│   │   ├── services/
│   │   │   ├── token-service.ts
│   │   │   ├── umbrella-service.ts
│   │   │   ├── crypto.ts
│   │   │   └── refresh-worker.ts
│   │   ├── middleware/
│   │   │   ├── auth.ts
│   │   │   └── tenant.ts
│   │   └── config.ts
│   ├── sdk/
│   │   └── index.ts
│   └── cli/
│       └── index.ts
├── frontend/
│   ├── app/
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   ├── admin/
│   │   │   ├── page.tsx
│   │   │   ├── config/
│   │   │   │   └── page.tsx
│   │   │   └── audit/
│   │   │       └── page.tsx
│   │   └── user/
│   │       └── page.tsx
│   ├── components/
│   │   ├── ui/
│   │   ├── token-table.tsx
│   │   ├── stats-bar.tsx
│   │   ├── refresh-config.tsx
│   │   ├── tenant-selector.tsx
│   │   └── user-access-list.tsx
│   ├── lib/
│   │   ├── api.ts
│   │   └── auth.ts
│   ├── next.config.js
│   └── tailwind.config.ts
└── tests/
    ├── unit/
    │   ├── crypto.test.ts
    │   ├── connectors/
    │   │   ├── cozy-drive.test.ts
    │   │   ├── tmail.test.ts
    │   │   ├── matrix.test.ts
    │   │   └── calendar.test.ts
    │   ├── token-service.test.ts
    │   ├── umbrella-service.test.ts
    │   └── refresh-worker.test.ts
    ├── integration/
    │   ├── setup.ts
    │   ├── api-tokens.test.ts
    │   ├── api-umbrella.test.ts
    │   ├── api-proxy.test.ts
    │   ├── cozy-oauth-flow.test.ts
    │   ├── refresh-cycle.test.ts
    │   └── multi-tenant.test.ts
    └── e2e/
        └── admin-dashboard.test.ts
```

---

## 3. Data Model

### Prisma Schema

```prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

enum TokenStatus {
  ACTIVE
  EXPIRED
  REVOKED
  REFRESH_FAILED
}

model Tenant {
  id        String           @id @default(cuid())
  domain    String           @unique
  name      String
  config    Json
  tokens    ServiceToken[]
  umbrella  UmbrellaToken[]
  createdAt DateTime         @default(now())
}

model ServiceToken {
  id            String      @id @default(cuid())
  tenantId      String
  userId        String
  service       String
  instanceUrl   String
  accessToken   String      // encrypted AES-256-GCM (format: base64(iv:authTag:ciphertext))
  refreshToken  String?     // encrypted AES-256-GCM
  expiresAt     DateTime
  autoRefresh   Boolean     @default(true)
  grantedBy     String
  grantedAt     DateTime    @default(now())
  lastUsedAt    DateTime?
  lastRefreshAt DateTime?
  status        TokenStatus @default(ACTIVE)
  tenant        Tenant      @relation(fields: [tenantId], references: [id])

  @@unique([tenantId, userId, service])
  @@index([expiresAt])
  @@index([tenantId, status])
}

model UmbrellaToken {
  id        String    @id @default(cuid())
  tenantId  String
  userId    String
  token     String    @unique   // SHA-256 hash of opaque "twt_..." value
  scopes    String[]
  expiresAt DateTime
  issuedAt  DateTime  @default(now())
  revokedAt DateTime?
  tenant    Tenant    @relation(fields: [tenantId], references: [id])

  @@index([token])
  @@index([tenantId, userId])
}

model AuditLog {
  id        String   @id @default(cuid())
  tenantId  String
  userId    String
  service   String?
  action    String
  details   Json?
  ip        String?
  createdAt DateTime @default(now())

  @@index([tenantId, userId])
  @@index([createdAt])
}
```

### Encryption

- `accessToken` and `refreshToken` fields are encrypted at rest using AES-256-GCM
- Key: `TOKEN_ENCRYPTION_KEY` from `.env` (32 bytes hex = 64 hex chars)
- Storage format: `base64(iv:authTag:ciphertext)` where iv is 12 random bytes per operation
- `UmbrellaToken.token` stores a SHA-256 hash; the opaque `twt_...` value is returned to the client but never stored in cleartext
- Uses Node.js `crypto` native module, no external dependency

### Default tenant bootstrap

On startup, if no tenant exists, the API seeds:

```json
{
  "domain": "twake.local",
  "name": "Twake Local Dev",
  "config": {
    "cozyBaseUrl": "https://{user}-drive.twake.local",
    "jmapUrl": "https://jmap.twake.local",
    "matrixUrl": "https://matrix.twake.local",
    "caldavUrl": "https://tcalendar-side-service.twake.local"
  }
}
```

---

## 4. Service Connectors

### Interface

```typescript
interface ServiceConnector {
  readonly serviceId: string

  authenticate(userId: string, tenant: Tenant): Promise<AuthResult>
  handleCallback?(code: string, state: string): Promise<TokenPair>
  refresh(refreshToken: string, tenant: Tenant): Promise<TokenPair>
  revoke(accessToken: string, tenant: Tenant): Promise<void>
  getInstanceUrl(userId: string, tenant: Tenant): string
}

interface AuthResult {
  type: 'redirect' | 'direct'
  redirectUrl?: string
  tokenPair?: TokenPair
}

interface TokenPair {
  accessToken: string
  refreshToken?: string
  expiresAt: Date
}
```

### Connector hierarchy

```
ServiceConnector (interface)
├── CozyDriveConnector        — OAuth2 PKCE custom
├── OidcBaseConnector          — shared OIDC logic (abstract)
│   ├── TmailConnector         — JMAP scopes
│   └── CalendarConnector      — CalDAV scopes
└── MatrixConnector            — Matrix login SSO + access token
```

### CozyDriveConnector

The most complex connector. Each Cozy user instance has its own OAuth2 application registry.

**Flow:**
1. `authenticate()` checks if a "twake-token-manager" OAuth2 app is registered on the user's Cozy instance
2. If not, registers via `POST https://{user}-drive.twake.local/auth/register`
3. Returns `{ type: 'redirect', redirectUrl }` to Cozy's authorize endpoint with PKCE `code_challenge`
4. User consents once in their browser
5. `handleCallback()` exchanges the authorization code for access_token + refresh_token via `POST /auth/access_token` with PKCE `code_verifier`
6. `refresh()` uses `POST /auth/access_token` with `grant_type=refresh_token`
7. `revoke()` calls `DELETE /auth/register/{client_id}`

Instance URL pattern: `https://{username}-drive.twake.local` (dynamic per user).

### TmailConnector / CalendarConnector (OidcBaseConnector)

Both use OIDC standard via LemonLDAP. Shared base logic:

1. `authenticate()` uses the user's OIDC token (from `Authorization` header) directly or via token exchange (RFC 8693) depending on service config
2. Returns `{ type: 'direct', tokenPair }` — no browser redirect needed
3. `refresh()` via LemonLDAP `/oauth2/token` with `grant_type=refresh_token`
4. `revoke()` via LemonLDAP OIDC revocation endpoint

TMail instance URL: `https://jmap.twake.local`
Calendar instance URL: `https://tcalendar-side-service.twake.local`

### MatrixConnector

1. `authenticate()` uses the OIDC token to obtain a Matrix access token via `POST /_matrix/client/v3/login` (type `m.login.sso` or `m.login.token`)
2. Returns `{ type: 'direct', tokenPair }`
3. `refresh()` via `POST /_matrix/client/v3/refresh`
4. `revoke()` via `POST /_matrix/client/v3/logout`

Matrix tokens are long-lived; refresh is infrequent.

---

## 5. API Routes

All routes prefixed `/api/v1`, protected by OIDC auth middleware (validates LemonLDAP Bearer token). Tenant middleware resolves tenant from user email domain or `X-Twake-Tenant` header.

### Granular token endpoints

```
POST   /api/v1/tokens                    Create/obtain a service token
POST   /api/v1/tokens/refresh            Force refresh a token
GET    /api/v1/tokens?user=...           List user's tokens
GET    /api/v1/tokens/:service?user=...  Token detail
DELETE /api/v1/tokens/:service?user=...  Revoke one token
DELETE /api/v1/tokens?user=...           Revoke all tokens (offboarding)
```

### Umbrella token endpoints

```
POST   /api/v1/umbrella-token              Create umbrella token
POST   /api/v1/umbrella-token/introspect   Introspect umbrella token
DELETE /api/v1/umbrella-token/:token       Revoke umbrella token
```

### Proxy

```
ALL    /api/v1/proxy/:service/*            Transparent proxy to target service
```

### OAuth2 callbacks (no auth middleware)

```
GET    /oauth/callback/cozy               Cozy Drive OAuth2 callback
```

### Admin endpoints

```
GET    /api/v1/admin/tokens?tenant=...           List all tokens for a tenant
GET    /api/v1/admin/config?tenant=...           View refresh config
PUT    /api/v1/admin/config?tenant=...           Update refresh config
GET    /api/v1/admin/audit?tenant=...&user=...   Query audit log
```

### Flow: POST /api/v1/tokens

```
Client                    Token Manager API              Connector             Target Service
  |                              |                           |                      |
  | POST /api/v1/tokens          |                           |                      |
  | { service, user }            |                           |                      |
  |----------------------------->|                           |                      |
  |                              | 1. Validate OIDC token    |                      |
  |                              | 2. Resolve tenant         |                      |
  |                              | 3. Lookup token in DB     |                      |
  |                              |                           |                      |
  |                              |-- Token ACTIVE + valid? --|                      |
  |                              |   YES: decrypt & return   |                      |
  |<-----------------------------|                           |                      |
  |                              |                           |                      |
  |                              |-- NO (missing/expired) -->|                      |
  |                              |                           | authenticate(user)   |
  |                              |                           |--------------------->|
  |                              |                           |                      |
  |                              |   If type='redirect':     |                      |
  |<-----------------------------|   202 + redirect_url      |                      |
  |                              |                           |                      |
  |                              |   If type='direct':       |                      |
  |                              |   encrypt + store + audit |                      |
  |<-----------------------------|   return token            |                      |
```

**Consent case (Cozy Drive):** API returns `202 Accepted` with `{ status: "consent_required", redirect_url: "..." }`. Client must open the URL in user's browser. After consent, `/oauth/callback/cozy` stores the token and redirects to a confirmation page.

### Flow: Umbrella Proxy

```
Client                    Token Manager API              Database                Target Service
  |                              |                           |                      |
  | GET /api/v1/proxy/           |                           |                      |
  |   twake-drive/files          |                           |                      |
  | Bearer: twt_4f8a...         |                           |                      |
  |----------------------------->|                           |                      |
  |                              | 1. SHA-256 hash token     |                      |
  |                              | 2. Lookup UmbrellaToken   |                      |
  |                              |-------------------------->|                      |
  |                              | 3. Verify scope includes  |                      |
  |                              |    "twake-drive"          |                      |
  |                              | 4. Lookup ServiceToken    |                      |
  |                              |    for (userId, service)  |                      |
  |                              |-------------------------->|                      |
  |                              | 5. Decrypt accessToken    |                      |
  |                              |                           |                      |
  |                              | 6. Proxy request          |                      |
  |                              |------------------------------------------------->|
  |                              |                           |                      |
  |                              | 7. Return response        |                      |
  |<-----------------------------|<-------------------------------------------------|
  |                              |                           |                      |
  |                              | 8. Update lastUsedAt      |                      |
  |                              | 9. Audit log (async)      |                      |
```

Proxy implementation uses `@fastify/http-proxy` or `undici`. Path mapping: `/api/v1/proxy/twake-drive/files` maps to `https://user1-drive.twake.local/files`. The `Authorization` header is replaced with the target service Bearer. `lastUsedAt` update is async (non-blocking).

### Error responses

| Situation | HTTP Code | Body |
|---|---|---|
| Invalid/expired OIDC token | 401 | `{ error: "invalid_oidc_token" }` |
| Invalid umbrella token | 401 | `{ error: "invalid_umbrella_token" }` |
| Umbrella token missing scope | 403 | `{ error: "scope_not_granted", service: "..." }` |
| No service token in DB | 404 | `{ error: "no_token", service: "..." }` |
| Service token expired + refresh failed | 502 | `{ error: "token_refresh_failed" }` |
| Target service unavailable | 502 | `{ error: "service_unavailable" }` |
| Consent required (Cozy) | 202 | `{ status: "consent_required", redirect_url: "..." }` |

---

## 6. Automatic Refresh (BullMQ)

### Architecture

```
                    +---------------------+
                    |   BullMQ Scheduler   |
                    |  (configurable cron) |
                    +----------+----------+
                               | every 5 min (default)
                               v
                    +---------------------+
                    |   Refresh Worker    |
                    |                     |
                    | 1. SELECT tokens    |
                    |    WHERE autoRefresh |
                    |    AND expiresAt <   |
                    |    now() + margin    |
                    |    AND status =      |
                    |    ACTIVE            |
                    |                     |
                    | 2. Per token:       |
                    |   connector.refresh()|
                    |   success: update    |
                    |   failure: retry 3x  |
                    |   then REFRESH_FAILED|
                    +---------------------+
```

### Behavior

- **Queue**: `token-refresh` on Valkey, cron-scheduled jobs
- **Concurrency**: worker processes up to 10 tokens in parallel per cycle
- **Retry**: on network failure, BullMQ retries with exponential backoff (1s, 5s, 15s), 3 attempts max
- **After 3 failures**: token status set to `REFRESH_FAILED`, AuditLog entry created
- **REFRESH_FAILED tokens**: no longer attempted automatically; admin can re-trigger via `POST /api/v1/tokens/refresh` or CLI
- **Idempotence**: worker checks `lastRefreshAt` to avoid duplicate refreshes if cycles overlap

### Configuration (config.yaml)

```yaml
server:
  port: 3100
  host: 0.0.0.0

database:
  url: postgresql://postgres:postgres@postgres:5432/token_manager

redis:
  url: redis://:valkeypass@visio-valkey:6379

oidc:
  issuer: https://auth.${BASE_DOMAIN}
  jwksUri: https://auth.${BASE_DOMAIN}/.well-known/openid-configuration
  audience: token-manager

refresh:
  cron: "*/5 * * * *"
  refresh_before_expiry: 15m
  max_retries: 3

services:
  twake-drive:
    auto_refresh: true
    token_validity: 1h
    refresh_token_validity: 30d
    scopes:
      - io.cozy.files
    instance_url_pattern: "https://{username}-drive.${BASE_DOMAIN}"
    oauth_redirect_uri: "https://token-manager-api.${BASE_DOMAIN}/oauth/callback/cozy"

  twake-mail:
    auto_refresh: false
    token_validity: 1h
    scopes:
      - "Email/*"
      - "EmailSubmission/*"
    instance_url: "https://jmap.${BASE_DOMAIN}"

  twake-calendar:
    auto_refresh: true
    token_validity: 8h
    refresh_token_validity: 90d
    scopes:
      - "CalDAV:REPORT"
      - "CalDAV:PUT"
      - "CalDAV:GET"
    instance_url: "https://tcalendar-side-service.${BASE_DOMAIN}"

  twake-chat:
    auto_refresh: true
    token_validity: 24h
    refresh_token_validity: 365d
    scopes:
      - "m.room.message"
    instance_url: "https://matrix.${BASE_DOMAIN}"
```

Config is hot-reloadable via `PUT /api/v1/admin/config` — changes persist to tenant `config` JSON in DB and take effect on next cron cycle.

---

## 7. SDK

### TwakeTokenManager class (`src/sdk/index.ts`)

```typescript
class TwakeTokenManager {
  constructor(options: {
    baseUrl: string
    oidcToken: string
    tenant?: string
  })

  // Granular mode
  async getToken(service: string, user: string): Promise<ServiceTokenResponse>
  async refreshToken(service: string, user: string): Promise<ServiceTokenResponse>
  async listTokens(user: string): Promise<ServiceTokenResponse[]>
  async revokeToken(service: string, user: string): Promise<void>
  async revokeAllTokens(user: string): Promise<void>
  async getTokenStatus(service: string, user: string): Promise<TokenStatusResponse>

  // Umbrella mode
  async getUmbrellaToken(user: string, scopes: string[]): Promise<UmbrellaTokenResponse>
  async introspectUmbrellaToken(token: string): Promise<UmbrellaIntrospectResponse>
  async revokeUmbrellaToken(token: string): Promise<void>

  // Proxy
  async proxy(service: string, path: string, umbrellaToken: string, options?: {
    method?: string
    headers?: Record<string, string>
    body?: any
  }): Promise<Response>
}
```

- Thin HTTP wrapper over the REST API — no business logic, no local cache
- Uses native `fetch` (Node 18+) — zero dependencies
- API errors wrapped in typed `TwakeTokenManagerError` with `code`, `message`, `service`
- Cozy consent case raises `ConsentRequiredError` with `redirectUrl`

---

## 8. CLI

### Commands (`src/cli/index.ts`)

Based on Commander.js. Instantiates the SDK internally.

```
twake-token <command> [options]

Global options:
  --api-url <url>        API URL (default: https://token-manager-api.twake.local)
  --token <oidc_token>   OIDC token (or env TWAKE_OIDC_TOKEN)
  --tenant <domain>      Explicit tenant
  --format <json|table>  Output format (default: table)

Token commands:
  create   --service <s> --user <u>
  list     --user <u>
  status   --service <s> --user <u>
  refresh  --service <s> --user <u>
  revoke   --service <s> --user <u>
  revoke   --all-services --user <u>

Umbrella commands:
  umbrella create      --user <u> --scopes <s1,s2>
  umbrella introspect  --token <twt_...>
  umbrella revoke      --token <twt_...>

Admin commands:
  admin list-tokens    --tenant <domain>
  admin config show    --tenant <domain>
  admin config update  --tenant <domain> --service <s> --auto-refresh <bool>
  admin audit          --tenant <domain> --user <u>
```

- OIDC token from `--token`, `TWAKE_OIDC_TOKEN` env, or `~/.twake-token-manager/credentials`
- `table` format via `cli-table3`, `json` outputs raw JSON
- `consent_required` displays URL and opens browser if possible (`open` package)

---

## 9. Frontend

### Stack

Next.js App Router + shadcn/ui + Tailwind CSS, served from `token-manager.twake.local`.

### Views

**Admin Dashboard** (`/admin`):
- Stats cards: active tokens, expired/failed, umbrella tokens (30s polling)
- Paginated, filterable token table (by user, service, status)
- Status badges: green (ACTIVE), orange (< 15min), red (EXPIRED/REFRESH_FAILED)
- Inline actions: Revoke (confirmation dialog), manual Refresh
- Tenant selector in header

**Admin Config** (`/admin/config`):
- Toggle auto-refresh per service
- Selectors for token_validity and refresh_before_expiry
- Save via `PUT /api/v1/admin/config`
- Toast feedback on success/error

**Admin Audit** (`/admin/audit`):
- Paginated audit log table
- Filterable by user, service, action, date range

**User Self-Service** (`/user`):
- User sees only their own tokens
- Can revoke access (confirmation dialog)
- Shows `grantedBy` (which service client requested access)
- Lists services without active tokens

### Authentication

1. User accesses `token-manager.twake.local`
2. Traefik/LemonLDAP redirects to `auth.twake.local` if no session
3. After SSO login, frontend obtains OIDC token via Authorization Code flow
4. Token stored in memory (not localStorage), sent as Bearer to API

Admin vs user distinction: based on LDAP group membership (`memberOf: cn=token-manager-admins,ou=groups,dc=twake,dc=local`), verified server-side by the API auth middleware. The LDAP group is created by an init LDIF in `twake_db/ldap/bootstrap/` and `user1` is added as admin by default for testing.

---

## 10. Docker Integration

### docker-compose.yml

```yaml
services:
  token-manager-api:
    build:
      context: .
      dockerfile: Dockerfile.api
    container_name: token-manager-api
    restart: unless-stopped
    environment:
      DATABASE_URL: postgresql://postgres:postgres@postgres:5432/token_manager
      REDIS_URL: redis://:valkeypass@visio-valkey:6379
      TOKEN_ENCRYPTION_KEY: ${TOKEN_ENCRYPTION_KEY}
      OIDC_ISSUER: https://auth.${BASE_DOMAIN}
      BASE_DOMAIN: ${BASE_DOMAIN}
      NODE_EXTRA_CA_CERTS: /usr/local/share/ca-certificates/root-ca.crt
    volumes:
      - ../twake_auth/traefik/ssl/root-ca.crt:/usr/local/share/ca-certificates/root-ca.crt:ro
      - ./config:/app/config:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.token-manager-api.rule=Host(`token-manager-api.${BASE_DOMAIN}`)"
      - "traefik.http.routers.token-manager-api.entrypoints=websecure"
      - "traefik.http.routers.token-manager-api.tls=true"
      - "traefik.http.services.token-manager-api.loadbalancer.server.port=3100"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3100/health || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 30s
    networks:
      - twake-network

  token-manager-frontend:
    build:
      context: .
      dockerfile: Dockerfile.frontend
    container_name: token-manager-frontend
    restart: unless-stopped
    environment:
      NEXT_PUBLIC_API_URL: https://token-manager-api.${BASE_DOMAIN}
      BASE_DOMAIN: ${BASE_DOMAIN}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.token-manager-frontend.rule=Host(`token-manager.${BASE_DOMAIN}`)"
      - "traefik.http.routers.token-manager-frontend.entrypoints=websecure"
      - "traefik.http.routers.token-manager-frontend.tls=true"
      - "traefik.http.services.token-manager-frontend.loadbalancer.server.port=3000"
    networks:
      - twake-network

networks:
  twake-network:
    external: true
```

### Dockerfiles

**Dockerfile.api:**
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
COPY prisma ./prisma/
RUN npm ci --omit=dev && npx prisma generate
COPY src ./src
COPY config ./config
RUN npm run build:api
EXPOSE 3100
CMD ["node", "dist/api/server.js"]
```

**Dockerfile.frontend:**
```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY frontend ./frontend
COPY next.config.js ./
RUN npm run build:frontend

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/frontend/.next/standalone ./
COPY --from=builder /app/frontend/.next/static ./frontend/.next/static
COPY --from=builder /app/frontend/public ./frontend/public
EXPOSE 3000
CMD ["node", "frontend/server.js"]
```

### Modifications to existing files

**`wrapper.sh`** — additions:
```bash
REPOS["token_manager"]="${BASE_DIR}/token_manager"

START_ORDER=("twake_db" "twake_auth" "cozy_stack" "token_manager" "onlyoffice_app" "meet_app" "calendar_app" "chat_app" "tmail_app")
STOP_ORDER=("tmail_app" "chat_app" "calendar_app" "meet_app" "onlyoffice_app" "token_manager" "cozy_stack" "twake_auth" "twake_db")

REPO_DEPS["token_manager"]="lemonldap-ng"
```

**`docker-compose.yaml` root** — add include:
```yaml
include:
  - token_manager/docker-compose.yml
```

**`.env` root** — add:
```
TOKEN_ENCRYPTION_KEY=a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2
```

**`twake_db/postgres/init-db-postgres/03-init-token-manager.sql`**:
```sql
CREATE DATABASE token_manager;
```

**`/etc/hosts`** — add:
```
127.0.0.1  token-manager.twake.local token-manager-api.twake.local
```

### Startup sequence

1. `compose-wrapper.sh` runs `envsubst` on `config/config.yaml.template` → `config/config.yaml`
2. Container starts, runs `npx prisma migrate deploy`
3. Seeds default tenant `twake.local` if absent
4. Loads `config.yaml`
5. Starts Fastify server + BullMQ scheduler

---

## 11. Tests

### Unit tests (`tests/unit/`)
- Vitest, fast, no infrastructure needed
- Prisma mocked via `vitest-mock-extended`
- Connectors tested in isolation: verify correct HTTP requests and response parsing
- Crypto tested with known vectors (encrypt/decrypt roundtrip, unique IV per call)

### Integration tests (`tests/integration/`)
- Require Docker infrastructure (`twake_db` minimum)
- Use dedicated `token_manager_test` database
- Cozy OAuth flow test requires `cozy_stack` running — tests full cycle
- Refresh cycle test verifies BullMQ triggers refresh and updates DB

### E2E tests (`tests/e2e/`)
- Optional Playwright smoke test for admin dashboard

### Commands
```bash
npm run test              # Unit tests only (vitest)
npm run test:integration  # Integration tests (requires Docker)
npm run test:all          # Everything
```

---

## 12. Dependencies

```json
{
  "dependencies": {
    "fastify": "^5",
    "@fastify/cors": "^10",
    "@fastify/http-proxy": "^11",
    "@prisma/client": "^6",
    "bullmq": "^5",
    "commander": "^13",
    "cli-table3": "^0.6",
    "yaml": "^2",
    "jose": "^6"
  },
  "devDependencies": {
    "prisma": "^6",
    "typescript": "^5.4",
    "tsx": "^4",
    "vitest": "^3",
    "@types/node": "^20",
    "next": "^15",
    "react": "^19",
    "react-dom": "^19",
    "@shadcn/ui": "latest"
  }
}
```

Key choices:
- `jose` for OIDC JWT validation (lightweight, zero-dep)
- Native `fetch` (Node 18+), no axios/node-fetch
- `tsx` for dev execution
- `vitest` over Jest for faster TypeScript support
