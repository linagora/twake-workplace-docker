import { describe, it, expect, beforeEach } from 'vitest'
import { mockDeep } from 'vitest-mock-extended'
import type { PrismaClient } from '@prisma/client'
import { UmbrellaService } from '../../src/api/services/umbrella-service.js'
import { hashToken } from '../../src/api/services/crypto.js'

describe('UmbrellaService', () => {
  let prisma: ReturnType<typeof mockDeep<PrismaClient>>
  let service: UmbrellaService

  beforeEach(() => {
    prisma = mockDeep<PrismaClient>()
    service = new UmbrellaService(prisma as unknown as PrismaClient)
  })

  describe('createUmbrellaToken', () => {
    it('returns token with twt_ prefix and creates DB record with hashed token', async () => {
      const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000)
      const scopes = ['read', 'write']

      ;(prisma.umbrellaToken.create as ReturnType<typeof import('vitest').vi.fn>).mockResolvedValue({
        id: 'umbrella-1',
        tenantId: 'tenant-1',
        userId: 'user1',
        token: 'hashed-token',
        scopes,
        expiresAt,
        issuedAt: new Date(),
        revokedAt: null,
      })

      const result = await service.createUmbrellaToken('user1', scopes, 'tenant-1')

      expect(result.umbrellaToken).toMatch(/^twt_/)
      expect(result.scopes).toEqual(scopes)
      expect(result.expiresAt).toBeInstanceOf(Date)

      const createCall = (prisma.umbrellaToken.create as ReturnType<typeof import('vitest').vi.fn>).mock.calls[0][0]
      expect(createCall.data.userId).toBe('user1')
      expect(createCall.data.tenantId).toBe('tenant-1')
      expect(createCall.data.scopes).toEqual(scopes)
      // The stored token must be the hash of the raw token
      expect(createCall.data.token).toBe(hashToken(result.umbrellaToken))
    })
  })

  describe('introspect', () => {
    it('returns details for a valid token', async () => {
      const rawToken = 'twt_abc123'
      const hashed = hashToken(rawToken)
      const issuedAt = new Date()
      const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000)

      ;(prisma.umbrellaToken.findUnique as ReturnType<typeof import('vitest').vi.fn>).mockResolvedValue({
        id: 'umbrella-1',
        tenantId: 'tenant-1',
        userId: 'user1',
        token: hashed,
        scopes: ['read'],
        expiresAt,
        issuedAt,
        revokedAt: null,
      })

      const result = await service.introspect(rawToken)

      expect(result).not.toBeNull()
      expect(result!.active).toBe(true)
      expect(result!.userId).toBe('user1')
      expect(result!.scopes).toEqual(['read'])
      expect(result!.issuedAt).toEqual(issuedAt)
      expect(result!.expiresAt).toEqual(expiresAt)

      expect(prisma.umbrellaToken.findUnique).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { token: hashed },
        }),
      )
    })

    it('returns null for an unknown token', async () => {
      ;(prisma.umbrellaToken.findUnique as ReturnType<typeof import('vitest').vi.fn>).mockResolvedValue(null)

      const result = await service.introspect('twt_unknown')

      expect(result).toBeNull()
    })

    it('returns active=false for a revoked token', async () => {
      const rawToken = 'twt_revoked'
      const hashed = hashToken(rawToken)

      ;(prisma.umbrellaToken.findUnique as ReturnType<typeof import('vitest').vi.fn>).mockResolvedValue({
        id: 'umbrella-2',
        tenantId: 'tenant-1',
        userId: 'user1',
        token: hashed,
        scopes: ['read'],
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
        issuedAt: new Date(),
        revokedAt: new Date(),
      })

      const result = await service.introspect(rawToken)

      expect(result).not.toBeNull()
      expect(result!.active).toBe(false)
    })

    it('returns active=false for an expired token', async () => {
      const rawToken = 'twt_expired'
      const hashed = hashToken(rawToken)

      ;(prisma.umbrellaToken.findUnique as ReturnType<typeof import('vitest').vi.fn>).mockResolvedValue({
        id: 'umbrella-3',
        tenantId: 'tenant-1',
        userId: 'user1',
        token: hashed,
        scopes: ['read'],
        expiresAt: new Date(Date.now() - 1000),
        issuedAt: new Date(),
        revokedAt: null,
      })

      const result = await service.introspect(rawToken)

      expect(result).not.toBeNull()
      expect(result!.active).toBe(false)
    })
  })

  describe('resolveUmbrellaToken', () => {
    it('returns userId, tenantId, scopes for a valid token', async () => {
      const rawToken = 'twt_valid'
      const hashed = hashToken(rawToken)

      ;(prisma.umbrellaToken.findUnique as ReturnType<typeof import('vitest').vi.fn>).mockResolvedValue({
        id: 'umbrella-4',
        tenantId: 'tenant-1',
        userId: 'user1',
        token: hashed,
        scopes: ['read', 'write'],
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
        issuedAt: new Date(),
        revokedAt: null,
      })

      const result = await service.resolveUmbrellaToken(rawToken)

      expect(result).not.toBeNull()
      expect(result!.userId).toBe('user1')
      expect(result!.tenantId).toBe('tenant-1')
      expect(result!.scopes).toEqual(['read', 'write'])
    })

    it('returns null for an unknown token', async () => {
      ;(prisma.umbrellaToken.findUnique as ReturnType<typeof import('vitest').vi.fn>).mockResolvedValue(null)

      const result = await service.resolveUmbrellaToken('twt_unknown')

      expect(result).toBeNull()
    })

    it('returns null for a revoked or expired token', async () => {
      const rawToken = 'twt_revoked2'
      const hashed = hashToken(rawToken)

      ;(prisma.umbrellaToken.findUnique as ReturnType<typeof import('vitest').vi.fn>).mockResolvedValue({
        id: 'umbrella-5',
        tenantId: 'tenant-1',
        userId: 'user1',
        token: hashed,
        scopes: ['read'],
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
        issuedAt: new Date(),
        revokedAt: new Date(),
      })

      const result = await service.resolveUmbrellaToken(rawToken)

      expect(result).toBeNull()
    })
  })

  describe('revokeUmbrellaToken', () => {
    it('sets revokedAt on the DB record', async () => {
      const rawToken = 'twt_to_revoke'
      const hashed = hashToken(rawToken)

      ;(prisma.umbrellaToken.findUnique as ReturnType<typeof import('vitest').vi.fn>).mockResolvedValue({
        id: 'umbrella-6',
        tenantId: 'tenant-1',
        userId: 'user1',
        token: hashed,
        scopes: ['read'],
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
        issuedAt: new Date(),
        revokedAt: null,
      })
      ;(prisma.umbrellaToken.update as ReturnType<typeof import('vitest').vi.fn>).mockResolvedValue({})

      await service.revokeUmbrellaToken(rawToken)

      expect(prisma.umbrellaToken.findUnique).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { token: hashed },
        }),
      )
      expect(prisma.umbrellaToken.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'umbrella-6' },
          data: expect.objectContaining({ revokedAt: expect.any(Date) }),
        }),
      )
    })

    it('throws if the token is not found', async () => {
      ;(prisma.umbrellaToken.findUnique as ReturnType<typeof import('vitest').vi.fn>).mockResolvedValue(null)

      await expect(service.revokeUmbrellaToken('twt_unknown')).rejects.toThrow('Umbrella token not found')
      expect(prisma.umbrellaToken.update).not.toHaveBeenCalled()
    })
  })
})
