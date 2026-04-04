# Token Manager Cozy App Migration — Design Spec

**Date**: 2026-04-03
**Status**: Approved
**Branch**: `feat/cozy-app` (based on `feat/token-manager`)
**Scope**: Convert Token Manager frontend into a native Cozy App

---

## 1. Overview

Create a second frontend (`frontend-cozy/`) that runs as a native Cozy App inside Cozy Stack. The existing Next.js frontend (`frontend/`) remains unchanged for standalone use. The API backend (Fastify) is shared — no changes needed.

### Design decisions

| Decision | Choice |
|---|---|
| Mode | Dual — Cozy App + Next.js standalone coexist |
| Bundler | create-cozy-app (official Cozy Webpack toolchain) |
| Auth | Token Cozy → silent OIDC Authorization Code flow → LemonLDAP |
| Deployment | Via patcher-cozy (ENABLE_APPS) + volume mount |
| Components | Copied from frontend/ and adapted (Next.js → React Router) |

---

## 2. Project Structure

```
token_manager/
├── frontend/                 ← Next.js standalone (UNCHANGED)
├── frontend-cozy/            ← NEW: Cozy App
│   ├── manifest.webapp       ← Cozy app manifest
│   ├── package.json          ← create-cozy-app deps
│   ├── src/
│   │   ├── index.jsx         ← Entry: cozy-bar init + React render
│   │   ├── App.jsx           ← HashRouter + routes
│   │   ├── targets/
│   │   │   └── browser/
│   │   │       └── index.ejs ← HTML template with {{.Token}} etc.
│   │   ├── components/       ← Copied and adapted from frontend/
│   │   │   ├── app-layout.jsx
│   │   │   ├── token-list.jsx
│   │   │   ├── create-token-dialog.jsx
│   │   │   ├── stats-cards.jsx
│   │   │   ├── audit-table.jsx
│   │   │   ├── user-accordion.jsx
│   │   │   └── bulk-revoke-bar.jsx
│   │   ├── pages/            ← Page components (from frontend/app/)
│   │   │   ├── TokensPage.jsx
│   │   │   ├── DashboardPage.jsx
│   │   │   ├── AuditPage.jsx
│   │   │   ├── AdminUsersPage.jsx
│   │   │   ├── AdminAuditPage.jsx
│   │   │   └── AdminConfigPage.jsx
│   │   └── lib/
│   │       ├── auth.js       ← Cozy token → OIDC exchange
│   │       └── api.js        ← apiFetch (same as frontend/)
│   └── build/                ← Static output for Cozy Stack
├── Dockerfile.frontend       ← Next.js (UNCHANGED)
├── Dockerfile.cozy-app       ← NEW: build create-cozy-app
└── src/                      ← API Fastify (UNCHANGED)
```

---

## 3. Manifest

`frontend-cozy/manifest.webapp`:

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

Minimal permissions — the app only communicates with the external Token Manager API. Cozy permissions just authorize the app to run and access cozy-bar/settings.

---

## 4. HTML Template

`frontend-cozy/src/targets/browser/index.ejs`:

```html
<!DOCTYPE html>
<html lang="{{.Locale}}">
<head>
  <meta charset="utf-8">
  <title>Twake Token Manager</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  {{.ThemeCSS}}
  {{.CozyClientJS}}
  {{.CozyBar}}
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

Webpack injects the bundled JS/CSS automatically.

---

## 5. Authentication: Cozy Token → OIDC

### Flow

1. Cozy Stack injects `{{.Token}}` into index.html at serve time
2. Frontend reads `data-cozy-token` from the DOM
3. Frontend initiates a silent OIDC Authorization Code flow:
   - Opens a hidden iframe to `https://auth.{BASE_DOMAIN}/oauth2/authorize?client_id=token-manager&redirect_uri=...&prompt=none`
   - If user has an active LemonLDAP SSO session (they do — they logged into Cozy via SSO), LemonLDAP auto-approves (bypassConsent=1) and returns a code
   - Frontend exchanges the code for an access_token via POST to `/oauth2/token`
4. The OIDC access_token is stored in memory
5. All API calls to Token Manager API use this OIDC token as Bearer

### Fallback

If the silent flow fails (no SSO session, iframe blocked), the frontend shows a "Connect to Twake" button that opens a full-page redirect to LemonLDAP login. After login, the app reloads and the silent flow succeeds.

### lib/auth.js

```javascript
const TOKEN_MANAGER_CLIENT_ID = 'token-manager'
const OIDC_ISSUER = 'https://auth.twake.local'
const REDIRECT_URI = 'https://user1-token-manager.twake.local/'

let oidcToken = null

export function getCozyToken() {
  const root = document.querySelector('[data-cozy-token]')
  return root?.dataset.cozyToken ?? null
}

export function getCozyDomain() {
  const root = document.querySelector('[data-cozy-domain]')
  return root?.dataset.cozyDomain ?? null
}

export async function initAuth() {
  // Try silent OIDC flow
  try {
    const code = await silentAuthorize()
    const token = await exchangeCode(code)
    oidcToken = token.access_token
  } catch {
    // Will show login button via UI
  }
}

export function getOidcToken() { return oidcToken }
export function isAuthenticated() { return oidcToken !== null }

export function authHeaders() {
  if (!oidcToken) return {}
  return { Authorization: `Bearer ${oidcToken}` }
}

// ... getCurrentUserEmail(), isAdmin() same as frontend/lib/auth.ts
```

---

## 6. Routing (React Router + Hash)

```javascript
// src/App.jsx
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
          <Route path="/" element={<Navigate to="/tokens" />} />
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

URLs in browser: `https://user1-token-manager.twake.local/#/tokens`, `/#/dashboard`, etc.

---

## 7. Component Adaptation

### Changes per component

| Component | Changes needed |
|---|---|
| `app-layout` | Remove `'use client'`, `next/link` → React Router `<Link>`, `usePathname()` → `useLocation()`, remove theme toggle |
| `token-list` | Remove `'use client'` only |
| `create-token-dialog` | Remove `'use client'` only |
| `stats-cards` | Remove `'use client'` only |
| `audit-table` | Remove `'use client'` only |
| `user-accordion` | Remove `'use client'` only |
| `bulk-revoke-bar` | Remove `'use client'` only |

### Pages adaptation

Each Next.js page (`app/tokens/page.tsx`) becomes a plain React component (`pages/TokensPage.jsx`):
- Remove `'use client'`
- Remove `<AppLayout>` wrapper (handled by App.jsx)
- Replace `next/navigation` imports with React Router equivalents
- Keep all logic, state, and API calls identical

### Cozy-bar in layout

The `app-layout` component is modified to account for the cozy-bar at the top:
- Add `padding-top: 48px` (cozy-bar height) to the main container
- The sidebar starts below the cozy-bar

---

## 8. Cozy-bar Initialization

```javascript
// src/index.jsx
import React from 'react'
import { render } from 'react-dom'
import App from './App'
import { initAuth } from './lib/auth'

const root = document.querySelector('[data-cozy-token]')
const data = root.dataset

// Initialize cozy-bar
if (window.cozy && window.cozy.bar) {
  window.cozy.bar.init({
    appName: 'Token Manager',
    appSlug: 'token-manager',
    cozyDomain: data.cozyDomain,
    token: data.cozyToken,
    lang: data.cozyLocale,
  })
}

// Initialize auth then render
initAuth().then(() => {
  render(<App />, root)
})
```

---

## 9. Deployment in Cozy Stack

### Volume mount

In `cozy_stack/docker-compose.yml`, add to `cozy-stack` service volumes:

```yaml
- ../token_manager/frontend-cozy/build:/data/cozy-app/token-manager
```

### Patcher activation

In `cozy_stack/docker-compose.yml`, add `token-manager` to `ENABLE_APPS`:

```yaml
environment:
  - ENABLE_APPS="mail,linshare,chat,calendar,meet,calendar-v2,contacts,token-manager"
```

### Traefik routing

Add subdomains to Cozy router HostRegexp in `cozy_stack/docker-compose.yml`:

```yaml
labels:
  - "traefik.http.routers.cozy.rule=HostRegexp(`{subdomain:...|user1-token-manager|user2-token-manager|user3-token-manager|...}.${BASE_DOMAIN}`)"
```

### /etc/hosts

```
127.0.0.1  user1-token-manager.twake.local user2-token-manager.twake.local user3-token-manager.twake.local
```

### Dockerfile.cozy-app

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY frontend-cozy/package*.json ./
RUN yarn install
COPY frontend-cozy/ ./
RUN yarn build

FROM alpine:3.19
COPY --from=builder /app/build /app
```

The build output is static HTML/JS/CSS — no runtime server needed.

---

## 10. API Backend

**No changes.** The Fastify API receives OIDC Bearer tokens from both frontends identically. It doesn't know or care whether the client is Next.js or Cozy App.

---

## 11. Dependencies

```json
{
  "cozy-bar": "latest",
  "cozy-client": "latest",
  "cozy-ui": "latest",
  "react": "^18.0.0",
  "react-dom": "^18.0.0",
  "react-router-dom": "^6.0.0"
}
```

Note: create-cozy-app uses React 18 (not 19) for compatibility with cozy-ui / MUI v4. The components work identically on React 18.
