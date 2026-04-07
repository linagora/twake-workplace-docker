import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mockDeep } from 'vitest-mock-extended'
import type { PrismaClient } from '@prisma/client'
import { TokenService } from '../../src/api/services/token-service.js'
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

const mockConnector: ServiceConnector = {
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

describe('TokenService', () => {
  let prisma: ReturnType<typeof mockDeep<PrismaClient>>
  let connectors: Map<string, ServiceConnector>
  let service: TokenService

  beforeEach(() => {
    prisma = mockDeep<PrismaClient>()
    connectors = new Map([['twake-mail', mockConnector]])
    service = new TokenService(prisma as unknown as PrismaClient, connectors, TEST_KEY)
    vi.clearAllMocks()
  })

  describe('getOrCreateToken', () => {
    it('returns existing ACTIVE token without calling connector', async () => {
      const encryptedAccess = encrypt('access-123', TEST_KEY)
      const encryptedRefresh = encrypt('refresh-123', TEST_KEY)
      const expiresAt = new Date(Date.now() + 3600000)

      ;(prisma.serviceToken.findUnique as ReturnType<typeof vi.fn>).mockResolvedValue({
        id: 'token-1',
        tenantId: 'tenant-1',
        userId: 'user1',
        service: 'twake-mail',
        instanceUrl: 'https://jmap.twake.local',
        accessToken: encryptedAccess,
        refreshToken: encryptedRefresh,
        expiresAt,
        status: 'ACTIVE',
        autoRefresh: true,
        grantedBy: 'user1',
        grantedAt: new Date(),
        lastUsedAt: null,
        lastRefreshAt: null,
      })

      const result = await service.getOrCreateToken(
        'twake-mail',
        'user1',
        mockTenant as any,
        'oidc-token',
        'user1',
      )

      expect(result.status).toBe('active')
      expect(result.token?.accessToken).toBe('access-123')
      expect(result.token?.service).toBe('twake-mail')
      expect(mockConnector.authenticate).not.toHaveBeenCalled()
    })

    it('authenticates and stores token when none exists', async () => {
      ;(prisma.serviceToken.findUnique as ReturnType<typeof vi.fn>).mockResolvedValue(null)

      const newTokenPair = {
        accessToken: 'access-123',
        refreshToken: 'refresh-123',
        expiresAt: new Date(Date.now() + 3600000),
      }
      ;(mockConnector.authenticate as ReturnType<typeof vi.fn>).mockResolvedValue({
        type: 'direct',
        tokenPair: newTokenPair,
      })
      ;(mockConnector.getInstanceUrl as ReturnType<typeof vi.fn>).mockReturnValue(
        'https://jmap.twake.local',
      )
      ;(prisma.serviceToken.upsert as ReturnType<typeof vi.fn>).mockResolvedValue({
        id: 'token-2',
        tenantId: 'tenant-1',
        userId: 'user1',
        service: 'twake-mail',
        instanceUrl: 'https://jmap.twake.local',
        accessToken: 'encrypted',
        refreshToken: 'encrypted-refresh',
        expiresAt: newTokenPair.expiresAt,
        status: 'ACTIVE',
        autoRefresh: true,
        grantedBy: 'user1',
        grantedAt: new Date(),
        lastUsedAt: null,
        lastRefreshAt: null,
      })

      const result = await service.getOrCreateToken(
        'twake-mail',
        'user1',
        mockTenant as any,
        'oidc-token',
        'user1',
      )

      expect(mockConnector.authenticate).toHaveBeenCalledWith('user1', mockTenant, 'oidc-token')
      expect(prisma.serviceToken.upsert).toHaveBeenCalled()
      expect(result.status).toBe('active')
      expect(result.token?.accessToken).toBe('access-123')
    })

    it('returns consent_required when connector returns redirect type', async () => {
      ;(prisma.serviceToken.findUnique as ReturnType<typeof vi.fn>).mockResolvedValue(null)
      ;(mockConnector.authenticate as ReturnType<typeof vi.fn>).mockResolvedValue({
        type: 'redirect',
        redirectUrl: 'https://oauth.provider.com/authorize?state=abc',
      })

      const result = await service.getOrCreateToken(
        'twake-mail',
        'user1',
        mockTenant as any,
        'oidc-token',
        'user1',
      )

      expect(result.status).toBe('consent_required')
      expect(result.redirectUrl).toBe('https://oauth.provider.com/authorize?state=abc')
      expect(prisma.serviceToken.upsert).not.toHaveBeenCalled()
    })
  })

  describe('revokeToken', () => {
    it('sets token status to REVOKED', async () => {
      const encryptedAccess = encrypt('access-123', TEST_KEY)

      ;(prisma.serviceToken.findUnique as ReturnType<typeof vi.fn>).mockResolvedValue({
        id: 'token-1',
        tenantId: 'tenant-1',
        userId: 'user1',
        service: 'twake-mail',
        instanceUrl: 'https://jmap.twake.local',
        accessToken: encryptedAccess,
        refreshToken: null,
        expiresAt: new Date(Date.now() + 3600000),
        status: 'ACTIVE',
        autoRefresh: true,
        grantedBy: 'user1',
        grantedAt: new Date(),
        lastUsedAt: null,
        lastRefreshAt: null,
      })
      ;(prisma.serviceToken.update as ReturnType<typeof vi.fn>).mockResolvedValue({})

      await service.revokeToken('twake-mail', 'user1', mockTenant as any)

      expect(prisma.serviceToken.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: 'REVOKED' }),
        }),
      )
    })
  })

  describe('listTokens', () => {
    it('queries by userId and tenantId', async () => {
      ;(prisma.serviceToken.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([])

      await service.listTokens('user1', 'tenant-1')

      expect(prisma.serviceToken.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            userId: 'user1',
            tenantId: 'tenant-1',
          }),
        }),
      )
    })
  })
})
