import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  TwakeTokenManager,
  ConsentRequiredError,
  TwakeTokenManagerError,
} from '../../src/sdk/index.js'

const BASE_URL = 'https://token-manager.twake.local'
const OIDC_TOKEN = 'test-oidc-token'

function makeMockFetch(status: number, body: unknown, headers: Record<string, string> = {}) {
  return vi.fn().mockResolvedValue({
    ok: status >= 200 && status < 300,
    status,
    headers: {
      get: (name: string) => headers[name.toLowerCase()] ?? null,
    },
    json: () => Promise.resolve(body),
    text: () => Promise.resolve(typeof body === 'string' ? body : JSON.stringify(body)),
  })
}

describe('TwakeTokenManager SDK', () => {
  let client: TwakeTokenManager
  let mockFetch: ReturnType<typeof vi.fn>

  beforeEach(() => {
    client = new TwakeTokenManager({ baseUrl: BASE_URL, oidcToken: OIDC_TOKEN })
  })

  describe('getToken', () => {
    it('sends correct POST with auth header', async () => {
      const responseBody = {
        access_token: 'svc-access',
        expires_at: '2026-01-01T00:00:00Z',
        service: 'twake-mail',
        instance_url: 'https://mail.twake.local',
      }
      mockFetch = makeMockFetch(200, responseBody)
      vi.stubGlobal('fetch', mockFetch)

      const result = await client.getToken('twake-mail', 'user1')

      expect(mockFetch).toHaveBeenCalledOnce()
      const [url, options] = mockFetch.mock.calls[0]
      expect(url).toBe(`${BASE_URL}/api/v1/tokens`)
      expect(options.method).toBe('POST')
      expect(options.headers['Authorization']).toBe(`Bearer ${OIDC_TOKEN}`)
      expect(options.headers['Content-Type']).toBe('application/json')
      expect(JSON.parse(options.body)).toEqual({ service: 'twake-mail', user: 'user1' })
      expect(result).toEqual(responseBody)
    })

    it('throws ConsentRequiredError on 202 with consent_required', async () => {
      const responseBody = {
        status: 'consent_required',
        redirect_url: 'https://auth.twake.local/consent',
        service: 'twake-mail',
      }
      mockFetch = makeMockFetch(202, responseBody)
      vi.stubGlobal('fetch', mockFetch)

      await expect(client.getToken('twake-mail', 'user1')).rejects.toThrow(ConsentRequiredError)

      try {
        await client.getToken('twake-mail', 'user1')
      } catch (err) {
        expect(err).toBeInstanceOf(ConsentRequiredError)
        const consentErr = err as ConsentRequiredError
        expect(consentErr.redirectUrl).toBe('https://auth.twake.local/consent')
        expect(consentErr.code).toBe('consent_required')
        expect(consentErr.service).toBe('twake-mail')
      }
    })

    it('throws TwakeTokenManagerError on non-ok response', async () => {
      const responseBody = { error: 'not_found', message: 'Service not found' }
      mockFetch = makeMockFetch(404, responseBody)
      vi.stubGlobal('fetch', mockFetch)

      await expect(client.getToken('unknown-service', 'user1')).rejects.toThrow(TwakeTokenManagerError)
    })
  })

  describe('listTokens', () => {
    it('sends correct GET with encoded user param', async () => {
      const responseBody = [
        {
          service: 'twake-mail',
          status: 'active',
          expires_at: '2026-01-01T00:00:00Z',
          instance_url: 'https://mail.twake.local',
          granted_by: 'oauth',
          granted_at: '2025-01-01T00:00:00Z',
          auto_refresh: true,
        },
      ]
      mockFetch = makeMockFetch(200, responseBody)
      vi.stubGlobal('fetch', mockFetch)

      const result = await client.listTokens('user1@twake.local')

      expect(mockFetch).toHaveBeenCalledOnce()
      const [url, options] = mockFetch.mock.calls[0]
      expect(url).toBe(`${BASE_URL}/api/v1/tokens?user=${encodeURIComponent('user1@twake.local')}`)
      expect(options.method).toBe('GET')
      expect(options.headers['Authorization']).toBe(`Bearer ${OIDC_TOKEN}`)
      expect(result).toEqual(responseBody)
    })
  })

  describe('revokeToken', () => {
    it('sends DELETE request for specific service', async () => {
      mockFetch = makeMockFetch(204, null)
      vi.stubGlobal('fetch', mockFetch)

      await client.revokeToken('twake-mail', 'user1')

      expect(mockFetch).toHaveBeenCalledOnce()
      const [url, options] = mockFetch.mock.calls[0]
      expect(url).toBe(`${BASE_URL}/api/v1/tokens/twake-mail?user=${encodeURIComponent('user1')}`)
      expect(options.method).toBe('DELETE')
      expect(options.headers['Authorization']).toBe(`Bearer ${OIDC_TOKEN}`)
    })
  })

  describe('getUmbrellaToken', () => {
    it('sends correct POST with scopes', async () => {
      const responseBody = {
        umbrella_token: 'umbrella-abc123',
        scopes: ['twake-mail', 'twake-drive'],
        expires_at: '2026-01-01T00:00:00Z',
      }
      mockFetch = makeMockFetch(200, responseBody)
      vi.stubGlobal('fetch', mockFetch)

      const result = await client.getUmbrellaToken('user1', ['twake-mail', 'twake-drive'])

      expect(mockFetch).toHaveBeenCalledOnce()
      const [url, options] = mockFetch.mock.calls[0]
      expect(url).toBe(`${BASE_URL}/api/v1/umbrella-token`)
      expect(options.method).toBe('POST')
      expect(options.headers['Authorization']).toBe(`Bearer ${OIDC_TOKEN}`)
      expect(JSON.parse(options.body)).toEqual({ user: 'user1', scopes: ['twake-mail', 'twake-drive'] })
      expect(result).toEqual(responseBody)
    })
  })

  describe('tenant header', () => {
    it('includes X-Twake-Tenant header when tenant is set', async () => {
      const tenantClient = new TwakeTokenManager({
        baseUrl: BASE_URL,
        oidcToken: OIDC_TOKEN,
        tenant: 'my-tenant',
      })
      mockFetch = makeMockFetch(200, [])
      vi.stubGlobal('fetch', mockFetch)

      await tenantClient.listTokens('user1')

      const [, options] = mockFetch.mock.calls[0]
      expect(options.headers['X-Twake-Tenant']).toBe('my-tenant')
    })

    it('does not include X-Twake-Tenant header when tenant is not set', async () => {
      mockFetch = makeMockFetch(200, [])
      vi.stubGlobal('fetch', mockFetch)

      await client.listTokens('user1')

      const [, options] = mockFetch.mock.calls[0]
      expect(options.headers['X-Twake-Tenant']).toBeUndefined()
    })
  })
})
