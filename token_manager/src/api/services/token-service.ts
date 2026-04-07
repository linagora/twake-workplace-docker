import type { PrismaClient, ServiceToken, Tenant } from '@prisma/client'
import { encrypt, decrypt } from './crypto.js'
import type { ServiceConnector } from '../connectors/interface.js'

export interface TokenResult {
  status: 'active' | 'consent_required'
  token?: {
    accessToken: string
    refreshToken?: string
    expiresAt: Date
    service: string
    instanceUrl: string
    bearerKey?: string
  }
  redirectUrl?: string
  state?: string
}

export class TokenService {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly connectors: Map<string, ServiceConnector>,
    private readonly encryptionKey: string,
  ) {}

  private getConnector(service: string): ServiceConnector {
    const connector = this.connectors.get(service)
    if (!connector) {
      throw new Error(`No connector registered for service: ${service}`)
    }
    return connector
  }

  async getOrCreateToken(
    service: string,
    userId: string,
    tenant: Tenant,
    oidcToken: string,
    grantedBy: string,
  ): Promise<TokenResult> {
    const existing = await this.prisma.serviceToken.findUnique({
      where: {
        tenantId_userId_service: {
          tenantId: tenant.id,
          userId,
          service,
        },
      },
    })

    if (existing && existing.status === 'ACTIVE' && existing.expiresAt > new Date()) {
      return {
        status: 'active',
        token: {
          accessToken: decrypt(existing.accessToken, this.encryptionKey),
          refreshToken: existing.refreshToken
            ? decrypt(existing.refreshToken, this.encryptionKey)
            : undefined,
          expiresAt: existing.expiresAt,
          service: existing.service,
          instanceUrl: existing.instanceUrl,
          bearerKey: existing.bearerKey ?? undefined,
        },
      }
    }

    const connector = this.getConnector(service)
    const authResult = await connector.authenticate(userId, tenant, oidcToken)

    if (authResult.type === 'redirect') {
      return {
        status: 'consent_required',
        redirectUrl: authResult.redirectUrl,
        state: authResult.state,
      }
    }

    const { tokenPair } = authResult
    if (!tokenPair) {
      throw new Error('Connector returned direct auth without tokenPair')
    }

    const instanceUrl = connector.getInstanceUrl(userId, tenant)
    const encryptedAccess = encrypt(tokenPair.accessToken, this.encryptionKey)
    const encryptedRefresh = tokenPair.refreshToken
      ? encrypt(tokenPair.refreshToken, this.encryptionKey)
      : null

    await this.prisma.serviceToken.upsert({
      where: {
        tenantId_userId_service: {
          tenantId: tenant.id,
          userId,
          service,
        },
      },
      update: {
        accessToken: encryptedAccess,
        refreshToken: encryptedRefresh,
        expiresAt: tokenPair.expiresAt,
        instanceUrl,
        status: 'ACTIVE',
        lastRefreshAt: new Date(),
      },
      create: {
        tenantId: tenant.id,
        userId,
        service,
        instanceUrl,
        accessToken: encryptedAccess,
        refreshToken: encryptedRefresh,
        expiresAt: tokenPair.expiresAt,
        grantedBy,
        status: 'ACTIVE',
      },
    })

    return {
      status: 'active',
      token: {
        accessToken: tokenPair.accessToken,
        refreshToken: tokenPair.refreshToken,
        expiresAt: tokenPair.expiresAt,
        service,
        instanceUrl,
      },
    }
  }

  async refreshToken(service: string, userId: string, tenant: Tenant): Promise<TokenResult> {
    const existing = await this.prisma.serviceToken.findUnique({
      where: {
        tenantId_userId_service: {
          tenantId: tenant.id,
          userId,
          service,
        },
      },
    })

    if (!existing) {
      throw new Error(`No token found for service ${service}, user ${userId}`)
    }
    if (!existing.refreshToken) {
      throw new Error(`No refresh token available for service ${service}, user ${userId}`)
    }

    const connector = this.getConnector(service)
    const refreshToken = decrypt(existing.refreshToken, this.encryptionKey)
    const tokenPair = await connector.refresh(refreshToken, tenant, existing.instanceUrl)

    const encryptedAccess = encrypt(tokenPair.accessToken, this.encryptionKey)
    const encryptedRefresh = tokenPair.refreshToken
      ? encrypt(tokenPair.refreshToken, this.encryptionKey)
      : existing.refreshToken

    await this.prisma.serviceToken.update({
      where: { id: existing.id },
      data: {
        accessToken: encryptedAccess,
        refreshToken: encryptedRefresh,
        expiresAt: tokenPair.expiresAt,
        status: 'ACTIVE',
        lastRefreshAt: new Date(),
      },
    })

    return {
      status: 'active',
      token: {
        accessToken: tokenPair.accessToken,
        refreshToken: tokenPair.refreshToken,
        expiresAt: tokenPair.expiresAt,
        service,
        instanceUrl: existing.instanceUrl,
      },
    }
  }

  async revokeToken(service: string, userId: string, tenant: Tenant): Promise<void> {
    const existing = await this.prisma.serviceToken.findUnique({
      where: {
        tenantId_userId_service: {
          tenantId: tenant.id,
          userId,
          service,
        },
      },
    })

    if (!existing) {
      return
    }

    // Best-effort revocation via connector
    try {
      const connector = this.connectors.get(service)
      if (connector) {
        const accessToken = decrypt(existing.accessToken, this.encryptionKey)
        await connector.revoke(accessToken, tenant)
      }
    } catch {
      // Revocation failure is non-fatal; we still mark as REVOKED in DB
    }

    await this.prisma.serviceToken.update({
      where: { id: existing.id },
      data: { status: 'REVOKED' },
    })
  }

  async revokeAllTokens(userId: string, tenant: Tenant): Promise<void> {
    const tokens = await this.prisma.serviceToken.findMany({
      where: {
        tenantId: tenant.id,
        userId,
        status: 'ACTIVE',
      },
    })

    await Promise.all(
      tokens.map((token: ServiceToken) => this.revokeToken(token.service, userId, tenant)),
    )
  }

  async listTokens(userId: string, tenantId: string): Promise<ServiceToken[]> {
    return this.prisma.serviceToken.findMany({
      where: {
        userId,
        tenantId,
      },
    })
  }
}
