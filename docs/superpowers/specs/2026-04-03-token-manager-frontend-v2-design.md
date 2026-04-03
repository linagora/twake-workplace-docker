# Token Manager Frontend v2 — Design Spec

**Date**: 2026-04-03
**Status**: Approved
**Scope**: cozy-ui migration, console-style token UX, user/admin separation, SSO auth

---

## 1. Overview

Complete rewrite of the Token Manager frontend from Tailwind CSS to cozy-ui (MUI v4-based Cozy design system). Adds console-style token management (OpenAI pattern), user-scoped views, admin user management with bulk revocation, and real OIDC SSO authentication.

### Design decisions

| Decision | Choice |
|---|---|
| Design system | cozy-ui (`cozy-ui/transpiled/react/*`) |
| Theme | Light + Dark with toggle (MuiCozyTheme) |
| Navigation | Unified sidebar with sections (user + admin) |
| Token creation | Modal dialog (cozy-ui Dialog) |
| Token display | One-time strict — lost if dialog closed without copy |
| Admin user management | Accordion expandable + multi-select bulk revoke |
| Auth | SSO redirect to LemonLDAP + dev-token fallback |
| Approach | Full rewrite (not incremental migration) |

---

## 2. Dependencies

```json
{
  "cozy-ui": "latest",
  "@material-ui/core": "^4",
  "@material-ui/icons": "^4"
}
```

Remove: `tailwindcss`, `postcss`, `autoprefixer`, `tailwind.config.ts`, `postcss.config.js`, `globals.css` with Tailwind directives.

### Next.js config additions

```js
// next.config.mjs
const nextConfig = {
  output: 'standalone',
  transpilePackages: ['cozy-ui'],
}
```

### Root layout imports

```tsx
import 'cozy-ui/transpiled/react/stylesheet.css'
import 'cozy-ui/dist/cozy-ui.utils.min.css'
```

Wrap app in `<MuiCozyTheme>` provider.

---

## 3. Layout & Navigation

### Sidebar (unified, role-aware)

```
Token Manager (brand)
─────────────────────
MON ESPACE
  My Tokens          ← token list + create
  Dashboard          ← stats overview
  Audit Log          ← user's own actions
─────────────────────
ADMINISTRATION        ← visible only if isAdmin
  Users & Tokens     ← user list + accordion + bulk revoke
  Configuration      ← per-service refresh settings
─────────────────────
[🌙 Dark / ☀️ Light]  ← theme toggle at bottom
```

### cozy-ui components used

- `Layout` with `monoColumn={false}` for sidebar layout
- `Sidebar` for the aside container
- `NavigationList`, `NavigationListSection`, `NavigationListHeader` for nav items
- `Main` + `Content` for the main area

### Route structure

```
/tokens              ← My Tokens (default landing page)
/dashboard           ← Dashboard stats
/audit               ← Audit log (user's own)
/admin/users         ← Admin: Users & Tokens
/admin/config        ← Admin: Configuration
```

No `/user` or `/admin` prefix for user pages — they are the default. Admin pages live under `/admin/`.

---

## 4. My Tokens Page (`/tokens`)

The main page for users. Lists all their tokens (service + umbrella).

### Token list table

| Column | Content |
|---|---|
| Name / Service | Display name + service ID in muted text |
| Type | Badge: "Service" (green) or "Umbrella" (blue) |
| Token | Masked: `eyJhbG...WFFw` or `twt_f98a...1ffc` (first 6 + last 4 chars) |
| Status | Badge: Active (green), Expiring (orange), Failed (red) |
| Actions | "Refresh" link (service only) + "Revoke" link (both) |

### "+ Create Token" button

Opens a Dialog modal.

---

## 5. Create Token Dialog

### Step 1: Configuration form

- **Token type**: two cards — "Service" (single service) / "Umbrella" (multi-service)
- **Service selector**: dropdown of available services (`twake-mail`, `twake-calendar`, `twake-chat`, `twake-drive`). For Umbrella: multi-select checkboxes.
- **Name** (optional): text input for labeling (e.g., "ZeroInbox integration")
- **Create Token** button

### Behavior

- POST `/api/v1/tokens` for service tokens
- POST `/api/v1/umbrella-token` for umbrella tokens
- If API returns `202 consent_required`: show the `redirect_url` as a link "Complete authorization" — user clicks, completes consent in new tab, then refreshes the token list.
- If API returns `200`: proceed to Step 2.

### Step 2: One-time token display

- Success icon + "Token created" heading
- Warning banner (yellow): "Copy this token now. It won't be shown again."
- Token display area: full token in monospace `<code>`, with "Copy" button
- Service/expiry info below
- "Done — I've copied it" button to close

After closing: the token is NOT stored in frontend state. The list shows the masked version from the API.

### cozy-ui components

- `Dialog` for the modal
- `Button` for actions
- `TextField` for name input
- `Select` for service picker
- `Alert` for the warning banner

---

## 6. Dashboard Page (`/dashboard`)

User's personal overview.

### Stats cards (grid of 4)

- Active Tokens (count)
- Expiring Soon (count, tokens expiring within refresh margin)
- Umbrella Tokens (count)
- Last Activity (timestamp of most recent audit entry)

### Recent activity list

Last 10 audit log entries for the current user (from `/api/v1/admin/audit?user=...`). Shows timestamp, service, action.

### cozy-ui components

- `Card` for stats
- `Table` for recent activity

---

## 7. Audit Log Page (`/audit`)

User's own audit trail. Paginated table.

### Columns

| Column | Field |
|---|---|
| Time | `createdAt` formatted as locale string |
| Service | `service` or "—" |
| Action | `action` as badge |
| IP | `ip` |

### Filters

- Date range (optional, future enhancement)
- Service filter dropdown

### API

`GET /api/v1/admin/audit?user={currentUser}` — the API already supports user filtering.

Note: need a new non-admin endpoint `GET /api/v1/audit` that returns the current user's audit entries without requiring admin role. The existing `/admin/audit` requires `isAdmin`.

---

## 8. Admin: Users & Tokens Page (`/admin/users`)

Visible only to admins.

### Stats bar (grid of 4)

- Total users (count of distinct users)
- Active tokens (total)
- Expiring soon (total)
- Umbrella tokens (total)

### Search bar

Text input to filter users by email.

### User list with accordion

Each user row shows:
- Checkbox for multi-select
- Avatar circle (initials, colored)
- Email + display name
- Badge counts: "N active", "M umbrella"
- Expand/collapse chevron

Expanded view: table of user's tokens with columns Service, Type, Token (masked), Status, Expires, Actions (Refresh/Revoke).

"Revoke all tokens for this user" button at bottom of expanded section.

### Bulk revocation

When 1+ users are checked:
- "Revoke Selected" button in header becomes active (red)
- Clicking shows a confirmation banner: "N users selected — X active tokens will be revoked"
- "Cancel" and "Revoke all tokens for N users" buttons

### API additions needed

- `GET /api/v1/admin/users` — returns list of distinct users with token counts. New endpoint.
- `DELETE /api/v1/admin/users/bulk-revoke` — body: `{ users: ["user1@twake.local", "user2@twake.local"] }`. New endpoint.

---

## 9. Admin: Configuration Page (`/admin/config`)

Per-service refresh settings (existing functionality, now in admin section).

### Per service card

- Service name (monospace)
- Auto-refresh toggle (Switch)
- Token validity selector (Select: 30m, 1h, 4h, 8h, 24h)
- Refresh margin selector (Select: 5m, 10m, 15m, 30m)

### Save button

`PUT /api/v1/admin/config` with updated settings.

---

## 10. Authentication

### SSO flow

1. Frontend checks for OIDC token (in memory or from SSO cookie)
2. If none: redirect to `https://auth.{BASE_DOMAIN}/oauth2/authorize` with Token Manager as client
3. LemonLDAP authenticates user, redirects back with authorization code
4. Frontend exchanges code for access token via `/oauth2/token`
5. Token stored in memory (not localStorage) for security
6. Token sent as `Authorization: Bearer` to API on every request

### Dev fallback

When `NODE_ENV !== 'production'` or `NEXT_PUBLIC_DEV_AUTH=true`:
- URL param `?dev_user=user1` stores `dev-user1` token in localStorage
- Used automatically if no OIDC token present
- Dev token format: `dev-{username}` — API auth middleware recognizes and bypasses JWT validation

### LemonLDAP client registration

Need to register a new OIDC client "token-manager" in LemonLDAP config:
- `client_id`: `token-manager`
- `redirect_uri`: `https://token-manager.twake.local/auth/callback`
- `bypassConsent`: 1
- `allowPasswordGrant`: 0

### Frontend auth flow (new files)

- `/auth/callback` page — handles OIDC redirect, exchanges code, stores token, redirects to `/tokens`
- `lib/auth.ts` — `getOidcToken()`, `setOidcToken()`, `authHeaders()`, `isAuthenticated()`, `logout()`

---

## 11. Theme

### MuiCozyTheme wrapper

```tsx
import MuiCozyTheme from 'cozy-ui/transpiled/react/MuiCozyTheme'

// In root layout:
<MuiCozyTheme type={themeMode}>
  {children}
</MuiCozyTheme>
```

### Theme toggle

Stored in localStorage (`twake_theme`). Toggle button at bottom of sidebar.

- `type="light"` — default
- `type="dark"` — dark mode

---

## 12. File Structure

```
frontend/
├── app/
│   ├── layout.tsx              ← MuiCozyTheme + stylesheet imports
│   ├── page.tsx                ← redirect to /tokens
│   ├── tokens/
│   │   └── page.tsx            ← My Tokens (list + create dialog)
│   ├── dashboard/
│   │   └── page.tsx            ← Dashboard stats
│   ├── audit/
│   │   └── page.tsx            ← User audit log
│   ├── auth/
│   │   └── callback/
│   │       └── page.tsx        ← OIDC callback handler
│   └── admin/
│       ├── users/
│       │   └── page.tsx        ← Admin: Users & Tokens
│       └── config/
│           └── page.tsx        ← Admin: Configuration
├── components/
│   ├── app-layout.tsx          ← Sidebar + Layout wrapper
│   ├── token-list.tsx          ← Token table with masked values
│   ├── create-token-dialog.tsx ← Create dialog (form + one-time display)
│   ├── stats-cards.tsx         ← Reusable stats grid
│   ├── audit-table.tsx         ← Audit log table
│   ├── user-accordion.tsx      ← Admin: expandable user row
│   ├── bulk-revoke-bar.tsx     ← Admin: bulk revocation banner
│   └── theme-toggle.tsx        ← Dark/Light switch
├── lib/
│   ├── api.ts                  ← apiFetch with /api/v1 prefix
│   └── auth.ts                 ← OIDC + dev-token auth
├── next.config.mjs
└── package.json
```

---

## 13. API Changes Required

### New endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/audit` | User's own audit log (no admin required) |
| `GET` | `/api/v1/admin/users` | List distinct users with token counts |
| `DELETE` | `/api/v1/admin/users/bulk-revoke` | Bulk revoke by user list |

### Fix existing endpoints

- `GET /api/v1/admin/audit` — already returns `createdAt` / `userId` (Prisma format). Keep as-is, frontend adapts.
- `GET /api/v1/admin/tokens` — already maps to snake_case (fixed in previous sprint).
