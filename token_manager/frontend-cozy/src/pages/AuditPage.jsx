import { useEffect, useState } from 'react'
import AuditTable from '../components/audit-table'
import { apiFetch } from '../lib/api'
import { authHeaders, getCurrentUserEmail } from '../lib/auth'

export default function AuditPage() {
  const [entries, setEntries] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [clearing, setClearing] = useState(false)

  const email = getCurrentUserEmail()

  function fetchAudit() {
    if (!email) return
    setLoading(true)
    apiFetch(`/audit?user=${encodeURIComponent(email)}`, { headers: authHeaders() })
      .then(data => setEntries(data ?? []))
      .catch(e => {
        if (e?.status === 404) {
          setEntries([])
        } else {
          setError(e instanceof Error ? e.message : 'Failed to load audit logs')
        }
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => { fetchAudit() }, [email])

  async function handleClear() {
    if (!window.confirm('Clear your audit history?')) return
    setClearing(true)
    try {
      await apiFetch(`/audit?user=${encodeURIComponent(email)}`, { method: 'DELETE', headers: authHeaders() })
      setEntries([])
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to clear audit log')
    } finally {
      setClearing(false)
    }
  }

  return (
    <>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 20 }}>
        <div>
          <h1 style={{ margin: '0 0 6px', fontSize: 24, fontWeight: 700, color: '#1a1a2e' }}>Audit Log</h1>
          <p style={{ margin: 0, fontSize: 14, color: '#95a0b4' }}>
            A complete history of token operations performed on your account.
          </p>
        </div>
        {entries.length > 0 && (
          <button
            onClick={handleClear}
            disabled={clearing}
            style={{
              padding: '7px 14px', fontSize: 13, fontWeight: 500, borderRadius: 6,
              border: '1px solid #fca5a5', background: '#fff', color: '#dc2626',
              cursor: clearing ? 'not-allowed' : 'pointer', opacity: clearing ? 0.6 : 1,
            }}
          >
            {clearing ? 'Clearing...' : 'Clear History'}
          </button>
        )}
      </div>

      {error && (
        <div style={{ marginBottom: 16, padding: '10px 14px', background: '#fee2e2', borderRadius: 6, color: '#991b1b', fontSize: 13 }}>
          {error}
        </div>
      )}

      {loading ? (
        <div style={{ textAlign: 'center', padding: '48px 24px', color: '#95a0b4', fontSize: 14 }}>
          Loading audit logs...
        </div>
      ) : (
        <AuditTable entries={entries} />
      )}
    </>
  )
}
