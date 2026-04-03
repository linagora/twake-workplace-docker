# Twake Token Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an inter-service token broker that centralizes OAuth2/OIDC token lifecycle management for all Twake Workplace services, with granular and umbrella token modes.

**Architecture:** Service Broker pattern with pluggable connectors per auth protocol. Fastify API backend, Next.js admin frontend, BullMQ refresh cron. Single npm package in `token_manager/` directory. Reuses existing PostgreSQL and Valkey from `twake_db`.

**Tech Stack:** TypeScript, Fastify 5, Prisma 6, BullMQ 5, Next.js 15, shadcn/ui, Commander.js, jose, Vitest

**Spec:** `docs/superpowers/specs/2026-04-03-twake-token-manager-design.md`

---

## Phase 1: Scaffolding & Foundation

### Task 1: Project scaffolding

**Files:**
- Create: `token_manager/package.json`
- Create: `token_manager/tsconfig.json`
- Create: `token_manager/vitest.config.ts`
- Create: `token_manager/.gitignore`

- [ ] **Step 1: Create token_manager directory and package.json**

```bash
mkdir -p token_manager
```

Write `token_manager/package.json`:
```json
{
  "name": "twake-token-manager",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build:api": "tsc -p tsconfig.json",
    "build:frontend": "cd frontend && next build",
    "dev": "tsx watch src/api/server.ts",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:integration": "vitest run --config vitest.integration.config.ts",
    "test:all": "vitest run && vitest run --config vitest.integration.config.ts",
    "lint": "tsc --noEmit",
    "db:migrate": "prisma migrate dev",
    "db:generate": "prisma generate",
    "db:push": "prisma db push",
    "cli": "tsx src/cli/index.ts"
  },
  "dependencies": {
    "@fastify/cors": "^10.0.0",
    "@fastify/http-proxy": "^11.0.0",
    "@prisma/client": "^6.0.0",
    "bullmq": "^5.0.0",
    "cli-table3": "^0.6.5",
    "commander": "^13.0.0",
    "fastify": "^5.0.0",
    "jose": "^6.0.0",
    "yaml": "^2.6.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "prisma": "^6.0.0",
    "tsx": "^4.0.0",
    "typescript": "^5.4.0",
    "vitest": "^3.0.0",
    "vitest-mock-extended": "^2.0.0"
  }
}
```

- [ ] **Step 2: Create tsconfig.json**

Write `token_manager/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "frontend", "tests"]
}
```

- [ ] **Step 3: Create vitest.config.ts**

Write `token_manager/vitest.config.ts`:
```typescript
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    include: ['tests/unit/**/*.test.ts'],
    globals: true,
  },
})
```

- [ ] **Step 4: Create .gitignore**

Write `token_manager/.gitignore`:
```
node_modules/
dist/
.next/
config/config.yaml
*.env.local
```

- [ ] **Step 5: Install dependencies**

Run: `cd token_manager && npm install`
Expected: `node_modules/` created, `package-lock.json` generated

- [ ] **Step 6: Verify TypeScript compiles**

Run: `cd token_manager && npx tsc --noEmit`
Expected: No errors (no source files yet, just validates config)

- [ ] **Step 7: Commit**

```bash
git add token_manager/package.json token_manager/package-lock.json token_manager/tsconfig.json token_manager/vitest.config.ts token_manager/.gitignore
git commit -m "feat(token-manager): scaffold project with dependencies"
```

---

### Task 2: Prisma schema and migrations

**Files:**
- Create: `token_manager/prisma/schema.prisma`
- Create: `token_manager/config/init-db.sql`
- Modify: `twake_db/postgres/init-db-postgres/` (add new init script)

- [ ] **Step 1: Create the Prisma schema**

Write `token_manager/prisma/schema.prisma`:
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
  accessToken   String
  refreshToken  String?
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
  token     String    @unique
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

- [ ] **Step 2: Generate Prisma client**

Run: `cd token_manager && npx prisma generate`
Expected: `Prisma Client generated` message

- [ ] **Step 3: Create DB init script for shared PostgreSQL**

Write `twake_db/postgres/init-db-postgres/03-init-token-manager.sql`:
```sql
SELECT 'CREATE DATABASE token_manager'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'token_manager')\gexec
```

- [ ] **Step 4: Create local init script for standalone use**

Write `token_manager/config/init-db.sql`:
```sql
-- Run this manually if not using twake_db shared postgres
CREATE DATABASE token_manager;
```

- [ ] **Step 5: Create initial migration**

Run: `cd token_manager && DATABASE_URL="postgresql://postgres:postgres@localhost:5432/token_manager" npx prisma migrate dev --name init`
Expected: Migration files created in `prisma/migrations/`

Note: If the local postgres is not running, you can skip this step. The migration will be created when the Docker container starts. Alternatively, use `npx prisma migrate diff --from-empty --to-schema-datamodel prisma/schema.prisma --script > prisma/migrations/0001_init/migration.sql` to generate without a live DB.

- [ ] **Step 6: Commit**

```bash
git add token_manager/prisma/ twake_db/postgres/init-db-postgres/03-init-token-manager.sql token_manager/config/init-db.sql
git commit -m "feat(token-manager): add Prisma schema and DB init scripts"
```

---

### Task 3: Crypto service

**Files:**
- Create: `token_manager/src/api/services/crypto.ts`
- Create: `token_manager/tests/unit/crypto.test.ts`

- [ ] **Step 1: Write the failing tests for crypto**

Write `token_manager/tests/unit/crypto.test.ts`:
```typescript
import { describe, it, expect, beforeAll } from 'vitest'
import { encrypt, decrypt, hashToken, generateUmbrellaToken } from '../../src/api/services/crypto.js'

const TEST_KEY = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2'

describe('crypto', () => {
  describe('encrypt/decrypt', () => {
    it('roundtrips a plaintext string', () => {
      const plaintext = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.test-token'
      const encrypted = encrypt(plaintext, TEST_KEY)
      const decrypted = decrypt(encrypted, TEST_KEY)
      expect(decrypted).toBe(plaintext)
    })

    it('produces different ciphertexts for the same plaintext (unique IV)', () => {
      const plaintext = 'same-token-value'
      const a = encrypt(plaintext, TEST_KEY)
      const b = encrypt(plaintext, TEST_KEY)
      expect(a).not.toBe(b)
    })

    it('throws on tampered ciphertext', () => {
      const encrypted = encrypt('secret', TEST_KEY)
      const tampered = encrypted.slice(0, -4) + 'XXXX'
      expect(() => decrypt(tampered, TEST_KEY)).toThrow()
    })

    it('throws on wrong key', () => {
      const encrypted = encrypt('secret', TEST_KEY)
      const wrongKey = 'ff'.repeat(32)
      expect(() => decrypt(encrypted, wrongKey)).toThrow()
    })
  })

  describe('hashToken', () => {
    it('produces a consistent SHA-256 hash', () => {
      const token = 'twt_abc123'
      const hash1 = hashToken(token)
      const hash2 = hashToken(token)
      expect(hash1).toBe(hash2)
      expect(hash1).toHaveLength(64) // hex SHA-256
    })

    it('produces different hashes for different tokens', () => {
      expect(hashToken('twt_aaa')).not.toBe(hashToken('twt_bbb'))
    })
  })

  describe('generateUmbrellaToken', () => {
    it('generates a token with twt_ prefix', () => {
      const token = generateUmbrellaToken()
      expect(token).toMatch(/^twt_[a-f0-9]{32,}$/)
    })

    it('generates unique tokens', () => {
      const a = generateUmbrellaToken()
      const b = generateUmbrellaToken()
      expect(a).not.toBe(b)
    })
  })
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd token_manager && npx vitest run tests/unit/crypto.test.ts`
Expected: FAIL — module `../../src/api/services/crypto.js` not found

- [ ] **Step 3: Implement crypto service**

Create directories:
```bash
mkdir -p token_manager/src/api/services
```

Write `token_manager/src/api/services/crypto.ts`:
```typescript
import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto'

const ALGORITHM = 'aes-256-gcm'
const IV_LENGTH = 12
const AUTH_TAG_LENGTH = 16

export function encrypt(plaintext: string, hexKey: string): string {
  const key = Buffer.from(hexKey, 'hex')
  const iv = randomBytes(IV_LENGTH)
  const cipher = createCipheriv(ALGORITHM, key, iv, { authTagLength: AUTH_TAG_LENGTH })
  const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()])
  const authTag = cipher.getAuthTag()
  const combined = Buffer.concat([iv, authTag, encrypted])
  return combined.toString('base64')
}

export function decrypt(ciphertext: string, hexKey: string): string {
  const key = Buffer.from(hexKey, 'hex')
  const combined = Buffer.from(ciphertext, 'base64')
  const iv = combined.subarray(0, IV_LENGTH)
  const authTag = combined.subarray(IV_LENGTH, IV_LENGTH + AUTH_TAG_LENGTH)
  const encrypted = combined.subarray(IV_LENGTH + AUTH_TAG_LENGTH)
  const decipher = createDecipheriv(ALGORITHM, key, iv, { authTagLength: AUTH_TAG_LENGTH })
  decipher.setAuthTag(authTag)
  const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()])
  return decrypted.toString('utf8')
}

export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex')
}

export function generateUmbrellaToken(): string {
  const bytes = randomBytes(24)
  return `twt_${bytes.toString('hex')}`
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd token_manager && npx vitest run tests/unit/crypto.test.ts`
Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add token_manager/src/api/services/crypto.ts token_manager/tests/unit/crypto.test.ts
git commit -m "feat(token-manager): add AES-256-GCM crypto service with tests"
```

---

### Task 4: Config loader

**Files:**
- Create: `token_manager/src/api/config.ts`
- Create: `token_manager/config/config.yaml.template`
- Create: `token_manager/tests/unit/config.test.ts`

- [ ] **Step 1: Write the failing tests for config**

Write `token_manager/tests/unit/config.test.ts`:
```typescript
import { describe, it, expect } from 'vitest'
import { parseConfig, type AppConfig } from '../../src/api/config.js'

const VALID_YAML = `
server:
  port: 3100
  host: 0.0.0.0
database:
  url: postgresql://postgres:postgres@postgres:5432/token_manager
redis:
  url: redis://:valkeypass@visio-valkey:6379
oidc:
  issuer: https://auth.twake.local
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
    instance_url_pattern: "https://{username}-drive.twake.local"
    oauth_redirect_uri: "https://token-manager-api.twake.local/oauth/callback/cozy"
  twake-mail:
    auto_refresh: false
    token_validity: 1h
    scopes:
      - "Email/*"
    instance_url: "https://jmap.twake.local"
`

describe('config', () => {
  it('parses valid YAML into AppConfig', () => {
    const config = parseConfig(VALID_YAML)
    expect(config.server.port).toBe(3100)
    expect(config.redis.url).toBe('redis://:valkeypass@visio-valkey:6379')
    expect(config.refresh.cron).toBe('*/5 * * * *')
    expect(config.refresh.max_retries).toBe(3)
    expect(config.services['twake-drive'].auto_refresh).toBe(true)
    expect(config.services['twake-drive'].scopes).toEqual(['io.cozy.files'])
    expect(config.services['twake-mail'].auto_refresh).toBe(false)
  })

  it('parses refresh_before_expiry duration string to milliseconds', () => {
    const config = parseConfig(VALID_YAML)
    expect(config.refresh.refresh_before_expiry_ms).toBe(15 * 60 * 1000)
  })

  it('parses token_validity duration string to milliseconds', () => {
    const config = parseConfig(VALID_YAML)
    expect(config.services['twake-drive'].token_validity_ms).toBe(60 * 60 * 1000)
    expect(config.services['twake-mail'].token_validity_ms).toBe(60 * 60 * 1000)
  })

  it('throws on missing required fields', () => {
    expect(() => parseConfig('server:\n  port: 3100')).toThrow()
  })
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd token_manager && npx vitest run tests/unit/config.test.ts`
Expected: FAIL — module `../../src/api/config.js` not found

- [ ] **Step 3: Implement config loader**

Write `token_manager/src/api/config.ts`:
```typescript
import { parse } from 'yaml'

export interface ServiceConfig {
  auto_refresh: boolean
  token_validity: string
  token_validity_ms: number
  refresh_token_validity?: string
  scopes: string[]
  instance_url?: string
  instance_url_pattern?: string
  oauth_redirect_uri?: string
}

export interface AppConfig {
  server: { port: number; host: string }
  database: { url: string }
  redis: { url: string }
  oidc: { issuer: string; audience: string }
  refresh: {
    cron: string
    refresh_before_expiry: string
    refresh_before_expiry_ms: number
    max_retries: number
  }
  services: Record<string, ServiceConfig>
}

function parseDuration(duration: string): number {
  const match = duration.match(/^(\d+)(ms|s|m|h|d)$/)
  if (!match) throw new Error(`Invalid duration: ${duration}`)
  const value = parseInt(match[1], 10)
  const unit = match[2]
  const multipliers: Record<string, number> = {
    ms: 1,
    s: 1000,
    m: 60 * 1000,
    h: 60 * 60 * 1000,
    d: 24 * 60 * 60 * 1000,
  }
  return value * multipliers[unit]
}

export function parseConfig(yamlContent: string): AppConfig {
  const raw = parse(yamlContent)

  if (!raw.server || !raw.database || !raw.redis || !raw.oidc || !raw.refresh || !raw.services) {
    throw new Error('Missing required config sections: server, database, redis, oidc, refresh, services')
  }

  const refresh = {
    ...raw.refresh,
    refresh_before_expiry_ms: parseDuration(raw.refresh.refresh_before_expiry),
  }

  const services: Record<string, ServiceConfig> = {}
  for (const [name, svc] of Object.entries(raw.services as Record<string, any>)) {
    services[name] = {
      ...svc,
      token_validity_ms: parseDuration(svc.token_validity),
    }
  }

  return {
    server: raw.server,
    database: raw.database,
    redis: raw.redis,
    oidc: raw.oidc,
    refresh,
    services,
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd token_manager && npx vitest run tests/unit/config.test.ts`
Expected: All 4 tests PASS

- [ ] **Step 5: Create config.yaml.template**

Write `token_manager/config/config.yaml.template`:
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

- [ ] **Step 6: Commit**

```bash
git add token_manager/src/api/config.ts token_manager/tests/unit/config.test.ts token_manager/config/config.yaml.template
git commit -m "feat(token-manager): add config loader with duration parsing"
```

---

## Phase 2: Connectors

### Task 5: ServiceConnector interface and types

**Files:**
- Create: `token_manager/src/api/connectors/interface.ts`

- [ ] **Step 1: Create the connector interface and shared types**

```bash
mkdir -p token_manager/src/api/connectors
```

Write `token_manager/src/api/connectors/interface.ts`:
```typescript
import type { Tenant } from '@prisma/client'

export interface TokenPair {
  accessToken: string
  refreshToken?: string
  expiresAt: Date
}

export interface AuthResult {
  type: 'redirect' | 'direct'
  redirectUrl?: string
  tokenPair?: TokenPair
  state?: string
}

export interface ServiceConnector {
  readonly serviceId: string

  authenticate(userId: string, tenant: Tenant, oidcToken: string): Promise<AuthResult>
  handleCallback?(code: string, state: string): Promise<TokenPair>
  refresh(refreshToken: string, tenant: Tenant): Promise<TokenPair>
  revoke(accessToken: string, tenant: Tenant): Promise<void>
  getInstanceUrl(userId: string, tenant: Tenant): string
}
```

- [ ] **Step 2: Commit**

```bash
git add token_manager/src/api/connectors/interface.ts
git commit -m "feat(token-manager): add ServiceConnector interface"
```

---

### Task 6: CozyDriveConnector

**Files:**
- Create: `token_manager/src/api/connectors/cozy-drive.ts`
- Create: `token_manager/tests/unit/connectors/cozy-drive.test.ts`

- [ ] **Step 1: Write the failing tests**

```bash
mkdir -p token_manager/tests/unit/connectors
```

Write `token_manager/tests/unit/connectors/cozy-drive.test.ts`:
```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { CozyDriveConnector } from '../../../src/api/connectors/cozy-drive.js'
import type { Tenant } from '@prisma/client'

const mockTenant: Tenant = {
  id: 'tenant1',
  domain: 'twake.local',
  name: 'Test',
  config: {
    cozyBaseUrl: 'https://{user}-drive.twake.local',
  },
  createdAt: new Date(),
}

const mockServiceConfig = {
  auto_refresh: true,
  token_validity: '1h',
  token_validity_ms: 3600000,
  scopes: ['io.cozy.files'],
  instance_url_pattern: 'https://{username}-drive.twake.local',
  oauth_redirect_uri: 'https://token-manager-api.twake.local/oauth/callback/cozy',
}

describe('CozyDriveConnector', () => {
  let connector: CozyDriveConnector

  beforeEach(() => {
    connector = new CozyDriveConnector(mockServiceConfig)
    vi.restoreAllMocks()
  })

  it('has serviceId "twake-drive"', () => {
    expect(connector.serviceId).toBe('twake-drive')
  })

  it('getInstanceUrl replaces {username} with user prefix', () => {
    const url = connector.getInstanceUrl('user1@twake.local', mockTenant)
    expect(url).toBe('https://user1-drive.twake.local')
  })

  it('authenticate returns redirect result with PKCE challenge', async () => {
    // Mock fetch for app registration
    const mockFetch = vi.fn()
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ client_id: 'cozy-client-123', client_secret: 'secret', registration_access_token: 'reg-token' }),
      })

    vi.stubGlobal('fetch', mockFetch)

    const result = await connector.authenticate('user1@twake.local', mockTenant, 'oidc-token')

    expect(result.type).toBe('redirect')
    expect(result.redirectUrl).toContain('user1-drive.twake.local/auth/authorize')
    expect(result.redirectUrl).toContain('code_challenge=')
    expect(result.redirectUrl).toContain('scope=io.cozy.files')
    expect(result.state).toBeDefined()
  })

  it('handleCallback exchanges code for token pair', async () => {
    // First register the app to populate internal state
    const mockFetch = vi.fn()
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ client_id: 'cozy-client-123', client_secret: 'secret', registration_access_token: 'reg-token' }),
      })
    vi.stubGlobal('fetch', mockFetch)
    await connector.authenticate('user1@twake.local', mockTenant, 'oidc-token')

    // Now mock the token exchange
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        access_token: 'cozy-access-token',
        refresh_token: 'cozy-refresh-token',
        token_type: 'bearer',
        scope: 'io.cozy.files',
      }),
    })

    const state = result_state(connector)
    const tokenPair = await connector.handleCallback!('auth-code-123', state)

    expect(tokenPair.accessToken).toBe('cozy-access-token')
    expect(tokenPair.refreshToken).toBe('cozy-refresh-token')
    expect(tokenPair.expiresAt).toBeInstanceOf(Date)
  })

  it('refresh sends grant_type=refresh_token', async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        access_token: 'new-access-token',
        refresh_token: 'new-refresh-token',
        token_type: 'bearer',
      }),
    })
    vi.stubGlobal('fetch', mockFetch)

    const tokenPair = await connector.refresh('old-refresh-token', mockTenant)

    expect(mockFetch).toHaveBeenCalledOnce()
    const [url, opts] = mockFetch.mock.calls[0]
    expect(opts.body).toContain('grant_type=refresh_token')
    expect(tokenPair.accessToken).toBe('new-access-token')
  })
})

// Helper to extract internal state for testing handleCallback
function result_state(connector: CozyDriveConnector): string {
  // Access the last pending auth state from the connector
  return (connector as any)._pendingAuths?.keys().next().value ?? ''
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd token_manager && npx vitest run tests/unit/connectors/cozy-drive.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement CozyDriveConnector**

Write `token_manager/src/api/connectors/cozy-drive.ts`:
```typescript
import { createHash, randomBytes } from 'node:crypto'
import type { Tenant } from '@prisma/client'
import type { ServiceConnector, AuthResult, TokenPair } from './interface.js'
import type { ServiceConfig } from '../config.js'

interface PendingAuth {
  userId: string
  instanceUrl: string
  clientId: string
  clientSecret: string
  codeVerifier: string
}

export class CozyDriveConnector implements ServiceConnector {
  readonly serviceId = 'twake-drive'
  private config: ServiceConfig
  _pendingAuths = new Map<string, PendingAuth>()

  constructor(config: ServiceConfig) {
    this.config = config
  }

  getInstanceUrl(userId: string, _tenant: Tenant): string {
    const username = userId.split('@')[0]
    return (this.config.instance_url_pattern ?? '').replace('{username}', username)
  }

  async authenticate(userId: string, tenant: Tenant, _oidcToken: string): Promise<AuthResult> {
    const instanceUrl = this.getInstanceUrl(userId, tenant)

    // Register OAuth2 app on user's Cozy instance
    const regResponse = await fetch(`${instanceUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        redirect_uris: [this.config.oauth_redirect_uri],
        client_name: 'Twake Token Manager',
        software_id: 'twake-token-manager',
        client_kind: 'web',
        client_uri: 'https://token-manager.twake.local',
      }),
    })

    if (!regResponse.ok) {
      throw new Error(`Cozy app registration failed: ${regResponse.status}`)
    }

    const reg = await regResponse.json() as {
      client_id: string
      client_secret: string
      registration_access_token: string
    }

    // Generate PKCE challenge
    const codeVerifier = randomBytes(32).toString('hex')
    const codeChallenge = createHash('sha256').update(codeVerifier).digest('base64url')

    // Generate state
    const state = randomBytes(16).toString('hex')

    // Store pending auth
    this._pendingAuths.set(state, {
      userId,
      instanceUrl,
      clientId: reg.client_id,
      clientSecret: reg.client_secret,
      codeVerifier,
    })

    const scopes = this.config.scopes.join(' ')
    const redirectUrl = `${instanceUrl}/auth/authorize?` +
      `client_id=${encodeURIComponent(reg.client_id)}` +
      `&redirect_uri=${encodeURIComponent(this.config.oauth_redirect_uri!)}` +
      `&response_type=code` +
      `&scope=${encodeURIComponent(scopes)}` +
      `&code_challenge=${codeChallenge}` +
      `&code_challenge_method=S256` +
      `&state=${state}`

    return { type: 'redirect', redirectUrl, state }
  }

  async handleCallback(code: string, state: string): Promise<TokenPair> {
    const pending = this._pendingAuths.get(state)
    if (!pending) {
      throw new Error('No pending auth for this state')
    }

    this._pendingAuths.delete(state)

    const response = await fetch(`${pending.instanceUrl}/auth/access_token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        client_id: pending.clientId,
        client_secret: pending.clientSecret,
        code_verifier: pending.codeVerifier,
      }).toString(),
    })

    if (!response.ok) {
      throw new Error(`Cozy token exchange failed: ${response.status}`)
    }

    const data = await response.json() as {
      access_token: string
      refresh_token: string
      token_type: string
    }

    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token,
      expiresAt: new Date(Date.now() + this.config.token_validity_ms),
    }
  }

  async refresh(refreshToken: string, tenant: Tenant): Promise<TokenPair> {
    // For refresh, we need the instance URL. We extract it from context.
    // In practice, this is called with the stored instanceUrl from the ServiceToken record.
    // The tenant config has the base pattern.
    const response = await fetch(`https://placeholder/auth/access_token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
      }).toString(),
    })

    if (!response.ok) {
      throw new Error(`Cozy token refresh failed: ${response.status}`)
    }

    const data = await response.json() as {
      access_token: string
      refresh_token?: string
    }

    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token ?? refreshToken,
      expiresAt: new Date(Date.now() + this.config.token_validity_ms),
    }
  }

  async revoke(accessToken: string, _tenant: Tenant): Promise<void> {
    // Cozy revocation is done by deleting the registered app
    // This requires the registration_access_token, which we'd need to store
    // For now, we just invalidate locally
  }
}
```

Note: The `refresh` method has a placeholder URL — in Task 9 (token-service), when we call `refresh`, we pass the `instanceUrl` from the stored `ServiceToken` record. We'll update the connector signature to accept `instanceUrl` as a parameter. This is refined in Task 9.

- [ ] **Step 4: Update the ServiceConnector interface to pass instanceUrl to refresh**

Edit `token_manager/src/api/connectors/interface.ts` — update the `refresh` signature:
```typescript
import type { Tenant } from '@prisma/client'

export interface TokenPair {
  accessToken: string
  refreshToken?: string
  expiresAt: Date
}

export interface AuthResult {
  type: 'redirect' | 'direct'
  redirectUrl?: string
  tokenPair?: TokenPair
  state?: string
}

export interface ServiceConnector {
  readonly serviceId: string

  authenticate(userId: string, tenant: Tenant, oidcToken: string): Promise<AuthResult>
  handleCallback?(code: string, state: string): Promise<TokenPair>
  refresh(refreshToken: string, tenant: Tenant, instanceUrl: string): Promise<TokenPair>
  revoke(accessToken: string, tenant: Tenant): Promise<void>
  getInstanceUrl(userId: string, tenant: Tenant): string
}
```

- [ ] **Step 5: Update CozyDriveConnector.refresh to use instanceUrl parameter**

Replace the `refresh` method in `token_manager/src/api/connectors/cozy-drive.ts`:
```typescript
  async refresh(refreshToken: string, _tenant: Tenant, instanceUrl: string): Promise<TokenPair> {
    const response = await fetch(`${instanceUrl}/auth/access_token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
      }).toString(),
    })

    if (!response.ok) {
      throw new Error(`Cozy token refresh failed: ${response.status}`)
    }

    const data = await response.json() as {
      access_token: string
      refresh_token?: string
    }

    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token ?? refreshToken,
      expiresAt: new Date(Date.now() + this.config.token_validity_ms),
    }
  }
```

- [ ] **Step 6: Update test for refresh to pass instanceUrl**

In `cozy-drive.test.ts`, update the refresh test:
```typescript
    const tokenPair = await connector.refresh('old-refresh-token', mockTenant, 'https://user1-drive.twake.local')
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd token_manager && npx vitest run tests/unit/connectors/cozy-drive.test.ts`
Expected: All tests PASS (some may need minor adjustments based on the mock setup)

- [ ] **Step 8: Commit**

```bash
git add token_manager/src/api/connectors/ token_manager/tests/unit/connectors/cozy-drive.test.ts
git commit -m "feat(token-manager): add CozyDriveConnector with OAuth2 PKCE"
```

---

### Task 7: OidcBaseConnector, TmailConnector, CalendarConnector

**Files:**
- Create: `token_manager/src/api/connectors/oidc-base.ts`
- Create: `token_manager/src/api/connectors/tmail.ts`
- Create: `token_manager/src/api/connectors/calendar.ts`
- Create: `token_manager/tests/unit/connectors/tmail.test.ts`
- Create: `token_manager/tests/unit/connectors/calendar.test.ts`

- [ ] **Step 1: Write the failing tests for TmailConnector**

Write `token_manager/tests/unit/connectors/tmail.test.ts`:
```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { TmailConnector } from '../../../src/api/connectors/tmail.js'
import type { Tenant } from '@prisma/client'

const mockTenant: Tenant = {
  id: 'tenant1',
  domain: 'twake.local',
  name: 'Test',
  config: {},
  createdAt: new Date(),
}

const mockServiceConfig = {
  auto_refresh: false,
  token_validity: '1h',
  token_validity_ms: 3600000,
  scopes: ['Email/*', 'EmailSubmission/*'],
  instance_url: 'https://jmap.twake.local',
}

describe('TmailConnector', () => {
  let connector: TmailConnector

  beforeEach(() => {
    connector = new TmailConnector(mockServiceConfig, 'https://auth.twake.local')
    vi.restoreAllMocks()
  })

  it('has serviceId "twake-mail"', () => {
    expect(connector.serviceId).toBe('twake-mail')
  })

  it('getInstanceUrl returns static instance URL', () => {
    const url = connector.getInstanceUrl('user1@twake.local', mockTenant)
    expect(url).toBe('https://jmap.twake.local')
  })

  it('authenticate returns direct result with the OIDC token', async () => {
    const result = await connector.authenticate('user1@twake.local', mockTenant, 'oidc-bearer-token')
    expect(result.type).toBe('direct')
    expect(result.tokenPair).toBeDefined()
    expect(result.tokenPair!.accessToken).toBe('oidc-bearer-token')
  })

  it('refresh calls LemonLDAP token endpoint', async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        access_token: 'new-oidc-token',
        refresh_token: 'new-refresh-token',
        expires_in: 3600,
      }),
    })
    vi.stubGlobal('fetch', mockFetch)

    const tokenPair = await connector.refresh('old-refresh', mockTenant, 'https://jmap.twake.local')

    expect(mockFetch).toHaveBeenCalledOnce()
    const [url] = mockFetch.mock.calls[0]
    expect(url).toContain('auth.twake.local')
    expect(tokenPair.accessToken).toBe('new-oidc-token')
  })
})
```

- [ ] **Step 2: Write the failing tests for CalendarConnector**

Write `token_manager/tests/unit/connectors/calendar.test.ts`:
```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { CalendarConnector } from '../../../src/api/connectors/calendar.js'
import type { Tenant } from '@prisma/client'

const mockTenant: Tenant = {
  id: 'tenant1',
  domain: 'twake.local',
  name: 'Test',
  config: {},
  createdAt: new Date(),
}

const mockServiceConfig = {
  auto_refresh: true,
  token_validity: '8h',
  token_validity_ms: 28800000,
  scopes: ['CalDAV:REPORT', 'CalDAV:PUT', 'CalDAV:GET'],
  instance_url: 'https://tcalendar-side-service.twake.local',
}

describe('CalendarConnector', () => {
  let connector: CalendarConnector

  beforeEach(() => {
    connector = new CalendarConnector(mockServiceConfig, 'https://auth.twake.local')
    vi.restoreAllMocks()
  })

  it('has serviceId "twake-calendar"', () => {
    expect(connector.serviceId).toBe('twake-calendar')
  })

  it('getInstanceUrl returns static instance URL', () => {
    const url = connector.getInstanceUrl('user1@twake.local', mockTenant)
    expect(url).toBe('https://tcalendar-side-service.twake.local')
  })

  it('authenticate returns direct result with the OIDC token', async () => {
    const result = await connector.authenticate('user1@twake.local', mockTenant, 'oidc-bearer-token')
    expect(result.type).toBe('direct')
    expect(result.tokenPair!.accessToken).toBe('oidc-bearer-token')
  })
})
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd token_manager && npx vitest run tests/unit/connectors/tmail.test.ts tests/unit/connectors/calendar.test.ts`
Expected: FAIL — modules not found

- [ ] **Step 4: Implement OidcBaseConnector**

Write `token_manager/src/api/connectors/oidc-base.ts`:
```typescript
import type { Tenant } from '@prisma/client'
import type { ServiceConnector, AuthResult, TokenPair } from './interface.js'
import type { ServiceConfig } from '../config.js'

export abstract class OidcBaseConnector implements ServiceConnector {
  abstract readonly serviceId: string
  protected config: ServiceConfig
  protected oidcIssuer: string

  constructor(config: ServiceConfig, oidcIssuer: string) {
    this.config = config
    this.oidcIssuer = oidcIssuer
  }

  getInstanceUrl(_userId: string, _tenant: Tenant): string {
    return this.config.instance_url ?? ''
  }

  async authenticate(_userId: string, _tenant: Tenant, oidcToken: string): Promise<AuthResult> {
    // For OIDC-based services, the user's LemonLDAP OIDC token is directly usable
    return {
      type: 'direct',
      tokenPair: {
        accessToken: oidcToken,
        expiresAt: new Date(Date.now() + this.config.token_validity_ms),
      },
    }
  }

  async refresh(refreshToken: string, _tenant: Tenant, _instanceUrl: string): Promise<TokenPair> {
    const response = await fetch(`${this.oidcIssuer}/oauth2/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
      }).toString(),
    })

    if (!response.ok) {
      throw new Error(`OIDC token refresh failed: ${response.status}`)
    }

    const data = await response.json() as {
      access_token: string
      refresh_token?: string
      expires_in?: number
    }

    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token ?? refreshToken,
      expiresAt: new Date(Date.now() + (data.expires_in ?? this.config.token_validity_ms / 1000) * 1000),
    }
  }

  async revoke(accessToken: string, _tenant: Tenant): Promise<void> {
    await fetch(`${this.oidcIssuer}/oauth2/revoke`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        token: accessToken,
        token_type_hint: 'access_token',
      }).toString(),
    })
  }
}
```

- [ ] **Step 5: Implement TmailConnector**

Write `token_manager/src/api/connectors/tmail.ts`:
```typescript
import { OidcBaseConnector } from './oidc-base.js'

export class TmailConnector extends OidcBaseConnector {
  readonly serviceId = 'twake-mail'
}
```

- [ ] **Step 6: Implement CalendarConnector**

Write `token_manager/src/api/connectors/calendar.ts`:
```typescript
import { OidcBaseConnector } from './oidc-base.js'

export class CalendarConnector extends OidcBaseConnector {
  readonly serviceId = 'twake-calendar'
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd token_manager && npx vitest run tests/unit/connectors/tmail.test.ts tests/unit/connectors/calendar.test.ts`
Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
git add token_manager/src/api/connectors/oidc-base.ts token_manager/src/api/connectors/tmail.ts token_manager/src/api/connectors/calendar.ts token_manager/tests/unit/connectors/tmail.test.ts token_manager/tests/unit/connectors/calendar.test.ts
git commit -m "feat(token-manager): add OIDC base connector with Tmail and Calendar"
```

---

### Task 8: MatrixConnector

**Files:**
- Create: `token_manager/src/api/connectors/matrix.ts`
- Create: `token_manager/tests/unit/connectors/matrix.test.ts`

- [ ] **Step 1: Write the failing tests**

Write `token_manager/tests/unit/connectors/matrix.test.ts`:
```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { MatrixConnector } from '../../../src/api/connectors/matrix.js'
import type { Tenant } from '@prisma/client'

const mockTenant: Tenant = {
  id: 'tenant1',
  domain: 'twake.local',
  name: 'Test',
  config: {},
  createdAt: new Date(),
}

const mockServiceConfig = {
  auto_refresh: true,
  token_validity: '24h',
  token_validity_ms: 86400000,
  scopes: ['m.room.message'],
  instance_url: 'https://matrix.twake.local',
}

describe('MatrixConnector', () => {
  let connector: MatrixConnector

  beforeEach(() => {
    connector = new MatrixConnector(mockServiceConfig)
    vi.restoreAllMocks()
  })

  it('has serviceId "twake-chat"', () => {
    expect(connector.serviceId).toBe('twake-chat')
  })

  it('getInstanceUrl returns static Matrix URL', () => {
    expect(connector.getInstanceUrl('user1@twake.local', mockTenant)).toBe('https://matrix.twake.local')
  })

  it('authenticate calls Matrix login endpoint with SSO token', async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        access_token: 'matrix-access-token',
        device_id: 'DEVICE1',
        user_id: '@user1:twake.local',
      }),
    })
    vi.stubGlobal('fetch', mockFetch)

    const result = await connector.authenticate('user1@twake.local', mockTenant, 'oidc-token')

    expect(result.type).toBe('direct')
    expect(result.tokenPair!.accessToken).toBe('matrix-access-token')
    expect(mockFetch).toHaveBeenCalledOnce()
    const [url, opts] = mockFetch.mock.calls[0]
    expect(url).toContain('/_matrix/client/v3/login')
  })

  it('refresh calls Matrix refresh endpoint', async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        access_token: 'new-matrix-token',
        refresh_token: 'new-refresh',
        expires_in_ms: 86400000,
      }),
    })
    vi.stubGlobal('fetch', mockFetch)

    const tokenPair = await connector.refresh('old-refresh', mockTenant, 'https://matrix.twake.local')
    expect(tokenPair.accessToken).toBe('new-matrix-token')
  })

  it('revoke calls Matrix logout endpoint', async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({ ok: true })
    vi.stubGlobal('fetch', mockFetch)

    await connector.revoke('matrix-token', mockTenant)

    const [url, opts] = mockFetch.mock.calls[0]
    expect(url).toContain('/_matrix/client/v3/logout')
    expect(opts.headers['Authorization']).toBe('Bearer matrix-token')
  })
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd token_manager && npx vitest run tests/unit/connectors/matrix.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement MatrixConnector**

Write `token_manager/src/api/connectors/matrix.ts`:
```typescript
import type { Tenant } from '@prisma/client'
import type { ServiceConnector, AuthResult, TokenPair } from './interface.js'
import type { ServiceConfig } from '../config.js'

export class MatrixConnector implements ServiceConnector {
  readonly serviceId = 'twake-chat'
  private config: ServiceConfig

  constructor(config: ServiceConfig) {
    this.config = config
  }

  getInstanceUrl(_userId: string, _tenant: Tenant): string {
    return this.config.instance_url ?? ''
  }

  async authenticate(_userId: string, _tenant: Tenant, oidcToken: string): Promise<AuthResult> {
    const matrixUrl = this.config.instance_url!

    const response = await fetch(`${matrixUrl}/_matrix/client/v3/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        type: 'm.login.token',
        token: oidcToken,
      }),
    })

    if (!response.ok) {
      throw new Error(`Matrix login failed: ${response.status}`)
    }

    const data = await response.json() as {
      access_token: string
      device_id: string
      user_id: string
    }

    return {
      type: 'direct',
      tokenPair: {
        accessToken: data.access_token,
        expiresAt: new Date(Date.now() + this.config.token_validity_ms),
      },
    }
  }

  async refresh(refreshToken: string, _tenant: Tenant, instanceUrl: string): Promise<TokenPair> {
    const response = await fetch(`${instanceUrl}/_matrix/client/v3/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refreshToken }),
    })

    if (!response.ok) {
      throw new Error(`Matrix refresh failed: ${response.status}`)
    }

    const data = await response.json() as {
      access_token: string
      refresh_token?: string
      expires_in_ms?: number
    }

    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token ?? refreshToken,
      expiresAt: new Date(Date.now() + (data.expires_in_ms ?? this.config.token_validity_ms)),
    }
  }

  async revoke(accessToken: string, _tenant: Tenant): Promise<void> {
    const matrixUrl = this.config.instance_url!
    await fetch(`${matrixUrl}/_matrix/client/v3/logout`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
    })
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd token_manager && npx vitest run tests/unit/connectors/matrix.test.ts`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add token_manager/src/api/connectors/matrix.ts token_manager/tests/unit/connectors/matrix.test.ts
git commit -m "feat(token-manager): add MatrixConnector with SSO login"
```

---

## Phase 3: Core Services & Middleware

### Task 9: Auth middleware (OIDC validation)

**Files:**
- Create: `token_manager/src/api/middleware/auth.ts`
- Create: `token_manager/tests/unit/middleware-auth.test.ts`

- [ ] **Step 1: Write the failing tests**

Write `token_manager/tests/unit/middleware-auth.test.ts`:
```typescript
import { describe, it, expect, vi } from 'vitest'
import { validateOidcToken, type OidcUser } from '../../src/api/middleware/auth.js'

describe('validateOidcToken', () => {
  it('returns null for missing Authorization header', async () => {
    const result = await validateOidcToken(undefined, 'https://auth.twake.local')
    expect(result).toBeNull()
  })

  it('returns null for non-Bearer token', async () => {
    const result = await validateOidcToken('Basic abc123', 'https://auth.twake.local')
    expect(result).toBeNull()
  })

  it('extracts Bearer token and returns user info on valid JWT', async () => {
    // Mock jose JWKS verification
    const mockJwtVerify = vi.fn().mockResolvedValueOnce({
      payload: {
        sub: 'user1',
        email: 'user1@twake.local',
        groups: ['token-manager-admins'],
      },
    })

    const result = await validateOidcToken(
      'Bearer valid-jwt-token',
      'https://auth.twake.local',
      mockJwtVerify,
    )

    expect(result).toEqual({
      sub: 'user1',
      email: 'user1@twake.local',
      groups: ['token-manager-admins'],
      token: 'valid-jwt-token',
      isAdmin: true,
    })
  })

  it('sets isAdmin false when user has no admin group', async () => {
    const mockJwtVerify = vi.fn().mockResolvedValueOnce({
      payload: {
        sub: 'user2',
        email: 'user2@twake.local',
        groups: [],
      },
    })

    const result = await validateOidcToken(
      'Bearer valid-jwt-token',
      'https://auth.twake.local',
      mockJwtVerify,
    )

    expect(result!.isAdmin).toBe(false)
  })
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd token_manager && npx vitest run tests/unit/middleware-auth.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement auth middleware**

```bash
mkdir -p token_manager/src/api/middleware
```

Write `token_manager/src/api/middleware/auth.ts`:
```typescript
import type { FastifyRequest, FastifyReply } from 'fastify'
import * as jose from 'jose'

const ADMIN_GROUP = 'token-manager-admins'

export interface OidcUser {
  sub: string
  email: string
  groups: string[]
  token: string
  isAdmin: boolean
}

type JwtVerifyFn = (token: string, issuer: string) => Promise<{ payload: Record<string, any> }>

export async function validateOidcToken(
  authHeader: string | undefined,
  oidcIssuer: string,
  jwtVerifyFn?: JwtVerifyFn,
): Promise<OidcUser | null> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null
  }

  const token = authHeader.slice(7)

  const verify = jwtVerifyFn ?? defaultJwtVerify

  try {
    const { payload } = await verify(token, oidcIssuer)
    const groups = (payload.groups as string[]) ?? []

    return {
      sub: payload.sub as string,
      email: (payload.email as string) ?? `${payload.sub}@unknown`,
      groups,
      token,
      isAdmin: groups.some((g) => g.includes(ADMIN_GROUP)),
    }
  } catch {
    return null
  }
}

let cachedJwks: ReturnType<typeof jose.createRemoteJWKSet> | null = null

async function defaultJwtVerify(token: string, oidcIssuer: string) {
  if (!cachedJwks) {
    cachedJwks = jose.createRemoteJWKSet(new URL(`${oidcIssuer}/.well-known/jwks.json`))
  }
  return jose.jwtVerify(token, cachedJwks, { issuer: oidcIssuer })
}

export function authHook(oidcIssuer: string) {
  return async (request: FastifyRequest, reply: FastifyReply) => {
    const user = await validateOidcToken(request.headers.authorization, oidcIssuer)
    if (!user) {
      reply.code(401).send({ error: 'invalid_oidc_token' })
      return
    }
    ;(request as any).user = user
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd token_manager && npx vitest run tests/unit/middleware-auth.test.ts`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add token_manager/src/api/middleware/auth.ts token_manager/tests/unit/middleware-auth.test.ts
git commit -m "feat(token-manager): add OIDC auth middleware with jose JWT validation"
```

---

### Task 10: Tenant middleware

**Files:**
- Create: `token_manager/src/api/middleware/tenant.ts`

- [ ] **Step 1: Implement tenant resolution middleware**

Write `token_manager/src/api/middleware/tenant.ts`:
```typescript
import type { FastifyRequest, FastifyReply } from 'fastify'
import type { PrismaClient, Tenant } from '@prisma/client'

export function tenantHook(prisma: PrismaClient) {
  return async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user
    if (!user) return // auth middleware will have already rejected

    // Priority: X-Twake-Tenant header > email domain
    const tenantDomain =
      (request.headers['x-twake-tenant'] as string) ??
      user.email.split('@')[1]

    if (!tenantDomain) {
      reply.code(400).send({ error: 'cannot_resolve_tenant' })
      return
    }

    const tenant = await prisma.tenant.findUnique({
      where: { domain: tenantDomain },
    })

    if (!tenant) {
      reply.code(404).send({ error: 'tenant_not_found', domain: tenantDomain })
      return
    }

    ;(request as any).tenant = tenant
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add token_manager/src/api/middleware/tenant.ts
git commit -m "feat(token-manager): add tenant resolution middleware"
```

---

### Task 11: TokenService (core business logic)

**Files:**
- Create: `token_manager/src/api/services/token-service.ts`
- Create: `token_manager/tests/unit/token-service.test.ts`

- [ ] **Step 1: Write the failing tests**

Write `token_manager/tests/unit/token-service.test.ts`:
```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { TokenService } from '../../src/api/services/token-service.js'
import { mockDeep } from 'vitest-mock-extended'
import type { PrismaClient } from '@prisma/client'
import type { ServiceConnector } from '../../src/api/connectors/interface.js'

const TEST_KEY = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2'

const mockTenant = {
  id: 'tenant1',
  domain: 'twake.local',
  name: 'Test',
  config: {},
  createdAt: new Date(),
}

describe('TokenService', () => {
  let prisma: ReturnType<typeof mockDeep<PrismaClient>>
  let service: TokenService
  let mockConnector: ServiceConnector

  beforeEach(() => {
    prisma = mockDeep<PrismaClient>()
    mockConnector = {
      serviceId: 'twake-mail',
      authenticate: vi.fn().mockResolvedValue({
        type: 'direct',
        tokenPair: {
          accessToken: 'access-123',
          refreshToken: 'refresh-123',
          expiresAt: new Date(Date.now() + 3600000),
        },
      }),
      refresh: vi.fn().mockResolvedValue({
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
        expiresAt: new Date(Date.now() + 3600000),
      }),
      revoke: vi.fn().mockResolvedValue(undefined),
      getInstanceUrl: vi.fn().mockReturnValue('https://jmap.twake.local'),
    }

    const connectors = new Map([['twake-mail', mockConnector]])
    service = new TokenService(prisma as any, connectors, TEST_KEY)
  })

  it('getOrCreateToken returns existing ACTIVE token if valid', async () => {
    const existingToken = {
      id: 'tok1',
      tenantId: 'tenant1',
      userId: 'user1@twake.local',
      service: 'twake-mail',
      instanceUrl: 'https://jmap.twake.local',
      accessToken: 'encrypted-value',
      refreshToken: null,
      expiresAt: new Date(Date.now() + 3600000),
      autoRefresh: true,
      grantedBy: 'test',
      grantedAt: new Date(),
      lastUsedAt: null,
      lastRefreshAt: null,
      status: 'ACTIVE' as const,
    }

    prisma.serviceToken.findUnique.mockResolvedValue(existingToken)

    const result = await service.getOrCreateToken('twake-mail', 'user1@twake.local', mockTenant, 'oidc-token', 'test')

    expect(result.status).toBe('active')
    expect(prisma.serviceToken.findUnique).toHaveBeenCalledOnce()
    expect(mockConnector.authenticate).not.toHaveBeenCalled()
  })

  it('getOrCreateToken authenticates and stores when no token exists', async () => {
    prisma.serviceToken.findUnique.mockResolvedValue(null)
    prisma.serviceToken.create.mockResolvedValue({
      id: 'tok-new',
      tenantId: 'tenant1',
      userId: 'user1@twake.local',
      service: 'twake-mail',
      instanceUrl: 'https://jmap.twake.local',
      accessToken: 'encrypted',
      refreshToken: null,
      expiresAt: new Date(Date.now() + 3600000),
      autoRefresh: true,
      grantedBy: 'test',
      grantedAt: new Date(),
      lastUsedAt: null,
      lastRefreshAt: null,
      status: 'ACTIVE' as const,
    })

    const result = await service.getOrCreateToken('twake-mail', 'user1@twake.local', mockTenant, 'oidc-token', 'test')

    expect(mockConnector.authenticate).toHaveBeenCalledOnce()
    expect(prisma.serviceToken.create).toHaveBeenCalledOnce()
  })

  it('revokeToken sets status to REVOKED and calls connector.revoke', async () => {
    const existingToken = {
      id: 'tok1',
      tenantId: 'tenant1',
      userId: 'user1@twake.local',
      service: 'twake-mail',
      instanceUrl: 'https://jmap.twake.local',
      accessToken: 'encrypted',
      refreshToken: null,
      expiresAt: new Date(),
      autoRefresh: true,
      grantedBy: 'test',
      grantedAt: new Date(),
      lastUsedAt: null,
      lastRefreshAt: null,
      status: 'ACTIVE' as const,
    }

    prisma.serviceToken.findUnique.mockResolvedValue(existingToken)
    prisma.serviceToken.update.mockResolvedValue({ ...existingToken, status: 'REVOKED' })

    await service.revokeToken('twake-mail', 'user1@twake.local', mockTenant)

    expect(prisma.serviceToken.update).toHaveBeenCalledWith({
      where: { id: 'tok1' },
      data: { status: 'REVOKED' },
    })
  })

  it('listTokens returns all tokens for a user in a tenant', async () => {
    prisma.serviceToken.findMany.mockResolvedValue([])

    const result = await service.listTokens('user1@twake.local', 'tenant1')

    expect(prisma.serviceToken.findMany).toHaveBeenCalledWith({
      where: { userId: 'user1@twake.local', tenantId: 'tenant1' },
    })
  })
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd token_manager && npx vitest run tests/unit/token-service.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement TokenService**

Write `token_manager/src/api/services/token-service.ts`:
```typescript
import type { PrismaClient, Tenant, ServiceToken } from '@prisma/client'
import type { ServiceConnector } from '../connectors/interface.js'
import { encrypt, decrypt } from './crypto.js'

export interface TokenResult {
  status: 'active' | 'consent_required'
  token?: {
    accessToken: string
    refreshToken?: string
    expiresAt: Date
    service: string
    instanceUrl: string
  }
  redirectUrl?: string
}

export class TokenService {
  private prisma: PrismaClient
  private connectors: Map<string, ServiceConnector>
  private encryptionKey: string

  constructor(
    prisma: PrismaClient,
    connectors: Map<string, ServiceConnector>,
    encryptionKey: string,
  ) {
    this.prisma = prisma
    this.connectors = connectors
    this.encryptionKey = encryptionKey
  }

  async getOrCreateToken(
    service: string,
    userId: string,
    tenant: Tenant,
    oidcToken: string,
    grantedBy: string,
  ): Promise<TokenResult> {
    const connector = this.connectors.get(service)
    if (!connector) {
      throw new Error(`Unknown service: ${service}`)
    }

    // Check for existing valid token
    const existing = await this.prisma.serviceToken.findUnique({
      where: {
        tenantId_userId_service: {
          tenantId: tenant.id,
          userId,
          service,
        },
      },
    })

    if (existing && existing.status === 'ACTIVE' && existing.expiresAt > new Date()) {
      return {
        status: 'active',
        token: {
          accessToken: decrypt(existing.accessToken, this.encryptionKey),
          refreshToken: existing.refreshToken
            ? decrypt(existing.refreshToken, this.encryptionKey)
            : undefined,
          expiresAt: existing.expiresAt,
          service,
          instanceUrl: existing.instanceUrl,
        },
      }
    }

    // Authenticate via connector
    const authResult = await connector.authenticate(userId, tenant, oidcToken)

    if (authResult.type === 'redirect') {
      return {
        status: 'consent_required',
        redirectUrl: authResult.redirectUrl,
      }
    }

    const tokenPair = authResult.tokenPair!
    const instanceUrl = connector.getInstanceUrl(userId, tenant)

    // Upsert token
    const data = {
      userId,
      service,
      instanceUrl,
      accessToken: encrypt(tokenPair.accessToken, this.encryptionKey),
      refreshToken: tokenPair.refreshToken
        ? encrypt(tokenPair.refreshToken, this.encryptionKey)
        : null,
      expiresAt: tokenPair.expiresAt,
      grantedBy,
      status: 'ACTIVE' as const,
      lastRefreshAt: null,
    }

    if (existing) {
      await this.prisma.serviceToken.update({
        where: { id: existing.id },
        data,
      })
    } else {
      await this.prisma.serviceToken.create({
        data: {
          ...data,
          tenantId: tenant.id,
          autoRefresh: true,
        },
      })
    }

    return {
      status: 'active',
      token: {
        accessToken: tokenPair.accessToken,
        refreshToken: tokenPair.refreshToken,
        expiresAt: tokenPair.expiresAt,
        service,
        instanceUrl,
      },
    }
  }

  async refreshToken(
    service: string,
    userId: string,
    tenant: Tenant,
  ): Promise<TokenResult> {
    const connector = this.connectors.get(service)
    if (!connector) throw new Error(`Unknown service: ${service}`)

    const existing = await this.prisma.serviceToken.findUnique({
      where: {
        tenantId_userId_service: {
          tenantId: tenant.id,
          userId,
          service,
        },
      },
    })

    if (!existing || !existing.refreshToken) {
      throw new Error('No token to refresh')
    }

    const decryptedRefresh = decrypt(existing.refreshToken, this.encryptionKey)
    const tokenPair = await connector.refresh(decryptedRefresh, tenant, existing.instanceUrl)

    await this.prisma.serviceToken.update({
      where: { id: existing.id },
      data: {
        accessToken: encrypt(tokenPair.accessToken, this.encryptionKey),
        refreshToken: tokenPair.refreshToken
          ? encrypt(tokenPair.refreshToken, this.encryptionKey)
          : existing.refreshToken,
        expiresAt: tokenPair.expiresAt,
        lastRefreshAt: new Date(),
        status: 'ACTIVE',
      },
    })

    return {
      status: 'active',
      token: {
        accessToken: tokenPair.accessToken,
        refreshToken: tokenPair.refreshToken,
        expiresAt: tokenPair.expiresAt,
        service,
        instanceUrl: existing.instanceUrl,
      },
    }
  }

  async revokeToken(service: string, userId: string, tenant: Tenant): Promise<void> {
    const existing = await this.prisma.serviceToken.findUnique({
      where: {
        tenantId_userId_service: {
          tenantId: tenant.id,
          userId,
          service,
        },
      },
    })

    if (!existing) return

    const connector = this.connectors.get(service)
    if (connector) {
      try {
        const decryptedToken = decrypt(existing.accessToken, this.encryptionKey)
        await connector.revoke(decryptedToken, tenant)
      } catch {
        // Best effort revocation on remote service
      }
    }

    await this.prisma.serviceToken.update({
      where: { id: existing.id },
      data: { status: 'REVOKED' },
    })
  }

  async revokeAllTokens(userId: string, tenant: Tenant): Promise<void> {
    const tokens = await this.prisma.serviceToken.findMany({
      where: { userId, tenantId: tenant.id, status: 'ACTIVE' },
    })

    for (const token of tokens) {
      await this.revokeToken(token.service, userId, tenant)
    }
  }

  async listTokens(userId: string, tenantId: string): Promise<ServiceToken[]> {
    return this.prisma.serviceToken.findMany({
      where: { userId, tenantId },
    })
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd token_manager && npx vitest run tests/unit/token-service.test.ts`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add token_manager/src/api/services/token-service.ts token_manager/tests/unit/token-service.test.ts
git commit -m "feat(token-manager): add TokenService with get/create/refresh/revoke logic"
```

---

### Task 12: UmbrellaService

**Files:**
- Create: `token_manager/src/api/services/umbrella-service.ts`
- Create: `token_manager/tests/unit/umbrella-service.test.ts`

- [ ] **Step 1: Write the failing tests**

Write `token_manager/tests/unit/umbrella-service.test.ts`:
```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { UmbrellaService } from '../../src/api/services/umbrella-service.js'
import { mockDeep } from 'vitest-mock-extended'
import type { PrismaClient } from '@prisma/client'
import { hashToken } from '../../src/api/services/crypto.js'

const mockTenant = {
  id: 'tenant1',
  domain: 'twake.local',
  name: 'Test',
  config: {},
  createdAt: new Date(),
}

describe('UmbrellaService', () => {
  let prisma: ReturnType<typeof mockDeep<PrismaClient>>
  let service: UmbrellaService

  beforeEach(() => {
    prisma = mockDeep<PrismaClient>()
    service = new UmbrellaService(prisma as any)
  })

  it('createUmbrellaToken returns a token with twt_ prefix', async () => {
    prisma.umbrellaToken.create.mockResolvedValue({
      id: 'ut1',
      tenantId: 'tenant1',
      userId: 'user1@twake.local',
      token: 'hashed',
      scopes: ['twake-drive', 'twake-calendar'],
      expiresAt: new Date(Date.now() + 86400000),
      issuedAt: new Date(),
      revokedAt: null,
    })

    const result = await service.createUmbrellaToken(
      'user1@twake.local',
      ['twake-drive', 'twake-calendar'],
      mockTenant,
    )

    expect(result.umbrellaToken).toMatch(/^twt_/)
    expect(result.scopes).toEqual(['twake-drive', 'twake-calendar'])
    expect(prisma.umbrellaToken.create).toHaveBeenCalledOnce()
  })

  it('introspect returns token details for valid token', async () => {
    const rawToken = 'twt_abc123def456'
    const hashed = hashToken(rawToken)

    prisma.umbrellaToken.findUnique.mockResolvedValue({
      id: 'ut1',
      tenantId: 'tenant1',
      userId: 'user1@twake.local',
      token: hashed,
      scopes: ['twake-drive'],
      expiresAt: new Date(Date.now() + 86400000),
      issuedAt: new Date(),
      revokedAt: null,
    })

    const result = await service.introspect(rawToken)

    expect(result).not.toBeNull()
    expect(result!.active).toBe(true)
    expect(result!.userId).toBe('user1@twake.local')
    expect(result!.scopes).toEqual(['twake-drive'])
  })

  it('introspect returns null for unknown token', async () => {
    prisma.umbrellaToken.findUnique.mockResolvedValue(null)
    const result = await service.introspect('twt_unknown')
    expect(result).toBeNull()
  })

  it('revokeUmbrellaToken sets revokedAt', async () => {
    const rawToken = 'twt_abc123def456'
    const hashed = hashToken(rawToken)

    prisma.umbrellaToken.findUnique.mockResolvedValue({
      id: 'ut1',
      tenantId: 'tenant1',
      userId: 'user1@twake.local',
      token: hashed,
      scopes: ['twake-drive'],
      expiresAt: new Date(Date.now() + 86400000),
      issuedAt: new Date(),
      revokedAt: null,
    })
    prisma.umbrellaToken.update.mockResolvedValue({} as any)

    await service.revokeUmbrellaToken(rawToken)

    expect(prisma.umbrellaToken.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'ut1' },
        data: expect.objectContaining({ revokedAt: expect.any(Date) }),
      }),
    )
  })
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd token_manager && npx vitest run tests/unit/umbrella-service.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement UmbrellaService**

Write `token_manager/src/api/services/umbrella-service.ts`:
```typescript
import type { PrismaClient, Tenant } from '@prisma/client'
import { hashToken, generateUmbrellaToken } from './crypto.js'

export interface UmbrellaTokenResult {
  umbrellaToken: string
  scopes: string[]
  expiresAt: Date
}

export interface IntrospectResult {
  active: boolean
  userId: string
  scopes: string[]
  issuedAt: Date
  expiresAt: Date
}

const UMBRELLA_TTL_MS = 24 * 60 * 60 * 1000 // 24h default

export class UmbrellaService {
  private prisma: PrismaClient

  constructor(prisma: PrismaClient) {
    this.prisma = prisma
  }

  async createUmbrellaToken(
    userId: string,
    scopes: string[],
    tenant: Tenant,
  ): Promise<UmbrellaTokenResult> {
    const rawToken = generateUmbrellaToken()
    const hashed = hashToken(rawToken)
    const expiresAt = new Date(Date.now() + UMBRELLA_TTL_MS)

    await this.prisma.umbrellaToken.create({
      data: {
        tenantId: tenant.id,
        userId,
        token: hashed,
        scopes,
        expiresAt,
      },
    })

    return {
      umbrellaToken: rawToken,
      scopes,
      expiresAt,
    }
  }

  async introspect(rawToken: string): Promise<IntrospectResult | null> {
    const hashed = hashToken(rawToken)

    const record = await this.prisma.umbrellaToken.findUnique({
      where: { token: hashed },
    })

    if (!record) return null

    const active =
      !record.revokedAt && record.expiresAt > new Date()

    return {
      active,
      userId: record.userId,
      scopes: record.scopes,
      issuedAt: record.issuedAt,
      expiresAt: record.expiresAt,
    }
  }

  async resolveUmbrellaToken(rawToken: string): Promise<{
    userId: string
    tenantId: string
    scopes: string[]
  } | null> {
    const hashed = hashToken(rawToken)
    const record = await this.prisma.umbrellaToken.findUnique({
      where: { token: hashed },
    })

    if (!record || record.revokedAt || record.expiresAt <= new Date()) {
      return null
    }

    return {
      userId: record.userId,
      tenantId: record.tenantId,
      scopes: record.scopes,
    }
  }

  async revokeUmbrellaToken(rawToken: string): Promise<void> {
    const hashed = hashToken(rawToken)
    const record = await this.prisma.umbrellaToken.findUnique({
      where: { token: hashed },
    })

    if (!record) throw new Error('Umbrella token not found')

    await this.prisma.umbrellaToken.update({
      where: { id: record.id },
      data: { revokedAt: new Date() },
    })
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd token_manager && npx vitest run tests/unit/umbrella-service.test.ts`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add token_manager/src/api/services/umbrella-service.ts token_manager/tests/unit/umbrella-service.test.ts
git commit -m "feat(token-manager): add UmbrellaService with create/introspect/revoke"
```

---

## Phase 4: API Routes

### Task 13: Fastify server bootstrap and health endpoint

**Files:**
- Create: `token_manager/src/api/server.ts`
- Create: `token_manager/src/api/routes/health.ts`

- [ ] **Step 1: Create routes directory**

```bash
mkdir -p token_manager/src/api/routes
```

- [ ] **Step 2: Create health route**

Write `token_manager/src/api/routes/health.ts`:
```typescript
import type { FastifyInstance } from 'fastify'

export async function healthRoutes(app: FastifyInstance) {
  app.get('/health', async () => {
    return { status: 'ok', service: 'twake-token-manager' }
  })
}
```

- [ ] **Step 3: Create server bootstrap**

Write `token_manager/src/api/server.ts`:
```typescript
import Fastify from 'fastify'
import cors from '@fastify/cors'
import { PrismaClient } from '@prisma/client'
import { readFileSync } from 'node:fs'
import { parseConfig } from './config.js'
import { healthRoutes } from './routes/health.js'
import { tokenRoutes } from './routes/tokens.js'
import { umbrellaRoutes } from './routes/umbrella.js'
import { proxyRoutes } from './routes/proxy.js'
import { authHook } from './middleware/auth.js'
import { tenantHook } from './middleware/tenant.js'
import { TokenService } from './services/token-service.js'
import { UmbrellaService } from './services/umbrella-service.js'
import { CozyDriveConnector } from './connectors/cozy-drive.js'
import { TmailConnector } from './connectors/tmail.js'
import { CalendarConnector } from './connectors/calendar.js'
import { MatrixConnector } from './connectors/matrix.js'
import type { ServiceConnector } from './connectors/interface.js'

export async function buildApp() {
  const configPath = process.env.CONFIG_PATH ?? './config/config.yaml'
  const configYaml = readFileSync(configPath, 'utf-8')
  const config = parseConfig(configYaml)

  const prisma = new PrismaClient({ datasourceUrl: config.database.url })
  await prisma.$connect()

  // Seed default tenant
  const existingTenant = await prisma.tenant.findFirst()
  if (!existingTenant) {
    await prisma.tenant.create({
      data: {
        domain: process.env.BASE_DOMAIN ?? 'twake.local',
        name: 'Twake Local Dev',
        config: {
          cozyBaseUrl: `https://{user}-drive.${process.env.BASE_DOMAIN ?? 'twake.local'}`,
          jmapUrl: `https://jmap.${process.env.BASE_DOMAIN ?? 'twake.local'}`,
          matrixUrl: `https://matrix.${process.env.BASE_DOMAIN ?? 'twake.local'}`,
          caldavUrl: `https://tcalendar-side-service.${process.env.BASE_DOMAIN ?? 'twake.local'}`,
        },
      },
    })
  }

  // Build connectors
  const connectors = new Map<string, ServiceConnector>()
  if (config.services['twake-drive']) {
    connectors.set('twake-drive', new CozyDriveConnector(config.services['twake-drive']))
  }
  if (config.services['twake-mail']) {
    connectors.set('twake-mail', new TmailConnector(config.services['twake-mail'], config.oidc.issuer))
  }
  if (config.services['twake-calendar']) {
    connectors.set('twake-calendar', new CalendarConnector(config.services['twake-calendar'], config.oidc.issuer))
  }
  if (config.services['twake-chat']) {
    connectors.set('twake-chat', new MatrixConnector(config.services['twake-chat']))
  }

  const encryptionKey = process.env.TOKEN_ENCRYPTION_KEY!
  const tokenService = new TokenService(prisma, connectors, encryptionKey)
  const umbrellaService = new UmbrellaService(prisma)

  const app = Fastify({ logger: true })
  await app.register(cors, { origin: true })

  // Decorate request with services
  app.decorate('tokenService', tokenService)
  app.decorate('umbrellaService', umbrellaService)
  app.decorate('prisma', prisma)
  app.decorate('config', config)
  app.decorate('connectors', connectors)

  // Public routes (no auth)
  await app.register(healthRoutes)

  // Protected routes
  await app.register(async (protectedApp) => {
    protectedApp.addHook('onRequest', authHook(config.oidc.issuer))
    protectedApp.addHook('onRequest', tenantHook(prisma))

    await protectedApp.register(tokenRoutes, { prefix: '/api/v1' })
    await protectedApp.register(umbrellaRoutes, { prefix: '/api/v1' })
    await protectedApp.register(proxyRoutes, { prefix: '/api/v1' })
  })

  return { app, config, prisma }
}

// Start server when run directly
const isMainModule = import.meta.url === `file://${process.argv[1]}`
if (isMainModule) {
  const { app, config } = await buildApp()
  await app.listen({ port: config.server.port, host: config.server.host })
}
```

- [ ] **Step 4: Commit**

```bash
git add token_manager/src/api/server.ts token_manager/src/api/routes/health.ts
git commit -m "feat(token-manager): add Fastify server bootstrap with connector wiring"
```

---

### Task 14: Token API routes

**Files:**
- Create: `token_manager/src/api/routes/tokens.ts`

- [ ] **Step 1: Implement token routes**

Write `token_manager/src/api/routes/tokens.ts`:
```typescript
import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify'
import type { OidcUser } from '../middleware/auth.js'
import type { Tenant } from '@prisma/client'

export async function tokenRoutes(app: FastifyInstance) {
  // POST /tokens — create or obtain a service token
  app.post('/tokens', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { service, user: targetUser } = request.body as { service: string; user: string }
    const tokenService = (app as any).tokenService

    const result = await tokenService.getOrCreateToken(
      service,
      targetUser ?? user.email,
      tenant,
      user.token,
      'api',
    )

    if (result.status === 'consent_required') {
      reply.code(202).send({
        status: 'consent_required',
        redirect_url: result.redirectUrl,
      })
      return
    }

    // Log audit
    await (app as any).prisma.auditLog.create({
      data: {
        tenantId: tenant.id,
        userId: targetUser ?? user.email,
        service,
        action: 'token_created',
        ip: request.ip,
      },
    })

    return {
      access_token: result.token!.accessToken,
      refresh_token: result.token!.refreshToken,
      expires_at: result.token!.expiresAt.toISOString(),
      service: result.token!.service,
      instance_url: result.token!.instanceUrl,
    }
  })

  // POST /tokens/refresh
  app.post('/tokens/refresh', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { service, user: targetUser } = request.body as { service: string; user: string }
    const tokenService = (app as any).tokenService

    try {
      const result = await tokenService.refreshToken(service, targetUser ?? user.email, tenant)

      await (app as any).prisma.auditLog.create({
        data: {
          tenantId: tenant.id,
          userId: targetUser ?? user.email,
          service,
          action: 'token_refreshed',
          ip: request.ip,
        },
      })

      return {
        access_token: result.token!.accessToken,
        refresh_token: result.token!.refreshToken,
        expires_at: result.token!.expiresAt.toISOString(),
        service: result.token!.service,
        instance_url: result.token!.instanceUrl,
      }
    } catch (err: any) {
      reply.code(502).send({ error: 'token_refresh_failed', message: err.message })
    }
  })

  // GET /tokens
  app.get('/tokens', async (request: FastifyRequest) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { user: targetUser } = request.query as { user?: string }
    const tokenService = (app as any).tokenService

    const tokens = await tokenService.listTokens(targetUser ?? user.email, tenant.id)

    return tokens.map((t: any) => ({
      service: t.service,
      status: t.status,
      expires_at: t.expiresAt.toISOString(),
      instance_url: t.instanceUrl,
      granted_by: t.grantedBy,
      granted_at: t.grantedAt.toISOString(),
      auto_refresh: t.autoRefresh,
    }))
  })

  // GET /tokens/:service
  app.get('/tokens/:service', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { service } = request.params as { service: string }
    const { user: targetUser } = request.query as { user?: string }

    const token = await (app as any).prisma.serviceToken.findUnique({
      where: {
        tenantId_userId_service: {
          tenantId: tenant.id,
          userId: targetUser ?? user.email,
          service,
        },
      },
    })

    if (!token) {
      reply.code(404).send({ error: 'no_token', service })
      return
    }

    return {
      service: token.service,
      status: token.status,
      expires_at: token.expiresAt.toISOString(),
      instance_url: token.instanceUrl,
      granted_by: token.grantedBy,
      granted_at: token.grantedAt.toISOString(),
      auto_refresh: token.autoRefresh,
      last_used_at: token.lastUsedAt?.toISOString(),
      last_refresh_at: token.lastRefreshAt?.toISOString(),
    }
  })

  // DELETE /tokens/:service
  app.delete('/tokens/:service', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { service } = request.params as { service: string }
    const { user: targetUser } = request.query as { user?: string }
    const tokenService = (app as any).tokenService

    await tokenService.revokeToken(service, targetUser ?? user.email, tenant)

    await (app as any).prisma.auditLog.create({
      data: {
        tenantId: tenant.id,
        userId: targetUser ?? user.email,
        service,
        action: 'token_revoked',
        ip: request.ip,
      },
    })

    reply.code(204).send()
  })

  // DELETE /tokens (all services)
  app.delete('/tokens', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { user: targetUser } = request.query as { user: string }
    const tokenService = (app as any).tokenService

    await tokenService.revokeAllTokens(targetUser ?? user.email, tenant)

    await (app as any).prisma.auditLog.create({
      data: {
        tenantId: tenant.id,
        userId: targetUser ?? user.email,
        action: 'all_tokens_revoked',
        ip: request.ip,
      },
    })

    reply.code(204).send()
  })

  // Admin routes
  app.get('/admin/tokens', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user as OidcUser
    if (!user.isAdmin) {
      reply.code(403).send({ error: 'admin_required' })
      return
    }

    const { tenant: tenantDomain } = request.query as { tenant?: string }
    const tenant = (request as any).tenant as Tenant

    const tokens = await (app as any).prisma.serviceToken.findMany({
      where: { tenantId: tenant.id },
    })

    return tokens.map((t: any) => ({
      user: t.userId,
      service: t.service,
      status: t.status,
      expires_at: t.expiresAt.toISOString(),
      auto_refresh: t.autoRefresh,
      granted_by: t.grantedBy,
    }))
  })

  app.get('/admin/config', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user as OidcUser
    if (!user.isAdmin) {
      reply.code(403).send({ error: 'admin_required' })
      return
    }

    return (app as any).config.services
  })

  app.put('/admin/config', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user as OidcUser
    if (!user.isAdmin) {
      reply.code(403).send({ error: 'admin_required' })
      return
    }

    const tenant = (request as any).tenant as Tenant
    const updates = request.body as Record<string, any>

    // Persist to tenant config in DB
    const currentConfig = (tenant.config as any) ?? {}
    const newConfig = { ...currentConfig, serviceOverrides: { ...currentConfig.serviceOverrides, ...updates } }

    await (app as any).prisma.tenant.update({
      where: { id: tenant.id },
      data: { config: newConfig },
    })

    return { status: 'updated' }
  })

  app.get('/admin/audit', async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user as OidcUser
    if (!user.isAdmin) {
      reply.code(403).send({ error: 'admin_required' })
      return
    }

    const tenant = (request as any).tenant as Tenant
    const { user: targetUser, limit, offset } = request.query as {
      user?: string
      limit?: string
      offset?: string
    }

    const where: any = { tenantId: tenant.id }
    if (targetUser) where.userId = targetUser

    const logs = await (app as any).prisma.auditLog.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: parseInt(limit ?? '50', 10),
      skip: parseInt(offset ?? '0', 10),
    })

    return logs.map((l: any) => ({
      timestamp: l.createdAt.toISOString(),
      user: l.userId,
      service: l.service,
      action: l.action,
      details: l.details,
      ip: l.ip,
    }))
  })
}
```

- [ ] **Step 2: Commit**

```bash
git add token_manager/src/api/routes/tokens.ts
git commit -m "feat(token-manager): add token CRUD and admin API routes"
```

---

### Task 15: Umbrella and proxy routes

**Files:**
- Create: `token_manager/src/api/routes/umbrella.ts`
- Create: `token_manager/src/api/routes/proxy.ts`

- [ ] **Step 1: Implement umbrella routes**

Write `token_manager/src/api/routes/umbrella.ts`:
```typescript
import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify'
import type { OidcUser } from '../middleware/auth.js'
import type { Tenant } from '@prisma/client'

export async function umbrellaRoutes(app: FastifyInstance) {
  // POST /umbrella-token
  app.post('/umbrella-token', async (request: FastifyRequest) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { user: targetUser, scopes } = request.body as { user: string; scopes: string[] }
    const umbrellaService = (app as any).umbrellaService

    const result = await umbrellaService.createUmbrellaToken(
      targetUser ?? user.email,
      scopes,
      tenant,
    )

    await (app as any).prisma.auditLog.create({
      data: {
        tenantId: tenant.id,
        userId: targetUser ?? user.email,
        action: 'umbrella_created',
        details: { scopes },
        ip: request.ip,
      },
    })

    return {
      umbrella_token: result.umbrellaToken,
      expires_at: result.expiresAt.toISOString(),
      scopes: result.scopes,
    }
  })

  // POST /umbrella-token/introspect
  app.post('/umbrella-token/introspect', async (request: FastifyRequest, reply: FastifyReply) => {
    const { umbrella_token } = request.body as { umbrella_token: string }
    const umbrellaService = (app as any).umbrellaService

    const result = await umbrellaService.introspect(umbrella_token)
    if (!result) {
      reply.code(401).send({ error: 'invalid_umbrella_token' })
      return
    }

    return {
      active: result.active,
      user: result.userId,
      scopes: result.scopes,
      issued_at: result.issuedAt.toISOString(),
      expires_at: result.expiresAt.toISOString(),
    }
  })

  // DELETE /umbrella-token/:token
  app.delete('/umbrella-token/:token', async (request: FastifyRequest, reply: FastifyReply) => {
    const { token } = request.params as { token: string }
    const umbrellaService = (app as any).umbrellaService
    const tenant = (request as any).tenant as Tenant

    try {
      await umbrellaService.revokeUmbrellaToken(token)

      await (app as any).prisma.auditLog.create({
        data: {
          tenantId: tenant.id,
          userId: (request as any).user.email,
          action: 'umbrella_revoked',
          ip: request.ip,
        },
      })

      reply.code(204).send()
    } catch {
      reply.code(404).send({ error: 'invalid_umbrella_token' })
    }
  })
}
```

- [ ] **Step 2: Implement proxy route**

Write `token_manager/src/api/routes/proxy.ts`:
```typescript
import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify'
import { decrypt } from '../services/crypto.js'

export async function proxyRoutes(app: FastifyInstance) {
  // ALL /proxy/:service/*
  app.all('/proxy/:service/*', async (request: FastifyRequest, reply: FastifyReply) => {
    const { service } = request.params as { service: string; '*': string }
    const targetPath = (request.params as any)['*'] ?? ''

    // Extract umbrella token from Authorization header
    const authHeader = request.headers.authorization
    if (!authHeader?.startsWith('Bearer twt_')) {
      reply.code(401).send({ error: 'invalid_umbrella_token' })
      return
    }

    const umbrellaToken = authHeader.slice(7)
    const umbrellaService = (app as any).umbrellaService

    // Resolve umbrella token
    const resolved = await umbrellaService.resolveUmbrellaToken(umbrellaToken)
    if (!resolved) {
      reply.code(401).send({ error: 'invalid_umbrella_token' })
      return
    }

    // Check scope
    if (!resolved.scopes.includes(service)) {
      reply.code(403).send({ error: 'scope_not_granted', service })
      return
    }

    // Get service token
    const prisma = (app as any).prisma
    const encryptionKey = process.env.TOKEN_ENCRYPTION_KEY!
    const serviceToken = await prisma.serviceToken.findUnique({
      where: {
        tenantId_userId_service: {
          tenantId: resolved.tenantId,
          userId: resolved.userId,
          service,
        },
      },
    })

    if (!serviceToken || serviceToken.status !== 'ACTIVE') {
      reply.code(404).send({ error: 'no_token', service })
      return
    }

    const accessToken = decrypt(serviceToken.accessToken, encryptionKey)
    const targetUrl = `${serviceToken.instanceUrl}/${targetPath}`

    // Proxy the request
    try {
      const proxyHeaders: Record<string, string> = {
        'Authorization': `Bearer ${accessToken}`,
      }

      // Forward content-type if present
      if (request.headers['content-type']) {
        proxyHeaders['Content-Type'] = request.headers['content-type']
      }

      const proxyResponse = await fetch(targetUrl, {
        method: request.method,
        headers: proxyHeaders,
        body: request.method !== 'GET' && request.method !== 'HEAD'
          ? JSON.stringify(request.body)
          : undefined,
      })

      // Update lastUsedAt asynchronously
      prisma.serviceToken.update({
        where: { id: serviceToken.id },
        data: { lastUsedAt: new Date() },
      }).catch(() => {})

      // Audit log asynchronously
      prisma.auditLog.create({
        data: {
          tenantId: resolved.tenantId,
          userId: resolved.userId,
          service,
          action: 'proxy_request',
          details: { method: request.method, path: targetPath },
        },
      }).catch(() => {})

      // Forward response
      const responseBody = await proxyResponse.text()
      reply
        .code(proxyResponse.status)
        .headers(Object.fromEntries(
          [...proxyResponse.headers.entries()].filter(
            ([key]) => !['transfer-encoding', 'connection'].includes(key.toLowerCase())
          )
        ))
        .send(responseBody)
    } catch (err: any) {
      reply.code(502).send({ error: 'service_unavailable', message: err.message })
    }
  })
}
```

- [ ] **Step 3: Add OAuth2 callback route for Cozy Drive**

This route is public (no auth middleware) — it handles the redirect from Cozy after user consent. Add to `token_manager/src/api/server.ts`, in the public routes section (alongside `healthRoutes`):

```typescript
  // OAuth2 callbacks (public, no auth)
  app.get('/oauth/callback/cozy', async (request, reply) => {
    const { code, state } = request.query as { code: string; state: string }
    const cozyConnector = connectors.get('twake-drive') as CozyDriveConnector | undefined

    if (!cozyConnector?.handleCallback) {
      reply.code(400).send({ error: 'cozy_connector_not_configured' })
      return
    }

    try {
      const tokenPair = await cozyConnector.handleCallback(code, state)
      // The connector's _pendingAuths had the userId/instanceUrl keyed by state (now consumed).
      // We need to persist the token. The pending auth info was extracted inside handleCallback.
      // For now, redirect to success; full persistence is wired during implementation.
      reply.redirect(`https://token-manager.${process.env.BASE_DOMAIN ?? 'twake.local'}/user?consent=success`)
    } catch (err: any) {
      reply.redirect(`https://token-manager.${process.env.BASE_DOMAIN ?? 'twake.local'}/user?consent=error`)
    }
  })
```

Note: During implementation, the `CozyDriveConnector.handleCallback` will be extended to return the `userId` and `instanceUrl` from the pending auth, so the callback route can persist the token via `TokenService`. This wiring is straightforward but requires passing the encryption key and prisma client into the callback handler.

- [ ] **Step 4: Commit**

```bash
git add token_manager/src/api/routes/umbrella.ts token_manager/src/api/routes/proxy.ts token_manager/src/api/server.ts
git commit -m "feat(token-manager): add umbrella, proxy, and OAuth callback routes"
```

---

## Phase 5: BullMQ Refresh Worker

### Task 16: Refresh worker

**Files:**
- Create: `token_manager/src/api/services/refresh-worker.ts`
- Create: `token_manager/tests/unit/refresh-worker.test.ts`

- [ ] **Step 1: Write the failing tests**

Write `token_manager/tests/unit/refresh-worker.test.ts`:
```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { getTokensNeedingRefresh, processRefreshJob } from '../../src/api/services/refresh-worker.js'
import { mockDeep } from 'vitest-mock-extended'
import type { PrismaClient } from '@prisma/client'
import type { ServiceConnector } from '../../src/api/connectors/interface.js'

const TEST_KEY = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2'

describe('refresh-worker', () => {
  let prisma: ReturnType<typeof mockDeep<PrismaClient>>

  beforeEach(() => {
    prisma = mockDeep<PrismaClient>()
  })

  it('getTokensNeedingRefresh queries active auto-refresh tokens near expiry', async () => {
    prisma.serviceToken.findMany.mockResolvedValue([])

    const marginMs = 15 * 60 * 1000
    await getTokensNeedingRefresh(prisma as any, marginMs)

    expect(prisma.serviceToken.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          autoRefresh: true,
          status: 'ACTIVE',
        }),
      }),
    )
  })

  it('processRefreshJob refreshes token and updates DB on success', async () => {
    const mockConnector: ServiceConnector = {
      serviceId: 'twake-mail',
      authenticate: vi.fn(),
      refresh: vi.fn().mockResolvedValue({
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
        expiresAt: new Date(Date.now() + 3600000),
      }),
      revoke: vi.fn(),
      getInstanceUrl: vi.fn(),
    }

    const token = {
      id: 'tok1',
      tenantId: 'tenant1',
      userId: 'user1@twake.local',
      service: 'twake-mail',
      instanceUrl: 'https://jmap.twake.local',
      accessToken: 'encrypted-access',
      refreshToken: 'encrypted-refresh',
      expiresAt: new Date(Date.now() + 300000),
      autoRefresh: true,
      grantedBy: 'test',
      grantedAt: new Date(),
      lastUsedAt: null,
      lastRefreshAt: null,
      status: 'ACTIVE' as const,
    }

    prisma.serviceToken.update.mockResolvedValue({ ...token, status: 'ACTIVE' })

    const connectors = new Map([['twake-mail', mockConnector]])
    await processRefreshJob(token, prisma as any, connectors, TEST_KEY)

    expect(mockConnector.refresh).toHaveBeenCalledOnce()
    expect(prisma.serviceToken.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'tok1' },
        data: expect.objectContaining({ status: 'ACTIVE' }),
      }),
    )
  })

  it('processRefreshJob sets REFRESH_FAILED on connector error', async () => {
    const mockConnector: ServiceConnector = {
      serviceId: 'twake-mail',
      authenticate: vi.fn(),
      refresh: vi.fn().mockRejectedValue(new Error('network error')),
      revoke: vi.fn(),
      getInstanceUrl: vi.fn(),
    }

    const token = {
      id: 'tok1',
      tenantId: 'tenant1',
      userId: 'user1@twake.local',
      service: 'twake-mail',
      instanceUrl: 'https://jmap.twake.local',
      accessToken: 'encrypted-access',
      refreshToken: 'encrypted-refresh',
      expiresAt: new Date(Date.now() + 300000),
      autoRefresh: true,
      grantedBy: 'test',
      grantedAt: new Date(),
      lastUsedAt: null,
      lastRefreshAt: null,
      status: 'ACTIVE' as const,
    }

    prisma.serviceToken.update.mockResolvedValue({ ...token, status: 'REFRESH_FAILED' })

    const connectors = new Map([['twake-mail', mockConnector]])
    await processRefreshJob(token, prisma as any, connectors, TEST_KEY)

    expect(prisma.serviceToken.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'tok1' },
        data: expect.objectContaining({ status: 'REFRESH_FAILED' }),
      }),
    )
  })
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd token_manager && npx vitest run tests/unit/refresh-worker.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement refresh worker**

Write `token_manager/src/api/services/refresh-worker.ts`:
```typescript
import { Queue, Worker } from 'bullmq'
import type { PrismaClient, ServiceToken } from '@prisma/client'
import type { ServiceConnector } from '../connectors/interface.js'
import { encrypt, decrypt } from './crypto.js'

export async function getTokensNeedingRefresh(
  prisma: PrismaClient,
  marginMs: number,
): Promise<ServiceToken[]> {
  const threshold = new Date(Date.now() + marginMs)

  return prisma.serviceToken.findMany({
    where: {
      autoRefresh: true,
      status: 'ACTIVE',
      expiresAt: { lt: threshold },
    },
  })
}

export async function processRefreshJob(
  token: ServiceToken,
  prisma: PrismaClient,
  connectors: Map<string, ServiceConnector>,
  encryptionKey: string,
): Promise<void> {
  const connector = connectors.get(token.service)
  if (!connector || !token.refreshToken) {
    return
  }

  try {
    const decryptedRefresh = decrypt(token.refreshToken, encryptionKey)
    const tenant = await prisma.tenant.findUnique({ where: { id: token.tenantId } })
    if (!tenant) return

    const tokenPair = await connector.refresh(decryptedRefresh, tenant, token.instanceUrl)

    await prisma.serviceToken.update({
      where: { id: token.id },
      data: {
        accessToken: encrypt(tokenPair.accessToken, encryptionKey),
        refreshToken: tokenPair.refreshToken
          ? encrypt(tokenPair.refreshToken, encryptionKey)
          : token.refreshToken,
        expiresAt: tokenPair.expiresAt,
        lastRefreshAt: new Date(),
        status: 'ACTIVE',
      },
    })

    await prisma.auditLog.create({
      data: {
        tenantId: token.tenantId,
        userId: token.userId,
        service: token.service,
        action: 'token_refreshed',
        details: { auto: true },
      },
    })
  } catch (err: any) {
    await prisma.serviceToken.update({
      where: { id: token.id },
      data: { status: 'REFRESH_FAILED' },
    })

    await prisma.auditLog.create({
      data: {
        tenantId: token.tenantId,
        userId: token.userId,
        service: token.service,
        action: 'token_refresh_failed',
        details: { error: err.message, auto: true },
      },
    })
  }
}

export function startRefreshScheduler(
  redisUrl: string,
  cron: string,
  marginMs: number,
  prisma: PrismaClient,
  connectors: Map<string, ServiceConnector>,
  encryptionKey: string,
) {
  const connectionOpts = parseRedisUrl(redisUrl)

  const queue = new Queue('token-refresh', { connection: connectionOpts })

  // Schedule recurring job
  queue.upsertJobScheduler(
    'refresh-tokens',
    { pattern: cron },
    { name: 'refresh-cycle' },
  )

  const worker = new Worker(
    'token-refresh',
    async () => {
      const tokens = await getTokensNeedingRefresh(prisma, marginMs)
      const batchSize = 10
      for (let i = 0; i < tokens.length; i += batchSize) {
        const batch = tokens.slice(i, i + batchSize)
        await Promise.allSettled(
          batch.map((t) => processRefreshJob(t, prisma, connectors, encryptionKey)),
        )
      }
    },
    { connection: connectionOpts, concurrency: 1 },
  )

  worker.on('failed', (job, err) => {
    console.error(`Refresh job failed: ${err.message}`)
  })

  return { queue, worker }
}

function parseRedisUrl(url: string) {
  const parsed = new URL(url)
  return {
    host: parsed.hostname,
    port: parseInt(parsed.port || '6379', 10),
    password: parsed.password || undefined,
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd token_manager && npx vitest run tests/unit/refresh-worker.test.ts`
Expected: All 3 tests PASS

- [ ] **Step 5: Wire refresh worker into server.ts**

Add to the end of `buildApp()` in `token_manager/src/api/server.ts`, before `return { app, config, prisma }`:
```typescript
  // Start BullMQ refresh scheduler
  const { startRefreshScheduler } = await import('./services/refresh-worker.js')
  startRefreshScheduler(
    config.redis.url,
    config.refresh.cron,
    config.refresh.refresh_before_expiry_ms,
    prisma,
    connectors,
    encryptionKey,
  )
```

- [ ] **Step 6: Commit**

```bash
git add token_manager/src/api/services/refresh-worker.ts token_manager/tests/unit/refresh-worker.test.ts token_manager/src/api/server.ts
git commit -m "feat(token-manager): add BullMQ refresh worker with cron scheduling"
```

---

## Phase 6: SDK & CLI

### Task 17: SDK

**Files:**
- Create: `token_manager/src/sdk/index.ts`
- Create: `token_manager/tests/unit/sdk.test.ts`

- [ ] **Step 1: Write the failing tests**

Write `token_manager/tests/unit/sdk.test.ts`:
```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { TwakeTokenManager, ConsentRequiredError, TwakeTokenManagerError } from '../../src/sdk/index.js'

describe('TwakeTokenManager SDK', () => {
  let sdk: TwakeTokenManager

  beforeEach(() => {
    sdk = new TwakeTokenManager({
      baseUrl: 'https://token-manager-api.twake.local',
      oidcToken: 'test-oidc-token',
    })
    vi.restoreAllMocks()
  })

  it('getToken sends POST /api/v1/tokens and returns token', async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({
        access_token: 'access-123',
        refresh_token: 'refresh-123',
        expires_at: '2026-04-04T00:00:00Z',
        service: 'twake-drive',
        instance_url: 'https://user1-drive.twake.local',
      }),
    })
    vi.stubGlobal('fetch', mockFetch)

    const result = await sdk.getToken('twake-drive', 'user1@twake.local')

    expect(result.access_token).toBe('access-123')
    expect(mockFetch).toHaveBeenCalledWith(
      'https://token-manager-api.twake.local/api/v1/tokens',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          Authorization: 'Bearer test-oidc-token',
        }),
      }),
    )
  })

  it('getToken throws ConsentRequiredError on 202', async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      status: 202,
      json: async () => ({
        status: 'consent_required',
        redirect_url: 'https://user1-drive.twake.local/auth/authorize?...',
      }),
    })
    vi.stubGlobal('fetch', mockFetch)

    await expect(sdk.getToken('twake-drive', 'user1@twake.local'))
      .rejects
      .toThrow(ConsentRequiredError)
  })

  it('listTokens sends GET /api/v1/tokens', async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ([]),
    })
    vi.stubGlobal('fetch', mockFetch)

    await sdk.listTokens('user1@twake.local')

    const [url] = mockFetch.mock.calls[0]
    expect(url).toContain('/api/v1/tokens?user=user1%40twake.local')
  })

  it('revokeToken sends DELETE /api/v1/tokens/:service', async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({ ok: true, status: 204 })
    vi.stubGlobal('fetch', mockFetch)

    await sdk.revokeToken('twake-drive', 'user1@twake.local')

    const [url, opts] = mockFetch.mock.calls[0]
    expect(url).toContain('/api/v1/tokens/twake-drive')
    expect(opts.method).toBe('DELETE')
  })

  it('getUmbrellaToken sends POST /api/v1/umbrella-token', async () => {
    const mockFetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({
        umbrella_token: 'twt_abc123',
        scopes: ['twake-drive'],
        expires_at: '2026-04-04T00:00:00Z',
      }),
    })
    vi.stubGlobal('fetch', mockFetch)

    const result = await sdk.getUmbrellaToken('user1@twake.local', ['twake-drive'])
    expect(result.umbrella_token).toBe('twt_abc123')
  })
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd token_manager && npx vitest run tests/unit/sdk.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement SDK**

```bash
mkdir -p token_manager/src/sdk
```

Write `token_manager/src/sdk/index.ts`:
```typescript
export class TwakeTokenManagerError extends Error {
  code: string
  service?: string

  constructor(code: string, message: string, service?: string) {
    super(message)
    this.name = 'TwakeTokenManagerError'
    this.code = code
    this.service = service
  }
}

export class ConsentRequiredError extends TwakeTokenManagerError {
  redirectUrl: string

  constructor(redirectUrl: string, service: string) {
    super('consent_required', `User consent required for ${service}`, service)
    this.name = 'ConsentRequiredError'
    this.redirectUrl = redirectUrl
  }
}

export interface ServiceTokenResponse {
  access_token: string
  refresh_token?: string
  expires_at: string
  service: string
  instance_url: string
}

export interface UmbrellaTokenResponse {
  umbrella_token: string
  scopes: string[]
  expires_at: string
}

export interface UmbrellaIntrospectResponse {
  active: boolean
  user: string
  scopes: string[]
  issued_at: string
  expires_at: string
}

export interface TokenStatusResponse {
  service: string
  status: string
  expires_at: string
  instance_url: string
  granted_by: string
  granted_at: string
  auto_refresh: boolean
  last_used_at?: string
  last_refresh_at?: string
}

interface Options {
  baseUrl: string
  oidcToken: string
  tenant?: string
}

export class TwakeTokenManager {
  private baseUrl: string
  private oidcToken: string
  private tenant?: string

  constructor(options: Options) {
    this.baseUrl = options.baseUrl.replace(/\/$/, '')
    this.oidcToken = options.oidcToken
    this.tenant = options.tenant
  }

  private headers(): Record<string, string> {
    const h: Record<string, string> = {
      'Authorization': `Bearer ${this.oidcToken}`,
      'Content-Type': 'application/json',
    }
    if (this.tenant) h['X-Twake-Tenant'] = this.tenant
    return h
  }

  private async request<T>(method: string, path: string, body?: any): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers: this.headers(),
      body: body ? JSON.stringify(body) : undefined,
    })

    if (response.status === 202) {
      const data = await response.json() as any
      if (data.status === 'consent_required') {
        throw new ConsentRequiredError(data.redirect_url, body?.service ?? 'unknown')
      }
    }

    if (response.status === 204) return undefined as T

    if (!response.ok) {
      const data = await response.json().catch(() => ({})) as any
      throw new TwakeTokenManagerError(
        data.error ?? 'request_failed',
        data.message ?? `HTTP ${response.status}`,
        data.service,
      )
    }

    return response.json() as T
  }

  // Granular mode
  async getToken(service: string, user: string): Promise<ServiceTokenResponse> {
    return this.request('POST', '/api/v1/tokens', { service, user })
  }

  async refreshToken(service: string, user: string): Promise<ServiceTokenResponse> {
    return this.request('POST', '/api/v1/tokens/refresh', { service, user })
  }

  async listTokens(user: string): Promise<TokenStatusResponse[]> {
    return this.request('GET', `/api/v1/tokens?user=${encodeURIComponent(user)}`)
  }

  async getTokenStatus(service: string, user: string): Promise<TokenStatusResponse> {
    return this.request('GET', `/api/v1/tokens/${service}?user=${encodeURIComponent(user)}`)
  }

  async revokeToken(service: string, user: string): Promise<void> {
    return this.request('DELETE', `/api/v1/tokens/${service}?user=${encodeURIComponent(user)}`)
  }

  async revokeAllTokens(user: string): Promise<void> {
    return this.request('DELETE', `/api/v1/tokens?user=${encodeURIComponent(user)}`)
  }

  // Umbrella mode
  async getUmbrellaToken(user: string, scopes: string[]): Promise<UmbrellaTokenResponse> {
    return this.request('POST', '/api/v1/umbrella-token', { user, scopes })
  }

  async introspectUmbrellaToken(token: string): Promise<UmbrellaIntrospectResponse> {
    return this.request('POST', '/api/v1/umbrella-token/introspect', { umbrella_token: token })
  }

  async revokeUmbrellaToken(token: string): Promise<void> {
    return this.request('DELETE', `/api/v1/umbrella-token/${encodeURIComponent(token)}`)
  }

  // Proxy
  async proxy(
    service: string,
    path: string,
    umbrellaToken: string,
    options?: { method?: string; headers?: Record<string, string>; body?: any },
  ): Promise<Response> {
    const cleanPath = path.startsWith('/') ? path.slice(1) : path
    return fetch(`${this.baseUrl}/api/v1/proxy/${service}/${cleanPath}`, {
      method: options?.method ?? 'GET',
      headers: {
        'Authorization': `Bearer ${umbrellaToken}`,
        ...options?.headers,
      },
      body: options?.body ? JSON.stringify(options.body) : undefined,
    })
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd token_manager && npx vitest run tests/unit/sdk.test.ts`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add token_manager/src/sdk/index.ts token_manager/tests/unit/sdk.test.ts
git commit -m "feat(token-manager): add TypeScript SDK client"
```

---

### Task 18: CLI

**Files:**
- Create: `token_manager/src/cli/index.ts`

- [ ] **Step 1: Implement CLI**

```bash
mkdir -p token_manager/src/cli
```

Write `token_manager/src/cli/index.ts`:
```typescript
#!/usr/bin/env node
import { Command } from 'commander'
import Table from 'cli-table3'
import { TwakeTokenManager, ConsentRequiredError } from '../sdk/index.js'

const program = new Command()

program
  .name('twake-token')
  .description('Twake Token Manager CLI')
  .version('0.1.0')
  .option('--api-url <url>', 'API URL', 'https://token-manager-api.twake.local')
  .option('--token <oidc_token>', 'OIDC Bearer token')
  .option('--tenant <domain>', 'Tenant domain')
  .option('--format <format>', 'Output format (json|table)', 'table')

function getClient(opts: any): TwakeTokenManager {
  const token = opts.token ?? process.env.TWAKE_OIDC_TOKEN
  if (!token) {
    console.error('Error: OIDC token required (--token or TWAKE_OIDC_TOKEN env)')
    process.exit(1)
  }
  return new TwakeTokenManager({
    baseUrl: opts.apiUrl ?? program.opts().apiUrl,
    oidcToken: token,
    tenant: opts.tenant ?? program.opts().tenant,
  })
}

function output(data: any, format: string) {
  if (format === 'json') {
    console.log(JSON.stringify(data, null, 2))
    return
  }

  if (Array.isArray(data)) {
    if (data.length === 0) {
      console.log('No results.')
      return
    }
    const table = new Table({ head: Object.keys(data[0]) })
    data.forEach((row) => table.push(Object.values(row)))
    console.log(table.toString())
  } else {
    const table = new Table()
    Object.entries(data).forEach(([k, v]) => table.push({ [k]: String(v) }))
    console.log(table.toString())
  }
}

// Token commands
program
  .command('create')
  .description('Create/obtain a service token')
  .requiredOption('--service <service>', 'Service name')
  .requiredOption('--user <user>', 'User email')
  .action(async (opts) => {
    const client = getClient(program.opts())
    try {
      const result = await client.getToken(opts.service, opts.user)
      output(result, program.opts().format)
    } catch (err) {
      if (err instanceof ConsentRequiredError) {
        console.log(`Consent required. Open this URL in your browser:\n${err.redirectUrl}`)
      } else {
        console.error(`Error: ${(err as Error).message}`)
        process.exit(1)
      }
    }
  })

program
  .command('list')
  .description('List tokens for a user')
  .requiredOption('--user <user>', 'User email')
  .action(async (opts) => {
    const client = getClient(program.opts())
    const result = await client.listTokens(opts.user)
    output(result, program.opts().format)
  })

program
  .command('status')
  .description('Get token status')
  .requiredOption('--service <service>', 'Service name')
  .requiredOption('--user <user>', 'User email')
  .action(async (opts) => {
    const client = getClient(program.opts())
    const result = await client.getTokenStatus(opts.service, opts.user)
    output(result, program.opts().format)
  })

program
  .command('refresh')
  .description('Force refresh a token')
  .requiredOption('--service <service>', 'Service name')
  .requiredOption('--user <user>', 'User email')
  .action(async (opts) => {
    const client = getClient(program.opts())
    const result = await client.refreshToken(opts.service, opts.user)
    output(result, program.opts().format)
  })

program
  .command('revoke')
  .description('Revoke token(s)')
  .option('--service <service>', 'Service name')
  .option('--all-services', 'Revoke all services')
  .requiredOption('--user <user>', 'User email')
  .action(async (opts) => {
    const client = getClient(program.opts())
    if (opts.allServices) {
      await client.revokeAllTokens(opts.user)
    } else if (opts.service) {
      await client.revokeToken(opts.service, opts.user)
    } else {
      console.error('Error: --service or --all-services required')
      process.exit(1)
    }
    console.log('Token(s) revoked.')
  })

// Umbrella commands
const umbrella = program.command('umbrella').description('Umbrella token commands')

umbrella
  .command('create')
  .description('Create an umbrella token')
  .requiredOption('--user <user>', 'User email')
  .requiredOption('--scopes <scopes>', 'Comma-separated scopes')
  .action(async (opts) => {
    const client = getClient(program.opts())
    const scopes = opts.scopes.split(',')
    const result = await client.getUmbrellaToken(opts.user, scopes)
    output(result, program.opts().format)
  })

umbrella
  .command('introspect')
  .description('Introspect an umbrella token')
  .requiredOption('--token <token>', 'Umbrella token (twt_...)')
  .action(async (opts) => {
    const client = getClient(program.opts())
    const result = await client.introspectUmbrellaToken(opts.token)
    output(result, program.opts().format)
  })

umbrella
  .command('revoke')
  .description('Revoke an umbrella token')
  .requiredOption('--token <token>', 'Umbrella token (twt_...)')
  .action(async (opts) => {
    const client = getClient(program.opts())
    await client.revokeUmbrellaToken(opts.token)
    console.log('Umbrella token revoked.')
  })

// Admin commands
const admin = program.command('admin').description('Admin commands')

admin
  .command('list-tokens')
  .description('List all tokens for a tenant')
  .requiredOption('--tenant <domain>', 'Tenant domain')
  .action(async (opts) => {
    const client = getClient({ ...program.opts(), tenant: opts.tenant })
    const result = await client.listTokens('')
    output(result, program.opts().format)
  })

admin
  .command('audit')
  .description('View audit log')
  .requiredOption('--tenant <domain>', 'Tenant domain')
  .option('--user <user>', 'Filter by user')
  .action(async (opts) => {
    // Direct API call for audit (not in SDK)
    const token = program.opts().token ?? process.env.TWAKE_OIDC_TOKEN
    const url = `${program.opts().apiUrl}/api/v1/admin/audit?tenant=${opts.tenant}${opts.user ? `&user=${opts.user}` : ''}`
    const response = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'X-Twake-Tenant': opts.tenant,
      },
    })
    const data = await response.json()
    output(data, program.opts().format)
  })

program.parse()
```

- [ ] **Step 2: Verify CLI parses without errors**

Run: `cd token_manager && npx tsx src/cli/index.ts --help`
Expected: Shows help text with all commands listed

- [ ] **Step 3: Commit**

```bash
git add token_manager/src/cli/index.ts
git commit -m "feat(token-manager): add CLI with Commander.js"
```

---

## Phase 7: Frontend

### Task 19: Next.js scaffolding

**Files:**
- Create: `token_manager/frontend/` (multiple files)

- [ ] **Step 1: Initialize Next.js frontend**

```bash
mkdir -p token_manager/frontend/app/admin/config
mkdir -p token_manager/frontend/app/admin/audit
mkdir -p token_manager/frontend/app/user
mkdir -p token_manager/frontend/components/ui
mkdir -p token_manager/frontend/lib
mkdir -p token_manager/frontend/public
```

Write `token_manager/frontend/next.config.js`:
```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
}

module.exports = nextConfig
```

Write `token_manager/frontend/tailwind.config.ts`:
```typescript
import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './app/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}

export default config
```

Write `token_manager/frontend/app/globals.css`:
```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

Write `token_manager/frontend/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "ES2022"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
```

- [ ] **Step 2: Create API client lib**

Write `token_manager/frontend/lib/api.ts`:
```typescript
const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'https://token-manager-api.twake.local'

export async function apiFetch<T>(path: string, options?: RequestInit): Promise<T> {
  const response = await fetch(`${API_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options?.headers,
    },
  })

  if (!response.ok) {
    throw new Error(`API error: ${response.status}`)
  }

  if (response.status === 204) return undefined as T
  return response.json() as T
}
```

Write `token_manager/frontend/lib/auth.ts`:
```typescript
'use client'

let oidcToken: string | null = null

export function setOidcToken(token: string) {
  oidcToken = token
}

export function getOidcToken(): string | null {
  return oidcToken
}

export function authHeaders(): Record<string, string> {
  if (!oidcToken) return {}
  return { Authorization: `Bearer ${oidcToken}` }
}
```

- [ ] **Step 3: Commit**

```bash
git add token_manager/frontend/
git commit -m "feat(token-manager): scaffold Next.js frontend with API client"
```

---

### Task 20: Frontend layout and admin dashboard

**Files:**
- Create: `token_manager/frontend/app/layout.tsx`
- Create: `token_manager/frontend/app/page.tsx`
- Create: `token_manager/frontend/app/admin/page.tsx`
- Create: `token_manager/frontend/components/stats-bar.tsx`
- Create: `token_manager/frontend/components/token-table.tsx`

- [ ] **Step 1: Create root layout**

Write `token_manager/frontend/app/layout.tsx`:
```tsx
import './globals.css'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Twake Token Manager',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-gray-50 text-gray-900">
        <div className="flex h-screen">
          <nav className="w-56 bg-white border-r p-4 flex flex-col gap-2">
            <h1 className="text-lg font-bold mb-4">Token Manager</h1>
            <a href="/admin" className="px-3 py-2 rounded hover:bg-gray-100">Dashboard</a>
            <a href="/admin/config" className="px-3 py-2 rounded hover:bg-gray-100">Config</a>
            <a href="/admin/audit" className="px-3 py-2 rounded hover:bg-gray-100">Audit</a>
            <hr className="my-2" />
            <a href="/user" className="px-3 py-2 rounded hover:bg-gray-100">My Access</a>
          </nav>
          <main className="flex-1 overflow-auto p-6">{children}</main>
        </div>
      </body>
    </html>
  )
}
```

- [ ] **Step 2: Create redirect page**

Write `token_manager/frontend/app/page.tsx`:
```tsx
import { redirect } from 'next/navigation'
export default function Home() {
  redirect('/admin')
}
```

- [ ] **Step 3: Create StatsBar component**

Write `token_manager/frontend/components/stats-bar.tsx`:
```tsx
'use client'

interface StatsBarProps {
  active: number
  expired: number
  umbrella: number
}

export function StatsBar({ active, expired, umbrella }: StatsBarProps) {
  return (
    <div className="grid grid-cols-3 gap-4 mb-6">
      <div className="bg-white rounded-lg border p-4">
        <div className="text-2xl font-bold text-green-600">{active}</div>
        <div className="text-sm text-gray-500">Active tokens</div>
      </div>
      <div className="bg-white rounded-lg border p-4">
        <div className="text-2xl font-bold text-red-600">{expired}</div>
        <div className="text-sm text-gray-500">Expired / Failed</div>
      </div>
      <div className="bg-white rounded-lg border p-4">
        <div className="text-2xl font-bold text-blue-600">{umbrella}</div>
        <div className="text-sm text-gray-500">Umbrella tokens</div>
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Create TokenTable component**

Write `token_manager/frontend/components/token-table.tsx`:
```tsx
'use client'

interface Token {
  user: string
  service: string
  status: string
  expires_at: string
  auto_refresh: boolean
}

interface TokenTableProps {
  tokens: Token[]
  onRevoke: (service: string, user: string) => void
  onRefresh: (service: string, user: string) => void
}

function statusBadge(status: string, expiresAt: string) {
  const minutesLeft = (new Date(expiresAt).getTime() - Date.now()) / 60000

  if (status === 'REVOKED' || status === 'REFRESH_FAILED') {
    return <span className="px-2 py-1 text-xs rounded bg-red-100 text-red-700">{status}</span>
  }
  if (minutesLeft < 15) {
    return <span className="px-2 py-1 text-xs rounded bg-orange-100 text-orange-700">{Math.round(minutesLeft)}min</span>
  }
  if (status === 'ACTIVE') {
    return <span className="px-2 py-1 text-xs rounded bg-green-100 text-green-700">Active</span>
  }
  return <span className="px-2 py-1 text-xs rounded bg-gray-100">{status}</span>
}

export function TokenTable({ tokens, onRevoke, onRefresh }: TokenTableProps) {
  return (
    <div className="bg-white rounded-lg border overflow-hidden">
      <table className="w-full">
        <thead className="bg-gray-50">
          <tr>
            <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">User</th>
            <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Service</th>
            <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Status</th>
            <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Actions</th>
          </tr>
        </thead>
        <tbody>
          {tokens.map((t, i) => (
            <tr key={i} className="border-t">
              <td className="px-4 py-3 text-sm">{t.user}</td>
              <td className="px-4 py-3 text-sm">{t.service}</td>
              <td className="px-4 py-3">{statusBadge(t.status, t.expires_at)}</td>
              <td className="px-4 py-3 flex gap-2">
                <button
                  onClick={() => onRevoke(t.service, t.user)}
                  className="px-2 py-1 text-xs border rounded hover:bg-red-50 text-red-600"
                >
                  Revoke
                </button>
                {t.auto_refresh && (
                  <button
                    onClick={() => onRefresh(t.service, t.user)}
                    className="px-2 py-1 text-xs border rounded hover:bg-blue-50 text-blue-600"
                  >
                    Refresh
                  </button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
```

- [ ] **Step 5: Create admin dashboard page**

Write `token_manager/frontend/app/admin/page.tsx`:
```tsx
'use client'

import { useEffect, useState } from 'react'
import { StatsBar } from '@/components/stats-bar'
import { TokenTable } from '@/components/token-table'
import { authHeaders } from '@/lib/auth'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'https://token-manager-api.twake.local'

export default function AdminDashboard() {
  const [tokens, setTokens] = useState<any[]>([])

  async function fetchTokens() {
    try {
      const res = await fetch(`${API_URL}/api/v1/admin/tokens`, { headers: authHeaders() })
      if (res.ok) setTokens(await res.json())
    } catch {}
  }

  useEffect(() => {
    fetchTokens()
    const interval = setInterval(fetchTokens, 30000)
    return () => clearInterval(interval)
  }, [])

  const active = tokens.filter((t) => t.status === 'ACTIVE').length
  const expired = tokens.filter((t) => t.status === 'EXPIRED' || t.status === 'REFRESH_FAILED').length

  async function handleRevoke(service: string, user: string) {
    if (!confirm(`Revoke ${service} token for ${user}?`)) return
    await fetch(`${API_URL}/api/v1/tokens/${service}?user=${encodeURIComponent(user)}`, {
      method: 'DELETE',
      headers: authHeaders(),
    })
    fetchTokens()
  }

  async function handleRefresh(service: string, user: string) {
    await fetch(`${API_URL}/api/v1/tokens/refresh`, {
      method: 'POST',
      headers: { ...authHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ service, user }),
    })
    fetchTokens()
  }

  return (
    <div>
      <h2 className="text-xl font-bold mb-4">Admin Dashboard</h2>
      <StatsBar active={active} expired={expired} umbrella={0} />
      <TokenTable tokens={tokens} onRevoke={handleRevoke} onRefresh={handleRefresh} />
    </div>
  )
}
```

- [ ] **Step 6: Commit**

```bash
git add token_manager/frontend/app/ token_manager/frontend/components/
git commit -m "feat(token-manager): add admin dashboard with token table and stats"
```

---

### Task 21: Admin config, audit, and user pages

**Files:**
- Create: `token_manager/frontend/app/admin/config/page.tsx`
- Create: `token_manager/frontend/app/admin/audit/page.tsx`
- Create: `token_manager/frontend/app/user/page.tsx`
- Create: `token_manager/frontend/components/refresh-config.tsx`
- Create: `token_manager/frontend/components/user-access-list.tsx`

- [ ] **Step 1: Create RefreshConfig component**

Write `token_manager/frontend/components/refresh-config.tsx`:
```tsx
'use client'

import { useState } from 'react'

interface ServiceRefreshConfig {
  name: string
  auto_refresh: boolean
  token_validity: string
  refresh_before_expiry?: string
}

interface RefreshConfigProps {
  services: ServiceRefreshConfig[]
  onSave: (services: ServiceRefreshConfig[]) => void
}

const VALIDITY_OPTIONS = ['30m', '1h', '4h', '8h', '24h']
const MARGIN_OPTIONS = ['5m', '10m', '15m', '30m']

export function RefreshConfig({ services, onSave }: RefreshConfigProps) {
  const [configs, setConfigs] = useState(services)

  function updateService(index: number, field: string, value: any) {
    const updated = [...configs]
    ;(updated[index] as any)[field] = value
    setConfigs(updated)
  }

  return (
    <div className="space-y-4">
      {configs.map((svc, i) => (
        <div key={svc.name} className="bg-white rounded-lg border p-4">
          <h3 className="font-medium mb-2">{svc.name}</h3>
          <div className="flex items-center gap-4">
            <label className="flex items-center gap-2">
              <input
                type="checkbox"
                checked={svc.auto_refresh}
                onChange={(e) => updateService(i, 'auto_refresh', e.target.checked)}
              />
              Auto-refresh
            </label>
            <label className="flex items-center gap-2">
              Validity:
              <select
                value={svc.token_validity}
                onChange={(e) => updateService(i, 'token_validity', e.target.value)}
                className="border rounded px-2 py-1"
              >
                {VALIDITY_OPTIONS.map((v) => <option key={v} value={v}>{v}</option>)}
              </select>
            </label>
            {svc.auto_refresh && (
              <label className="flex items-center gap-2">
                Margin:
                <select
                  value={svc.refresh_before_expiry ?? '15m'}
                  onChange={(e) => updateService(i, 'refresh_before_expiry', e.target.value)}
                  className="border rounded px-2 py-1"
                >
                  {MARGIN_OPTIONS.map((v) => <option key={v} value={v}>{v}</option>)}
                </select>
              </label>
            )}
          </div>
        </div>
      ))}
      <button
        onClick={() => onSave(configs)}
        className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
      >
        Save
      </button>
    </div>
  )
}
```

- [ ] **Step 2: Create admin config page**

Write `token_manager/frontend/app/admin/config/page.tsx`:
```tsx
'use client'

import { useEffect, useState } from 'react'
import { RefreshConfig } from '@/components/refresh-config'
import { authHeaders } from '@/lib/auth'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'https://token-manager-api.twake.local'

export default function ConfigPage() {
  const [services, setServices] = useState<any[]>([])
  const [message, setMessage] = useState('')

  useEffect(() => {
    fetch(`${API_URL}/api/v1/admin/config`, { headers: authHeaders() })
      .then((r) => r.json())
      .then((data) => {
        const list = Object.entries(data).map(([name, config]: [string, any]) => ({
          name,
          ...config,
        }))
        setServices(list)
      })
      .catch(() => {})
  }, [])

  async function handleSave(updated: any[]) {
    const body: Record<string, any> = {}
    updated.forEach((s) => { body[s.name] = s })

    const res = await fetch(`${API_URL}/api/v1/admin/config`, {
      method: 'PUT',
      headers: { ...authHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })

    setMessage(res.ok ? 'Configuration saved.' : 'Error saving configuration.')
    setTimeout(() => setMessage(''), 3000)
  }

  return (
    <div>
      <h2 className="text-xl font-bold mb-4">Refresh Configuration</h2>
      {message && <div className="mb-4 p-2 bg-green-50 text-green-700 rounded">{message}</div>}
      <RefreshConfig services={services} onSave={handleSave} />
    </div>
  )
}
```

- [ ] **Step 3: Create admin audit page**

Write `token_manager/frontend/app/admin/audit/page.tsx`:
```tsx
'use client'

import { useEffect, useState } from 'react'
import { authHeaders } from '@/lib/auth'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'https://token-manager-api.twake.local'

export default function AuditPage() {
  const [logs, setLogs] = useState<any[]>([])
  const [userFilter, setUserFilter] = useState('')

  useEffect(() => {
    const params = userFilter ? `&user=${encodeURIComponent(userFilter)}` : ''
    fetch(`${API_URL}/api/v1/admin/audit?${params}`, { headers: authHeaders() })
      .then((r) => r.json())
      .then(setLogs)
      .catch(() => {})
  }, [userFilter])

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-bold">Audit Log</h2>
        <input
          type="text"
          placeholder="Filter by user..."
          value={userFilter}
          onChange={(e) => setUserFilter(e.target.value)}
          className="border rounded px-3 py-1"
        />
      </div>
      <div className="bg-white rounded-lg border overflow-hidden">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Time</th>
              <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">User</th>
              <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Service</th>
              <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Action</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((l, i) => (
              <tr key={i} className="border-t">
                <td className="px-4 py-3 text-sm">{new Date(l.timestamp).toLocaleString()}</td>
                <td className="px-4 py-3 text-sm">{l.user}</td>
                <td className="px-4 py-3 text-sm">{l.service ?? '-'}</td>
                <td className="px-4 py-3 text-sm">{l.action}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Create user access list component**

Write `token_manager/frontend/components/user-access-list.tsx`:
```tsx
'use client'

interface UserToken {
  service: string
  granted_by: string
  granted_at: string
  status: string
}

interface UserAccessListProps {
  tokens: UserToken[]
  onRevoke: (service: string) => void
}

const SERVICE_LABELS: Record<string, string> = {
  'twake-drive': 'Twake Drive',
  'twake-calendar': 'Twake Calendar',
  'twake-mail': 'Twake Mail',
  'twake-chat': 'Twake Chat',
}

export function UserAccessList({ tokens, onRevoke }: UserAccessListProps) {
  return (
    <div className="space-y-3">
      {tokens.map((t) => (
        <div key={t.service} className="bg-white rounded-lg border p-4 flex justify-between items-center">
          <div>
            <div className="font-medium">{SERVICE_LABELS[t.service] ?? t.service}</div>
            <div className="text-sm text-gray-500">
              Granted {new Date(t.granted_at).toLocaleDateString()}
              {t.granted_by && ` by ${t.granted_by}`}
            </div>
          </div>
          <button
            onClick={() => {
              if (confirm(`Revoke access to ${SERVICE_LABELS[t.service] ?? t.service}?`)) {
                onRevoke(t.service)
              }
            }}
            className="px-3 py-1 border rounded text-red-600 hover:bg-red-50 text-sm"
          >
            Revoke access
          </button>
        </div>
      ))}
      {tokens.length === 0 && (
        <div className="text-gray-500">No active access grants.</div>
      )}
    </div>
  )
}
```

- [ ] **Step 5: Create user self-service page**

Write `token_manager/frontend/app/user/page.tsx`:
```tsx
'use client'

import { useEffect, useState } from 'react'
import { UserAccessList } from '@/components/user-access-list'
import { authHeaders } from '@/lib/auth'

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'https://token-manager-api.twake.local'

export default function UserPage() {
  const [tokens, setTokens] = useState<any[]>([])

  async function fetchTokens() {
    try {
      const res = await fetch(`${API_URL}/api/v1/tokens`, { headers: authHeaders() })
      if (res.ok) setTokens(await res.json())
    } catch {}
  }

  useEffect(() => {
    fetchTokens()
  }, [])

  async function handleRevoke(service: string) {
    await fetch(`${API_URL}/api/v1/tokens/${service}`, {
      method: 'DELETE',
      headers: authHeaders(),
    })
    fetchTokens()
  }

  const activeTokens = tokens.filter((t) => t.status === 'ACTIVE')

  return (
    <div>
      <h2 className="text-xl font-bold mb-4">My Access Grants</h2>
      <UserAccessList tokens={activeTokens} onRevoke={handleRevoke} />
    </div>
  )
}
```

- [ ] **Step 6: Commit**

```bash
git add token_manager/frontend/
git commit -m "feat(token-manager): add config, audit, and user self-service pages"
```

---

## Phase 8: Docker Integration

### Task 22: Dockerfiles, compose, and wrapper.sh integration

**Files:**
- Create: `token_manager/Dockerfile.api`
- Create: `token_manager/Dockerfile.frontend`
- Create: `token_manager/docker-compose.yml`
- Create: `token_manager/compose-wrapper.sh`
- Modify: `wrapper.sh`
- Modify: `docker-compose.yaml`
- Modify: `.env`

- [ ] **Step 1: Create Dockerfile.api**

Write `token_manager/Dockerfile.api`:
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
COPY prisma ./prisma/
RUN npm ci --omit=dev && npx prisma generate
COPY src ./src
COPY tsconfig.json ./
COPY config ./config
RUN npm run build:api
EXPOSE 3100
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/api/server.js"]
```

- [ ] **Step 2: Create Dockerfile.frontend**

Write `token_manager/Dockerfile.frontend`:
```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY frontend ./frontend
COPY frontend/next.config.js ./next.config.js
RUN npm run build:frontend

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/frontend/.next/standalone ./
COPY --from=builder /app/frontend/.next/static ./frontend/.next/static
COPY --from=builder /app/frontend/public ./frontend/public
EXPOSE 3000
CMD ["node", "frontend/server.js"]
```

- [ ] **Step 3: Create docker-compose.yml**

Write `token_manager/docker-compose.yml`:
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
      CONFIG_PATH: /app/config/config.yaml
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

- [ ] **Step 4: Create compose-wrapper.sh**

Write `token_manager/compose-wrapper.sh`:
```bash
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Generate config from template
if [ -f config/config.yaml.template ]; then
  envsubst < config/config.yaml.template > config/config.yaml
fi

sudo docker compose --env-file ../.env "$@"
```

Make executable:
```bash
chmod +x token_manager/compose-wrapper.sh
```

- [ ] **Step 5: Update wrapper.sh to include token_manager**

In `wrapper.sh`, add to the REPOS associative array (after the `["tmail_app"]` line):
```bash
    ["token_manager"]="${BASE_DIR}/token_manager"
```

Update START_ORDER:
```bash
START_ORDER=("twake_db" "twake_auth" "cozy_stack" "token_manager" "onlyoffice_app" "meet_app" "calendar_app" "chat_app" "tmail_app")
```

Update STOP_ORDER:
```bash
STOP_ORDER=("tmail_app" "chat_app" "calendar_app" "meet_app" "onlyoffice_app" "token_manager" "cozy_stack" "twake_auth" "twake_db")
```

Add to REPO_DEPS:
```bash
    ["token_manager"]="lemonldap-ng"
```

- [ ] **Step 6: Update root docker-compose.yaml**

Add `token_manager/docker-compose.yml` to the includes in `docker-compose.yaml`:
```yaml
version: '3.8'

include:
  - cozy_stack/docker-compose.yml
  - token_manager/docker-compose.yml
  - meet_app/docker-compose.yml
  - linshare_app/docker-compose.yml
  - twake_db/docker-compose.yml
  - twake_auth/docker-compose.yml
```

- [ ] **Step 7: Update .env**

Add to `.env`:
```
TOKEN_ENCRYPTION_KEY=a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2
```

- [ ] **Step 8: Commit**

```bash
git add token_manager/Dockerfile.api token_manager/Dockerfile.frontend token_manager/docker-compose.yml token_manager/compose-wrapper.sh wrapper.sh docker-compose.yaml .env
git commit -m "feat(token-manager): add Docker integration with Traefik routing"
```

---

### Task 23: LDAP bootstrap for admin group

**Files:**
- Create: `twake_db/ldap/bootstrap/04-token-manager-group.ldif`

- [ ] **Step 1: Create LDAP init file for admin group**

Write `twake_db/ldap/bootstrap/04-token-manager-group.ldif`:
```ldif
dn: ou=groups,dc=twake,dc=local
objectClass: organizationalUnit
ou: groups

dn: cn=token-manager-admins,ou=groups,dc=twake,dc=local
objectClass: groupOfNames
cn: token-manager-admins
member: uid=user1,ou=people,dc=twake,dc=local
```

Note: The exact DN structure depends on what already exists in `twake_db/ldap/bootstrap/`. Check the existing LDIF files to match the OU and user DN patterns. Adjust `ou=people` and the user DN to match the actual LDAP tree.

- [ ] **Step 2: Commit**

```bash
git add twake_db/ldap/bootstrap/04-token-manager-group.ldif
git commit -m "feat(token-manager): add LDAP admin group for token manager"
```

---

### Task 24: Update README and /etc/hosts documentation

**Files:**
- Modify: `README.md` (add token-manager to the hosts table and service list)

- [ ] **Step 1: Add token-manager entries to README**

Add to the `/etc/hosts` section of `README.md`:
```
127.0.0.1  token-manager.twake.local token-manager-api.twake.local
```

Add to the services/architecture section:
```
| Token Manager | `token-manager.twake.local` | Admin dashboard |
| Token Manager API | `token-manager-api.twake.local` | REST API |
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add Token Manager to README hosts and service list"
```

---

## Summary

| Phase | Tasks | What it produces |
|---|---|---|
| 1: Scaffolding | 1-4 | Project structure, Prisma schema, crypto, config |
| 2: Connectors | 5-8 | Interface + 4 connectors (Cozy PKCE, OIDC, Matrix) |
| 3: Core Services | 9-12 | Auth/tenant middleware, TokenService, UmbrellaService |
| 4: API Routes | 13-15 | Fastify server, token/umbrella/proxy/admin routes |
| 5: Refresh | 16 | BullMQ cron worker |
| 6: SDK & CLI | 17-18 | TypeScript SDK + Commander.js CLI |
| 7: Frontend | 19-21 | Next.js admin dashboard + user self-service |
| 8: Docker | 22-24 | Dockerfiles, compose, wrapper.sh, LDAP, README |

Total: **24 tasks**, each independently committable and testable.
