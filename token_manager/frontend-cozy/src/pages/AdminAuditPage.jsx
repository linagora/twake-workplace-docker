import { useEffect, useState } from 'react'
import { apiFetch } from '../lib/api'
import { authHeaders } from '../lib/auth'

export default function AdminAuditPage() {
  const [logs, setLogs] = useState([])
  const [userFilter, setUserFilter] = useState('')
  const [error, setError] = useState('')

  async function fetchLogs() {
    try {
      const params = userFilter ? `?user=${encodeURIComponent(userFilter)}` : ''
      const data = await apiFetch(`/admin/audit${params}`, { headers: authHeaders() })
      setLogs(data ?? [])
      setError('')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load audit logs')
    }
  }

  useEffect(() => { fetchLogs() }, [userFilter])

  const thStyle = {
    textAlign: 'left', padding: '8px 12px', fontSize: 11, fontWeight: 600,
    textTransform: 'uppercase', letterSpacing: '0.05em', color: '#95a0b4',
  }
  const tdStyle = { padding: '10px 12px', fontSize: 13 }

  return (
    <>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 20 }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 24, fontWeight: 700 }}>Global Audit Log</h1>
          <p style={{ margin: '6px 0 0', fontSize: 14, color: '#95a0b4' }}>All token actions across all users.</p>
        </div>
        <input
          value={userFilter}
          onChange={(e) => setUserFilter(e.target.value)}
          placeholder="Filter by user email..."
          style={{ padding: '7px 12px', border: '1px solid #d0d5dd', borderRadius: 6, fontSize: 13, width: 250 }}
        />
      </div>

      {error && (
        <div style={{ marginBottom: 16, padding: '10px 14px', background: '#fee2e2', borderRadius: 6, color: '#991b1b', fontSize: 13 }}>
          {error}
        </div>
      )}

      {logs.length === 0 ? (
        <div style={{ textAlign: 'center', padding: 32, color: '#95a0b4', fontSize: 14, border: '1px solid #e8ecf0', borderRadius: 8 }}>
          No audit logs found.
        </div>
      ) : (
        <div style={{ border: '1px solid #e8ecf0', borderRadius: 8, overflow: 'hidden' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead style={{ background: '#f7f8fa' }}>
              <tr>
                <th style={thStyle}>Time</th>
                <th style={thStyle}>User</th>
                <th style={thStyle}>Service</th>
                <th style={thStyle}>Action</th>
                <th style={thStyle}>IP</th>
              </tr>
            </thead>
            <tbody>
              {logs.map((log, i) => (
                <tr key={i} style={{ borderTop: '1px solid #f0f0f0' }}>
                  <td style={{ ...tdStyle, color: '#95a0b4', whiteSpace: 'nowrap' }}>
                    {new Date(log.createdAt).toLocaleString()}
                  </td>
                  <td style={{ ...tdStyle, fontWeight: 500 }}>{log.userId}</td>
                  <td style={{ ...tdStyle, fontFamily: 'monospace' }}>{log.service ?? '—'}</td>
                  <td style={tdStyle}>
                    <span style={{ background: '#f0f0f0', padding: '2px 8px', borderRadius: 10, fontSize: 11 }}>
                      {log.action}
                    </span>
                  </td>
                  <td style={{ ...tdStyle, color: '#95a0b4', fontSize: 12 }}>{log.ip ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  )
}
