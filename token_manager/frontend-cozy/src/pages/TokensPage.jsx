import { useEffect, useState } from 'react'
import TokenList from '../components/token-list'
import CreateTokenDialog from '../components/create-token-dialog'
import { apiFetch } from '../lib/api'
import { authHeaders, getCurrentUserEmail } from '../lib/auth'

export default function TokensPage() {
  const [tokens, setTokens] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [dialogOpen, setDialogOpen] = useState(false)

  const email = getCurrentUserEmail()

  async function fetchTokens() {
    setLoading(true)
    setError('')
    try {
      // Fetch service tokens
      const serviceTokens = await apiFetch(`/tokens?user=${encodeURIComponent(email)}`, {
        headers: authHeaders(),
      })

      // Fetch umbrella tokens
      let umbrellaTokens = []
      try {
        umbrellaTokens = await apiFetch(`/umbrella-tokens?user=${encodeURIComponent(email)}`, {
          headers: authHeaders(),
        })
      } catch { /* endpoint may not exist yet */ }

      // Merge: service tokens get type='service', umbrella tokens already have type='umbrella'
      const allTokens = [
        ...(serviceTokens ?? []).map((t) => ({ ...t, type: 'service' })),
        ...(umbrellaTokens ?? []),
      ]
      setTokens(allTokens)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load tokens')
      setTokens([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (email) fetchTokens()
  }, [email])

  async function handleRevoke(service, tokenId, tokenType) {
    const label = tokenType === 'umbrella' ? `umbrella token (${service})` : service
    if (!confirm(`Are you sure you want to revoke the token for ${label}? This action cannot be undone.`)) return
    try {
      if (tokenType === 'umbrella' && tokenId) {
        // Umbrella tokens are revoked by ID
        await apiFetch(`/umbrella-token/${encodeURIComponent(tokenId)}`, {
          method: 'DELETE',
          headers: authHeaders(),
        })
      } else {
        // Service tokens are revoked by service name
        await apiFetch(`/tokens/${encodeURIComponent(service)}?user=${encodeURIComponent(email)}`, {
          method: 'DELETE',
          headers: authHeaders(),
        })
      }
      await fetchTokens()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to revoke token')
    }
  }

  async function handleRefresh(service) {
    try {
      await apiFetch('/tokens/refresh', {
        method: 'POST',
        headers: { ...authHeaders(), 'Content-Type': 'application/json' },
        body: JSON.stringify({ service, user: email }),
      })
      await fetchTokens()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to refresh token')
    }
  }

  return (
    <>
      {/* Page header */}
      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 24 }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 24, fontWeight: 700, color: '#1a1a2e' }}>My Tokens</h1>
          <p style={{ margin: '6px 0 0', fontSize: 14, color: '#95a0b4' }}>
            Manage your service tokens and umbrella tokens.
          </p>
        </div>
        <button
          onClick={() => setDialogOpen(true)}
          style={{
            background: '#297EF2',
            color: '#ffffff',
            border: 'none',
            borderRadius: 7,
            padding: '10px 18px',
            fontSize: 14,
            fontWeight: 600,
            cursor: 'pointer',
            whiteSpace: 'nowrap',
          }}
        >
          + Create Token
        </button>
      </div>

      {/* Error banner */}
      {error && (
        <div style={{ marginBottom: 16, padding: '10px 14px', background: '#fee2e2', borderRadius: 6, color: '#991b1b', fontSize: 13 }}>
          {error}
        </div>
      )}

      {/* Token list */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '48px 24px', color: '#95a0b4', fontSize: 14 }}>
          Loading tokens...
        </div>
      ) : (
        <TokenList
          tokens={tokens}
          onRefresh={handleRefresh}
          onRevoke={handleRevoke}
        />
      )}

      {/* Create dialog */}
      <CreateTokenDialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        onCreated={fetchTokens}
      />
    </>
  )
}
