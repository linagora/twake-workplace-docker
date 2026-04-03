import Fastify from 'fastify'
import cors from '@fastify/cors'
import { PrismaClient } from '@prisma/client'
import { readFileSync } from 'node:fs'
import { parseConfig } from './config.js'
import { healthRoutes } from './routes/health.js'
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
  const encryptionKey = process.env.ENCRYPTION_KEY ?? '0'.repeat(64) // 32-byte hex key
  const tokenService = new TokenService(prisma, connectors, encryptionKey)
  const umbrellaService = new UmbrellaService(prisma)

  // Create Fastify app
  const app = Fastify({ logger: true })

  // Register CORS
  await app.register(cors)

  // Decorate app with services and shared state
  app.decorate('tokenService', tokenService)
  app.decorate('umbrellaService', umbrellaService)
  app.decorate('prisma', prisma)
  app.decorate('config', config)
  app.decorate('connectors', connectors)

  // Public routes
  await app.register(healthRoutes)

  // Protected routes (added in Tasks 14-15)
  await app.register(async (protectedApp) => {
    protectedApp.addHook('onRequest', authHook(config.oidc.issuer))
    protectedApp.addHook('onRequest', tenantHook(prisma))
    // Routes will be registered here in upcoming tasks
  })

  return { app, config, prisma }
}

const isMainModule = import.meta.url === `file://${process.argv[1]}`
if (isMainModule) {
  const { app, config } = await buildApp()
  await app.listen({ port: config.server.port, host: config.server.host })
}
