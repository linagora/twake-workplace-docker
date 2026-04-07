import type { FastifyInstance } from 'fastify'
import type { Tenant } from '@prisma/client'
import type { OidcUser } from '../middleware/auth.js'
import type { UmbrellaService } from '../services/umbrella-service.js'
import type { PrismaClient } from '@prisma/client'

export async function umbrellaRoutes(app: FastifyInstance) {
  const umbrellaService = (app as any).umbrellaService as UmbrellaService
  const prisma = (app as any).prisma as PrismaClient

  // GET /umbrella-tokens — List umbrella tokens for user
  app.get('/umbrella-tokens', async (request) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { user: targetUser } = request.query as { user?: string }
    const userId = targetUser ?? user.email

    const tokens = await prisma.umbrellaToken.findMany({
      where: { tenantId: tenant.id, userId, revokedAt: null },
      orderBy: { issuedAt: 'desc' },
    })

    return tokens.map((t) => ({
      id: t.id,
      name: t.name,
      scopes: t.scopes,
      expires_at: t.expiresAt.toISOString(),
      issued_at: t.issuedAt.toISOString(),
      type: 'umbrella',
      status: t.expiresAt > new Date() ? 'ACTIVE' : 'EXPIRED',
      service: t.scopes.join(', '),
    }))
  })

  // POST /umbrella-token — Create umbrella token
  app.post('/umbrella-token', async (request, reply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { user: targetUser, scopes, name: tokenName } = request.body as { user: string; scopes: string[]; name?: string }

    let result
    try {
      result = await umbrellaService.createUmbrellaToken(targetUser ?? user.email, scopes, tenant.id, tokenName)
    } catch (err: any) {
      if (err.message?.includes('already exists')) {
        return reply.code(409).send({ error: 'duplicate_name', message: err.message })
      }
      throw err
    }

    await prisma.auditLog.create({
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

  // POST /umbrella-token/introspect — Introspect umbrella token
  app.post('/umbrella-token/introspect', async (request, reply) => {
    const { umbrella_token } = request.body as { umbrella_token: string }

    const result = await umbrellaService.introspect(umbrella_token)

    if (!result) {
      return reply.code(401).send({ error: 'invalid_umbrella_token' })
    }

    return {
      active: result.active,
      user: result.userId,
      scopes: result.scopes,
      issued_at: result.issuedAt.toISOString(),
      expires_at: result.expiresAt.toISOString(),
    }
  })

  // DELETE /umbrella-token/:token — Revoke umbrella token
  app.delete('/umbrella-token/:token', async (request, reply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { token } = request.params as { token: string }

    try {
      // Try revoke by ID first (from frontend list), then by raw token (from CLI/SDK)
      try {
        await umbrellaService.revokeById(token)
      } catch {
        await umbrellaService.revokeUmbrellaToken(token)
      }

      await prisma.auditLog.create({
        data: {
          tenantId: tenant.id,
          userId: user.email,
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
