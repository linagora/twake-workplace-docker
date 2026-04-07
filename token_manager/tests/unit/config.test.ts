import { describe, it, expect } from 'vitest'
import { parseConfig, type AppConfig } from '../../src/api/config.js'

const VALID_YAML = `
server:
  port: 3100
  host: 0.0.0.0
database:
  url: postgresql://postgres:postgres@postgres:5432/token_manager
redis:
  url: redis://:valkeypass@visio-valkey:6379
oidc:
  issuer: https://auth.twake.local
  audience: token-manager
refresh:
  cron: "*/5 * * * *"
  refresh_before_expiry: 15m
  max_retries: 3
services:
  twake-drive:
    auto_refresh: true
    token_validity: 1h
    refresh_token_validity: 30d
    scopes:
      - io.cozy.files
    instance_url_pattern: "https://{username}-drive.twake.local"
    oauth_redirect_uri: "https://token-manager-api.twake.local/oauth/callback/cozy"
  twake-mail:
    auto_refresh: false
    token_validity: 1h
    scopes:
      - "Email/*"
    instance_url: "https://jmap.twake.local"
`

describe('config', () => {
  it('parses valid YAML into AppConfig', () => {
    const config = parseConfig(VALID_YAML)
    expect(config.server.port).toBe(3100)
    expect(config.redis.url).toBe('redis://:valkeypass@visio-valkey:6379')
    expect(config.refresh.cron).toBe('*/5 * * * *')
    expect(config.refresh.max_retries).toBe(3)
    expect(config.services['twake-drive'].auto_refresh).toBe(true)
    expect(config.services['twake-drive'].scopes).toEqual(['io.cozy.files'])
    expect(config.services['twake-mail'].auto_refresh).toBe(false)
  })

  it('parses refresh_before_expiry duration string to milliseconds', () => {
    const config = parseConfig(VALID_YAML)
    expect(config.refresh.refresh_before_expiry_ms).toBe(15 * 60 * 1000)
  })

  it('parses token_validity duration string to milliseconds', () => {
    const config = parseConfig(VALID_YAML)
    expect(config.services['twake-drive'].token_validity_ms).toBe(60 * 60 * 1000)
    expect(config.services['twake-mail'].token_validity_ms).toBe(60 * 60 * 1000)
  })

  it('throws on missing required fields', () => {
    expect(() => parseConfig('server:\n  port: 3100')).toThrow()
  })
})
