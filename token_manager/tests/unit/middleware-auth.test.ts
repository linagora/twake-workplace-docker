import { describe, it, expect, vi } from 'vitest'
import { validateOidcToken, type OidcUser } from '../../src/api/middleware/auth.js'

describe('validateOidcToken', () => {
  it('returns null for missing Authorization header', async () => {
    const result = await validateOidcToken(undefined, 'https://auth.twake.local')
    expect(result).toBeNull()
  })

  it('returns null for non-Bearer token', async () => {
    const result = await validateOidcToken('Basic abc123', 'https://auth.twake.local')
    expect(result).toBeNull()
  })

  it('extracts Bearer token and returns user info on valid JWT', async () => {
    const mockJwtVerify = vi.fn().mockResolvedValueOnce({
      payload: {
        sub: 'user1',
        email: 'user1@twake.local',
        groups: ['token-manager-admins'],
      },
    })

    const result = await validateOidcToken(
      'Bearer valid-jwt-token',
      'https://auth.twake.local',
      mockJwtVerify,
    )

    expect(result).toEqual({
      sub: 'user1',
      email: 'user1@twake.local',
      groups: ['token-manager-admins'],
      token: 'valid-jwt-token',
      isAdmin: true,
    })
  })

  it('sets isAdmin false when user has no admin group', async () => {
    const mockJwtVerify = vi.fn().mockResolvedValueOnce({
      payload: {
        sub: 'user2',
        email: 'user2@twake.local',
        groups: [],
      },
    })

    const result = await validateOidcToken(
      'Bearer valid-jwt-token',
      'https://auth.twake.local',
      mockJwtVerify,
    )

    expect(result!.isAdmin).toBe(false)
  })
})
