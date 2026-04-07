import { useEffect, useState } from 'react'
import TokenList from '../components/token-list'
import CreateTokenDialog, { SERVICES, PROXY, stripComments } from '../components/create-token-dialog'
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

  const [consentToken, setConsentToken] = useState(null)
  const [consentTab, setConsentTab] = useState('token')
  const [consentCopied, setConsentCopied] = useState(false)
  const [consentCurlCopied, setConsentCurlCopied] = useState(false)
  const [jmapAccountId, setJmapAccountId] = useState('')

  useEffect(() => {
    if (email) fetchTokens()
  }, [email])

  // Compute JMAP accountId when consent token is shown
  useEffect(() => {
    if (consentToken) {
      const em = getCurrentUserEmail()
      if (em && typeof crypto !== 'undefined' && crypto.subtle) {
        crypto.subtle.digest('SHA-256', new TextEncoder().encode(em))
          .then(buf => setJmapAccountId(Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('')))
          .catch(() => setJmapAccountId('YOUR_ACCOUNT_ID'))
      }
    }
  }, [consentToken])

  // After OAuth consent redirect, fetch and display the newly created token
  useEffect(() => {
    const params = new URLSearchParams(window.location.search || window.location.hash.split('?')[1])
    const consent = params.get('consent')
    const service = params.get('service')
    if (consent === 'success' && service && email) {
      // Clean URL
      window.history.replaceState({}, '', window.location.pathname + '#/tokens')
      // Fetch the token detail (includes access_token)
      apiFetch(`/tokens/${encodeURIComponent(service)}?user=${encodeURIComponent(email)}`, { headers: authHeaders() })
        .then(data => setConsentToken(data))
        .catch(() => {})
    }
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
      // Remove locally first for instant UI feedback
      setTokens(prev => prev.filter(t => {
        if (tokenType === 'umbrella') return t.id !== tokenId
        return t.service !== service || t.type === 'umbrella'
      }))
      await fetchTokens()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to revoke token')
      await fetchTokens() // Refresh on error too
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

      {/* Token display after OAuth consent — 2 tabs, must copy before closing */}
      {consentToken && (() => {
        const tkn = consentToken.access_token
        const svc = consentToken.service
        const aid = jmapAccountId || 'YOUR_ACCOUNT_ID'
        const username = getCurrentUserEmail().split('@')[0]
        const svcDef = SERVICES.find(s => s.id === svc)
        const curlCmd = svcDef?.curlExample(tkn, aid, username) ?? `curl -sk ${PROXY}/${svc}/ \\\n  -H "Authorization: Bearer ${tkn}"`
        return (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ background: '#fff', borderRadius: 12, width: 680, maxWidth: '95vw', maxHeight: '90vh', overflowY: 'auto', boxShadow: '0 20px 60px rgba(0,0,0,0.2)' }}>
            <div style={{ padding: '20px 24px 16px', borderBottom: '1px solid #e8ecf0' }}>
              <span style={{ fontSize: 17, fontWeight: 700, color: '#1a1a2e' }}>Token Created — {svc}</span>
            </div>
            <div style={{ padding: '20px 24px' }}>
              {/* Warning */}
              <div style={{ background: '#fee2e2', border: '1px solid #fca5a5', borderRadius: 8, padding: '10px 14px', marginBottom: 16, fontSize: 13, color: '#991b1b', fontWeight: 600 }}>
                Copy this token now — it will NOT be shown again.
              </div>

              {/* Tabs */}
              <div style={{ display: 'flex', gap: 0, borderBottom: '2px solid #e8ecf0', marginBottom: 16 }}>
                {[{ id: 'token', label: 'Token' }, { id: 'usage', label: 'Usage' }].map(tab => (
                  <button key={tab.id} onClick={() => setConsentTab(tab.id)} style={{
                    padding: '8px 20px', fontSize: 13, fontWeight: 600, cursor: 'pointer',
                    background: 'none', border: 'none', borderBottom: consentTab === tab.id ? '2px solid #297EF2' : '2px solid transparent',
                    color: consentTab === tab.id ? '#297EF2' : '#95a0b4', marginBottom: -2,
                  }}>
                    {tab.label}
                  </button>
                ))}
              </div>

              {consentTab === 'token' && (
                <>
                  <div style={{ fontSize: 12, fontWeight: 600, color: '#475569', marginBottom: 6 }}>Your token</div>
                  <div style={{ background: '#f8fafc', border: '1px solid #e8ecf0', borderRadius: 6, padding: '10px 12px', display: 'flex', alignItems: 'flex-start', gap: 10, marginBottom: 16 }}>
                    <code style={{ fontFamily: 'monospace', fontSize: 13, color: '#1a1a2e', flex: 1, wordBreak: 'break-all', lineHeight: 1.4 }}>
                      {tkn}
                    </code>
                    <button onClick={() => { navigator.clipboard.writeText(tkn); setConsentCopied(true) }} style={{
                      background: consentCopied ? '#16a34a' : '#297EF2', color: '#fff', border: 'none', borderRadius: 6,
                      padding: '8px 16px', fontSize: 13, fontWeight: 600, cursor: 'pointer', whiteSpace: 'nowrap', flexShrink: 0,
                    }}>
                      {consentCopied ? 'Copied!' : 'Copy'}
                    </button>
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '4px 16px', fontSize: 12, color: '#95a0b4' }}>
                    <div><span style={{ fontWeight: 600, color: '#475569' }}>Service:</span> {svc}</div>
                    <div><span style={{ fontWeight: 600, color: '#475569' }}>Expires:</span> {new Date(consentToken.expires_at).toLocaleDateString()}</div>
                    <div><span style={{ fontWeight: 600, color: '#475569' }}>Instance:</span> {consentToken.instance_url}</div>
                    <div><span style={{ fontWeight: 600, color: '#475569' }}>Status:</span> {consentToken.status}</div>
                  </div>
                </>
              )}

              {consentTab === 'usage' && (
                <>
                  <div style={{ fontSize: 12, fontWeight: 600, color: '#475569', marginBottom: 6 }}>Example curl command</div>
                  <div style={{ background: '#1e293b', borderRadius: 6, padding: '12px 14px', position: 'relative' }}>
                    <pre style={{ margin: 0, fontSize: 11, color: '#e2e8f0', fontFamily: 'monospace', whiteSpace: 'pre-wrap', wordBreak: 'break-all', lineHeight: 1.6 }}>
{curlCmd}
                    </pre>
                    <button onClick={() => { navigator.clipboard.writeText(stripComments(curlCmd)); setConsentCurlCopied(true); setTimeout(() => setConsentCurlCopied(false), 2000) }} style={{
                      position: 'absolute', top: 8, right: 8, background: consentCurlCopied ? '#16a34a' : '#334155',
                      border: '1px solid #475569', color: '#e2e8f0', borderRadius: 4, padding: '4px 12px', fontSize: 12, fontWeight: 600, cursor: 'pointer',
                    }}>
                      {consentCurlCopied ? 'Curl copied!' : 'Copy curl'}
                    </button>
                  </div>
                </>
              )}
            </div>
            <div style={{ padding: '16px 24px', borderTop: '1px solid #e8ecf0', display: 'flex', justifyContent: 'flex-end' }}>
              {consentCopied ? (
                <button onClick={() => { setConsentToken(null); setConsentCopied(false); setConsentCurlCopied(false); setConsentTab('token') }} style={{
                  background: '#297EF2', color: '#fff', border: 'none', borderRadius: 6, padding: '9px 20px', fontSize: 14, fontWeight: 600, cursor: 'pointer',
                }}>
                  Done — I've copied it
                </button>
              ) : (
                <span style={{ fontSize: 13, color: '#95a0b4', fontStyle: 'italic' }}>
                  Copy the token first to close this dialog
                </span>
              )}
            </div>
          </div>
        </div>
        )
      })()}

      {/* Create dialog */}
      <CreateTokenDialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        onCreated={fetchTokens}
        existingTokens={tokens}
      />
    </>
  )
}
