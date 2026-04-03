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
import { startRefreshScheduler } from './services/refresh-worker.js'
import { CozyDriveConnector } from './connectors/cozy-drive.js'
import { TmailConnector } from './connectors/tmail.js'
import { CalendarConnector } from './connectors/calendar.js'
import { MatrixConnector } from './connectors/matrix.js'
import type { ServiceConnector } from './connectors/interface.js'
import { PendingAuthStore } from './services/pending-auth-store.js'
import { encrypt } from './services/crypto.js'

export async function buildApp() {
  // Load and parse config
  const configPath = process.env.CONFIG_PATH ?? './config/config.yaml'
  const yamlContent = readFileSync(configPath, 'utf-8')
  const config = parseConfig(yamlContent)

  // Connect to database
  const prisma = new PrismaClient({ datasourceUrl: config.database.url })
  await prisma.$connect()

  // Seed default tenant if none exists
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

  // Build connectors from config
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

  // Create services
  const encryptionKey = process.env.TOKEN_ENCRYPTION_KEY ?? '0'.repeat(64) // 32-byte hex key
  const tokenService = new TokenService(prisma, connectors, encryptionKey)
  const umbrellaService = new UmbrellaService(prisma)
  const pendingAuthStore = new PendingAuthStore(prisma)

  // Create Fastify app with WebDAV methods support
  const app = Fastify({ logger: true })

  // Register WebDAV methods for CalDAV proxy support
  for (const method of ['PROPFIND', 'REPORT', 'MKCALENDAR', 'PROPPATCH']) {
    app.addHttpMethod(method, { hasBody: true })
  }

  // Register CORS
  await app.register(cors)

  // Decorate app with services and shared state
  app.decorate('tokenService', tokenService)
  app.decorate('umbrellaService', umbrellaService)
  app.decorate('prisma', prisma)
  app.decorate('config', config)
  app.decorate('connectors', connectors)
  app.decorate('pendingAuthStore', pendingAuthStore)

  // Public routes
  await app.register(healthRoutes)

  // Protected routes (added in Tasks 14-15)
  await app.register(async (protectedApp) => {
    protectedApp.addHook('onRequest', authHook(config.oidc.issuer))
    protectedApp.addHook('onRequest', tenantHook(prisma))
    await protectedApp.register(tokenRoutes, { prefix: '/api/v1' })
    await protectedApp.register(umbrellaRoutes, { prefix: '/api/v1' })
  })

  // Proxy routes — separate scope, uses umbrella token auth (not standard OIDC auth)
  await app.register(proxyRoutes, { prefix: '/api/v1' })

  // Start background token refresh scheduler
  startRefreshScheduler(config.redis.url, config.refresh.cron, config.refresh.refresh_before_expiry_ms, prisma, connectors, encryptionKey)

  // Generic OAuth callback handler — uses PendingAuthStore (DB-persisted, survives restarts)
  async function handleOAuthCallback(
    request: any, reply: any,
    getCodeAndState: (query: any) => { code: string; state: string },
  ) {
    const { code, state } = getCodeAndState(request.query)
    const baseDomain = process.env.BASE_DOMAIN ?? 'twake.local'

    // Look up pending auth from DB
    const pending = await pendingAuthStore.consume(state)
    if (!pending) {
      return reply.code(400).send({ error: 'no_pending_auth_for_state', state })
    }

    const connector = connectors.get(pending.service) as any
    if (!connector?.handleCallback) {
      return reply.code(400).send({ error: 'connector_not_configured', service: pending.service })
    }

    try {
      const tokenPair = await connector.handleCallback(code, state)
      const tenantId = pending.data.tenantId as string
      const userId = pending.userId

      await prisma.serviceToken.upsert({
        where: { tenantId_userId_service: { tenantId, userId, service: pending.service } },
        create: {
          tenantId, userId, service: pending.service,
          instanceUrl: connector.getInstanceUrl(userId, { id: tenantId } as any),
          accessToken: encrypt(tokenPair.accessToken, encryptionKey),
          refreshToken: tokenPair.refreshToken ? encrypt(tokenPair.refreshToken, encryptionKey) : null,
          expiresAt: tokenPair.expiresAt, grantedBy: 'oauth-consent', autoRefresh: true, status: 'ACTIVE',
        },
        update: {
          accessToken: encrypt(tokenPair.accessToken, encryptionKey),
          refreshToken: tokenPair.refreshToken ? encrypt(tokenPair.refreshToken, encryptionKey) : null,
          expiresAt: tokenPair.expiresAt, status: 'ACTIVE',
        },
      })

      await prisma.auditLog.create({
        data: { tenantId, userId, service: pending.service, action: 'token_created', details: { via: 'oauth-consent' }, ip: request.ip },
      })

      reply.redirect(`https://token-manager.${baseDomain}/tokens?consent=success&service=${pending.service}`)
    } catch (err: any) {
      console.error(`[callback/${pending.service}] Error:`, err.message)
      reply.redirect(`https://token-manager.${baseDomain}/tokens?consent=error&message=${encodeURIComponent(err.message)}`)
    }
  }

  // Cozy Drive callback
  app.get('/oauth/callback/cozy', async (request, reply) => {
    await handleOAuthCallback(request, reply, (q) => ({ code: q.code, state: q.state }))
  })

  // OIDC callback (Tmail, Calendar)
  app.get('/oauth/callback/oidc', async (request, reply) => {
    await handleOAuthCallback(request, reply, (q) => ({ code: q.code, state: q.state }))
  })

  // Matrix SSO callback — Matrix passes loginToken instead of code
  app.get('/oauth/callback/matrix', async (request, reply) => {
    await handleOAuthCallback(request, reply, (q) => ({ code: q.loginToken, state: q.state }))
  })

  return { app, config, prisma }
}

const isMainModule = import.meta.url === `file://${process.argv[1]}`
if (isMainModule) {
  const { app, config } = await buildApp()
  await app.listen({ port: config.server.port, host: config.server.host })
}
