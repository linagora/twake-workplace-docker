import { useEffect, useState } from 'react'
import StatsCards from '../components/stats-cards'
import UserAccordion from '../components/user-accordion'
import BulkRevokeBar from '../components/bulk-revoke-bar'
import { apiFetch } from '../lib/api'
import { authHeaders } from '../lib/auth'

export default function AdminUsersPage() {
  const [users, setUsers] = useState([])
  const [allTokens, setAllTokens] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState(new Set())
  const [expanded, setExpanded] = useState(new Set())
  const [expandedTokens, setExpandedTokens] = useState({})

  async function fetchUsers() {
    setLoading(true)
    setError('')
    try {
      const data = await apiFetch('/admin/users', { headers: authHeaders() })
      setUsers(data ?? [])
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load users')
    } finally {
      setLoading(false)
    }
  }

  async function fetchAllTokens() {
    try {
      const serviceTokens = await apiFetch('/admin/tokens', { headers: authHeaders() })
      // Also fetch umbrella tokens for all users
      let umbrellaTokens = []
      try {
        // Fetch umbrella tokens from each user we know about
        const usersData = await apiFetch('/admin/users', { headers: authHeaders() })
        for (const u of usersData ?? []) {
          try {
            const ut = await apiFetch(`/umbrella-tokens?user=${encodeURIComponent(u.email)}`, { headers: authHeaders() })
            umbrellaTokens.push(...(ut ?? []).map(t => ({ ...t, user: u.email })))
          } catch { /* ignore */ }
        }
      } catch { /* ignore */ }
      setAllTokens([...(serviceTokens ?? []), ...umbrellaTokens])
    } catch { /* ignore */ }
  }

  useEffect(() => {
    fetchUsers()
    fetchAllTokens()
  }, [])

  async function handleExpand(email) {
    const next = new Set(expanded)
    if (next.has(email)) {
      next.delete(email)
    } else {
      next.add(email)
      // Filter tokens from already-fetched allTokens
      const userTokens = allTokens.filter(t => t.user === email)
      setExpandedTokens(prev => ({ ...prev, [email]: userTokens }))
    }
    setExpanded(next)
  }

  async function handleRevokeToken(serviceOrId, email) {
    if (!confirm(`Revoke this token for ${email}?`)) return
    try {
      if (serviceOrId.startsWith('umbrella:')) {
        // Umbrella token — revoke by ID
        const id = serviceOrId.slice('umbrella:'.length)
        await apiFetch(`/umbrella-token/${encodeURIComponent(id)}`, {
          method: 'DELETE',
          headers: authHeaders(),
        })
      } else {
        // Service token — revoke by service name
        await apiFetch(`/tokens/${encodeURIComponent(serviceOrId)}?user=${encodeURIComponent(email)}`, {
          method: 'DELETE',
          headers: authHeaders(),
        })
      }
      await fetchUsers()
      await fetchAllTokens()
      // Re-expand the user
      const userTokens = allTokens.filter(t => t.user === email)
      setExpandedTokens(prev => ({ ...prev, [email]: userTokens }))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to revoke token')
    }
  }

  async function handleRefreshToken(service, email) {
    try {
      await apiFetch('/tokens/refresh', {
        method: 'POST',
        headers: { ...authHeaders(), 'Content-Type': 'application/json' },
        body: JSON.stringify({ service, user: email }),
      })
      await fetchAllTokens()
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Failed to refresh token'
      if (msg.includes('502') || msg.includes('refresh_failed')) {
        setError('Token refresh failed. The stored token may have expired. The user needs to re-authorize via the consent flow.')
      } else {
        setError(msg)
      }
    }
  }

  async function handleRevokeAll(email) {
    try {
      await apiFetch(`/tokens?user=${encodeURIComponent(email)}`, {
        method: 'DELETE',
        headers: authHeaders(),
      })
      await fetchUsers()
      await fetchAllTokens()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to revoke all tokens')
    }
  }

  async function handleBulkRevoke() {
    const userList = Array.from(selected)
    try {
      await apiFetch('/admin/users/bulk-revoke', {
        method: 'DELETE',
        headers: { ...authHeaders(), 'Content-Type': 'application/json' },
        body: JSON.stringify({ users: userList }),
      })
      setSelected(new Set())
      await fetchUsers()
      await fetchAllTokens()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Bulk revoke failed')
    }
  }

  const filteredUsers = users.filter(u =>
    !search || u.email.toLowerCase().includes(search.toLowerCase())
  )

  const totalActive = users.reduce((sum, u) => sum + u.active, 0)
  const totalUmbrella = users.reduce((sum, u) => sum + u.umbrella, 0)
  const selectedActiveCount = users
    .filter(u => selected.has(u.email))
    .reduce((sum, u) => sum + u.active, 0)

  return (
    <>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 24 }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 24, fontWeight: 700, color: '#1a1a2e' }}>Users & Tokens</h1>
          <p style={{ margin: '6px 0 0', fontSize: 14, color: '#95a0b4' }}>
            Manage users and their service tokens across the tenant.
          </p>
        </div>
        {/* Search */}
        <input
          type="text"
          placeholder="Search by email..."
          value={search}
          onChange={e => setSearch(e.target.value)}
          style={{
            border: '1px solid #e8ecf0', borderRadius: 7, padding: '9px 14px',
            fontSize: 14, width: 240, outline: 'none',
          }}
        />
      </div>

      {/* Error */}
      {error && (
        <div style={{ marginBottom: 16, padding: '10px 14px', background: '#fee2e2', borderRadius: 6, color: '#991b1b', fontSize: 13 }}>
          {error}
        </div>
      )}

      {/* Stats */}
      <div style={{ marginBottom: 20 }}>
        <StatsCards stats={[
          { label: 'Total Users', value: users.length, color: '#297EF2' },
          { label: 'Active Tokens', value: totalActive, color: '#2e7d32' },
          { label: 'Umbrella Tokens', value: totalUmbrella, color: '#7b1fa2' },
        ]} />
      </div>

      {/* Bulk revoke bar */}
      <BulkRevokeBar
        selectedCount={selected.size}
        tokenCount={selectedActiveCount}
        onRevoke={handleBulkRevoke}
        onCancel={() => setSelected(new Set())}
      />

      {/* User list */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '48px 24px', color: '#95a0b4', fontSize: 14 }}>
          Loading users...
        </div>
      ) : filteredUsers.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '48px 24px', color: '#95a0b4', fontSize: 14 }}>
          {search ? 'No users match your search.' : 'No users found.'}
        </div>
      ) : (
        filteredUsers.map(user => {
          const userTokens = expandedTokens[user.email] ?? allTokens.filter(t => t.user === user.email)
          return (
            <UserAccordion
              key={user.email}
              user={user}
              tokens={userTokens}
              selected={selected.has(user.email)}
              expanded={expanded.has(user.email)}
              onToggleSelect={() => {
                const next = new Set(selected)
                if (next.has(user.email)) next.delete(user.email)
                else next.add(user.email)
                setSelected(next)
              }}
              onExpand={() => handleExpand(user.email)}
              onRevokeToken={handleRevokeToken}
              onRefreshToken={handleRefreshToken}
              onRevokeAll={handleRevokeAll}
            />
          )
        })
      )}
    </>
  )
}
