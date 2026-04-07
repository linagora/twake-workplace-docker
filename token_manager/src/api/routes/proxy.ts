import type { FastifyInstance } from 'fastify'
import type { UmbrellaService } from '../services/umbrella-service.js'
import type { PrismaClient } from '@prisma/client'
import { decrypt } from '../services/crypto.js'

export async function proxyRoutes(app: FastifyInstance) {
  const umbrellaService = (app as any).umbrellaService as UmbrellaService
  const prisma = (app as any).prisma as PrismaClient

  // ALL /proxy/:service/* — Transparent proxy using umbrella token auth
  // Note: WebDAV methods (PROPFIND, REPORT) require Fastify addHttpMethod() — added in server.ts
  app.all('/proxy/:service/*', proxyHandler)

  async function proxyHandler(request: any, reply: any) {
    const { service } = request.params as { service: string }
    const wildcard = (request.params as any)['*'] as string

    // 1. Extract umbrella token from Authorization: Bearer twt_...
    const authHeader = request.headers.authorization ?? ''
    const rawToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null

    if (!rawToken) {
      return reply.code(401).send({ error: 'missing_token' })
    }

    let serviceToken: any

    if (rawToken.startsWith('stk_')) {
      // Service bearer key — direct lookup
      serviceToken = await prisma.serviceToken.findUnique({ where: { bearerKey: rawToken } })
      if (!serviceToken || serviceToken.status !== 'ACTIVE' || serviceToken.service !== service) {
        return reply.code(401).send({ error: 'invalid_token' })
      }
    } else {
      // Umbrella token (twt_...) — resolve via umbrellaService
      const resolved = await umbrellaService.resolveUmbrellaToken(rawToken)
      if (!resolved) {
        return reply.code(401).send({ error: 'invalid_token' })
      }
      if (!resolved.scopes.includes(service)) {
        return reply.code(403).send({ error: 'scope_not_granted', service })
      }
      serviceToken = await prisma.serviceToken.findUnique({
        where: {
          tenantId_userId_service: {
            tenantId: resolved.tenantId,
            userId: resolved.userId,
            service,
          },
        },
      })
      if (!serviceToken || serviceToken.status !== 'ACTIVE') {
        return reply.code(404).send({ error: 'no_token', service })
      }
    }

    // 7. Decrypt accessToken
    const encryptionKey = process.env.TOKEN_ENCRYPTION_KEY!
    let decryptedToken: string
    try {
      decryptedToken = decrypt(serviceToken.accessToken, encryptionKey)
    } catch {
      return reply.code(502).send({ error: 'service_unavailable' })
    }

    // 8. Proxy: fetch(targetUrl, { method, headers, body })
    const targetUrl = `${serviceToken.instanceUrl}/${wildcard}`
    let upstreamResponse: Response
    try {
      const proxyHeaders: Record<string, string> = {
        Authorization: `Bearer ${decryptedToken}`,
      }
      // Forward content-type and depth headers (important for WebDAV/CalDAV)
      const ct = request.headers['content-type']
      if (ct) proxyHeaders['Content-Type'] = ct
      const depth = request.headers['depth']
      if (depth) proxyHeaders['Depth'] = depth as string

      // For non-JSON bodies (XML, text), use rawBody if available, else stringify
      let proxyBody: any = undefined
      if (!['GET', 'HEAD'].includes(request.method)) {
        proxyBody = typeof request.body === 'string' ? request.body : JSON.stringify(request.body)
      }

      upstreamResponse = await fetch(targetUrl, {
        method: request.method,
        headers: proxyHeaders,
        body: proxyBody,
      })
    } catch {
      return reply.code(502).send({ error: 'service_unavailable' })
    }

    // 9. Forward response (status, headers, body)
    reply.code(upstreamResponse.status)
    upstreamResponse.headers.forEach((value, key) => {
      if (!['transfer-encoding', 'connection', 'content-encoding', 'content-length'].includes(key.toLowerCase())) {
        reply.header(key, value)
      }
    })
    const responseBody = await upstreamResponse.arrayBuffer()
    reply.send(Buffer.from(responseBody))

    // 10. Async: update lastUsedAt, create audit log (non-blocking)
    setImmediate(async () => {
      try {
        await prisma.serviceToken.update({
          where: { id: serviceToken.id },
          data: { lastUsedAt: new Date() },
        })
        await prisma.auditLog.create({
          data: {
            tenantId: serviceToken.tenantId,
            userId: serviceToken.userId,
            service,
            action: 'proxy_request',
            ip: request.ip,
          },
        })
      } catch {
        // Non-blocking, ignore errors
      }
    })
  }
}
