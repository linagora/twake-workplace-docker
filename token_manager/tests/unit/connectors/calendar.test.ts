import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { CalendarConnector } from '../../../src/api/connectors/calendar.js'
import type { ServiceConfig } from '../../../src/api/config.js'

const mockTenant = {
  id: 'tenant1',
  domain: 'twake.local',
  name: 'Test',
  config: {},
  createdAt: new Date(),
} as any

const mockServiceConfig: ServiceConfig = {
  auto_refresh: false,
  token_validity: '1h',
  token_validity_ms: 3600000,
  scopes: ['CalDAV:REPORT', 'CalDAV:PUT', 'CalDAV:GET'],
  instance_url: 'https://tcalendar-side-service.twake.local',
}

const oidcIssuer = 'https://auth.twake.local'

describe('CalendarConnector', () => {
  let connector: CalendarConnector
  let mockFetch: ReturnType<typeof vi.fn>

  beforeEach(() => {
    connector = new CalendarConnector(mockServiceConfig, oidcIssuer)
    mockFetch = vi.fn()
    vi.stubGlobal('fetch', mockFetch)
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('has serviceId set to twake-calendar', () => {
    expect(connector.serviceId).toBe('twake-calendar')
  })

  describe('getInstanceUrl', () => {
    it('returns the configured instance_url', () => {
      const url = connector.getInstanceUrl('user1@twake.local', mockTenant)
      expect(url).toBe('https://tcalendar-side-service.twake.local')
    })
  })

  describe('authenticate', () => {
    it('returns a direct result with the OIDC token as accessToken', async () => {
      const oidcToken = 'my-oidc-token'
      const result = await connector.authenticate('user1@twake.local', mockTenant, oidcToken)

      expect(result.type).toBe('direct')
      expect(result.tokenPair).toBeDefined()
      expect(result.tokenPair!.accessToken).toBe(oidcToken)
      expect(result.tokenPair!.expiresAt).toBeInstanceOf(Date)
    })

    it('sets expiresAt based on token_validity_ms', async () => {
      const before = Date.now()
      const result = await connector.authenticate('user1@twake.local', mockTenant, 'token')
      const after = Date.now()

      const expiresAtMs = result.tokenPair!.expiresAt.getTime()
      expect(expiresAtMs).toBeGreaterThanOrEqual(before + mockServiceConfig.token_validity_ms)
      expect(expiresAtMs).toBeLessThanOrEqual(after + mockServiceConfig.token_validity_ms)
    })

    it('does not call fetch', async () => {
      await connector.authenticate('user1@twake.local', mockTenant, 'token')
      expect(mockFetch).not.toHaveBeenCalled()
    })
  })

  describe('refresh', () => {
    it('calls the LemonLDAP token endpoint with grant_type=refresh_token', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          access_token: 'new-access-token',
          refresh_token: 'new-refresh-token',
          expires_in: 3600,
        }),
      })

      const instanceUrl = 'https://tcalendar-side-service.twake.local'
      const tokenPair = await connector.refresh('old-refresh-token', mockTenant, instanceUrl)

      expect(mockFetch).toHaveBeenCalledOnce()
      const [url, opts] = mockFetch.mock.calls[0]
      expect(url).toBe(`${oidcIssuer}/oauth2/token`)
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
        connector.refresh('bad-token', mockTenant, 'https://tcalendar-side-service.twake.local'),
      ).rejects.toThrow()
    })
  })

  describe('revoke', () => {
    it('calls the LemonLDAP revoke endpoint', async () => {
      mockFetch.mockResolvedValueOnce({ ok: true })

      await connector.revoke('some-access-token', mockTenant)

      expect(mockFetch).toHaveBeenCalledOnce()
      const [url, opts] = mockFetch.mock.calls[0]
      expect(url).toBe(`${oidcIssuer}/oauth2/revoke`)
      expect(opts.method).toBe('POST')

      const body = new URLSearchParams(opts.body)
      expect(body.get('token')).toBe('some-access-token')
      expect(body.get('token_type_hint')).toBe('access_token')
    })
  })
})
