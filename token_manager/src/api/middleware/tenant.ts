import type { FastifyRequest, FastifyReply } from 'fastify'
import type { PrismaClient, Tenant } from '@prisma/client'

export function tenantHook(prisma: PrismaClient) {
  return async (request: FastifyRequest, reply: FastifyReply) => {
    const user = (request as any).user
    if (!user) return

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
