import type { PrismaClient } from '@prisma/client'
import { generateUmbrellaToken, hashToken } from './crypto.js'

const DEFAULT_TTL_MS = 24 * 60 * 60 * 1000 // 24 hours

export interface UmbrellaTokenResult {
  umbrellaToken: string
  scopes: string[]
  expiresAt: Date
}

export interface IntrospectResult {
  active: boolean
  userId: string
  scopes: string[]
  issuedAt: Date
  expiresAt: Date
}

export class UmbrellaService {
  constructor(private readonly prisma: PrismaClient) {}

  async createUmbrellaToken(
    userId: string,
    scopes: string[],
    tenant: string,
    name?: string,
  ): Promise<UmbrellaTokenResult> {
    // Validate unique name per user (if name provided)
    if (name) {
      const existing = await this.prisma.umbrellaToken.findFirst({
        where: { tenantId: tenant, userId, name, revokedAt: null },
      })
      if (existing) {
        throw new Error(`An active umbrella token named "${name}" already exists`)
      }
    }

    const rawToken = generateUmbrellaToken()
    const hashed = hashToken(rawToken)
    const expiresAt = new Date(Date.now() + DEFAULT_TTL_MS)

    await this.prisma.umbrellaToken.create({
      data: {
        userId,
        tenantId: tenant,
        token: hashed,
        scopes,
        expiresAt,
        name: name || null,
      },
    })

    return {
      umbrellaToken: rawToken,
      scopes,
      expiresAt,
    }
  }

  async introspect(rawToken: string): Promise<IntrospectResult | null> {
    const hashed = hashToken(rawToken)
    const record = await this.prisma.umbrellaToken.findUnique({
      where: { token: hashed },
    })

    if (!record) {
      return null
    }

    const active = record.revokedAt === null && record.expiresAt > new Date()

    return {
      active,
      userId: record.userId,
      scopes: record.scopes,
      issuedAt: record.issuedAt,
      expiresAt: record.expiresAt,
    }
  }

  async resolveUmbrellaToken(
    rawToken: string,
  ): Promise<{ userId: string; tenantId: string; scopes: string[] } | null> {
    const hashed = hashToken(rawToken)
    const record = await this.prisma.umbrellaToken.findUnique({
      where: { token: hashed },
    })

    if (!record) {
      return null
    }

    if (record.revokedAt !== null || record.expiresAt <= new Date()) {
      return null
    }

    return {
      userId: record.userId,
      tenantId: record.tenantId,
      scopes: record.scopes,
    }
  }

  async revokeUmbrellaToken(rawToken: string): Promise<void> {
    const hashed = hashToken(rawToken)
    const record = await this.prisma.umbrellaToken.findUnique({
      where: { token: hashed },
    })

    if (!record) {
      throw new Error('Umbrella token not found')
    }

    await this.prisma.umbrellaToken.update({
      where: { id: record.id },
      data: { revokedAt: new Date() },
    })
  }

  async revokeById(id: string): Promise<void> {
    const record = await this.prisma.umbrellaToken.findUnique({ where: { id } })
    if (!record) {
      throw new Error('Umbrella token not found')
    }
    await this.prisma.umbrellaToken.update({
      where: { id },
      data: { revokedAt: new Date() },
    })
  }
}
