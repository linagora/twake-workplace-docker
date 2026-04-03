# Cozy App Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a native Cozy App frontend (`frontend-cozy/`) for the Token Manager that coexists with the existing Next.js frontend.

**Architecture:** New `frontend-cozy/` directory initialized with create-cozy-app. All React components are copied from `frontend/` and adapted (remove Next.js directives, replace routing). Auth uses silent OIDC flow. Deployed via Cozy Stack volume mount + patcher.

**Tech Stack:** create-cozy-app (Webpack), React 18, React Router 6, cozy-bar, cozy-ui

**Spec:** `docs/superpowers/specs/2026-04-03-cozy-app-migration-design.md`

---

## Phase 1: Scaffolding

### Task 1: Initialize create-cozy-app project

**Files:**
- Create: `token_manager/frontend-cozy/` (entire directory)

- [ ] **Step 1: Create the Cozy app scaffold**

```bash
cd /Users/mmaudet/work/twake-ai-kickstart/token_manager
npx create-cozy-app frontend-cozy
```

If `create-cozy-app` is not available or fails, manually create the structure:

```bash
mkdir -p frontend-cozy/src/{components,pages,lib,targets/browser}
```

- [ ] **Step 2: Write package.json**

Write `token_manager/frontend-cozy/package.json`:
```json
{
  "name": "twake-token-manager-cozy",
  "version": "0.2.0",
  "private": true,
  "scripts": {
    "start": "webpack serve --config webpack.config.js --mode development",
    "build": "webpack --config webpack.config.js --mode production"
  },
  "dependencies": {
    "cozy-bar": "^40.0.0",
    "cozy-client": "^48.0.0",
    "cozy-ui": "^106.0.0",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "react-router-dom": "^6.28.0"
  },
  "devDependencies": {
    "@babel/core": "^7.26.0",
    "@babel/preset-env": "^7.26.0",
    "@babel/preset-react": "^7.26.0",
    "babel-loader": "^9.2.0",
    "css-loader": "^7.1.0",
    "html-webpack-plugin": "^5.6.0",
    "mini-css-extract-plugin": "^2.9.0",
    "style-loader": "^4.0.0",
    "webpack": "^5.97.0",
    "webpack-cli": "^6.0.0",
    "webpack-dev-server": "^5.1.0",
    "copy-webpack-plugin": "^12.0.0"
  }
}
```

- [ ] **Step 3: Write webpack.config.js**

Write `token_manager/frontend-cozy/webpack.config.js`:
```javascript
const path = require('path')
const HtmlWebpackPlugin = require('html-webpack-plugin')
const MiniCssExtractPlugin = require('mini-css-extract-plugin')
const CopyPlugin = require('copy-webpack-plugin')

module.exports = (env, argv) => {
  const isProd = argv.mode === 'production'

  return {
    entry: './src/index.jsx',
    output: {
      path: path.resolve(__dirname, 'build'),
      filename: 'app.[contenthash:8].js',
      clean: true,
    },
    resolve: {
      extensions: ['.js', '.jsx'],
    },
    module: {
      rules: [
        {
          test: /\.jsx?$/,
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader',
            options: {
              presets: ['@babel/preset-env', '@babel/preset-react'],
            },
          },
        },
        {
          test: /\.css$/,
          use: [isProd ? MiniCssExtractPlugin.loader : 'style-loader', 'css-loader'],
        },
      ],
    },
    plugins: [
      new HtmlWebpackPlugin({
        template: './src/targets/browser/index.ejs',
        filename: 'index.html',
        inject: true,
      }),
      ...(isProd ? [new MiniCssExtractPlugin({ filename: 'app.[contenthash:8].css' })] : []),
      new CopyPlugin({
        patterns: [
          { from: 'manifest.webapp', to: '.' },
          { from: 'src/targets/browser/icon.svg', to: '.', noErrorOnMissing: true },
        ],
      }),
    ],
    devServer: {
      port: 3300,
      historyApiFallback: true,
    },
  }
}
```

- [ ] **Step 4: Write manifest.webapp**

Write `token_manager/frontend-cozy/manifest.webapp`:
```json
{
  "name": "Token Manager",
  "name_prefix": "Twake",
  "slug": "token-manager",
  "icon": "icon.svg",
  "categories": ["cozy"],
  "version": "0.2.0",
  "licence": "AGPL-3.0",
  "permissions": {
    "apps": { "type": "io.cozy.apps" },
    "settings": { "type": "io.cozy.settings" },
    "permissions": { "type": "io.cozy.permissions" }
  },
  "routes": {
    "/": {
      "folder": "/",
      "index": "index.html",
      "public": false
    }
  }
}
```

- [ ] **Step 5: Write HTML template**

Write `token_manager/frontend-cozy/src/targets/browser/index.ejs`:
```html
<!DOCTYPE html>
<html lang="<%= htmlWebpackPlugin.options.cozyLocale || 'en' %>">
<head>
  <meta charset="utf-8">
  <title>Twake Token Manager</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body>
  <div role="application"
       data-cozy-token="{{.Token}}"
       data-cozy-domain="{{.Domain}}"
       data-cozy-locale="{{.Locale}}"
       data-cozy-app-slug="token-manager">
  </div>
</body>
</html>
```

Note: In dev mode (webpack-dev-server), the `{{.Token}}` placeholders won't be replaced. The auth lib handles this with a dev fallback.

- [ ] **Step 6: Create a placeholder SVG icon**

Write `token_manager/frontend-cozy/src/targets/browser/icon.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="12" fill="#297EF2"/>
  <text x="50%" y="55%" dominant-baseline="middle" text-anchor="middle" fill="white" font-size="28" font-family="system-ui" font-weight="bold">TM</text>
</svg>
```

- [ ] **Step 7: Install dependencies**

```bash
cd token_manager/frontend-cozy && npm install --legacy-peer-deps
```

- [ ] **Step 8: Commit**

```bash
git add token_manager/frontend-cozy/
git commit -m "feat(cozy-app): scaffold create-cozy-app project with Webpack"
```

---

### Task 2: Auth library (Cozy → OIDC)

**Files:**
- Create: `token_manager/frontend-cozy/src/lib/auth.js`
- Create: `token_manager/frontend-cozy/src/lib/api.js`

- [ ] **Step 1: Write auth library**

Write `token_manager/frontend-cozy/src/lib/auth.js`:
```javascript
const OIDC_ISSUER = process.env.COZY_OIDC_ISSUER || 'https://auth.twake.local'
const CLIENT_ID = process.env.COZY_OIDC_CLIENT_ID || 'token-manager'

let oidcToken = null

// Read Cozy injected data from DOM
export function getCozyToken() {
  const root = document.querySelector('[data-cozy-token]')
  return root?.dataset.cozyToken ?? null
}

export function getCozyDomain() {
  const root = document.querySelector('[data-cozy-domain]')
  return root?.dataset.cozyDomain ?? null
}

// Silent OIDC Authorization Code flow via iframe
function silentAuthorize() {
  return new Promise((resolve, reject) => {
    const domain = getCozyDomain() || 'twake.local'
    const redirectUri = `https://${window.location.host}/`
    const state = Math.random().toString(36).slice(2)

    const url = `${OIDC_ISSUER}/oauth2/authorize?` +
      `response_type=code&client_id=${CLIENT_ID}` +
      `&redirect_uri=${encodeURIComponent(redirectUri)}` +
      `&scope=openid+email+profile&state=${state}&prompt=none`

    const iframe = document.createElement('iframe')
    iframe.style.display = 'none'

    const timeout = setTimeout(() => {
      document.body.removeChild(iframe)
      reject(new Error('Silent auth timeout'))
    }, 10000)

    iframe.onload = () => {
      try {
        const iframeUrl = new URL(iframe.contentWindow.location.href)
        const code = iframeUrl.searchParams.get('code')
        const returnedState = iframeUrl.searchParams.get('state')
        clearTimeout(timeout)
        document.body.removeChild(iframe)
        if (code && returnedState === state) {
          resolve(code)
        } else {
          reject(new Error('No code in iframe redirect'))
        }
      } catch {
        // Cross-origin — iframe redirected to auth page (no session)
        clearTimeout(timeout)
        document.body.removeChild(iframe)
        reject(new Error('Cross-origin — no active SSO session'))
      }
    }

    document.body.appendChild(iframe)
    iframe.src = url
  })
}

async function exchangeCode(code) {
  const redirectUri = `https://${window.location.host}/`
  const resp = await fetch(`${OIDC_ISSUER}/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: redirectUri,
      client_id: CLIENT_ID,
    }),
  })
  if (!resp.ok) throw new Error('Token exchange failed')
  return resp.json()
}

export async function initAuth() {
  // Check URL for dev_user param (dev fallback)
  const params = new URLSearchParams(window.location.search)
  const devUser = params.get('dev_user')
  if (devUser) {
    oidcToken = `dev-${devUser}`
    return
  }

  // Check if we're in dev mode (no Cozy token injected)
  const cozyToken = getCozyToken()
  if (!cozyToken || cozyToken === '{{.Token}}') {
    // Dev mode — no Cozy Stack, use localStorage dev token
    const stored = localStorage.getItem('twake_dev_token')
    if (stored) { oidcToken = stored; return }
    return
  }

  // Production: silent OIDC flow
  try {
    const code = await silentAuthorize()
    const data = await exchangeCode(code)
    oidcToken = data.access_token
  } catch {
    // Will show fallback login button
  }
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
    return payload.email || `${payload.sub}@twake.local`
  } catch { return '' }
}

export function isAdmin() {
  if (!oidcToken) return false
  if (oidcToken.startsWith('dev-')) return oidcToken === 'dev-user1'
  try {
    const payload = JSON.parse(atob(oidcToken.split('.')[1]))
    return (payload.groups || []).some(g => g.includes('token-manager-admins'))
  } catch { return false }
}

export function loginRedirect() {
  const redirectUri = `https://${window.location.host}/`
  window.location.href = `${OIDC_ISSUER}/oauth2/authorize?` +
    `response_type=code&client_id=${CLIENT_ID}` +
    `&redirect_uri=${encodeURIComponent(redirectUri)}` +
    `&scope=openid+email+profile`
}

export function logout() {
  oidcToken = null
  localStorage.removeItem('twake_dev_token')
  window.location.reload()
}
```

- [ ] **Step 2: Write API client**

Write `token_manager/frontend-cozy/src/lib/api.js`:
```javascript
const API_BASE = process.env.COZY_API_URL || 'https://token-manager-api.twake.local'
const API_URL = `${API_BASE}/api/v1`

export class ApiError extends Error {
  constructor(status, message) {
    super(message)
    this.status = status
  }
}

export async function apiFetch(path, options = {}) {
  const headers = { ...options.headers }
  if (options.body && !headers['Content-Type']) {
    headers['Content-Type'] = 'application/json'
  }

  const response = await fetch(`${API_URL}${path}`, { ...options, headers })

  if (!response.ok) {
    const text = await response.text().catch(() => '')
    let message = `API error ${response.status}`
    try {
      const parsed = JSON.parse(text)
      message = parsed.message || parsed.error || message
    } catch {
      if (text) message = `${message}: ${text}`
    }
    throw new ApiError(response.status, message)
  }

  if (response.status === 204) return undefined
  return response.json()
}
```

- [ ] **Step 3: Commit**

```bash
git add token_manager/frontend-cozy/src/lib/
git commit -m "feat(cozy-app): add auth library with silent OIDC flow and API client"
```

---

### Task 3: Entry point, App router, and cozy-bar init

**Files:**
- Create: `token_manager/frontend-cozy/src/index.jsx`
- Create: `token_manager/frontend-cozy/src/App.jsx`

- [ ] **Step 1: Write entry point with cozy-bar init**

Write `token_manager/frontend-cozy/src/index.jsx`:
```jsx
import React from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
import { initAuth } from './lib/auth'

const rootEl = document.querySelector('[data-cozy-token]')
const data = rootEl ? rootEl.dataset : {}

// Initialize cozy-bar if available (injected by Cozy Stack)
if (window.cozy && window.cozy.bar) {
  window.cozy.bar.init({
    appName: 'Token Manager',
    appSlug: 'token-manager',
    cozyDomain: data.cozyDomain,
    token: data.cozyToken,
    lang: data.cozyLocale || 'en',
  })
}

// Initialize auth then render
initAuth().then(() => {
  const root = createRoot(rootEl)
  root.render(<App />)
}).catch(() => {
  const root = createRoot(rootEl)
  root.render(<App />)
})
```

- [ ] **Step 2: Write App router**

Write `token_manager/frontend-cozy/src/App.jsx`:
```jsx
import React from 'react'
import { HashRouter, Routes, Route, Navigate } from 'react-router-dom'
import AppLayout from './components/app-layout'
import TokensPage from './pages/TokensPage'
import DashboardPage from './pages/DashboardPage'
import AuditPage from './pages/AuditPage'
import AdminUsersPage from './pages/AdminUsersPage'
import AdminAuditPage from './pages/AdminAuditPage'
import AdminConfigPage from './pages/AdminConfigPage'

export default function App() {
  return (
    <HashRouter>
      <AppLayout>
        <Routes>
          <Route path="/" element={<Navigate to="/tokens" replace />} />
          <Route path="/tokens" element={<TokensPage />} />
          <Route path="/dashboard" element={<DashboardPage />} />
          <Route path="/audit" element={<AuditPage />} />
          <Route path="/admin/users" element={<AdminUsersPage />} />
          <Route path="/admin/audit" element={<AdminAuditPage />} />
          <Route path="/admin/config" element={<AdminConfigPage />} />
        </Routes>
      </AppLayout>
    </HashRouter>
  )
}
```

- [ ] **Step 3: Commit**

```bash
git add token_manager/frontend-cozy/src/index.jsx token_manager/frontend-cozy/src/App.jsx
git commit -m "feat(cozy-app): add entry point with cozy-bar init and React Router"
```

---

## Phase 2: Components & Pages

### Task 4: Copy and adapt components

**Files:**
- Create: `token_manager/frontend-cozy/src/components/` (7 files)

- [ ] **Step 1: Copy all components from frontend/ to frontend-cozy/src/components/**

For each file, the adaptation is:
1. Rename `.tsx` → `.jsx`
2. Remove `'use client'` directive
3. Remove TypeScript type annotations (interfaces, `: type`, `as type`, generics)
4. For `app-layout`: replace `next/link` with React Router `Link`, replace `usePathname()` with `useLocation().pathname`

Use a script or do manually:

```bash
# Copy all components
for f in token-list create-token-dialog stats-cards audit-table user-accordion bulk-revoke-bar; do
  cp token_manager/frontend/components/${f}.tsx token_manager/frontend-cozy/src/components/${f}.jsx
done
cp token_manager/frontend/components/app-layout.tsx token_manager/frontend-cozy/src/components/app-layout.jsx
```

Then for EACH `.jsx` file:
- Remove the first line if it's `'use client'`
- Remove all TypeScript: `interface X { ... }`, `: string`, `: number`, `: React.CSSProperties`, `as any`, `as const`, `<Type>`, generic params

For `app-layout.jsx` specifically:
- Replace `import Link from 'next/link'` with `import { Link, useLocation } from 'react-router-dom'`
- Replace `import { usePathname } from 'next/navigation'` → remove (use `useLocation` instead)
- Replace `const pathname = usePathname()` with `const { pathname } = useLocation()`
- Add `paddingTop: 48` to the outer container (for cozy-bar)
- Remove theme-toggle import and usage

- [ ] **Step 2: Verify no TypeScript or Next.js imports remain**

```bash
grep -r "from 'next\|'use client'\|: React\.\|interface " token_manager/frontend-cozy/src/components/ || echo "Clean"
```

- [ ] **Step 3: Commit**

```bash
git add token_manager/frontend-cozy/src/components/
git commit -m "feat(cozy-app): copy and adapt components from Next.js (remove TS, use React Router)"
```

---

### Task 5: Copy and adapt pages

**Files:**
- Create: `token_manager/frontend-cozy/src/pages/` (6 files)

- [ ] **Step 1: Copy and adapt all pages**

Each Next.js page (`frontend/app/{path}/page.tsx`) becomes a plain React component (`frontend-cozy/src/pages/{Name}Page.jsx`):

```bash
cp token_manager/frontend/app/tokens/page.tsx token_manager/frontend-cozy/src/pages/TokensPage.jsx
cp token_manager/frontend/app/dashboard/page.tsx token_manager/frontend-cozy/src/pages/DashboardPage.jsx
cp token_manager/frontend/app/audit/page.tsx token_manager/frontend-cozy/src/pages/AuditPage.jsx
cp token_manager/frontend/app/admin/users/page.tsx token_manager/frontend-cozy/src/pages/AdminUsersPage.jsx
cp token_manager/frontend/app/admin/audit/page.tsx token_manager/frontend-cozy/src/pages/AdminAuditPage.jsx
cp token_manager/frontend/app/admin/config/page.tsx token_manager/frontend-cozy/src/pages/AdminConfigPage.jsx
```

For EACH page:
1. Remove `'use client'`
2. Remove TypeScript annotations
3. Remove `<AppLayout>` wrapper (handled by App.jsx)
4. Change `export default function XXXPage()` to match the filename
5. Replace `import AppLayout from '@/components/app-layout'` → remove
6. Replace `import ... from '@/components/...'` → `import ... from '../components/...'`
7. Replace `import ... from '@/lib/...'` → `import ... from '../lib/...'`

- [ ] **Step 2: Verify no Next.js or TypeScript remains**

```bash
grep -r "from '@/\|from 'next\|'use client'\|AppLayout\|: React\." token_manager/frontend-cozy/src/pages/ || echo "Clean"
```

- [ ] **Step 3: Commit**

```bash
git add token_manager/frontend-cozy/src/pages/
git commit -m "feat(cozy-app): copy and adapt pages from Next.js to plain React components"
```

---

### Task 6: Build and verify

**Files:**
- Modify: `token_manager/frontend-cozy/.gitignore`

- [ ] **Step 1: Create .gitignore**

Write `token_manager/frontend-cozy/.gitignore`:
```
node_modules/
build/
```

- [ ] **Step 2: Build the Cozy app**

```bash
cd token_manager/frontend-cozy && npm run build
```

Expected: `build/` directory with `index.html`, `app.*.js`, `manifest.webapp`

- [ ] **Step 3: Fix any build errors**

Common issues:
- Missing imports → fix paths
- JSX syntax errors from incomplete TS removal → clean up
- CSS import issues → ensure `import 'cozy-bar/dist/cozy-bar.css'` if needed

- [ ] **Step 4: Commit**

```bash
git add token_manager/frontend-cozy/.gitignore
git commit -m "feat(cozy-app): verify build succeeds"
```

---

## Phase 3: Deployment

### Task 7: Cozy Stack integration

**Files:**
- Modify: `drive_app/docker-compose.yml` (volume mount + ENABLE_APPS + Traefik)
- Create: `token_manager/Dockerfile.cozy-app`

- [ ] **Step 1: Add volume mount for the Cozy app**

In `drive_app/docker-compose.yml`, add to the `cozy-stack` service `volumes` section:

```yaml
      - ../token_manager/frontend-cozy/build:/data/cozy-app/token-manager
```

- [ ] **Step 2: Add token-manager to ENABLE_APPS**

In `drive_app/docker-compose.yml`, update the `patcher-cozy` environment:

```yaml
      - ENABLE_APPS="mail,linshare,chat,calendar,meet,calendar-v2,contacts,token-manager"
```

- [ ] **Step 3: Add Traefik subdomains for token-manager app**

In `drive_app/docker-compose.yml`, add to the Cozy HostRegexp the token-manager subdomains for all users:

Add `user1-token-manager|user2-token-manager|user3-token-manager` to the existing HostRegexp pattern.

- [ ] **Step 4: Create Dockerfile.cozy-app**

Write `token_manager/Dockerfile.cozy-app`:
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY frontend-cozy/package*.json ./
RUN npm install --legacy-peer-deps
COPY frontend-cozy/ ./
RUN npm run build

FROM alpine:3.19
WORKDIR /app
COPY --from=builder /app/build /app
```

- [ ] **Step 5: Commit**

```bash
git add drive_app/docker-compose.yml token_manager/Dockerfile.cozy-app
git commit -m "feat(cozy-app): integrate into Cozy Stack with volume mount and patcher"
```

---

### Task 8: Test deployment and verify

- [ ] **Step 1: Build the Cozy app**

```bash
cd /Users/mmaudet/work/twake-ai-kickstart/token_manager/frontend-cozy
npm run build
```

- [ ] **Step 2: Restart Cozy Stack to pick up the new app**

```bash
docker restart cozyt patcher-cozy
```

Wait for patcher to complete (check logs):
```bash
docker logs patcher-cozy 2>&1 | tail -20
```

- [ ] **Step 3: Add /etc/hosts entries**

```
127.0.0.1  user1-token-manager.twake.local user2-token-manager.twake.local user3-token-manager.twake.local
```

- [ ] **Step 4: Test in browser**

Open `https://user1-token-manager.twake.local/` — should show the Token Manager Cozy App with cozy-bar at the top.

For dev mode (no Cozy Stack): `https://user1-token-manager.twake.local/?dev_user=user1`

- [ ] **Step 5: Verify Cozy Home shows the app**

Open `https://user1.twake.local/` (Cozy Home) — the Token Manager icon should appear in the app grid.

- [ ] **Step 6: Commit any fixes**

```bash
git add -A
git commit -m "fix(cozy-app): deployment fixes for Cozy Stack integration"
```

---

## Summary

| Phase | Tasks | What it produces |
|---|---|---|
| 1: Scaffolding | 1-3 | Cozy app project, auth lib, entry point + router |
| 2: Components | 4-6 | All components + pages adapted, verified build |
| 3: Deployment | 7-8 | Cozy Stack integration, volume mount, E2E test |

Total: **8 tasks**, each independently committable.
