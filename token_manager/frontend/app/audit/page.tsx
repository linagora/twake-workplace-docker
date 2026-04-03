'use client'

import { useEffect, useState } from 'react'
import AppLayout from '@/components/app-layout'
import AuditTable from '@/components/audit-table'
import { apiFetch } from '@/lib/api'
import { authHeaders, getCurrentUserEmail } from '@/lib/auth'

interface AuditEntry {
  createdAt: string
  userId: string
  service?: string
  action: string
  ip?: string
}

export default function AuditPage() {
  const [entries, setEntries] = useState<AuditEntry[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const email = getCurrentUserEmail()

  useEffect(() => {
    if (!email) return
    apiFetch<AuditEntry[]>(`/audit?user=${encodeURIComponent(email)}`, { headers: authHeaders() })
      .then(data => setEntries(data ?? []))
      .catch(e => {
        // /audit endpoint may not exist yet — degrade gracefully
        if (e?.status === 404) {
          setEntries([])
        } else {
          setError(e instanceof Error ? e.message : 'Failed to load audit logs')
        }
      })
      .finally(() => setLoading(false))
  }, [email])

  return (
    <AppLayout>
      <h1 style={{ margin: '0 0 6px', fontSize: 24, fontWeight: 700, color: '#1a1a2e' }}>Audit Log</h1>
      <p style={{ margin: '0 0 24px', fontSize: 14, color: '#95a0b4' }}>
        A complete history of token operations performed on your account.
      </p>

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
    </AppLayout>
  )
}
