'use client'

const OIDC_ISSUER = process.env.NEXT_PUBLIC_OIDC_ISSUER ?? 'https://auth.twake.local'
const CLIENT_ID = process.env.NEXT_PUBLIC_OIDC_CLIENT_ID ?? 'token-manager'
const REDIRECT_URI = process.env.NEXT_PUBLIC_OIDC_REDIRECT_URI ?? 'https://token-manager.twake.local/auth/callback'

let oidcToken: string | null = null

export function setOidcToken(token: string) { oidcToken = token }
export function getOidcToken(): string | null { return oidcToken ?? getDevToken() }
export function isAuthenticated(): boolean { return getOidcToken() !== null }

export function authHeaders(): Record<string, string> {
  const token = getOidcToken()
  if (!token) return {}
  return { Authorization: `Bearer ${token}` }
}

export function getCurrentUserEmail(): string {
  const token = getOidcToken()
  if (!token) return ''
  if (token.startsWith('dev-')) return `${token.slice(4)}@twake.local`
  try {
    const payload = JSON.parse(atob(token.split('.')[1]))
    return payload.email ?? `${payload.sub}@twake.local`
  } catch { return '' }
}

export function isAdmin(): boolean {
  const token = getOidcToken()
  if (!token) return false
  if (token.startsWith('dev-')) return token === 'dev-user1'
  try {
    const payload = JSON.parse(atob(token.split('.')[1]))
    return (payload.groups ?? []).some((g: string) => g.includes('token-manager-admins'))
  } catch { return false }
}

export function loginRedirect() {
  if (typeof window === 'undefined') return
  const state = crypto.randomUUID()
  sessionStorage.setItem('oidc_state', state)
  window.location.href = `${OIDC_ISSUER}/oauth2/authorize?${new URLSearchParams({
    response_type: 'code', client_id: CLIENT_ID, redirect_uri: REDIRECT_URI, scope: 'openid email profile', state,
  })}`
}

export function logout() {
  oidcToken = null
  localStorage.removeItem('twake_dev_token')
  if (typeof window !== 'undefined') window.location.href = '/tokens'
}

function getDevToken(): string | null {
  if (typeof window === 'undefined') return null
  const params = new URLSearchParams(window.location.search)
  const devUser = params.get('dev_user')
  if (devUser) { localStorage.setItem('twake_dev_token', `dev-${devUser}`); return `dev-${devUser}` }
  return localStorage.getItem('twake_dev_token')
}
