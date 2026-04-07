import { createHash, randomBytes } from 'node:crypto'
import type { Tenant } from '@prisma/client'
import type { ServiceConfig } from '../config.js'
import type { AuthResult, ServiceConnector, TokenPair } from './interface.js'

interface OidcTokenResponse {
  access_token: string
  refresh_token?: string
  expires_in?: number
}

interface PendingOidcAuth {
  userId: string
  codeVerifier: string
}

export abstract class OidcBaseConnector implements ServiceConnector {
  abstract readonly serviceId: string

  protected readonly _config: ServiceConfig
  protected readonly _oidcIssuer: string
  readonly _pendingAuths = new Map<string, PendingOidcAuth>()

  constructor(config: ServiceConfig, oidcIssuer: string) {
    this._config = config
    this._oidcIssuer = oidcIssuer
  }

  getInstanceUrl(_userId: string, _tenant: Tenant): string {
    return this._config.instance_url ?? ''
  }

  async authenticate(userId: string, _tenant: Tenant, _oidcToken: string): Promise<AuthResult> {
    const clientId = this._config.client_id
    const redirectUri = this._config.oauth_redirect_uri

    if (!clientId || !redirectUri) {
      // Fallback: passthrough the OIDC token (for backward compat)
      return {
        type: 'direct',
        tokenPair: {
          accessToken: _oidcToken,
          expiresAt: new Date(Date.now() + this._config.token_validity_ms),
        },
      }
    }

    // PKCE
    const codeVerifier = randomBytes(32).toString('hex')
    const codeChallenge = createHash('sha256').update(codeVerifier).digest('base64url')
    const state = randomBytes(16).toString('hex')

    this._pendingAuths.set(state, { userId, codeVerifier })

    const scopes = this._config.scopes?.join(' ') ?? 'openid email profile'

    const params = new URLSearchParams({
      response_type: 'code',
      client_id: clientId,
      redirect_uri: redirectUri,
      scope: scopes,
      state,
      code_challenge: codeChallenge,
      code_challenge_method: 'S256',
    })

    const redirectUrl = `${this._oidcIssuer}/oauth2/authorize?${params.toString()}`

    return { type: 'redirect', redirectUrl, state }
  }

  async handleCallback(code: string, state: string): Promise<TokenPair> {
    const pending = this._pendingAuths.get(state)
    if (!pending) {
      throw new Error(`No pending auth found for state: ${state}`)
    }
    this._pendingAuths.delete(state)

    const clientId = this._config.client_id!
    const clientSecret = this._config.client_secret ?? ''
    const redirectUri = this._config.oauth_redirect_uri!

    const body = new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: redirectUri,
      client_id: clientId,
      client_secret: clientSecret,
      code_verifier: pending.codeVerifier,
    })

    const resp = await fetch(`${this._oidcIssuer}/oauth2/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    })

    if (!resp.ok) {
      const text = await resp.text()
      throw new Error(`OIDC token exchange failed (${resp.status}): ${text}`)
    }

    const data = (await resp.json()) as OidcTokenResponse
    const expiresInMs = (data.expires_in ?? this._config.token_validity_ms / 1000) * 1000

    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token,
      expiresAt: new Date(Date.now() + expiresInMs),
    }
  }

  async refresh(refreshToken: string, _tenant: Tenant, _instanceUrl: string): Promise<TokenPair> {
    const body = new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: this._config.client_id ?? '',
      client_secret: this._config.client_secret ?? '',
    })

    const resp = await fetch(`${this._oidcIssuer}/oauth2/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    })

    if (!resp.ok) {
      const text = await resp.text()
      throw new Error(`OIDC token refresh failed (${resp.status}): ${text}`)
    }

    const data = (await resp.json()) as OidcTokenResponse
    const expiresInMs = (data.expires_in ?? this._config.token_validity_ms / 1000) * 1000

    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token,
      expiresAt: new Date(Date.now() + expiresInMs),
    }
  }

  async revoke(accessToken: string, _tenant: Tenant): Promise<void> {
    const body = new URLSearchParams({
      token: accessToken,
      token_type_hint: 'access_token',
    })

    await fetch(`${this._oidcIssuer}/oauth2/revoke`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    }).catch(() => {})
  }
}
