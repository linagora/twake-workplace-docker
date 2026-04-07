const OIDC_ISSUER = 'https://auth.twake.local'
const CLIENT_ID = 'token-manager'

let oidcToken = null

export function getCozyToken() {
  const el = document.querySelector('[data-cozy-token]')
  const token = el ? el.getAttribute('data-cozy-token') : null
  // If token is the raw placeholder (not replaced by Cozy Stack), return null
  if (!token || token === '{{.Token}}') return null
  return token
}

export function getCozyDomain() {
  const el = document.querySelector('[data-cozy-domain]')
  const domain = el ? el.getAttribute('data-cozy-domain') : null
  if (!domain || domain === '{{.Domain}}') return null
  return domain
}

export async function initAuth() {
  // 1. Check if we're inside Cozy Stack (real token injected)
  const cozyToken = getCozyToken()
  if (cozyToken) {
    // We have a real Cozy session — try to get an OIDC token via redirect
    // Check if we already have an OIDC token in sessionStorage (from a previous redirect)
    const storedOidc = sessionStorage.getItem('oidc_access_token')
    if (storedOidc) {
      oidcToken = storedOidc
      return
    }

    // Check if URL has an authorization code (returning from SSO redirect)
    const hash = window.location.hash
    const params = new URLSearchParams(window.location.search)
    const code = params.get('code')
    const state = params.get('state')
    if (code && state) {
      const savedState = sessionStorage.getItem('oidc_state')
      if (state === savedState) {
        try {
          const token = await exchangeCode(code)
          oidcToken = token
          sessionStorage.setItem('oidc_access_token', token)
          sessionStorage.removeItem('oidc_state')
          // Clean URL
          window.history.replaceState({}, '', window.location.pathname + '#/tokens')
          return
        } catch (e) {
          console.error('OIDC code exchange failed:', e)
        }
      }
    }

    // No OIDC token yet — extract user from Cozy domain and use dev-token
    // as intermediate solution while SSO redirect is being set up
    const domain = getCozyDomain()
    if (domain) {
      const username = domain.split('.')[0] // user1.twake.local → user1
      oidcToken = `dev-${username}`
      return
    }
  }

  // 2. Not inside Cozy Stack (dev mode / standalone) — use dev-token
  const params = new URLSearchParams(window.location.search)
  const devUser = params.get('dev_user')
  if (devUser) {
    oidcToken = `dev-${devUser}`
    localStorage.setItem('twake_dev_token', oidcToken)
    return
  }

  const stored = localStorage.getItem('twake_dev_token')
  if (stored) { oidcToken = stored; return }
}

async function exchangeCode(code) {
  const redirectUri = `${window.location.origin}/`
  const response = await fetch(`${OIDC_ISSUER}/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      client_id: CLIENT_ID,
      redirect_uri: redirectUri,
    }),
  })
  if (!response.ok) throw new Error(`Token exchange failed: ${response.status}`)
  const data = await response.json()
  return data.access_token
}

export function getOidcToken() { return oidcToken }
export function isAuthenticated() { return oidcToken !== null }

export function authHeaders() {
  if (!oidcToken) return {}
  return { Authorization: `Bearer ${oidcToken}` }
}

export function getCurrentUserEmail() {
  if (!oidcToken) return ''
  if (oidcToken.startsWith('dev-')) return `${oidcToken.slice(4)}@twake.local`
  try {
    const payload = JSON.parse(atob(oidcToken.split('.')[1]))
    return payload.email ?? `${payload.sub}@twake.local`
  } catch { return '' }
}

export function isAdmin() {
  if (!oidcToken) return false
  if (oidcToken.startsWith('dev-')) return oidcToken === 'dev-user1'
  try {
    const payload = JSON.parse(atob(oidcToken.split('.')[1]))
    return (payload.groups ?? []).some(g => g.includes('token-manager-admins'))
  } catch { return false }
}

export function loginRedirect() {
  const state = crypto.randomUUID()
  sessionStorage.setItem('oidc_state', state)
  const redirectUri = `${window.location.origin}/`
  window.location.href = `${OIDC_ISSUER}/oauth2/authorize?${new URLSearchParams({
    response_type: 'code',
    client_id: CLIENT_ID,
    redirect_uri: redirectUri,
    scope: 'openid email profile',
    state,
  })}`
}

export function logout() {
  oidcToken = null
  sessionStorage.removeItem('oidc_access_token')
  localStorage.removeItem('twake_dev_token')
  window.location.href = '#/tokens'
}
