import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { CozyDriveConnector } from '../../../src/api/connectors/cozy-drive.js'
import type { ServiceConfig } from '../../../src/api/config.js'

const mockTenant = {
  id: 'tenant1',
  domain: 'twake.local',
  name: 'Test',
  config: { cozyBaseUrl: 'https://{user}-drive.twake.local' },
  createdAt: new Date(),
} as any

const mockServiceConfig: ServiceConfig = {
  auto_refresh: true,
  token_validity: '1h',
  token_validity_ms: 3600000,
  scopes: ['io.cozy.files'],
  instance_url_pattern: 'https://{username}-drive.twake.local',
  oauth_redirect_uri: 'https://token-manager-api.twake.local/oauth/callback/cozy',
}

describe('CozyDriveConnector', () => {
  let connector: CozyDriveConnector
  let mockFetch: ReturnType<typeof vi.fn>

  beforeEach(() => {
    connector = new CozyDriveConnector(mockServiceConfig)
    mockFetch = vi.fn()
    vi.stubGlobal('fetch', mockFetch)
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('has serviceId set to twake-drive', () => {
    expect(connector.serviceId).toBe('twake-drive')
  })

  describe('getInstanceUrl', () => {
    it('replaces {username} with email local part', () => {
      const url = connector.getInstanceUrl('user1@twake.local', mockTenant)
      expect(url).toBe('https://user1-drive.twake.local')
    })

    it('handles email with subdomain', () => {
      const url = connector.getInstanceUrl('alice@example.com', mockTenant)
      expect(url).toBe('https://alice-drive.twake.local')
    })
  })

  describe('authenticate', () => {
    it('calls the register endpoint and returns a redirect', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          client_id: 'test-client-id',
          client_secret: 'test-client-secret',
        }),
      })

      const result = await connector.authenticate('user1@twake.local', mockTenant, 'oidc-token')

      expect(mockFetch).toHaveBeenCalledOnce()
      const [url, opts] = mockFetch.mock.calls[0]
      expect(url).toBe('https://user1-drive.twake.local/auth/register')
      expect(opts.method).toBe('POST')

      expect(result.type).toBe('redirect')
      expect(result.redirectUrl).toBeDefined()
      expect(result.state).toBeDefined()
      expect(result.redirectUrl).toContain('code_challenge=')
      expect(result.redirectUrl).toContain('code_challenge_method=S256')
      expect(result.redirectUrl).toContain('state=')
    })

    it('stores pending auth state keyed by state', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ client_id: 'cid', client_secret: 'csec' }),
      })

      const result = await connector.authenticate('user1@twake.local', mockTenant, 'oidc-token')
      expect(result.state).toBeDefined()
      // Internal state is accessible via handleCallback
      // Just verify that the state in result is non-empty
      expect(result.state!.length).toBeGreaterThan(0)
    })

    it('throws when register endpoint fails', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
        text: async () => 'Internal Server Error',
      })

      await expect(
        connector.authenticate('user1@twake.local', mockTenant, 'oidc-token'),
      ).rejects.toThrow()
    })
  })

  describe('handleCallback', () => {
    it('exchanges code for token pair', async () => {
      // First authenticate to set up pending state
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ client_id: 'cid', client_secret: 'csec' }),
      })

      const authResult = await connector.authenticate('user1@twake.local', mockTenant, 'oidc-token')
      const state = authResult.state!

      // Now mock the token exchange
      const expiresIn = 3600
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          access_token: 'access-token-abc',
          refresh_token: 'refresh-token-xyz',
          expires_in: expiresIn,
          token_type: 'Bearer',
        }),
      })

      const tokenPair = await connector.handleCallback!(state, state)

      expect(mockFetch).toHaveBeenCalledTimes(2)
      const [url, opts] = mockFetch.mock.calls[1]
      expect(url).toContain('/auth/access_token')
      expect(opts.method).toBe('POST')

      const body = new URLSearchParams(opts.body)
      expect(body.get('grant_type')).toBe('authorization_code')
      expect(body.get('code')).toBe(state)
      expect(body.get('code_verifier')).toBeDefined()

      expect(tokenPair.accessToken).toBe('access-token-abc')
      expect(tokenPair.refreshToken).toBe('refresh-token-xyz')
      expect(tokenPair.expiresAt).toBeInstanceOf(Date)
    })

    it('throws when state is not found in pending auths', async () => {
      await expect(connector.handleCallback!('code', 'unknown-state')).rejects.toThrow()
    })
  })

  describe('refresh', () => {
    it('sends grant_type=refresh_token and returns token pair', async () => {
      const expiresIn = 3600
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          access_token: 'new-access-token',
          refresh_token: 'new-refresh-token',
          expires_in: expiresIn,
          token_type: 'Bearer',
        }),
      })

      const instanceUrl = 'https://user1-drive.twake.local'
      const tokenPair = await connector.refresh('old-refresh-token', mockTenant, instanceUrl)

      expect(mockFetch).toHaveBeenCalledOnce()
      const [url, opts] = mockFetch.mock.calls[0]
      expect(url).toBe(`${instanceUrl}/auth/access_token`)
      expect(opts.method).toBe('POST')

      const body = new URLSearchParams(opts.body)
      expect(body.get('grant_type')).toBe('refresh_token')
      expect(body.get('refresh_token')).toBe('old-refresh-token')

      expect(tokenPair.accessToken).toBe('new-access-token')
      expect(tokenPair.refreshToken).toBe('new-refresh-token')
      expect(tokenPair.expiresAt).toBeInstanceOf(Date)
    })

    it('throws when token endpoint fails', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 401,
        text: async () => 'Unauthorized',
      })

      await expect(
        connector.refresh('bad-token', mockTenant, 'https://user1-drive.twake.local'),
      ).rejects.toThrow()
    })
  })

  describe('revoke', () => {
    it('is a no-op and does not throw', async () => {
      await expect(connector.revoke('any-token', mockTenant)).resolves.toBeUndefined()
      expect(mockFetch).not.toHaveBeenCalled()
    })
  })
})
