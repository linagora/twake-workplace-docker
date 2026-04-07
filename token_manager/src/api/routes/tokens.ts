import type { FastifyInstance } from 'fastify'
import type { Tenant } from '@prisma/client'
import type { OidcUser } from '../middleware/auth.js'
import type { TokenService } from '../services/token-service.js'
import type { PrismaClient } from '@prisma/client'
import type { PendingAuthStore } from '../services/pending-auth-store.js'
import { decrypt, generateServiceBearerKey } from '../services/crypto.js'

export async function tokenRoutes(app: FastifyInstance) {
  const tokenService = (app as any).tokenService as TokenService
  const prisma = (app as any).prisma as PrismaClient
  const encryptionKey = process.env.TOKEN_ENCRYPTION_KEY ?? '0'.repeat(64)
  const pendingAuthStore = (app as any).pendingAuthStore as PendingAuthStore
  const config = (app as any).config

  // POST /tokens — Create/obtain a service token
  app.post('/tokens', async (request, reply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { service, user: targetUser } = request.body as { service: string; user?: string }

    const result = await tokenService.getOrCreateToken(
      service,
      targetUser ?? user.email,
      tenant,
      user.token,
      'api',
    )

    if (result.status === 'consent_required') {
      // Persist pending auth state in DB so it survives container restarts
      if (result.state && pendingAuthStore) {
        await pendingAuthStore.save(result.state, service, targetUser ?? user.email, {
          tenantId: tenant.id,
        })
      }
      reply.code(202).send({ status: 'consent_required', redirect_url: result.redirectUrl })
      return
    }

    // Generate short bearer key if not already set
    const userId = targetUser ?? user.email
    let bearerKey = result.token!.bearerKey
    if (!bearerKey) {
      bearerKey = generateServiceBearerKey()
      await prisma.serviceToken.update({
        where: { tenantId_userId_service: { tenantId: tenant.id, userId, service } },
        data: { bearerKey },
      })
    }

    await prisma.auditLog.create({
      data: {
        tenantId: tenant.id,
        userId,
        service,
        action: 'token_created',
        ip: request.ip,
      },
    })

    return {
      access_token: bearerKey,
      expires_at: result.token!.expiresAt.toISOString(),
      service: result.token!.service,
      instance_url: result.token!.instanceUrl,
    }
  })

  // POST /tokens/refresh — Force refresh a token
  app.post('/tokens/refresh', async (request, reply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { service, user: targetUser } = request.body as { service: string; user?: string }
    const userId = targetUser ?? user.email

    try {
      const result = await tokenService.refreshToken(service, userId, tenant)

      await prisma.auditLog.create({
        data: {
          tenantId: tenant.id,
          userId,
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
    } catch {
      reply.code(502).send({ error: 'token_refresh_failed' })
    }
  })

  // GET /tokens — List user's tokens
  app.get('/tokens', async (request) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { user: queryUser } = request.query as { user?: string }
    const userId = queryUser ?? user.email

    const tokens = await tokenService.listTokens(userId, tenant.id)

    return tokens.map((t) => ({
      service: t.service,
      status: t.status,
      expires_at: t.expiresAt.toISOString(),
      instance_url: t.instanceUrl,
      granted_by: t.grantedBy,
      granted_at: t.grantedAt.toISOString(),
      auto_refresh: t.autoRefresh,
    }))
  })

  // GET /tokens/:service — Token detail
  app.get('/tokens/:service', async (request, reply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { service } = request.params as { service: string }
    const { user: queryUser } = request.query as { user?: string }
    const userId = queryUser ?? user.email

    const token = await prisma.serviceToken.findUnique({
      where: {
        tenantId_userId_service: {
          tenantId: tenant.id,
          userId,
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
      access_token: token.bearerKey ?? decrypt(token.accessToken, encryptionKey),
      expires_at: token.expiresAt.toISOString(),
      instance_url: token.instanceUrl,
      granted_by: token.grantedBy,
      granted_at: token.grantedAt.toISOString(),
      auto_refresh: token.autoRefresh,
      last_used_at: token.lastUsedAt?.toISOString() ?? null,
      last_refresh_at: token.lastRefreshAt?.toISOString() ?? null,
    }
  })

  // DELETE /tokens/:service — Revoke one token
  app.delete('/tokens/:service', async (request, reply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { service } = request.params as { service: string }
    const { user: queryUser } = request.query as { user?: string }
    const userId = queryUser ?? user.email

    await tokenService.revokeToken(service, userId, tenant)

    await prisma.auditLog.create({
      data: {
        tenantId: tenant.id,
        userId,
        service,
        action: 'token_revoked',
        ip: request.ip,
      },
    })

    reply.code(204).send()
  })

  // DELETE /tokens — Revoke all tokens (offboarding)
  app.delete('/tokens', async (request, reply) => {
    const tenant = (request as any).tenant as Tenant
    const { user: queryUser } = request.query as { user?: string }

    if (!queryUser) {
      reply.code(400).send({ error: 'user_required' })
      return
    }

    await tokenService.revokeAllTokens(queryUser, tenant)

    await prisma.auditLog.create({
      data: {
        tenantId: tenant.id,
        userId: queryUser,
        action: 'all_tokens_revoked',
        ip: request.ip,
      },
    })

    reply.code(204).send()
  })

  // GET /admin/tokens — List all tokens for a tenant (admin only)
  app.get('/admin/tokens', async (request, reply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant

    if (!user.isAdmin) {
      reply.code(403).send({ error: 'forbidden' })
      return
    }

    const tokens = await prisma.serviceToken.findMany({ where: { tenantId: tenant.id } })
    return tokens.map((t: any) => ({
      user: t.userId,
      service: t.service,
      status: t.status,
      expires_at: t.expiresAt?.toISOString?.() ?? t.expiresAt,
      instance_url: t.instanceUrl,
      granted_by: t.grantedBy,
      granted_at: t.grantedAt?.toISOString?.() ?? t.grantedAt,
      auto_refresh: t.autoRefresh,
    }))
  })

  // GET /admin/config — View refresh config (admin only)
  app.get('/admin/config', async (request, reply) => {
    const user = (request as any).user as OidcUser

    if (!user.isAdmin) {
      reply.code(403).send({ error: 'forbidden' })
      return
    }

    return { services: config.services }
  })

  // PUT /admin/config — Update refresh config (admin only)
  app.put('/admin/config', async (request, reply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant

    if (!user.isAdmin) {
      reply.code(403).send({ error: 'forbidden' })
      return
    }

    const body = request.body as Record<string, unknown>

    await prisma.tenant.update({
      where: { id: tenant.id },
      data: { config: { ...(tenant.config as Record<string, unknown>), ...body } as any },
    })

    return { status: 'updated' }
  })

  // GET /audit — User's own audit log (excludes cleared entries)
  app.get('/audit', async (request) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { limit, offset } = request.query as { limit?: string; offset?: string }
    return prisma.auditLog.findMany({
      where: { tenantId: tenant.id, userId: user.email, userCleared: false },
      orderBy: { createdAt: 'desc' },
      take: parseInt(limit ?? '50', 10),
      skip: parseInt(offset ?? '0', 10),
    })
  })

  // DELETE /audit — Hide user's audit log (admin still sees them)
  app.delete('/audit', async (request, reply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant

    await prisma.auditLog.updateMany({
      where: { tenantId: tenant.id, userId: user.email, userCleared: false },
      data: { userCleared: true },
    })

    reply.code(204).send()
  })

  // GET /admin/users — List distinct users with token counts (admin only)
  app.get('/admin/users', async (request, reply) => {
    const user = (request as any).user as OidcUser
    if (!user.isAdmin) { reply.code(403).send({ error: 'forbidden' }); return }
    const tenant = (request as any).tenant as Tenant
    const tokens = await prisma.serviceToken.findMany({
      where: { tenantId: tenant.id },
      select: { userId: true, service: true, status: true },
    })
    const umbrellas = await prisma.umbrellaToken.findMany({
      where: { tenantId: tenant.id, revokedAt: null },
      select: { userId: true },
    })
    const userMap = new Map<string, { active: number; umbrella: number }>()
    for (const t of tokens) {
      if (!userMap.has(t.userId)) userMap.set(t.userId, { active: 0, umbrella: 0 })
      if (t.status === 'ACTIVE') userMap.get(t.userId)!.active++
    }
    for (const t of umbrellas) {
      if (!userMap.has(t.userId)) userMap.set(t.userId, { active: 0, umbrella: 0 })
      userMap.get(t.userId)!.umbrella++
    }
    return Array.from(userMap.entries()).map(([email, counts]) => ({
      email, name: email.split('@')[0], ...counts,
    }))
  })

  // DELETE /admin/users/bulk-revoke — Bulk revoke (admin only)
  app.delete('/admin/users/bulk-revoke', async (request, reply) => {
    const user = (request as any).user as OidcUser
    if (!user.isAdmin) { reply.code(403).send({ error: 'forbidden' }); return }
    const tenant = (request as any).tenant as Tenant
    const { users } = request.body as { users: string[] }
    let revokedCount = 0
    for (const userId of users) {
      const result = await prisma.serviceToken.updateMany({
        where: { tenantId: tenant.id, userId, status: 'ACTIVE' },
        data: { status: 'REVOKED' },
      })
      revokedCount += result.count
      await prisma.umbrellaToken.updateMany({
        where: { tenantId: tenant.id, userId, revokedAt: null },
        data: { revokedAt: new Date() },
      })
      await prisma.auditLog.create({
        data: { tenantId: tenant.id, userId, action: 'bulk_revoked', details: { by: user.email }, ip: request.ip },
      })
    }
    return { revoked: revokedCount, users: users.length }
  })

  // GET /admin/audit — Query audit log (admin only)
  app.get('/admin/audit', async (request, reply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant

    if (!user.isAdmin) {
      reply.code(403).send({ error: 'forbidden' })
      return
    }

    const { user: filterUser, limit, offset } = request.query as {
      user?: string
      limit?: string
      offset?: string
    }

    const take = limit ? parseInt(limit, 10) : 50
    const skip = offset ? parseInt(offset, 10) : 0

    return prisma.auditLog.findMany({
      where: {
        tenantId: tenant.id,
        ...(filterUser ? { userId: filterUser } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take,
      skip,
    })
  })

  // DELETE /admin/audit — Clear all audit logs (admin only)
  app.delete('/admin/audit', async (request, reply) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant

    if (!user.isAdmin) {
      reply.code(403).send({ error: 'forbidden' })
      return
    }

    await prisma.auditLog.deleteMany({
      where: { tenantId: tenant.id },
    })

    reply.code(204).send()
  })
}
