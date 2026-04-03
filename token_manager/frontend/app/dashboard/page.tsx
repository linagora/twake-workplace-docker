'use client'

import { useEffect, useState } from 'react'
import AppLayout from '@/components/app-layout'
import StatsCards from '@/components/stats-cards'
import { TokenItem } from '@/components/token-list'
import { apiFetch } from '@/lib/api'
import { authHeaders, getCurrentUserEmail } from '@/lib/auth'

interface AuditEntry {
  createdAt: string
  userId: string
  service?: string
  action: string
  ip?: string
}

function formatTime(iso: string): string {
  try {
    return new Date(iso).toLocaleString()
  } catch {
    return iso
  }
}

export default function DashboardPage() {
  const [tokens, setTokens] = useState<TokenItem[]>([])
  const [auditEntries, setAuditEntries] = useState<AuditEntry[]>([])
  const [loadingTokens, setLoadingTokens] = useState(true)
  const [loadingAudit, setLoadingAudit] = useState(true)

  const email = getCurrentUserEmail()

  useEffect(() => {
    if (!email) return

    // Fetch tokens for stats
    apiFetch<TokenItem[]>(`/tokens?user=${encodeURIComponent(email)}`, { headers: authHeaders() })
      .then(data => setTokens(data ?? []))
      .catch(() => setTokens([]))
      .finally(() => setLoadingTokens(false))

    // Fetch audit (may not exist yet)
    apiFetch<AuditEntry[]>(`/audit?user=${encodeURIComponent(email)}&limit=10`, { headers: authHeaders() })
      .then(data => setAuditEntries(data ?? []))
      .catch(() => setAuditEntries([]))
      .finally(() => setLoadingAudit(false))
  }, [email])

  const active = tokens.filter(t => t.status?.toLowerCase() === 'active').length
  const expiring = tokens.filter(t => t.status?.toLowerCase() === 'expiring').length
  const umbrella = tokens.filter(t => t.type === 'umbrella').length
  const lastActivity = auditEntries.length > 0 ? formatTime(auditEntries[0].createdAt).split(',')[0] : '—'

  const stats = [
    { label: 'Active Tokens', value: loadingTokens ? '…' : active, color: '#059669' },
    { label: 'Expiring Soon', value: loadingTokens ? '…' : expiring, color: '#d97706' },
    { label: 'Umbrella Tokens', value: loadingTokens ? '…' : umbrella, color: '#297EF2' },
    { label: 'Last Activity', value: lastActivity, color: '#7c3aed' },
  ]

  const thStyle: React.CSSProperties = {
    padding: '10px 14px',
    textAlign: 'left',
    fontSize: 12,
    fontWeight: 600,
    color: '#95a0b4',
    borderBottom: '1px solid #e8ecf0',
    whiteSpace: 'nowrap',
  }

  const tdStyle: React.CSSProperties = {
    padding: '11px 14px',
    fontSize: 14,
    borderBottom: '1px solid #e8ecf0',
    color: '#1a1a2e',
  }

  return (
    <AppLayout>
      <h1 style={{ margin: '0 0 6px', fontSize: 24, fontWeight: 700, color: '#1a1a2e' }}>Dashboard</h1>
      <p style={{ margin: '0 0 24px', fontSize: 14, color: '#95a0b4' }}>
        Overview of your token activity.
      </p>

      <StatsCards stats={stats} />

      <div style={{ marginTop: 32 }}>
        <h2 style={{ margin: '0 0 14px', fontSize: 17, fontWeight: 700, color: '#1a1a2e' }}>Recent Activity</h2>

        {loadingAudit ? (
          <div style={{ textAlign: 'center', padding: '32px 24px', color: '#95a0b4', fontSize: 14 }}>
            Loading activity...
          </div>
        ) : auditEntries.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '32px 24px', color: '#95a0b4', fontSize: 14, border: '1px solid #e8ecf0', borderRadius: 8, background: '#ffffff' }}>
            No recent activity found.
          </div>
        ) : (
          <div style={{ overflowX: 'auto', border: '1px solid #e8ecf0', borderRadius: 8 }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', background: '#ffffff' }}>
              <thead>
                <tr>
                  <th style={thStyle}>Time</th>
                  <th style={thStyle}>Service</th>
                  <th style={thStyle}>Action</th>
                </tr>
              </thead>
              <tbody>
                {auditEntries.map((entry, i) => (
                  <tr key={i}>
                    <td style={{ ...tdStyle, color: '#95a0b4', fontSize: 13 }}>{formatTime(entry.createdAt)}</td>
                    <td style={tdStyle}>{entry.service ?? '—'}</td>
                    <td style={tdStyle}>{entry.action}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </AppLayout>
  )
}
