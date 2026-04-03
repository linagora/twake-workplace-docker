import type { Tenant } from '@prisma/client'

export interface TokenPair {
  accessToken: string
  refreshToken?: string
  expiresAt: Date
}

export interface AuthResult {
  type: 'redirect' | 'direct'
  redirectUrl?: string
  tokenPair?: TokenPair
  state?: string
}

export interface ServiceConnector {
  readonly serviceId: string

  authenticate(userId: string, tenant: Tenant, oidcToken: string): Promise<AuthResult>
  handleCallback?(code: string, state: string): Promise<TokenPair>
  refresh(refreshToken: string, tenant: Tenant, instanceUrl: string): Promise<TokenPair>
  revoke(accessToken: string, tenant: Tenant): Promise<void>
  getInstanceUrl(userId: string, tenant: Tenant): string
}
