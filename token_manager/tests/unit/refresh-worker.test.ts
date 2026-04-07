import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mockDeep } from 'vitest-mock-extended'
import type { PrismaClient } from '@prisma/client'
import { getTokensNeedingRefresh, processRefreshJob } from '../../src/api/services/refresh-worker.js'
import type { ServiceConnector } from '../../src/api/connectors/interface.js'
import { encrypt } from '../../src/api/services/crypto.js'

const TEST_KEY = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2'

const mockTenant = {
  id: 'tenant-1',
  domain: 'twake.local',
  name: 'Twake',
  config: {},
  createdAt: new Date(),
}

const makeToken = (overrides = {}) => ({
  id: 'token-1',
  tenantId: 'tenant-1',
  userId: 'user1',
  service: 'twake-mail',
  instanceUrl: 'https://jmap.twake.local',
  accessToken: encrypt('access-123', TEST_KEY),
  refreshToken: encrypt('refresh-123', TEST_KEY),
  expiresAt: new Date(Date.now() + 5 * 60 * 1000),
  status: 'ACTIVE',
  autoRefresh: true,
  grantedBy: 'user1',
  grantedAt: new Date(),
  lastUsedAt: null,
  lastRefreshAt: null,
  ...overrides,
})

describe('getTokensNeedingRefresh', () => {
  let prisma: ReturnType<typeof mockDeep<PrismaClient>>

  beforeEach(() => {
    prisma = mockDeep<PrismaClient>()
  })

  it('queries active auto-refresh tokens expiring within the margin', async () => {
    const token = makeToken()
    ;(prisma.serviceToken.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([token])

    const marginMs = 10 * 60 * 1000 // 10 minutes
    const before = Date.now()
    const result = await getTokensNeedingRefresh(prisma as unknown as PrismaClient, marginMs)
    const after = Date.now()

    expect(prisma.serviceToken.findMany).toHaveBeenCalledOnce()
    const callArgs = (prisma.serviceToken.findMany as ReturnType<typeof vi.fn>).mock.calls[0][0]
    expect(callArgs.where.autoRefresh).toBe(true)
    expect(callArgs.where.status).toBe('ACTIVE')
    const threshold: Date = callArgs.where.expiresAt.lt
    expect(threshold.getTime()).toBeGreaterThanOrEqual(before + marginMs)
    expect(threshold.getTime()).toBeLessThanOrEqual(after + marginMs)
    expect(result).toEqual([token])
  })
})

describe('processRefreshJob', () => {
  let prisma: ReturnType<typeof mockDeep<PrismaClient>>
  let connector: ServiceConnector
  let connectors: Map<string, ServiceConnector>

  beforeEach(() => {
    prisma = mockDeep<PrismaClient>()
    connector = {
      serviceId: 'twake-mail',
      authenticate: vi.fn(),
      refresh: vi.fn(),
      revoke: vi.fn(),
      getInstanceUrl: vi.fn(),
    }
    connectors = new Map([['twake-mail', connector]])
    vi.clearAllMocks()
  })

  it('refreshes token and updates DB with ACTIVE status on success', async () => {
    const token = makeToken()
    const newExpiresAt = new Date(Date.now() + 3600000)

    ;(prisma.tenant.findUnique as ReturnType<typeof vi.fn>).mockResolvedValue(mockTenant)
    ;(connector.refresh as ReturnType<typeof vi.fn>).mockResolvedValue({
      accessToken: 'new-access',
      refreshToken: 'new-refresh',
      expiresAt: newExpiresAt,
    })
    ;(prisma.serviceToken.update as ReturnType<typeof vi.fn>).mockResolvedValue({})
    ;(prisma.auditLog.create as ReturnType<typeof vi.fn>).mockResolvedValue({})

    await processRefreshJob(token, prisma as unknown as PrismaClient, connectors, TEST_KEY)

    expect(connector.refresh).toHaveBeenCalledOnce()
    expect(connector.refresh).toHaveBeenCalledWith('refresh-123', mockTenant, token.instanceUrl)

    expect(prisma.serviceToken.update).toHaveBeenCalledOnce()
    const updateCall = (prisma.serviceToken.update as ReturnType<typeof vi.fn>).mock.calls[0][0]
    expect(updateCall.where.id).toBe('token-1')
    expect(updateCall.data.status).toBe('ACTIVE')
    expect(updateCall.data.expiresAt).toBe(newExpiresAt)
    expect(updateCall.data.lastRefreshAt).toBeInstanceOf(Date)

    expect(prisma.auditLog.create).toHaveBeenCalledOnce()
    const auditCall = (prisma.auditLog.create as ReturnType<typeof vi.fn>).mock.calls[0][0]
    expect(auditCall.data.action).toBe('token_refreshed')
    expect(auditCall.data.details.auto).toBe(true)
  })

  it('sets REFRESH_FAILED status and logs audit on connector error', async () => {
    const token = makeToken()

    ;(prisma.tenant.findUnique as ReturnType<typeof vi.fn>).mockResolvedValue(mockTenant)
    ;(connector.refresh as ReturnType<typeof vi.fn>).mockRejectedValue(new Error('upstream error'))
    ;(prisma.serviceToken.update as ReturnType<typeof vi.fn>).mockResolvedValue({})
    ;(prisma.auditLog.create as ReturnType<typeof vi.fn>).mockResolvedValue({})

    await processRefreshJob(token, prisma as unknown as PrismaClient, connectors, TEST_KEY)

    expect(prisma.serviceToken.update).toHaveBeenCalledOnce()
    const updateCall = (prisma.serviceToken.update as ReturnType<typeof vi.fn>).mock.calls[0][0]
    expect(updateCall.where.id).toBe('token-1')
    expect(updateCall.data.status).toBe('REFRESH_FAILED')

    expect(prisma.auditLog.create).toHaveBeenCalledOnce()
    const auditCall = (prisma.auditLog.create as ReturnType<typeof vi.fn>).mock.calls[0][0]
    expect(auditCall.data.action).toBe('token_refresh_failed')
    expect(auditCall.data.details.error).toBe('upstream error')
    expect(auditCall.data.details.auto).toBe(true)
  })

  it('returns early when no connector found for the token service', async () => {
    const token = makeToken({ service: 'unknown-service' })

    await processRefreshJob(token, prisma as unknown as PrismaClient, connectors, TEST_KEY)

    expect(prisma.serviceToken.update).not.toHaveBeenCalled()
    expect(prisma.auditLog.create).not.toHaveBeenCalled()
  })

  it('returns early when token has no refreshToken', async () => {
    const token = makeToken({ refreshToken: null })

    await processRefreshJob(token, prisma as unknown as PrismaClient, connectors, TEST_KEY)

    expect(prisma.serviceToken.update).not.toHaveBeenCalled()
    expect(prisma.auditLog.create).not.toHaveBeenCalled()
  })
})
