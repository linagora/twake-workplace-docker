// TypeScript SDK client for Twake Token Manager REST API

export interface ServiceTokenResponse {
  access_token: string
  refresh_token?: string
  expires_at: string
  service: string
  instance_url: string
}

export interface UmbrellaTokenResponse {
  umbrella_token: string
  scopes: string[]
  expires_at: string
}

export interface UmbrellaIntrospectResponse {
  active: boolean
  user: string
  scopes: string[]
  issued_at: string
  expires_at: string
}

export interface TokenStatusResponse {
  service: string
  status: string
  expires_at: string
  instance_url: string
  granted_by: string
  granted_at: string
  auto_refresh: boolean
  last_used_at?: string
  last_refresh_at?: string
}

export class TwakeTokenManagerError extends Error {
  code: string
  service?: string

  constructor(message: string, code: string, service?: string) {
    super(message)
    this.name = 'TwakeTokenManagerError'
    this.code = code
    this.service = service
  }
}

export class ConsentRequiredError extends TwakeTokenManagerError {
  redirectUrl: string

  constructor(redirectUrl: string, service?: string) {
    super('Consent required before accessing this service', 'consent_required', service)
    this.name = 'ConsentRequiredError'
    this.redirectUrl = redirectUrl
  }
}

export interface TwakeTokenManagerOptions {
  baseUrl: string
  oidcToken: string
  tenant?: string
}

export class TwakeTokenManager {
  private baseUrl: string
  private oidcToken: string
  private tenant?: string

  constructor({ baseUrl, oidcToken, tenant }: TwakeTokenManagerOptions) {
    this.baseUrl = baseUrl.replace(/\/$/, '')
    this.oidcToken = oidcToken
    this.tenant = tenant
  }

  private headers(): Record<string, string> {
    const h: Record<string, string> = {
      Authorization: `Bearer ${this.oidcToken}`,
      'Content-Type': 'application/json',
    }
    if (this.tenant) h['X-Twake-Tenant'] = this.tenant
    return h
  }

  private async request<T>(method: string, path: string, body?: unknown): Promise<T> {
    const url = `${this.baseUrl}${path}`
    const options: RequestInit = {
      method,
      headers: this.headers(),
    }
    if (body !== undefined) {
      options.body = JSON.stringify(body)
    }

    const response = await fetch(url, options)

    if (response.status === 202) {
      const data = await response.json() as Record<string, any>
      if (data.status === 'consent_required') {
        throw new ConsentRequiredError(data.redirect_url, data.service)
      }
      return data as T
    }

    if (response.status === 204) {
      return undefined as unknown as T
    }

    if (!response.ok) {
      let errorData: { error?: string; message?: string; service?: string } = {}
      try {
        errorData = await response.json() as { error?: string; message?: string; service?: string }
      } catch {
        // ignore parse errors
      }
      throw new TwakeTokenManagerError(
        errorData.message ?? `HTTP ${response.status}`,
        errorData.error ?? String(response.status),
        errorData.service,
      )
    }

    return response.json() as Promise<T>
  }

  async getToken(service: string, user: string): Promise<ServiceTokenResponse> {
    return this.request<ServiceTokenResponse>('POST', '/api/v1/tokens', { service, user })
  }

  async refreshToken(service: string, user: string): Promise<ServiceTokenResponse> {
    return this.request<ServiceTokenResponse>('POST', '/api/v1/tokens/refresh', { service, user })
  }

  async listTokens(user: string): Promise<TokenStatusResponse[]> {
    return this.request<TokenStatusResponse[]>(
      'GET',
      `/api/v1/tokens?user=${encodeURIComponent(user)}`,
    )
  }

  async getTokenStatus(service: string, user: string): Promise<TokenStatusResponse> {
    return this.request<TokenStatusResponse>(
      'GET',
      `/api/v1/tokens/${encodeURIComponent(service)}?user=${encodeURIComponent(user)}`,
    )
  }

  async revokeToken(service: string, user: string): Promise<void> {
    return this.request<void>(
      'DELETE',
      `/api/v1/tokens/${encodeURIComponent(service)}?user=${encodeURIComponent(user)}`,
    )
  }

  async revokeAllTokens(user: string): Promise<void> {
    return this.request<void>('DELETE', `/api/v1/tokens?user=${encodeURIComponent(user)}`)
  }

  async getUmbrellaToken(user: string, scopes: string[]): Promise<UmbrellaTokenResponse> {
    return this.request<UmbrellaTokenResponse>('POST', '/api/v1/umbrella-token', { user, scopes })
  }

  async introspectUmbrellaToken(token: string): Promise<UmbrellaIntrospectResponse> {
    return this.request<UmbrellaIntrospectResponse>('POST', '/api/v1/umbrella-token/introspect', {
      token,
    })
  }

  async revokeUmbrellaToken(token: string): Promise<void> {
    return this.request<void>('DELETE', `/api/v1/umbrella-token/${encodeURIComponent(token)}`)
  }

  async proxy(
    service: string,
    path: string,
    umbrellaToken: string,
    options?: RequestInit,
  ): Promise<Response> {
    const url = `${this.baseUrl}/api/v1/proxy/${encodeURIComponent(service)}${path.startsWith('/') ? path : `/${path}`}`
    return fetch(url, {
      ...options,
      headers: {
        ...this.headers(),
        'X-Umbrella-Token': umbrellaToken,
        ...(options?.headers as Record<string, string> | undefined),
      },
    })
  }
}
