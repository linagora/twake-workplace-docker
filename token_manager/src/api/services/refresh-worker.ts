import { Queue, Worker } from 'bullmq'
import type { PrismaClient, ServiceToken } from '@prisma/client'
import type { ServiceConnector } from '../connectors/interface.js'
import { encrypt, decrypt } from './crypto.js'

function parseRedisUrl(url: string) {
  const parsed = new URL(url)
  return {
    host: parsed.hostname,
    port: parseInt(parsed.port || '6379', 10),
    password: parsed.password || undefined,
  }
}

export async function getTokensNeedingRefresh(prisma: PrismaClient, marginMs: number): Promise<ServiceToken[]> {
  const threshold = new Date(Date.now() + marginMs)
  return prisma.serviceToken.findMany({
    where: { autoRefresh: true, status: 'ACTIVE', expiresAt: { lt: threshold } },
  })
}

export async function processRefreshJob(
  token: ServiceToken,
  prisma: PrismaClient,
  connectors: Map<string, ServiceConnector>,
  encryptionKey: string,
): Promise<void> {
  const connector = connectors.get(token.service)
  if (!connector || !token.refreshToken) return

  try {
    const decryptedRefresh = decrypt(token.refreshToken, encryptionKey)
    const tenant = await prisma.tenant.findUnique({ where: { id: token.tenantId } })
    if (!tenant) return

    const tokenPair = await connector.refresh(decryptedRefresh, tenant, token.instanceUrl)

    await prisma.serviceToken.update({
      where: { id: token.id },
      data: {
        accessToken: encrypt(tokenPair.accessToken, encryptionKey),
        refreshToken: tokenPair.refreshToken ? encrypt(tokenPair.refreshToken, encryptionKey) : token.refreshToken,
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
    await prisma.serviceToken.update({ where: { id: token.id }, data: { status: 'REFRESH_FAILED' } })
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

  queue.upsertJobScheduler('refresh-tokens', { pattern: cron }, { name: 'refresh-cycle' })

  const worker = new Worker(
    'token-refresh',
    async () => {
      const tokens = await getTokensNeedingRefresh(prisma, marginMs)
      const batchSize = 10
      for (let i = 0; i < tokens.length; i += batchSize) {
        const batch = tokens.slice(i, i + batchSize)
        await Promise.allSettled(batch.map((t) => processRefreshJob(t, prisma, connectors, encryptionKey)))
      }
    },
    { connection: connectionOpts, concurrency: 1 },
  )

  worker.on('failed', (job, err) => {
    console.error(`Refresh job failed: ${err.message}`)
  })

  return { queue, worker }
}
