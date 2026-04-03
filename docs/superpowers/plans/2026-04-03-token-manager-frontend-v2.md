# Token Manager Frontend v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the Token Manager frontend with cozy-ui design system, console-style token UX, user/admin separation, and SSO authentication.

**Architecture:** Full rewrite of `token_manager/frontend/` — delete all existing files and recreate with cozy-ui components. Add 3 new API endpoints for user audit, admin user list, and bulk revocation. Register a new OIDC client in LemonLDAP for frontend auth.

**Tech Stack:** Next.js 15, cozy-ui (MUI v4), React 19, TypeScript

**Spec:** `docs/superpowers/specs/2026-04-03-token-manager-frontend-v2-design.md`

---

## Phase 1: Scaffolding & Dependencies

### Task 1: Remove Tailwind, add cozy-ui dependencies

**Files:**
- Modify: `token_manager/frontend/package.json`
- Delete: `token_manager/frontend/tailwind.config.ts`
- Delete: `token_manager/frontend/postcss.config.js`
- Delete: `token_manager/frontend/app/globals.css`
- Modify: `token_manager/frontend/next.config.mjs`

- [ ] **Step 1: Update package.json**

Write `token_manager/frontend/package.json`:
```json
{
  "name": "twake-token-manager-frontend",
  "version": "0.2.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "cozy-ui": "^106.0.0",
    "@material-ui/core": "^4.12.4",
    "@material-ui/icons": "^4.11.3",
    "next": "^15.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@types/react": "^19.0.0",
    "typescript": "^5.4.0"
  }
}
```

- [ ] **Step 2: Update next.config.mjs**

Write `token_manager/frontend/next.config.mjs`:
```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  transpilePackages: ['cozy-ui'],
}
export default nextConfig
```

- [ ] **Step 3: Delete Tailwind files**

```bash
rm -f token_manager/frontend/tailwind.config.ts
rm -f token_manager/frontend/postcss.config.js
rm -f token_manager/frontend/app/globals.css
```

- [ ] **Step 4: Install dependencies**

```bash
cd token_manager/frontend && npm install
```

- [ ] **Step 5: Commit**

```bash
git add -A token_manager/frontend/
git commit -m "feat(frontend-v2): replace Tailwind with cozy-ui dependencies"
```

---

### Task 2: Auth library and API client

**Files:**
- Rewrite: `token_manager/frontend/lib/auth.ts`
- Rewrite: `token_manager/frontend/lib/api.ts`

- [ ] **Step 1: Write auth library**

Write `token_manager/frontend/lib/auth.ts`:
```typescript
'use client'

const OIDC_ISSUER = process.env.NEXT_PUBLIC_OIDC_ISSUER ?? 'https://auth.twake.local'
const CLIENT_ID = process.env.NEXT_PUBLIC_OIDC_CLIENT_ID ?? 'token-manager'
const REDIRECT_URI = process.env.NEXT_PUBLIC_OIDC_REDIRECT_URI ?? 'https://token-manager.twake.local/auth/callback'

let oidcToken: string | null = null

export function setOidcToken(token: string) {
  oidcToken = token
}

export function getOidcToken(): string | null {
  return oidcToken ?? getDevToken()
}

export function isAuthenticated(): boolean {
  return getOidcToken() !== null
}

export function authHeaders(): Record<string, string> {
  const token = getOidcToken()
  if (!token) return {}
  return { Authorization: `Bearer ${token}` }
}

export function getCurrentUserEmail(): string {
  const token = getOidcToken()
  if (!token) return ''
  // Dev token: dev-user1 → user1@twake.local
  if (token.startsWith('dev-')) {
    return `${token.slice(4)}@twake.local`
  }
  // JWT: decode payload for email claim
  try {
    const payload = JSON.parse(atob(token.split('.')[1]))
    return payload.email ?? `${payload.sub}@twake.local`
  } catch {
    return ''
  }
}

export function isAdmin(): boolean {
  const token = getOidcToken()
  if (!token) return false
  if (token.startsWith('dev-')) return token === 'dev-user1'
  try {
    const payload = JSON.parse(atob(token.split('.')[1]))
    const groups = payload.groups ?? []
    return groups.some((g: string) => g.includes('token-manager-admins'))
  } catch {
    return false
  }
}

export function loginRedirect() {
  if (typeof window === 'undefined') return
  const state = crypto.randomUUID()
  sessionStorage.setItem('oidc_state', state)
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    scope: 'openid email profile',
    state,
  })
  window.location.href = `${OIDC_ISSUER}/oauth2/authorize?${params}`
}

export function logout() {
  oidcToken = null
  localStorage.removeItem('twake_dev_token')
  if (typeof window !== 'undefined') {
    window.location.href = '/tokens'
  }
}

function getDevToken(): string | null {
  if (typeof window === 'undefined') return null
  const params = new URLSearchParams(window.location.search)
  const devUser = params.get('dev_user')
  if (devUser) {
    localStorage.setItem('twake_dev_token', `dev-${devUser}`)
    return `dev-${devUser}`
  }
  return localStorage.getItem('twake_dev_token')
}
```

- [ ] **Step 2: Write API client**

Write `token_manager/frontend/lib/api.ts`:
```typescript
const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? 'https://token-manager-api.twake.local'
const API_URL = `${API_BASE}/api/v1`

export class ApiError extends Error {
  status: number
  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

export async function apiFetch<T>(path: string, options?: RequestInit): Promise<T> {
  const headers: Record<string, string> = { ...options?.headers as Record<string, string> }
  if (options?.body && !headers['Content-Type']) {
    headers['Content-Type'] = 'application/json'
  }

  const response = await fetch(`${API_URL}${path}`, { ...options, headers })

  if (!response.ok) {
    const text = await response.text().catch(() => '')
    throw new ApiError(response.status, `API error ${response.status}: ${text}`)
  }
  if (response.status === 204) return undefined as T
  return response.json() as T
}
```

- [ ] **Step 3: Commit**

```bash
git add token_manager/frontend/lib/
git commit -m "feat(frontend-v2): add auth library with SSO + dev fallback, and API client"
```

---

### Task 3: Root layout with cozy-ui theme

**Files:**
- Rewrite: `token_manager/frontend/app/layout.tsx`
- Rewrite: `token_manager/frontend/app/page.tsx`
- Create: `token_manager/frontend/components/theme-toggle.tsx`

- [ ] **Step 1: Create theme toggle component**

Write `token_manager/frontend/components/theme-toggle.tsx`:
```tsx
'use client'

import { useEffect, useState } from 'react'

export type ThemeMode = 'light' | 'dark'

export function useThemeMode(): [ThemeMode, () => void] {
  const [mode, setMode] = useState<ThemeMode>('light')

  useEffect(() => {
    const stored = localStorage.getItem('twake_theme') as ThemeMode | null
    if (stored) setMode(stored)
  }, [])

  const toggle = () => {
    const next = mode === 'light' ? 'dark' : 'light'
    setMode(next)
    localStorage.setItem('twake_theme', next)
  }

  return [mode, toggle]
}

interface ThemeToggleProps {
  mode: ThemeMode
  onToggle: () => void
}

export default function ThemeToggle({ mode, onToggle }: ThemeToggleProps) {
  return (
    <button
      onClick={onToggle}
      style={{
        padding: '8px 16px',
        borderRadius: 8,
        border: '1px solid var(--secondaryTextColor, #ccc)',
        background: 'transparent',
        color: 'var(--primaryTextColor, #333)',
        cursor: 'pointer',
        fontSize: 13,
        width: '100%',
      }}
    >
      {mode === 'light' ? '🌙 Dark mode' : '☀️ Light mode'}
    </button>
  )
}
```

- [ ] **Step 2: Create root layout**

Write `token_manager/frontend/app/layout.tsx`:
```tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Twake Token Manager',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
```

Note: cozy-ui imports and MuiCozyTheme will be in the client-side `AppLayout` component (Task 4) rather than the server layout, because MuiCozyTheme requires client-side rendering and theme state.

- [ ] **Step 3: Create redirect page**

Write `token_manager/frontend/app/page.tsx`:
```tsx
import { redirect } from 'next/navigation'
export default function Home() {
  redirect('/tokens')
}
```

- [ ] **Step 4: Commit**

```bash
git add token_manager/frontend/app/layout.tsx token_manager/frontend/app/page.tsx token_manager/frontend/components/theme-toggle.tsx
git commit -m "feat(frontend-v2): add root layout and theme toggle"
```

---

### Task 4: App layout with cozy-ui sidebar

**Files:**
- Create: `token_manager/frontend/components/app-layout.tsx`

- [ ] **Step 1: Create the main layout with sidebar**

Write `token_manager/frontend/components/app-layout.tsx`:
```tsx
'use client'

import { usePathname } from 'next/navigation'
import Link from 'next/link'
import { isAdmin as checkIsAdmin, isAuthenticated, loginRedirect, getCurrentUserEmail, logout } from '@/lib/auth'
import ThemeToggle, { useThemeMode } from './theme-toggle'

const USER_NAV = [
  { label: 'My Tokens', href: '/tokens' },
  { label: 'Dashboard', href: '/dashboard' },
  { label: 'Audit Log', href: '/audit' },
]

const ADMIN_NAV = [
  { label: 'Users & Tokens', href: '/admin/users' },
  { label: 'Configuration', href: '/admin/config' },
]

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const [themeMode, toggleTheme] = useThemeMode()
  const admin = checkIsAdmin()
  const userEmail = getCurrentUserEmail()

  const isDark = themeMode === 'dark'
  const bgMain = isDark ? '#1a1a2e' : '#f7f8fa'
  const bgSidebar = isDark ? '#16213e' : '#ffffff'
  const bgContent = isDark ? '#0f3460' : '#ffffff'
  const textPrimary = isDark ? '#e0e0e0' : '#2d3748'
  const textMuted = isDark ? '#8899a6' : '#95a0b4'
  const accentColor = '#297EF2'
  const borderColor = isDark ? '#2a2a4a' : '#e8ecf0'

  const navItemStyle = (href: string) => ({
    display: 'block',
    padding: '8px 20px',
    textDecoration: 'none',
    fontSize: 14,
    color: pathname === href ? accentColor : textPrimary,
    fontWeight: pathname === href ? 600 : 400,
    background: pathname === href ? (isDark ? '#1a3a6e' : '#e8f0fe') : 'transparent',
    borderLeft: pathname === href ? `3px solid ${accentColor}` : '3px solid transparent',
  })

  return (
    <div style={{ display: 'flex', height: '100vh', background: bgMain, color: textPrimary }}>
      {/* Sidebar */}
      <aside style={{
        width: 240, background: bgSidebar, borderRight: `1px solid ${borderColor}`,
        display: 'flex', flexDirection: 'column', flexShrink: 0,
      }}>
        <div style={{ padding: '16px 20px 24px', fontSize: 18, fontWeight: 700, color: accentColor }}>
          Token Manager
        </div>

        <div style={{ padding: '4px 12px 4px', fontSize: 10, textTransform: 'uppercase', color: textMuted, fontWeight: 600, letterSpacing: 0.5 }}>
          Mon espace
        </div>
        {USER_NAV.map((item) => (
          <Link key={item.href} href={item.href} style={navItemStyle(item.href)}>
            {item.label}
          </Link>
        ))}

        {admin && (
          <>
            <div style={{ marginTop: 16, padding: '4px 12px 4px', fontSize: 10, textTransform: 'uppercase', color: textMuted, fontWeight: 600, letterSpacing: 0.5 }}>
              Administration
            </div>
            {ADMIN_NAV.map((item) => (
              <Link key={item.href} href={item.href} style={navItemStyle(item.href)}>
                {item.label}
              </Link>
            ))}
          </>
        )}

        <div style={{ marginTop: 'auto', padding: '12px 16px', borderTop: `1px solid ${borderColor}` }}>
          {userEmail && (
            <div style={{ fontSize: 12, color: textMuted, marginBottom: 8, overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {userEmail}
            </div>
          )}
          <ThemeToggle mode={themeMode} onToggle={toggleTheme} />
        </div>
      </aside>

      {/* Main content */}
      <main style={{ flex: 1, overflow: 'auto', padding: '24px 32px', background: bgContent }}>
        {children}
      </main>
    </div>
  )
}
```

Note: We use inline styles initially rather than importing cozy-ui Layout/Sidebar components, because cozy-ui requires specific React version compat and SSR handling. The inline styles follow the cozy-ui color palette. We can swap to native cozy-ui Layout components once we validate the build works.

- [ ] **Step 2: Commit**

```bash
git add token_manager/frontend/components/app-layout.tsx
git commit -m "feat(frontend-v2): add app layout with sidebar navigation and theme support"
```

---

## Phase 2: User Pages

### Task 5: Token list component

**Files:**
- Create: `token_manager/frontend/components/token-list.tsx`

- [ ] **Step 1: Create token list table component**

Write `token_manager/frontend/components/token-list.tsx`:
```tsx
'use client'

export interface TokenItem {
  service: string
  status: string
  expires_at: string
  granted_by?: string
  granted_at?: string
  auto_refresh?: boolean
  instance_url?: string
  type?: 'service' | 'umbrella'
  scopes?: string[]
}

interface TokenListProps {
  tokens: TokenItem[]
  onRefresh?: (service: string) => void
  onRevoke: (service: string) => void
  showUser?: boolean
}

function maskToken(token: string): string {
  if (!token || token.length < 12) return '••••••'
  return `${token.slice(0, 6)}...${token.slice(-4)}`
}

function statusBadge(status: string, expiresAt: string) {
  const minutesLeft = (new Date(expiresAt).getTime() - Date.now()) / 60000
  const isExpiring = status === 'ACTIVE' && minutesLeft < 15

  let bg = '#e8f5e9'
  let color = '#2e7d32'
  let label = 'Active'

  if (status === 'EXPIRED' || status === 'REFRESH_FAILED') {
    bg = '#ffebee'; color = '#c62828'; label = status === 'REFRESH_FAILED' ? 'Failed' : 'Expired'
  } else if (status === 'REVOKED') {
    bg = '#f5f5f5'; color = '#757575'; label = 'Revoked'
  } else if (isExpiring) {
    bg = '#fff3e0'; color = '#e65100'; label = 'Expiring'
  }

  return (
    <span style={{ background: bg, color, padding: '2px 8px', borderRadius: 10, fontSize: 11, fontWeight: 600 }}>
      {label}
    </span>
  )
}

function typeBadge(type: string) {
  const isUmbrella = type === 'umbrella'
  return (
    <span style={{
      background: isUmbrella ? '#e3f2fd' : '#e8f5e9',
      color: isUmbrella ? '#1565c0' : '#2e7d32',
      padding: '2px 8px', borderRadius: 10, fontSize: 11,
    }}>
      {isUmbrella ? 'Umbrella' : 'Service'}
    </span>
  )
}

const SERVICE_LABELS: Record<string, string> = {
  'twake-mail': 'TMail JMAP',
  'twake-calendar': 'Calendar CalDAV',
  'twake-chat': 'Matrix Chat',
  'twake-drive': 'Cozy Drive',
}

export default function TokenList({ tokens, onRefresh, onRevoke, showUser }: TokenListProps) {
  const activeTokens = tokens.filter((t) => t.status !== 'REVOKED')

  if (activeTokens.length === 0) {
    return (
      <div style={{ textAlign: 'center', padding: 32, color: '#95a0b4', fontSize: 14, border: '1px solid #e8ecf0', borderRadius: 8 }}>
        No tokens yet. Click "+ Create Token" to get started.
      </div>
    )
  }

  const headerStyle: React.CSSProperties = {
    padding: '10px 16px', fontSize: 10, textTransform: 'uppercase', color: '#95a0b4',
    fontWeight: 600, letterSpacing: 0.5,
  }
  const cellStyle: React.CSSProperties = { padding: '12px 16px', fontSize: 13 }

  return (
    <div style={{ border: '1px solid #e8ecf0', borderRadius: 8, overflow: 'hidden' }}>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead style={{ background: '#f7f8fa' }}>
          <tr>
            <th style={headerStyle}>Name / Service</th>
            <th style={headerStyle}>Type</th>
            <th style={headerStyle}>Token</th>
            <th style={headerStyle}>Status</th>
            <th style={{ ...headerStyle, textAlign: 'right' }}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {activeTokens.map((token, i) => (
            <tr key={`${token.service}-${i}`} style={{ borderTop: '1px solid #f0f0f0' }}>
              <td style={cellStyle}>
                <div style={{ fontWeight: 600 }}>{SERVICE_LABELS[token.service] ?? token.service}</div>
                <div style={{ fontSize: 11, color: '#95a0b4' }}>
                  {token.type === 'umbrella' ? token.scopes?.join(', ') : token.service}
                </div>
              </td>
              <td style={cellStyle}>{typeBadge(token.type ?? 'service')}</td>
              <td style={{ ...cellStyle, fontFamily: 'monospace', fontSize: 12, color: '#95a0b4' }}>
                {maskToken(token.service)}
              </td>
              <td style={cellStyle}>{statusBadge(token.status, token.expires_at)}</td>
              <td style={{ ...cellStyle, textAlign: 'right' }}>
                {token.type !== 'umbrella' && onRefresh && (
                  <button onClick={() => onRefresh(token.service)} style={{ background: 'none', border: 'none', color: '#297EF2', fontSize: 12, cursor: 'pointer', marginRight: 8 }}>
                    Refresh
                  </button>
                )}
                <button onClick={() => onRevoke(token.service)} style={{ background: 'none', border: 'none', color: '#e53e3e', fontSize: 12, cursor: 'pointer' }}>
                  Revoke
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add token_manager/frontend/components/token-list.tsx
git commit -m "feat(frontend-v2): add token list component with masked tokens and status badges"
```

---

### Task 6: Create Token Dialog

**Files:**
- Create: `token_manager/frontend/components/create-token-dialog.tsx`

- [ ] **Step 1: Create the dialog component**

Write `token_manager/frontend/components/create-token-dialog.tsx`:
```tsx
'use client'

import { useState } from 'react'
import { apiFetch } from '@/lib/api'
import { authHeaders, getCurrentUserEmail } from '@/lib/auth'

interface CreateTokenDialogProps {
  open: boolean
  onClose: () => void
  onCreated: () => void
}

type Step = 'form' | 'display' | 'consent'
type TokenType = 'service' | 'umbrella'

const SERVICES = [
  { id: 'twake-mail', label: 'TMail JMAP' },
  { id: 'twake-calendar', label: 'Calendar CalDAV' },
  { id: 'twake-chat', label: 'Matrix Chat' },
  { id: 'twake-drive', label: 'Cozy Drive' },
]

export default function CreateTokenDialog({ open, onClose, onCreated }: CreateTokenDialogProps) {
  const [step, setStep] = useState<Step>('form')
  const [tokenType, setTokenType] = useState<TokenType>('service')
  const [selectedService, setSelectedService] = useState(SERVICES[0].id)
  const [selectedScopes, setSelectedScopes] = useState<string[]>([])
  const [name, setName] = useState('')
  const [createdToken, setCreatedToken] = useState('')
  const [consentUrl, setConsentUrl] = useState('')
  const [tokenInfo, setTokenInfo] = useState({ service: '', expires_at: '' })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [copied, setCopied] = useState(false)

  if (!open) return null

  const handleCreate = async () => {
    setLoading(true)
    setError('')
    try {
      const user = getCurrentUserEmail()
      if (tokenType === 'service') {
        const res = await apiFetch<any>('/tokens', {
          method: 'POST',
          headers: authHeaders(),
          body: JSON.stringify({ service: selectedService, user }),
        })
        if (res.status === 'consent_required') {
          setConsentUrl(res.redirect_url)
          setStep('consent')
        } else {
          setCreatedToken(res.access_token)
          setTokenInfo({ service: selectedService, expires_at: res.expires_at })
          setStep('display')
        }
      } else {
        const scopes = selectedScopes.length > 0 ? selectedScopes : [SERVICES[0].id]
        const res = await apiFetch<any>('/umbrella-token', {
          method: 'POST',
          headers: authHeaders(),
          body: JSON.stringify({ user, scopes }),
        })
        setCreatedToken(res.umbrella_token)
        setTokenInfo({ service: scopes.join(', '), expires_at: res.expires_at })
        setStep('display')
      }
    } catch (err: any) {
      if (err.status === 202) {
        // consent_required handled above
      } else {
        setError(err.message ?? 'Failed to create token')
      }
    } finally {
      setLoading(false)
    }
  }

  const handleCopy = async () => {
    await navigator.clipboard.writeText(createdToken)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const handleDone = () => {
    setStep('form')
    setCreatedToken('')
    setConsentUrl('')
    setName('')
    setError('')
    setCopied(false)
    onCreated()
    onClose()
  }

  const handleCancel = () => {
    setStep('form')
    setCreatedToken('')
    setConsentUrl('')
    setError('')
    onClose()
  }

  const overlayStyle: React.CSSProperties = {
    position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)',
    display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000,
  }
  const dialogStyle: React.CSSProperties = {
    background: '#fff', borderRadius: 12, width: 520, padding: 24,
    boxShadow: '0 8px 32px rgba(0,0,0,0.2)', maxHeight: '90vh', overflow: 'auto',
  }

  return (
    <div style={overlayStyle} onClick={step === 'form' ? handleCancel : undefined}>
      <div style={dialogStyle} onClick={(e) => e.stopPropagation()}>
        {step === 'form' && (
          <>
            <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 4 }}>Create a new token</h2>
            <p style={{ fontSize: 13, color: '#95a0b4', marginBottom: 20 }}>
              The token will only be shown once. Copy it before closing.
            </p>

            {error && (
              <div style={{ background: '#ffebee', border: '1px solid #ef9a9a', borderRadius: 8, padding: '8px 12px', marginBottom: 16, fontSize: 12, color: '#c62828' }}>
                {error}
              </div>
            )}

            <div style={{ marginBottom: 16 }}>
              <div style={{ fontSize: 12, fontWeight: 600, color: '#5d6d7e', marginBottom: 6 }}>Token type</div>
              <div style={{ display: 'flex', gap: 8 }}>
                {(['service', 'umbrella'] as const).map((t) => (
                  <div key={t} onClick={() => setTokenType(t)} style={{
                    flex: 1, padding: 10, border: `2px solid ${tokenType === t ? '#297EF2' : '#e0e0e0'}`,
                    borderRadius: 8, background: tokenType === t ? '#f0f7ff' : '#fff',
                    textAlign: 'center', cursor: 'pointer',
                  }}>
                    <div style={{ fontWeight: 600, color: tokenType === t ? '#297EF2' : '#5d6d7e' }}>
                      {t === 'service' ? 'Service' : 'Umbrella'}
                    </div>
                    <div style={{ fontSize: 11, color: '#95a0b4' }}>
                      {t === 'service' ? 'Single service access' : 'Multi-service access'}
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {tokenType === 'service' ? (
              <div style={{ marginBottom: 16 }}>
                <div style={{ fontSize: 12, fontWeight: 600, color: '#5d6d7e', marginBottom: 6 }}>Service</div>
                <select value={selectedService} onChange={(e) => setSelectedService(e.target.value)}
                  style={{ width: '100%', padding: '8px 12px', border: '1px solid #d0d5dd', borderRadius: 6, fontSize: 13 }}>
                  {SERVICES.map((s) => <option key={s.id} value={s.id}>{s.id} — {s.label}</option>)}
                </select>
              </div>
            ) : (
              <div style={{ marginBottom: 16 }}>
                <div style={{ fontSize: 12, fontWeight: 600, color: '#5d6d7e', marginBottom: 6 }}>Services (select multiple)</div>
                {SERVICES.map((s) => (
                  <label key={s.id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '4px 0', fontSize: 13, cursor: 'pointer' }}>
                    <input type="checkbox" checked={selectedScopes.includes(s.id)}
                      onChange={(e) => setSelectedScopes(e.target.checked
                        ? [...selectedScopes, s.id]
                        : selectedScopes.filter((x) => x !== s.id)
                      )} />
                    {s.label} <span style={{ color: '#95a0b4', fontSize: 11 }}>({s.id})</span>
                  </label>
                ))}
              </div>
            )}

            <div style={{ marginBottom: 20 }}>
              <div style={{ fontSize: 12, fontWeight: 600, color: '#5d6d7e', marginBottom: 6 }}>Name (optional)</div>
              <input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. ZeroInbox integration"
                style={{ width: '100%', padding: '8px 12px', border: '1px solid #d0d5dd', borderRadius: 6, fontSize: 13, boxSizing: 'border-box' }} />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <button onClick={handleCancel} style={{ padding: '8px 16px', border: '1px solid #d0d5dd', borderRadius: 6, background: '#fff', cursor: 'pointer', fontSize: 13 }}>Cancel</button>
              <button onClick={handleCreate} disabled={loading} style={{ padding: '8px 16px', border: 'none', borderRadius: 6, background: '#297EF2', color: '#fff', fontWeight: 600, cursor: 'pointer', fontSize: 13, opacity: loading ? 0.6 : 1 }}>
                {loading ? 'Creating...' : 'Create Token'}
              </button>
            </div>
          </>
        )}

        {step === 'display' && (
          <>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
              <span style={{ fontSize: 20 }}>✅</span>
              <span style={{ fontSize: 18, fontWeight: 700 }}>Token created</span>
            </div>

            <div style={{ background: '#fef3cd', border: '1px solid #ffc107', borderRadius: 8, padding: '10px 14px', margin: '12px 0', fontSize: 12, color: '#856404' }}>
              ⚠️ Copy this token now. It won't be shown again.
            </div>

            <div style={{ background: '#f7f8fa', border: '1px solid #e0e0e0', borderRadius: 8, padding: '12px 14px', margin: '12px 0', display: 'flex', alignItems: 'center', gap: 8 }}>
              <code style={{ flex: 1, fontSize: 11, wordBreak: 'break-all', color: '#2d3748', lineHeight: 1.5 }}>
                {createdToken}
              </code>
              <button onClick={handleCopy} style={{
                padding: '6px 12px', border: `1px solid ${copied ? '#2e7d32' : '#297EF2'}`, borderRadius: 6,
                background: copied ? '#e8f5e9' : '#f0f7ff', color: copied ? '#2e7d32' : '#297EF2',
                fontSize: 12, fontWeight: 600, cursor: 'pointer', whiteSpace: 'nowrap',
              }}>
                {copied ? '✓ Copied' : '📋 Copy'}
              </button>
            </div>

            <div style={{ fontSize: 12, color: '#95a0b4', marginBottom: 16 }}>
              <strong>Service:</strong> {tokenInfo.service} &nbsp;|&nbsp;
              <strong>Expires:</strong> {new Date(tokenInfo.expires_at).toLocaleString()}
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
              <button onClick={handleDone} style={{ padding: '8px 20px', border: 'none', borderRadius: 6, background: '#297EF2', color: '#fff', fontWeight: 600, cursor: 'pointer', fontSize: 13 }}>
                Done — I've copied it
              </button>
            </div>
          </>
        )}

        {step === 'consent' && (
          <>
            <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 4 }}>Authorization required</h2>
            <p style={{ fontSize: 13, color: '#95a0b4', marginBottom: 16 }}>
              This service requires your consent. Click the link below to authorize, then come back and refresh.
            </p>
            <a href={consentUrl} target="_blank" rel="noopener noreferrer"
              style={{ display: 'block', padding: '12px 16px', background: '#f0f7ff', border: '1px solid #297EF2', borderRadius: 8, color: '#297EF2', fontWeight: 600, textAlign: 'center', textDecoration: 'none', marginBottom: 16 }}>
              Complete authorization →
            </a>
            <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
              <button onClick={handleDone} style={{ padding: '8px 16px', border: '1px solid #d0d5dd', borderRadius: 6, background: '#fff', cursor: 'pointer', fontSize: 13 }}>Close</button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add token_manager/frontend/components/create-token-dialog.tsx
git commit -m "feat(frontend-v2): add Create Token dialog with one-time display and consent flow"
```

---

### Task 7: My Tokens page

**Files:**
- Create: `token_manager/frontend/app/tokens/page.tsx`
- Delete: `token_manager/frontend/app/admin/page.tsx`
- Delete: `token_manager/frontend/app/user/page.tsx`
- Delete: old components

- [ ] **Step 1: Delete old pages and components**

```bash
rm -rf token_manager/frontend/app/admin
rm -rf token_manager/frontend/app/user
rm -f token_manager/frontend/components/stats-bar.tsx
rm -f token_manager/frontend/components/token-table.tsx
rm -f token_manager/frontend/components/refresh-config.tsx
rm -f token_manager/frontend/components/user-access-list.tsx
```

- [ ] **Step 2: Create My Tokens page**

Write `token_manager/frontend/app/tokens/page.tsx`:
```tsx
'use client'

import { useCallback, useEffect, useState } from 'react'
import AppLayout from '@/components/app-layout'
import TokenList, { type TokenItem } from '@/components/token-list'
import CreateTokenDialog from '@/components/create-token-dialog'
import { apiFetch } from '@/lib/api'
import { authHeaders, getCurrentUserEmail } from '@/lib/auth'

export default function MyTokensPage() {
  const [tokens, setTokens] = useState<TokenItem[]>([])
  const [error, setError] = useState<string | null>(null)
  const [dialogOpen, setDialogOpen] = useState(false)

  const fetchTokens = useCallback(async () => {
    try {
      const user = getCurrentUserEmail()
      if (!user) return
      const data = await apiFetch<TokenItem[]>(`/tokens?user=${encodeURIComponent(user)}`, {
        headers: authHeaders(),
      })
      setTokens(data.map((t) => ({ ...t, type: 'service' as const })))
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load tokens')
    }
  }, [])

  useEffect(() => {
    fetchTokens()
  }, [fetchTokens])

  const handleRevoke = async (service: string) => {
    const user = getCurrentUserEmail()
    try {
      await apiFetch(`/tokens/${service}?user=${encodeURIComponent(user)}`, {
        method: 'DELETE',
        headers: authHeaders(),
      })
      await fetchTokens()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Revoke failed')
    }
  }

  const handleRefresh = async (service: string) => {
    const user = getCurrentUserEmail()
    try {
      await apiFetch('/tokens/refresh', {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ service, user }),
      })
      await fetchTokens()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Refresh failed')
    }
  }

  return (
    <AppLayout>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <div>
          <h1 style={{ fontSize: 20, fontWeight: 700, margin: 0 }}>My Tokens</h1>
          <p style={{ fontSize: 13, color: '#95a0b4', margin: '4px 0 0' }}>Manage your service and umbrella tokens</p>
        </div>
        <button onClick={() => setDialogOpen(true)} style={{
          background: '#297EF2', color: '#fff', border: 'none', padding: '8px 16px',
          borderRadius: 6, fontWeight: 600, fontSize: 13, cursor: 'pointer',
        }}>
          + Create Token
        </button>
      </div>

      {error && (
        <div style={{ background: '#ffebee', border: '1px solid #ef9a9a', borderRadius: 8, padding: '8px 12px', marginBottom: 16, fontSize: 12, color: '#c62828' }}>
          {error}
        </div>
      )}

      <TokenList tokens={tokens} onRevoke={handleRevoke} onRefresh={handleRefresh} />

      <CreateTokenDialog open={dialogOpen} onClose={() => setDialogOpen(false)} onCreated={fetchTokens} />
    </AppLayout>
  )
}
```

- [ ] **Step 3: Commit**

```bash
git add -A token_manager/frontend/
git commit -m "feat(frontend-v2): add My Tokens page with token list and create dialog"
```

---

### Task 8: Stats cards component + Dashboard page

**Files:**
- Create: `token_manager/frontend/components/stats-cards.tsx`
- Create: `token_manager/frontend/app/dashboard/page.tsx`

- [ ] **Step 1: Create stats cards component**

Write `token_manager/frontend/components/stats-cards.tsx`:
```tsx
'use client'

interface StatCard {
  label: string
  value: number | string
  color?: string
}

interface StatsCardsProps {
  stats: StatCard[]
}

export default function StatsCards({ stats }: StatsCardsProps) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: `repeat(${Math.min(stats.length, 4)}, 1fr)`, gap: 12, marginBottom: 20 }}>
      {stats.map((stat) => (
        <div key={stat.label} style={{ border: '1px solid #e8ecf0', borderRadius: 8, padding: '12px 16px' }}>
          <div style={{ fontSize: 11, textTransform: 'uppercase', fontWeight: 600, letterSpacing: 0.5, color: stat.color ?? '#95a0b4' }}>
            {stat.label}
          </div>
          <div style={{ fontSize: 24, fontWeight: 700, color: stat.color ?? '#2d3748' }}>
            {stat.value}
          </div>
        </div>
      ))}
    </div>
  )
}
```

- [ ] **Step 2: Create Dashboard page**

Write `token_manager/frontend/app/dashboard/page.tsx`:
```tsx
'use client'

import { useCallback, useEffect, useState } from 'react'
import AppLayout from '@/components/app-layout'
import StatsCards from '@/components/stats-cards'
import { apiFetch } from '@/lib/api'
import { authHeaders, getCurrentUserEmail } from '@/lib/auth'

interface AuditEntry { createdAt: string; userId: string; service?: string; action: string }

export default function DashboardPage() {
  const [tokens, setTokens] = useState<any[]>([])
  const [recentActivity, setRecentActivity] = useState<AuditEntry[]>([])

  const fetchData = useCallback(async () => {
    const user = getCurrentUserEmail()
    if (!user) return
    try {
      const t = await apiFetch<any[]>(`/tokens?user=${encodeURIComponent(user)}`, { headers: authHeaders() })
      setTokens(t)
    } catch { /* ignore */ }
    try {
      const a = await apiFetch<AuditEntry[]>(`/audit?user=${encodeURIComponent(user)}&limit=10`, { headers: authHeaders() })
      setRecentActivity(a)
    } catch { /* will work once the audit endpoint exists */ }
  }, [])

  useEffect(() => { fetchData() }, [fetchData])

  const active = tokens.filter((t) => t.status === 'ACTIVE').length
  const expiring = tokens.filter((t) => {
    if (t.status !== 'ACTIVE') return false
    return (new Date(t.expires_at).getTime() - Date.now()) < 15 * 60 * 1000
  }).length
  const umbrella = tokens.filter((t) => t.type === 'umbrella').length

  return (
    <AppLayout>
      <h1 style={{ fontSize: 20, fontWeight: 700, marginBottom: 4 }}>Dashboard</h1>
      <p style={{ fontSize: 13, color: '#95a0b4', marginBottom: 20 }}>Your token overview</p>

      <StatsCards stats={[
        { label: 'Active Tokens', value: active, color: '#2e7d32' },
        { label: 'Expiring Soon', value: expiring, color: '#e65100' },
        { label: 'Umbrella Tokens', value: umbrella, color: '#1565c0' },
        { label: 'Last Activity', value: recentActivity[0] ? new Date(recentActivity[0].createdAt).toLocaleDateString() : '—' },
      ]} />

      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Recent Activity</h2>
      {recentActivity.length === 0 ? (
        <p style={{ color: '#95a0b4', fontSize: 13 }}>No recent activity.</p>
      ) : (
        <div style={{ border: '1px solid #e8ecf0', borderRadius: 8, overflow: 'hidden' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead style={{ background: '#f7f8fa' }}>
              <tr>
                <th style={{ padding: '8px 16px', textAlign: 'left', fontSize: 10, textTransform: 'uppercase', color: '#95a0b4', fontWeight: 600 }}>Time</th>
                <th style={{ padding: '8px 16px', textAlign: 'left', fontSize: 10, textTransform: 'uppercase', color: '#95a0b4', fontWeight: 600 }}>Service</th>
                <th style={{ padding: '8px 16px', textAlign: 'left', fontSize: 10, textTransform: 'uppercase', color: '#95a0b4', fontWeight: 600 }}>Action</th>
              </tr>
            </thead>
            <tbody>
              {recentActivity.map((entry, i) => (
                <tr key={i} style={{ borderTop: '1px solid #f0f0f0' }}>
                  <td style={{ padding: '8px 16px', color: '#95a0b4' }}>{new Date(entry.createdAt).toLocaleString()}</td>
                  <td style={{ padding: '8px 16px' }}>{entry.service ?? '—'}</td>
                  <td style={{ padding: '8px 16px' }}>
                    <span style={{ background: '#f0f0f0', padding: '2px 8px', borderRadius: 10, fontSize: 11 }}>{entry.action}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </AppLayout>
  )
}
```

- [ ] **Step 3: Commit**

```bash
git add token_manager/frontend/components/stats-cards.tsx token_manager/frontend/app/dashboard/
git commit -m "feat(frontend-v2): add Dashboard page with stats cards and recent activity"
```

---

### Task 9: Audit Log page

**Files:**
- Create: `token_manager/frontend/components/audit-table.tsx`
- Create: `token_manager/frontend/app/audit/page.tsx`

- [ ] **Step 1: Create audit table component**

Write `token_manager/frontend/components/audit-table.tsx`:
```tsx
'use client'

interface AuditEntry {
  createdAt: string
  userId: string
  service?: string
  action: string
  ip?: string
}

interface AuditTableProps {
  entries: AuditEntry[]
}

export default function AuditTable({ entries }: AuditTableProps) {
  if (entries.length === 0) {
    return (
      <div style={{ textAlign: 'center', padding: 32, color: '#95a0b4', fontSize: 14, border: '1px solid #e8ecf0', borderRadius: 8 }}>
        No audit logs found.
      </div>
    )
  }

  const headerStyle: React.CSSProperties = {
    padding: '8px 16px', textAlign: 'left', fontSize: 10, textTransform: 'uppercase',
    color: '#95a0b4', fontWeight: 600, letterSpacing: 0.5,
  }

  return (
    <div style={{ border: '1px solid #e8ecf0', borderRadius: 8, overflow: 'hidden' }}>
      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
        <thead style={{ background: '#f7f8fa' }}>
          <tr>
            <th style={headerStyle}>Time</th>
            <th style={headerStyle}>Service</th>
            <th style={headerStyle}>Action</th>
            <th style={headerStyle}>IP</th>
          </tr>
        </thead>
        <tbody>
          {entries.map((entry, i) => (
            <tr key={i} style={{ borderTop: '1px solid #f0f0f0' }}>
              <td style={{ padding: '8px 16px', color: '#95a0b4', whiteSpace: 'nowrap' }}>
                {new Date(entry.createdAt).toLocaleString()}
              </td>
              <td style={{ padding: '8px 16px', fontFamily: 'monospace' }}>{entry.service ?? '—'}</td>
              <td style={{ padding: '8px 16px' }}>
                <span style={{ background: '#f0f0f0', padding: '2px 8px', borderRadius: 10, fontSize: 11 }}>{entry.action}</span>
              </td>
              <td style={{ padding: '8px 16px', color: '#95a0b4', fontSize: 12 }}>{entry.ip ?? '—'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
```

- [ ] **Step 2: Create Audit page**

Write `token_manager/frontend/app/audit/page.tsx`:
```tsx
'use client'

import { useCallback, useEffect, useState } from 'react'
import AppLayout from '@/components/app-layout'
import AuditTable from '@/components/audit-table'
import { apiFetch } from '@/lib/api'
import { authHeaders, getCurrentUserEmail } from '@/lib/auth'

export default function AuditPage() {
  const [logs, setLogs] = useState<any[]>([])
  const [error, setError] = useState<string | null>(null)

  const fetchLogs = useCallback(async () => {
    const user = getCurrentUserEmail()
    if (!user) return
    try {
      const data = await apiFetch<any[]>(`/audit?user=${encodeURIComponent(user)}`, { headers: authHeaders() })
      setLogs(data)
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load audit logs')
    }
  }, [])

  useEffect(() => { fetchLogs() }, [fetchLogs])

  return (
    <AppLayout>
      <h1 style={{ fontSize: 20, fontWeight: 700, marginBottom: 4 }}>Audit Log</h1>
      <p style={{ fontSize: 13, color: '#95a0b4', marginBottom: 20 }}>Your token actions</p>

      {error && (
        <div style={{ background: '#ffebee', border: '1px solid #ef9a9a', borderRadius: 8, padding: '8px 12px', marginBottom: 16, fontSize: 12, color: '#c62828' }}>
          {error}
        </div>
      )}

      <AuditTable entries={logs} />
    </AppLayout>
  )
}
```

- [ ] **Step 3: Commit**

```bash
git add token_manager/frontend/components/audit-table.tsx token_manager/frontend/app/audit/
git commit -m "feat(frontend-v2): add Audit Log page with table component"
```

---

## Phase 3: Admin Pages

### Task 10: New API endpoints (user audit, admin users, bulk revoke)

**Files:**
- Modify: `token_manager/src/api/routes/tokens.ts`

- [ ] **Step 1: Add user audit endpoint and admin users endpoint**

Add these routes in `token_manager/src/api/routes/tokens.ts` inside the `tokenRoutes` function. The user audit endpoint goes in the protected scope (no admin check). The admin endpoints need the admin check.

Add BEFORE the admin routes section:

```typescript
  // GET /audit — User's own audit log (no admin required)
  app.get('/audit', async (request) => {
    const user = (request as any).user as OidcUser
    const tenant = (request as any).tenant as Tenant
    const { limit, offset } = request.query as { limit?: string; offset?: string }

    return prisma.auditLog.findMany({
      where: { tenantId: tenant.id, userId: user.email },
      orderBy: { createdAt: 'desc' },
      take: parseInt(limit ?? '50', 10),
      skip: parseInt(offset ?? '0', 10),
    })
  })
```

Add AFTER the existing admin routes:

```typescript
  // GET /admin/users — List distinct users with token counts (admin only)
  app.get('/admin/users', async (request, reply) => {
    const user = (request as any).user as OidcUser
    if (!user.isAdmin) {
      reply.code(403).send({ error: 'forbidden' })
      return
    }
    const tenant = (request as any).tenant as Tenant

    const tokens = await prisma.serviceToken.findMany({
      where: { tenantId: tenant.id },
      select: { userId: true, service: true, status: true },
    })

    const umbrellaTokens = await prisma.umbrellaToken.findMany({
      where: { tenantId: tenant.id, revokedAt: null },
      select: { userId: true },
    })

    // Aggregate by user
    const userMap = new Map<string, { active: number; expiring: number; umbrella: number }>()
    for (const t of tokens) {
      if (!userMap.has(t.userId)) userMap.set(t.userId, { active: 0, expiring: 0, umbrella: 0 })
      const u = userMap.get(t.userId)!
      if (t.status === 'ACTIVE') u.active++
    }
    for (const t of umbrellaTokens) {
      if (!userMap.has(t.userId)) userMap.set(t.userId, { active: 0, expiring: 0, umbrella: 0 })
      userMap.get(t.userId)!.umbrella++
    }

    return Array.from(userMap.entries()).map(([email, counts]) => ({
      email,
      name: email.split('@')[0],
      ...counts,
    }))
  })

  // DELETE /admin/users/bulk-revoke — Bulk revoke tokens for multiple users (admin only)
  app.delete('/admin/users/bulk-revoke', async (request, reply) => {
    const user = (request as any).user as OidcUser
    if (!user.isAdmin) {
      reply.code(403).send({ error: 'forbidden' })
      return
    }
    const tenant = (request as any).tenant as Tenant
    const { users } = request.body as { users: string[] }

    let revokedCount = 0
    for (const userId of users) {
      const tokens = await prisma.serviceToken.findMany({
        where: { tenantId: tenant.id, userId, status: 'ACTIVE' },
      })
      for (const t of tokens) {
        await prisma.serviceToken.update({ where: { id: t.id }, data: { status: 'REVOKED' } })
        revokedCount++
      }
      // Also revoke umbrella tokens
      await prisma.umbrellaToken.updateMany({
        where: { tenantId: tenant.id, userId, revokedAt: null },
        data: { revokedAt: new Date() },
      })

      await prisma.auditLog.create({
        data: { tenantId: tenant.id, userId, action: 'bulk_revoked', details: { by: user.email }, ip: request.ip },
      })
    }

    return { revoked: revokedCount, users: users.length }
  })
```

- [ ] **Step 2: Commit**

```bash
git add token_manager/src/api/routes/tokens.ts
git commit -m "feat(frontend-v2): add user audit, admin users list, and bulk revoke API endpoints"
```

---

### Task 11: Admin Users & Tokens page

**Files:**
- Create: `token_manager/frontend/components/user-accordion.tsx`
- Create: `token_manager/frontend/components/bulk-revoke-bar.tsx`
- Create: `token_manager/frontend/app/admin/users/page.tsx`

- [ ] **Step 1: Create user accordion component**

Write `token_manager/frontend/components/user-accordion.tsx`:
```tsx
'use client'

import { useState } from 'react'

interface UserTokenRow {
  service: string
  status: string
  expires_at: string
  type?: string
}

interface UserData {
  email: string
  name: string
  active: number
  umbrella: number
  tokens?: UserTokenRow[]
}

interface UserAccordionProps {
  user: UserData
  selected: boolean
  onToggleSelect: () => void
  onExpand: () => void
  expanded: boolean
  onRevokeToken: (service: string, user: string) => void
  onRefreshToken: (service: string, user: string) => void
  onRevokeAll: (user: string) => void
}

const COLORS = ['#297EF2', '#e65100', '#2e7d32', '#7b1fa2', '#c62828', '#0277bd']

export default function UserAccordion({
  user, selected, onToggleSelect, onExpand, expanded,
  onRevokeToken, onRefreshToken, onRevokeAll,
}: UserAccordionProps) {
  const initials = user.name.slice(0, 2).toUpperCase()
  const colorIndex = user.email.charCodeAt(0) % COLORS.length
  const avatarColor = COLORS[colorIndex]

  return (
    <div style={{ borderBottom: '1px solid #e8ecf0' }}>
      <div onClick={onExpand} style={{
        display: 'flex', alignItems: 'center', padding: '12px 16px',
        cursor: 'pointer', background: expanded ? '#f7f8fa' : 'transparent',
      }}>
        <input type="checkbox" checked={selected} onChange={(e) => { e.stopPropagation(); onToggleSelect() }}
          onClick={(e) => e.stopPropagation()}
          style={{ marginRight: 12, width: 16, height: 16, accentColor: '#297EF2' }} />
        <div style={{
          width: 32, height: 32, borderRadius: '50%', background: avatarColor, color: '#fff',
          display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 13, marginRight: 12,
        }}>{initials}</div>
        <div style={{ flex: 1 }}>
          <div style={{ fontWeight: 600 }}>{user.email}</div>
          <div style={{ fontSize: 11, color: '#95a0b4' }}>{user.name}</div>
        </div>
        <div style={{ display: 'flex', gap: 8, marginRight: 16 }}>
          {user.active > 0 && <span style={{ background: '#e8f5e9', color: '#2e7d32', padding: '2px 8px', borderRadius: 10, fontSize: 11, fontWeight: 600 }}>{user.active} active</span>}
          {user.umbrella > 0 && <span style={{ background: '#e3f2fd', color: '#1565c0', padding: '2px 8px', borderRadius: 10, fontSize: 11 }}>{user.umbrella} umbrella</span>}
        </div>
        <span style={{ color: expanded ? '#297EF2' : '#95a0b4', fontSize: 18 }}>{expanded ? '▾' : '▸'}</span>
      </div>

      {expanded && user.tokens && (
        <div style={{ padding: '0 16px 12px 60px', background: '#fafbfc' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12, marginTop: 8 }}>
            <thead>
              <tr style={{ color: '#95a0b4', textTransform: 'uppercase', fontSize: 10, fontWeight: 600 }}>
                <td style={{ padding: '6px 8px' }}>Service</td>
                <td>Status</td>
                <td>Expires</td>
                <td style={{ textAlign: 'right' }}>Actions</td>
              </tr>
            </thead>
            <tbody>
              {user.tokens.filter((t) => t.status !== 'REVOKED').map((t, i) => (
                <tr key={i} style={{ borderTop: '1px solid #eef0f3' }}>
                  <td style={{ padding: '8px 8px', fontWeight: 600 }}>{t.service}</td>
                  <td>
                    <span style={{
                      color: t.status === 'ACTIVE' ? '#2e7d32' : t.status === 'REFRESH_FAILED' ? '#c62828' : '#e65100',
                      fontWeight: 600,
                    }}>{t.status}</span>
                  </td>
                  <td style={{ color: '#95a0b4' }}>{new Date(t.expires_at).toLocaleString()}</td>
                  <td style={{ textAlign: 'right' }}>
                    <span onClick={() => onRefreshToken(t.service, user.email)} style={{ color: '#297EF2', cursor: 'pointer', marginRight: 6, fontSize: 11 }}>Refresh</span>
                    <span onClick={() => onRevokeToken(t.service, user.email)} style={{ color: '#e53e3e', cursor: 'pointer', fontSize: 11 }}>Revoke</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div style={{ marginTop: 8, textAlign: 'right' }}>
            <button onClick={() => onRevokeAll(user.email)} style={{
              background: 'none', border: '1px solid #e53e3e', color: '#e53e3e',
              padding: '5px 12px', borderRadius: 6, fontSize: 11, fontWeight: 600, cursor: 'pointer',
            }}>
              Revoke all tokens for this user
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 2: Create bulk revoke bar**

Write `token_manager/frontend/components/bulk-revoke-bar.tsx`:
```tsx
'use client'

interface BulkRevokeBarProps {
  selectedCount: number
  tokenCount: number
  onRevoke: () => void
  onCancel: () => void
}

export default function BulkRevokeBar({ selectedCount, tokenCount, onRevoke, onCancel }: BulkRevokeBarProps) {
  if (selectedCount === 0) return null

  return (
    <div style={{
      background: '#fef3cd', border: '1px solid #ffc107', borderRadius: 8,
      padding: '12px 16px', marginBottom: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'center',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <span style={{ fontSize: 16 }}>⚠️</span>
        <span style={{ fontWeight: 600, color: '#856404' }}>
          {selectedCount} user{selectedCount > 1 ? 's' : ''} selected — {tokenCount} active token{tokenCount !== 1 ? 's' : ''} will be revoked
        </span>
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        <button onClick={onCancel} style={{ padding: '6px 14px', border: '1px solid #d0d5dd', borderRadius: 6, background: '#fff', fontSize: 12, cursor: 'pointer' }}>Cancel</button>
        <button onClick={onRevoke} style={{ padding: '6px 14px', border: 'none', borderRadius: 6, background: '#e53e3e', color: '#fff', fontSize: 12, fontWeight: 600, cursor: 'pointer' }}>
          Revoke all tokens for {selectedCount} user{selectedCount > 1 ? 's' : ''}
        </button>
      </div>
    </div>
  )
}
```

- [ ] **Step 3: Create Admin Users page**

Write `token_manager/frontend/app/admin/users/page.tsx`:
```tsx
'use client'

import { useCallback, useEffect, useState } from 'react'
import AppLayout from '@/components/app-layout'
import StatsCards from '@/components/stats-cards'
import UserAccordion from '@/components/user-accordion'
import BulkRevokeBar from '@/components/bulk-revoke-bar'
import { apiFetch } from '@/lib/api'
import { authHeaders } from '@/lib/auth'

interface UserData {
  email: string
  name: string
  active: number
  umbrella: number
  tokens?: any[]
}

export default function AdminUsersPage() {
  const [users, setUsers] = useState<UserData[]>([])
  const [selectedUsers, setSelectedUsers] = useState<Set<string>>(new Set())
  const [expandedUser, setExpandedUser] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [error, setError] = useState<string | null>(null)

  const fetchUsers = useCallback(async () => {
    try {
      const data = await apiFetch<UserData[]>('/admin/users', { headers: authHeaders() })
      setUsers(data)
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load users')
    }
  }, [])

  useEffect(() => { fetchUsers() }, [fetchUsers])

  const handleExpand = async (email: string) => {
    if (expandedUser === email) { setExpandedUser(null); return }
    setExpandedUser(email)
    // Fetch user's tokens
    try {
      const tokens = await apiFetch<any[]>(`/admin/tokens`, { headers: authHeaders() })
      const userTokens = tokens.filter((t: any) => t.user === email)
      setUsers((prev) => prev.map((u) => u.email === email ? { ...u, tokens: userTokens } : u))
    } catch { /* ignore */ }
  }

  const toggleSelect = (email: string) => {
    setSelectedUsers((prev) => {
      const next = new Set(prev)
      if (next.has(email)) next.delete(email); else next.add(email)
      return next
    })
  }

  const handleBulkRevoke = async () => {
    try {
      await apiFetch('/admin/users/bulk-revoke', {
        method: 'DELETE',
        headers: authHeaders(),
        body: JSON.stringify({ users: Array.from(selectedUsers) }),
      })
      setSelectedUsers(new Set())
      await fetchUsers()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Bulk revoke failed')
    }
  }

  const handleRevokeToken = async (service: string, userEmail: string) => {
    try {
      await apiFetch(`/tokens/${service}?user=${encodeURIComponent(userEmail)}`, {
        method: 'DELETE', headers: authHeaders(),
      })
      await handleExpand(userEmail) // refresh
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Revoke failed')
    }
  }

  const handleRefreshToken = async (service: string, userEmail: string) => {
    try {
      await apiFetch('/tokens/refresh', {
        method: 'POST', headers: authHeaders(),
        body: JSON.stringify({ service, user: userEmail }),
      })
      await handleExpand(userEmail)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Refresh failed')
    }
  }

  const handleRevokeAll = async (userEmail: string) => {
    try {
      await apiFetch(`/tokens?user=${encodeURIComponent(userEmail)}`, {
        method: 'DELETE', headers: authHeaders(),
      })
      await fetchUsers()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Revoke all failed')
    }
  }

  const filtered = users.filter((u) => u.email.toLowerCase().includes(search.toLowerCase()))
  const totalActive = users.reduce((s, u) => s + u.active, 0)
  const totalUmbrella = users.reduce((s, u) => s + u.umbrella, 0)
  const selectedTokenCount = users.filter((u) => selectedUsers.has(u.email)).reduce((s, u) => s + u.active, 0)

  return (
    <AppLayout>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
        <div>
          <h1 style={{ fontSize: 20, fontWeight: 700, margin: 0 }}>Users & Tokens</h1>
          <p style={{ fontSize: 13, color: '#95a0b4', margin: '4px 0 0' }}>Manage tokens across all users</p>
        </div>
        <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="🔍 Search users..."
          style={{ padding: '7px 12px', border: '1px solid #d0d5dd', borderRadius: 6, fontSize: 13, width: 220 }} />
      </div>

      {error && (
        <div style={{ background: '#ffebee', border: '1px solid #ef9a9a', borderRadius: 8, padding: '8px 12px', marginBottom: 16, fontSize: 12, color: '#c62828' }}>
          {error}
        </div>
      )}

      <StatsCards stats={[
        { label: 'Users', value: users.length },
        { label: 'Active Tokens', value: totalActive, color: '#2e7d32' },
        { label: 'Umbrella Tokens', value: totalUmbrella, color: '#1565c0' },
      ]} />

      <BulkRevokeBar selectedCount={selectedUsers.size} tokenCount={selectedTokenCount}
        onRevoke={handleBulkRevoke} onCancel={() => setSelectedUsers(new Set())} />

      <div style={{ border: '1px solid #e8ecf0', borderRadius: 8, overflow: 'hidden' }}>
        {filtered.map((user) => (
          <UserAccordion key={user.email} user={user}
            selected={selectedUsers.has(user.email)}
            onToggleSelect={() => toggleSelect(user.email)}
            onExpand={() => handleExpand(user.email)}
            expanded={expandedUser === user.email}
            onRevokeToken={handleRevokeToken}
            onRefreshToken={handleRefreshToken}
            onRevokeAll={handleRevokeAll} />
        ))}
        {filtered.length === 0 && (
          <div style={{ textAlign: 'center', padding: 32, color: '#95a0b4', fontSize: 14 }}>
            No users found.
          </div>
        )}
      </div>
    </AppLayout>
  )
}
```

- [ ] **Step 4: Commit**

```bash
git add token_manager/frontend/components/user-accordion.tsx token_manager/frontend/components/bulk-revoke-bar.tsx token_manager/frontend/app/admin/
git commit -m "feat(frontend-v2): add Admin Users & Tokens page with accordion and bulk revoke"
```

---

### Task 12: Admin Configuration page

**Files:**
- Create: `token_manager/frontend/app/admin/config/page.tsx`

- [ ] **Step 1: Create admin config page**

Write `token_manager/frontend/app/admin/config/page.tsx`:
```tsx
'use client'

import { useCallback, useEffect, useState } from 'react'
import AppLayout from '@/components/app-layout'
import { apiFetch } from '@/lib/api'
import { authHeaders } from '@/lib/auth'

interface ServiceConfig {
  name: string
  auto_refresh: boolean
  token_validity: string
  refresh_margin: string
}

const VALIDITY_OPTIONS = ['30m', '1h', '4h', '8h', '24h']
const MARGIN_OPTIONS = ['5m', '10m', '15m', '30m']

export default function AdminConfigPage() {
  const [services, setServices] = useState<ServiceConfig[]>([])
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const loadConfig = useCallback(async () => {
    try {
      const data = await apiFetch<Record<string, any>>('/admin/config', { headers: authHeaders() })
      const servicesObj = data.services ?? data
      const list = Object.entries(servicesObj).map(([name, cfg]: [string, any]) => ({
        name,
        auto_refresh: cfg.auto_refresh ?? false,
        token_validity: cfg.token_validity ?? '1h',
        refresh_margin: cfg.refresh_before_expiry ?? '15m',
      }))
      setServices(list)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load config')
    }
  }, [])

  useEffect(() => { loadConfig() }, [loadConfig])

  const update = (index: number, patch: Partial<ServiceConfig>) => {
    setServices((prev) => prev.map((s, i) => i === index ? { ...s, ...patch } : s))
  }

  const handleSave = async () => {
    setSaving(true); setError(null); setSaved(false)
    try {
      const body: Record<string, any> = {}
      services.forEach((s) => { body[s.name] = s })
      await apiFetch('/admin/config', {
        method: 'PUT', headers: authHeaders(),
        body: JSON.stringify(body),
      })
      setSaved(true)
      setTimeout(() => setSaved(false), 3000)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Save failed')
    } finally {
      setSaving(false)
    }
  }

  return (
    <AppLayout>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
        <div>
          <h1 style={{ fontSize: 20, fontWeight: 700, margin: 0 }}>Configuration</h1>
          <p style={{ fontSize: 13, color: '#95a0b4', margin: '4px 0 0' }}>Auto-refresh settings per service</p>
        </div>
        <button onClick={handleSave} disabled={saving} style={{
          background: '#297EF2', color: '#fff', border: 'none', padding: '8px 16px',
          borderRadius: 6, fontWeight: 600, fontSize: 13, cursor: 'pointer', opacity: saving ? 0.6 : 1,
        }}>
          {saving ? 'Saving...' : 'Save'}
        </button>
      </div>

      {error && <div style={{ background: '#ffebee', border: '1px solid #ef9a9a', borderRadius: 8, padding: '8px 12px', marginBottom: 16, fontSize: 12, color: '#c62828' }}>{error}</div>}
      {saved && <div style={{ background: '#e8f5e9', border: '1px solid #a5d6a7', borderRadius: 8, padding: '8px 12px', marginBottom: 16, fontSize: 12, color: '#2e7d32' }}>Configuration saved.</div>}

      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        {services.map((svc, i) => (
          <div key={svc.name} style={{ border: '1px solid #e8ecf0', borderRadius: 8, padding: 16 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <span style={{ fontWeight: 600, fontFamily: 'monospace' }}>{svc.name}</span>
              <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, cursor: 'pointer' }}>
                <input type="checkbox" checked={svc.auto_refresh} onChange={(e) => update(i, { auto_refresh: e.target.checked })}
                  style={{ width: 16, height: 16, accentColor: '#297EF2' }} />
                Auto refresh
              </label>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <div style={{ fontSize: 11, color: '#95a0b4', marginBottom: 4 }}>Token validity</div>
                <select value={svc.token_validity} onChange={(e) => update(i, { token_validity: e.target.value })}
                  style={{ width: '100%', padding: '6px 10px', border: '1px solid #d0d5dd', borderRadius: 6, fontSize: 13 }}>
                  {VALIDITY_OPTIONS.map((v) => <option key={v} value={v}>{v}</option>)}
                </select>
              </div>
              <div>
                <div style={{ fontSize: 11, color: '#95a0b4', marginBottom: 4 }}>Refresh margin</div>
                <select value={svc.refresh_margin} onChange={(e) => update(i, { refresh_margin: e.target.value })}
                  style={{ width: '100%', padding: '6px 10px', border: '1px solid #d0d5dd', borderRadius: 6, fontSize: 13 }}>
                  {MARGIN_OPTIONS.map((v) => <option key={v} value={v}>{v}</option>)}
                </select>
              </div>
            </div>
          </div>
        ))}
      </div>
    </AppLayout>
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add token_manager/frontend/app/admin/config/
git commit -m "feat(frontend-v2): add Admin Configuration page"
```

---

## Phase 4: Auth & Docker

### Task 13: OIDC callback page + LemonLDAP client registration

**Files:**
- Create: `token_manager/frontend/app/auth/callback/page.tsx`
- Modify: `twake_auth/config/lmConf-1.json` (add token-manager OIDC client)

- [ ] **Step 1: Create OIDC callback page**

Write `token_manager/frontend/app/auth/callback/page.tsx`:
```tsx
'use client'

import { useEffect, useState } from 'react'
import { setOidcToken } from '@/lib/auth'

const OIDC_ISSUER = process.env.NEXT_PUBLIC_OIDC_ISSUER ?? 'https://auth.twake.local'
const CLIENT_ID = process.env.NEXT_PUBLIC_OIDC_CLIENT_ID ?? 'token-manager'
const REDIRECT_URI = process.env.NEXT_PUBLIC_OIDC_REDIRECT_URI ?? 'https://token-manager.twake.local/auth/callback'

export default function AuthCallbackPage() {
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    const code = params.get('code')
    const state = params.get('state')
    const savedState = sessionStorage.getItem('oidc_state')

    if (!code) { setError('No authorization code received'); return }
    if (state !== savedState) { setError('State mismatch — possible CSRF attack'); return }

    // Exchange code for token
    fetch(`${OIDC_ISSUER}/oauth2/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        redirect_uri: REDIRECT_URI,
        client_id: CLIENT_ID,
      }),
    })
      .then((res) => res.json())
      .then((data) => {
        if (data.access_token) {
          setOidcToken(data.access_token)
          sessionStorage.removeItem('oidc_state')
          window.location.href = '/tokens'
        } else {
          setError(data.error_description ?? data.error ?? 'Token exchange failed')
        }
      })
      .catch((err) => setError(err.message))
  }, [])

  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100vh', fontFamily: 'system-ui' }}>
      {error ? (
        <div style={{ textAlign: 'center' }}>
          <h2>Authentication Error</h2>
          <p style={{ color: '#e53e3e' }}>{error}</p>
          <a href="/tokens" style={{ color: '#297EF2' }}>Return to Token Manager</a>
        </div>
      ) : (
        <p>Authenticating...</p>
      )}
    </div>
  )
}
```

- [ ] **Step 2: Add token-manager OIDC client to LemonLDAP config**

Add a new entry in the `oidcRPMetaDataOptions` section of `twake_auth/config/lmConf-1.json`. Find the section and add after the last entry (before the closing `}`):

```json
      "tokenmanager" : {
         "oidcRPMetaDataOptionsAccessTokenClaims" : 1,
         "oidcRPMetaDataOptionsAccessTokenJWT" : 1,
         "oidcRPMetaDataOptionsAccessTokenSignAlg" : "RS256",
         "oidcRPMetaDataOptionsAllowClientCredentialsGrant" : 0,
         "oidcRPMetaDataOptionsAllowOffline" : 0,
         "oidcRPMetaDataOptionsAllowPasswordGrant" : 1,
         "oidcRPMetaDataOptionsBypassConsent" : 1,
         "oidcRPMetaDataOptionsClientID" : "token-manager",
         "oidcRPMetaDataOptionsClientSecret" : "token-manager-secret",
         "oidcRPMetaDataOptionsIDTokenForceClaims" : 1,
         "oidcRPMetaDataOptionsIDTokenSignAlg" : "RS256",
         "oidcRPMetaDataOptionsLogoutBypassConfirm" : 1,
         "oidcRPMetaDataOptionsLogoutType" : "front",
         "oidcRPMetaDataOptionsPublic" : 1,
         "oidcRPMetaDataOptionsRedirectUris" : "https://token-manager.twake.local/auth/callback",
         "oidcRPMetaDataOptionsRefreshToken" : 0,
         "oidcRPMetaDataOptionsRequirePKCE" : 0
      }
```

Also add in `oidcRPMetaDataExportedVars`:
```json
      "tokenmanager" : {
         "email" : "mail",
         "name" : "cn",
         "preferred_username" : "uid"
      }
```

And in `oidcRPMetaDataScopeRules`:
```json
      "tokenmanager" : {}
```

- [ ] **Step 3: Commit**

```bash
git add token_manager/frontend/app/auth/ twake_auth/config/lmConf-1.json
git commit -m "feat(frontend-v2): add OIDC callback page and register token-manager client in LemonLDAP"
```

---

### Task 14: Rebuild Docker and test

**Files:**
- Modify: `token_manager/Dockerfile.frontend` (if needed for cozy-ui)

- [ ] **Step 1: Update Dockerfile.frontend for cozy-ui**

Write `token_manager/Dockerfile.frontend`:
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./
RUN npx next build

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
EXPOSE 3000
ENV PORT=3000
CMD ["node", "server.js"]
```

Note: Changed to `node:20-alpine` (same as API) for consistency and better crypto support.

- [ ] **Step 2: Rebuild and restart both containers**

```bash
cd token_manager
docker compose --env-file ../.env build
docker compose --env-file ../.env up -d
```

- [ ] **Step 3: Test in browser**

Open `https://token-manager.twake.local/tokens?dev_user=user1` and verify:
- Sidebar shows "Mon espace" and "Administration" sections
- Token list displays existing tokens with masked values
- "+ Create Token" opens the dialog
- Dashboard, Audit, Admin pages all load

- [ ] **Step 4: Commit any fixes**

```bash
git add -A token_manager/
git commit -m "fix(frontend-v2): Docker build and runtime fixes for cozy-ui frontend"
```

---

## Summary

| Phase | Tasks | What it produces |
|---|---|---|
| 1: Scaffolding | 1-4 | cozy-ui deps, auth lib, API client, layout + sidebar |
| 2: User Pages | 5-9 | My Tokens (list + create dialog), Dashboard, Audit Log |
| 3: Admin Pages | 10-12 | API endpoints, Users & Tokens (accordion + bulk revoke), Config |
| 4: Auth & Docker | 13-14 | OIDC callback, LemonLDAP client, Docker rebuild |

Total: **14 tasks**, each independently committable.
