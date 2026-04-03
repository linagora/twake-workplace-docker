import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { MatrixConnector } from '../../../src/api/connectors/matrix.js'
import type { ServiceConfig } from '../../../src/api/config.js'

const mockTenant = {
  id: 'tenant1',
  domain: 'twake.local',
  name: 'Test',
  config: {},
  createdAt: new Date(),
} as any

const mockServiceConfig: ServiceConfig = {
  auto_refresh: true,
  token_validity: '24h',
  token_validity_ms: 86400000,
  scopes: ['m.room.message'],
  instance_url: 'https://matrix.twake.local',
}

describe('MatrixConnector', () => {
  let connector: MatrixConnector
  let mockFetch: ReturnType<typeof vi.fn>

  beforeEach(() => {
    connector = new MatrixConnector(mockServiceConfig)
    mockFetch = vi.fn()
    vi.stubGlobal('fetch', mockFetch)
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('has serviceId set to twake-chat', () => {
    expect(connector.serviceId).toBe('twake-chat')
  })

  describe('getInstanceUrl', () => {
    it('returns the configured instance_url', () => {
      const url = connector.getInstanceUrl('user1@twake.local', mockTenant)
      expect(url).toBe('https://matrix.twake.local')
    })
  })

  describe('authenticate', () => {
    it('returns a redirect result with the Matrix SSO URL', async () => {
      const result = await connector.authenticate('user1@twake.local', mockTenant, 'my-oidc-token')

      expect(mockFetch).not.toHaveBeenCalled()
      expect(result.type).toBe('redirect')
      expect(result.redirectUrl).toContain('https://matrix.twake.local/_matrix/client/v3/login/sso/redirect')
      expect(result.state).toBeDefined()
      expect(typeof result.state).toBe('string')
    })

    it('stores a pending auth entry for the returned state', async () => {
      const result = await connector.authenticate('user1@twake.local', mockTenant, 'token')

      expect(result.type).toBe('redirect')
      const pending = connector._pendingAuths.get(result.state!)
      expect(pending).toBeDefined()
      expect(pending!.userId).toBe('user1@twake.local')
      expect(pending!.instanceUrl).toBe('https://matrix.twake.local')
    })

    it('encodes the callback URL in the redirectUrl', async () => {
      const result = await connector.authenticate('user1@twake.local', mockTenant, 'token')

      expect(result.type).toBe('redirect')
      expect(result.redirectUrl).toContain('redirectUrl=')
      expect(result.redirectUrl).toContain(encodeURIComponent('state='))
    })
  })

  describe('refresh', () => {
    it('calls Matrix refresh endpoint', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          access_token: 'new-matrix-access-token',
          refresh_token: 'new-matrix-refresh-token',
          expires_in_ms: 86400000,
        }),
      })

      const instanceUrl = 'https://matrix.twake.local'
      const tokenPair = await connector.refresh('old-refresh-token', mockTenant, instanceUrl)

      expect(mockFetch).toHaveBeenCalledOnce()
      const [url, opts] = mockFetch.mock.calls[0]
      expect(url).toBe(`${instanceUrl}/_matrix/client/v3/refresh`)
      expect(opts.method).toBe('POST')
      expect(opts.headers['Content-Type']).toBe('application/json')

      const body = JSON.parse(opts.body)
      expect(body.refresh_token).toBe('old-refresh-token')

      expect(tokenPair.accessToken).toBe('new-matrix-access-token')
      expect(tokenPair.refreshToken).toBe('new-matrix-refresh-token')
      expect(tokenPair.expiresAt).toBeInstanceOf(Date)
    })

    it('throws when Matrix refresh endpoint fails', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 401,
        text: async () => 'Unauthorized',
      })

      await expect(
        connector.refresh('bad-token', mockTenant, 'https://matrix.twake.local'),
      ).rejects.toThrow()
    })
  })

  describe('revoke', () => {
    it('calls Matrix logout with Bearer header', async () => {
      mockFetch.mockResolvedValueOnce({ ok: true })

      await connector.revoke('some-access-token', mockTenant)

      expect(mockFetch).toHaveBeenCalledOnce()
      const [url, opts] = mockFetch.mock.calls[0]
      expect(url).toBe('https://matrix.twake.local/_matrix/client/v3/logout')
      expect(opts.method).toBe('POST')
      expect(opts.headers['Authorization']).toBe('Bearer some-access-token')
    })

    it('throws when Matrix logout endpoint fails', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 401,
        text: async () => 'Unauthorized',
      })

      await expect(connector.revoke('bad-token', mockTenant)).rejects.toThrow()
    })
  })
})
