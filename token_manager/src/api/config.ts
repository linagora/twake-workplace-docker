import { parse } from 'yaml'

export interface ServiceConfig {
  auto_refresh: boolean
  token_validity: string
  token_validity_ms: number
  refresh_token_validity?: string
  scopes: string[]
  instance_url?: string
  instance_url_pattern?: string
  auth_url_pattern?: string
  oauth_redirect_uri?: string
  client_id?: string
  client_secret?: string
}

export interface AppConfig {
  server: { port: number; host: string }
  database: { url: string }
  redis: { url: string }
  oidc: { issuer: string; audience: string }
  refresh: {
    cron: string
    refresh_before_expiry: string
    refresh_before_expiry_ms: number
    max_retries: number
  }
  services: Record<string, ServiceConfig>
}

function parseDuration(duration: string): number {
  const match = duration.match(/^(\d+)(ms|s|m|h|d)$/)
  if (!match) throw new Error(`Invalid duration: ${duration}`)
  const value = parseInt(match[1], 10)
  const unit = match[2]
  const multipliers: Record<string, number> = {
    ms: 1,
    s: 1000,
    m: 60 * 1000,
    h: 60 * 60 * 1000,
    d: 24 * 60 * 60 * 1000,
  }
  return value * multipliers[unit]
}

export function parseConfig(yamlContent: string): AppConfig {
  const raw = parse(yamlContent)

  if (!raw.server || !raw.database || !raw.redis || !raw.oidc || !raw.refresh || !raw.services) {
    throw new Error('Missing required config sections: server, database, redis, oidc, refresh, services')
  }

  const refresh = {
    ...raw.refresh,
    refresh_before_expiry_ms: parseDuration(raw.refresh.refresh_before_expiry),
  }

  const services: Record<string, ServiceConfig> = {}
  for (const [name, svc] of Object.entries(raw.services as Record<string, any>)) {
    services[name] = {
      ...svc,
      token_validity_ms: parseDuration(svc.token_validity),
    }
  }

  return {
    server: raw.server,
    database: raw.database,
    redis: raw.redis,
    oidc: raw.oidc,
    refresh,
    services,
  }
}
