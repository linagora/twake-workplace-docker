import React from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.jsx'
import { initAuth } from './lib/auth.js'

async function main() {
  // Read DOM data attributes injected by Cozy Stack
  const appEl = document.querySelector('[data-cozy-token]')
  const cozyToken = appEl ? appEl.getAttribute('data-cozy-token') : null
  const cozyDomain = appEl ? appEl.getAttribute('data-cozy-domain') : null
  const cozyLocale = appEl ? appEl.getAttribute('data-cozy-locale') : 'en'

  // Init cozy-bar if available
  if (window.cozy && window.cozy.bar) {
    try {
      await window.cozy.bar.init({
        appName: 'Token Manager',
        appNamePrefix: 'Twake',
        appSlug: 'token-manager',
        cozyURL: cozyDomain ? `https://${cozyDomain}` : `https://${window.location.hostname.replace('-token-manager', '')}`,
        token: cozyToken,
        lang: cozyLocale,
        iconPath: '/icon.svg',
        isPublic: false,
        appEditor: 'Linagora',
      })
    } catch (e) {
      console.warn('cozy-bar init error:', e)
    }
  }

  // Init auth (silent OIDC or dev-token fallback)
  await initAuth()

  // Mount React app
  const root = createRoot(appEl || document.getElementById('root') || document.body.appendChild(Object.assign(document.createElement('div'), { id: 'root' })))
  root.render(<App />)
}

main().catch(console.error)
