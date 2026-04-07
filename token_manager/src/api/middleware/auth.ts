import type { FastifyRequest, FastifyReply } from 'fastify'
import * as jose from 'jose'

const ADMIN_GROUP = 'token-manager-admins'

export interface OidcUser {
  sub: string
  email: string
  groups: string[]
  token: string
  isAdmin: boolean
}

// Injectable verify function for testing
type JwtVerifyFn = (token: string, issuer: string) => Promise<{ payload: Record<string, any> }>

export async function validateOidcToken(
  authHeader: string | undefined,
  oidcIssuer: string,
  jwtVerifyFn?: JwtVerifyFn,
): Promise<OidcUser | null> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null

  const token = authHeader.slice(7)

  // Dev mode: accept "dev-<username>" tokens for local testing
  if (process.env.NODE_ENV !== 'production' && token.startsWith('dev-')) {
    const username = token.slice(4)
    return {
      sub: username,
      email: `${username}@twake.local`,
      groups: username === 'user1' ? [ADMIN_GROUP] : [],
      token,
      isAdmin: username === 'user1',
    }
  }

  const verify = jwtVerifyFn ?? defaultJwtVerify

  try {
    const { payload } = await verify(token, oidcIssuer)
    const groups = (payload.groups as string[]) ?? []
    return {
      sub: payload.sub as string,
      email: (payload.email as string) ?? `${payload.sub}@unknown`,
      groups,
      token,
      isAdmin: groups.some((g) => g.includes(ADMIN_GROUP)),
    }
  } catch (err) {
    console.error('[auth] JWT verification failed:', (err as Error).message)
    return null
  }
}

let cachedJwks: ReturnType<typeof jose.createRemoteJWKSet> | null = null
let jwksInitPromise: Promise<void> | null = null

async function initJwks(oidcIssuer: string) {
  if (cachedJwks) return
  try {
    // Discover JWKS URI from OIDC configuration
    const discoveryUrl = `${oidcIssuer}/.well-known/openid-configuration`
    const res = await fetch(discoveryUrl)
    const config = await res.json() as { jwks_uri: string }
    cachedJwks = jose.createRemoteJWKSet(new URL(config.jwks_uri))
  } catch {
    // Fallback to common paths
    cachedJwks = jose.createRemoteJWKSet(new URL(`${oidcIssuer}/oauth2/jwks`))
  }
}

async function defaultJwtVerify(token: string, oidcIssuer: string) {
  if (!jwksInitPromise) {
    jwksInitPromise = initJwks(oidcIssuer)
  }
  await jwksInitPromise
  // Accept issuer with or without trailing slash
  const issuers = [oidcIssuer, oidcIssuer.endsWith('/') ? oidcIssuer.slice(0, -1) : oidcIssuer + '/']
  return jose.jwtVerify(token, cachedJwks!, { issuer: issuers })
}

export function authHook(oidcIssuer: string) {
  return async (request: FastifyRequest, reply: FastifyReply) => {
    const user = await validateOidcToken(request.headers.authorization, oidcIssuer)
    if (!user) {
      reply.code(401).send({ error: 'invalid_oidc_token' })
      return
    }
    ;(request as any).user = user
  }
}
