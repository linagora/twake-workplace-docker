import type { PrismaClient } from '@prisma/client'

const PENDING_AUTH_TTL_MS = 10 * 60 * 1000 // 10 minutes

export class PendingAuthStore {
  private prisma: PrismaClient

  constructor(prisma: PrismaClient) {
    this.prisma = prisma
  }

  async save(state: string, service: string, userId: string, data: Record<string, any>): Promise<void> {
    await this.prisma.pendingAuth.upsert({
      where: { state },
      create: {
        state,
        service,
        userId,
        data: data as any,
        expiresAt: new Date(Date.now() + PENDING_AUTH_TTL_MS),
      },
      update: {
        service,
        userId,
        data: data as any,
        expiresAt: new Date(Date.now() + PENDING_AUTH_TTL_MS),
      },
    })
  }

  async get(state: string): Promise<{ service: string; userId: string; data: Record<string, any> } | null> {
    const record = await this.prisma.pendingAuth.findUnique({ where: { state } })
    if (!record || record.expiresAt < new Date()) {
      if (record) await this.prisma.pendingAuth.delete({ where: { state } }).catch(() => {})
      return null
    }
    return {
      service: record.service,
      userId: record.userId,
      data: record.data as Record<string, any>,
    }
  }

  async consume(state: string): Promise<{ service: string; userId: string; data: Record<string, any> } | null> {
    const result = await this.get(state)
    if (result) {
      await this.prisma.pendingAuth.delete({ where: { state } }).catch(() => {})
    }
    return result
  }

  async cleanup(): Promise<void> {
    await this.prisma.pendingAuth.deleteMany({
      where: { expiresAt: { lt: new Date() } },
    })
  }
}
