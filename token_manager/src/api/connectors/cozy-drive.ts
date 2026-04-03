import { createHash, randomBytes } from 'node:crypto'
import type { Tenant } from '@prisma/client'
import type { ServiceConfig } from '../config.js'
import type { AuthResult, ServiceConnector, TokenPair } from './interface.js'

interface PendingAuth {
  instanceUrl: string
  clientId: string
  clientSecret: string
  codeVerifier: string
}

interface CozyTokenResponse {
  access_token: string
  refresh_token?: string
  expires_in?: number
  token_type?: string
}

export class CozyDriveConnector implements ServiceConnector {
  readonly serviceId = 'twake-drive'

  private readonly _config: ServiceConfig
  private readonly _pendingAuths = new Map<string, PendingAuth>()

  constructor(config: ServiceConfig) {
    this._config = config
  }

  getInstanceUrl(userId: string, _tenant: Tenant): string {
    const pattern = this._config.instance_url_pattern ?? ''
    const username = userId.includes('@') ? userId.split('@')[0] : userId
    return pattern.replace('{username}', username)
  }

  /** Cozy auth endpoints live on the base instance (user1.twake.local), not the drive app */
  private getAuthUrl(userId: string, _tenant: Tenant): string {
    const pattern = this._config.auth_url_pattern ?? this._config.instance_url_pattern ?? ''
    const username = userId.includes('@') ? userId.split('@')[0] : userId
    return pattern.replace('{username}', username)
  }

  async authenticate(userId: string, tenant: Tenant, _oidcToken: string): Promise<AuthResult> {
    const instanceUrl = this.getAuthUrl(userId, tenant)
    const redirectUri = this._config.oauth_redirect_uri ?? ''
    const scopes = this._config.scopes.join(' ')

    // Register OAuth2 app on the Cozy instance
    const registerBody = JSON.stringify({
      redirect_uris: [redirectUri],
      client_name: 'Twake Token Manager',
      software_id: 'twake-token-manager',
    })

    const registerResp = await fetch(`${instanceUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: registerBody,
    })

    if (!registerResp.ok) {
      const text = await registerResp.text()
      throw new Error(`Cozy register failed (${registerResp.status}): ${text}`)
    }

    const { client_id: clientId, client_secret: clientSecret } =
      (await registerResp.json()) as { client_id: string; client_secret: string }

    // Generate PKCE code_verifier and code_challenge
    const codeVerifier = randomBytes(32).toString('hex')
    const codeChallenge = createHash('sha256')
      .update(codeVerifier)
      .digest('base64url')

    // Generate random state
    const state = randomBytes(16).toString('hex')

    this._pendingAuths.set(state, { instanceUrl, clientId, clientSecret, codeVerifier })

    const params = new URLSearchParams({
      response_type: 'code',
      client_id: clientId,
      redirect_uri: redirectUri,
      scope: scopes,
      state,
      code_challenge: codeChallenge,
      code_challenge_method: 'S256',
    })

    const redirectUrl = `${instanceUrl}/auth/authorize?${params.toString()}`

    return { type: 'redirect', redirectUrl, state }
  }

  async handleCallback(code: string, state: string): Promise<TokenPair> {
    const pending = this._pendingAuths.get(state)
    if (!pending) {
      throw new Error(`No pending auth found for state: ${state}`)
    }
    this._pendingAuths.delete(state)

    const { instanceUrl, clientId, clientSecret, codeVerifier } = pending

    const body = new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: this._config.oauth_redirect_uri ?? '',
      client_id: clientId,
      client_secret: clientSecret,
      code_verifier: codeVerifier,
    })

    const resp = await fetch(`${instanceUrl}/auth/access_token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    })

    if (!resp.ok) {
      const text = await resp.text()
      throw new Error(`Cozy token exchange failed (${resp.status}): ${text}`)
    }

    const data = (await resp.json()) as CozyTokenResponse
    return this._toTokenPair(data)
  }

  async refresh(refreshToken: string, _tenant: Tenant, instanceUrl: string): Promise<TokenPair> {
    const body = new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    })

    const resp = await fetch(`${instanceUrl}/auth/access_token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    })

    if (!resp.ok) {
      const text = await resp.text()
      throw new Error(`Cozy refresh failed (${resp.status}): ${text}`)
    }

    const data = (await resp.json()) as CozyTokenResponse
    return this._toTokenPair(data)
  }

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async revoke(_accessToken: string, _tenant: Tenant): Promise<void> {
    // No-op: revoking requires the registration_access_token which is not stored.
  }

  private _toTokenPair(data: CozyTokenResponse): TokenPair {
    const expiresInMs = (data.expires_in ?? this._config.token_validity_ms / 1000) * 1000
    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token,
      expiresAt: new Date(Date.now() + expiresInMs),
    }
  }
}
