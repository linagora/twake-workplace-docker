const OIDC_ISSUER = 'https://auth.twake.local'
const CLIENT_ID = 'token-manager'

let oidcToken = null

export function getCozyToken() {
  const el = document.querySelector('[data-cozy-token]')
  return el ? el.getAttribute('data-cozy-token') : null
}

export function getCozyDomain() {
  const el = document.querySelector('[data-cozy-domain]')
  return el ? el.getAttribute('data-cozy-domain') : null
}

export async function initAuth() {
  // Try silent OIDC iframe flow first
  try {
    const token = await silentAuthorize()
    if (token) { oidcToken = token; return }
  } catch (_) {
    // silent flow failed, fall through to dev token
  }
  // Fall back to dev token
  const devToken = getDevToken()
  if (devToken) oidcToken = devToken
}

export function silentAuthorize() {
  return new Promise((resolve, reject) => {
    const state = crypto.randomUUID()
    const nonce = crypto.randomUUID()
    const redirectUri = `${window.location.origin}/auth/silent-callback`

    const params = new URLSearchParams({
      response_type: 'code',
      client_id: CLIENT_ID,
      redirect_uri: redirectUri,
      scope: 'openid email profile',
      state,
      nonce,
      prompt: 'none',
    })

    const iframe = document.createElement('iframe')
    iframe.style.display = 'none'
    iframe.src = `${OIDC_ISSUER}/oauth2/authorize?${params}`

    const timeout = setTimeout(() => {
      document.body.removeChild(iframe)
      reject(new Error('Silent OIDC flow timed out'))
    }, 10000)

    window.addEventListener('message', async function handler(event) {
      if (event.origin !== window.location.origin) return
      if (!event.data || event.data.type !== 'oidc_silent_callback') return
      window.removeEventListener('message', handler)
      clearTimeout(timeout)
      document.body.removeChild(iframe)

      if (event.data.error) { reject(new Error(event.data.error)); return }
      if (event.data.state !== state) { reject(new Error('State mismatch')); return }

      try {
        const token = await exchangeCode(event.data.code, redirectUri)
        resolve(token)
      } catch (err) {
        reject(err)
      }
    })

    document.body.appendChild(iframe)
  })
}

export async function exchangeCode(code, redirectUri) {
  const redirectUriToUse = redirectUri || `${window.location.origin}/auth/callback`
  const response = await fetch(`${OIDC_ISSUER}/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      client_id: CLIENT_ID,
      redirect_uri: redirectUriToUse,
    }),
  })
  if (!response.ok) throw new Error(`Token exchange failed: ${response.status}`)
  const data = await response.json()
  return data.access_token
}

export function getOidcToken() { return oidcToken ?? getDevToken() }
export function isAuthenticated() { return getOidcToken() !== null }

export function authHeaders() {
  const token = getOidcToken()
  if (!token) return {}
  return { Authorization: `Bearer ${token}` }
}

export function getCurrentUserEmail() {
  const token = getOidcToken()
  if (!token) return ''
  if (token.startsWith('dev-')) return `${token.slice(4)}@twake.local`
  try {
    const payload = JSON.parse(atob(token.split('.')[1]))
    return payload.email ?? `${payload.sub}@twake.local`
  } catch { return '' }
}

export function isAdmin() {
  const token = getOidcToken()
  if (!token) return false
  if (token.startsWith('dev-')) return token === 'dev-user1'
  try {
    const payload = JSON.parse(atob(token.split('.')[1]))
    return (payload.groups ?? []).some(g => g.includes('token-manager-admins'))
  } catch { return false }
}

export function loginRedirect() {
  const state = crypto.randomUUID()
  sessionStorage.setItem('oidc_state', state)
  const redirectUri = `${window.location.origin}/auth/callback`
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
  localStorage.removeItem('twake_dev_token')
  window.location.href = '#/tokens'
}

function getDevToken() {
  const params = new URLSearchParams(window.location.search)
  const devUser = params.get('dev_user')
  if (devUser) { localStorage.setItem('twake_dev_token', `dev-${devUser}`); return `dev-${devUser}` }
  return localStorage.getItem('twake_dev_token')
}
