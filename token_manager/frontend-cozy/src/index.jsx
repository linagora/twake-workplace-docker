import React from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.jsx'
import { initAuth } from './lib/auth.js'

async function main() {
  const appEl = document.querySelector('[role=application]')
  const dataset = appEl ? appEl.dataset : {}
  const cozyToken = dataset.cozyToken || null
  const cozyDomain = dataset.cozyDomain || null
  const cozyLocale = dataset.cozyLocale || 'en'

  // Init cozy-bar (standalone version injected by {{.CozyBar}})
  if (window.cozy && window.cozy.bar) {
    try {
      await window.cozy.bar.init({
        appName: 'Token Manager',
        appNamePrefix: 'Twake',
        appSlug: 'token-manager',
        cozyURL: `https://${cozyDomain}`,
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

  await initAuth()

  const root = createRoot(appEl || document.getElementById('root') || document.body.appendChild(Object.assign(document.createElement('div'), { id: 'root' })))
  root.render(<App />)
}

main().catch(console.error)
