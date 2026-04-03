import { randomBytes } from 'node:crypto'
import type { Tenant } from '@prisma/client'
import type { ServiceConfig } from '../config.js'
import type { AuthResult, ServiceConnector, TokenPair } from './interface.js'

interface MatrixLoginResponse {
  access_token: string
  user_id?: string
  device_id?: string
}

interface MatrixRefreshResponse {
  access_token: string
  refresh_token?: string
  expires_in_ms?: number
}

interface PendingMatrixAuth {
  instanceUrl: string
  userId: string
}

export class MatrixConnector implements ServiceConnector {
  readonly serviceId = 'twake-chat'

  private readonly _config: ServiceConfig
  readonly _pendingAuths = new Map<string, PendingMatrixAuth>()

  constructor(config: ServiceConfig) {
    this._config = config
  }

  getInstanceUrl(_userId: string, _tenant: Tenant): string {
    return this._config.instance_url ?? ''
  }

  async authenticate(userId: string, tenant: Tenant, _oidcToken: string): Promise<AuthResult> {
    const instanceUrl = this.getInstanceUrl(userId, tenant)

    // Matrix SSO flow: redirect user to Synapse SSO, which redirects to LemonLDAP,
    // then back to Synapse callback, then to our callback with a loginToken
    const state = randomBytes(16).toString('hex')
    const callbackUrl = this._config.oauth_redirect_uri ??
      `https://token-manager-api.twake.local/oauth/callback/matrix`

    this._pendingAuths.set(state, { instanceUrl, userId })

    // The redirect URL is Synapse's SSO redirect endpoint
    const redirectUrl = `${instanceUrl}/_matrix/client/v3/login/sso/redirect?redirectUrl=${encodeURIComponent(callbackUrl + '?state=' + state)}`

    return { type: 'redirect', redirectUrl, state }
  }

  async handleCallback(loginToken: string, state: string): Promise<TokenPair> {
    const pending = this._pendingAuths.get(state)
    if (!pending) {
      throw new Error(`No pending Matrix auth found for state: ${state}`)
    }
    this._pendingAuths.delete(state)

    const resp = await fetch(`${pending.instanceUrl}/_matrix/client/v3/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: 'm.login.token', token: loginToken }),
    })

    if (!resp.ok) {
      const text = await resp.text()
      throw new Error(`Matrix login failed (${resp.status}): ${text}`)
    }

    const data = (await resp.json()) as MatrixLoginResponse

    return {
      accessToken: data.access_token,
      expiresAt: new Date(Date.now() + this._config.token_validity_ms),
    }
  }

  async refresh(refreshToken: string, _tenant: Tenant, instanceUrl: string): Promise<TokenPair> {
    const resp = await fetch(`${instanceUrl}/_matrix/client/v3/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refreshToken }),
    })

    if (!resp.ok) {
      const text = await resp.text()
      throw new Error(`Matrix refresh failed (${resp.status}): ${text}`)
    }

    const data = (await resp.json()) as MatrixRefreshResponse
    const expiresInMs = data.expires_in_ms ?? this._config.token_validity_ms

    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token,
      expiresAt: new Date(Date.now() + expiresInMs),
    }
  }

  async revoke(accessToken: string, tenant: Tenant): Promise<void> {
    const instanceUrl = this.getInstanceUrl('', tenant)

    const resp = await fetch(`${instanceUrl}/_matrix/client/v3/logout`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${accessToken}` },
    })

    if (!resp.ok) {
      const text = await resp.text()
      throw new Error(`Matrix logout failed (${resp.status}): ${text}`)
    }
  }
}
