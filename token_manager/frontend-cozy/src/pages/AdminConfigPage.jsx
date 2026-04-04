import { useEffect, useState } from 'react'
import { apiFetch } from '../lib/api'
import { authHeaders } from '../lib/auth'

const VALIDITY_OPTIONS = [
  { label: '30 minutes', value: '30m' },
  { label: '1 hour', value: '1h' },
  { label: '4 hours', value: '4h' },
  { label: '8 hours', value: '8h' },
  { label: '24 hours', value: '24h' },
]

const MARGIN_OPTIONS = [
  { label: '5 minutes', value: '5m' },
  { label: '10 minutes', value: '10m' },
  { label: '15 minutes', value: '15m' },
  { label: '30 minutes', value: '30m' },
]

export default function AdminConfigPage() {
  const [services, setServices] = useState([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  async function fetchConfig() {
    setLoading(true)
    setError('')
    try {
      const data = await apiFetch('/admin/config', { headers: authHeaders() })
      // Handle both { services: {...} } and { data: { services: {...} } }
      const raw = data.services ?? data.data?.services ?? {}
      const parsed = Object.entries(raw).map(([name, cfg]) => ({
        name,
        auto_refresh: cfg.auto_refresh ?? false,
        token_validity: cfg.token_validity ?? '1h',
        refresh_margin: cfg.refresh_before_expiry ?? cfg.refresh_margin ?? '15m',
      }))
      setServices(parsed)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load config')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchConfig() }, [])

  function updateService(name, field, value) {
    setServices(prev => prev.map(s => s.name === name ? { ...s, [field]: value } : s))
  }

  async function handleSave() {
    setSaving(true)
    setError('')
    setSuccess('')
    try {
      const obj = {}
      for (const s of services) {
        obj[s.name] = {
          auto_refresh: s.auto_refresh,
          token_validity: s.token_validity,
          refresh_before_expiry: s.refresh_margin,
        }
      }
      await apiFetch('/admin/config', {
        method: 'PUT',
        headers: { ...authHeaders(), 'Content-Type': 'application/json' },
        body: JSON.stringify({ services: obj }),
      })
      setSuccess('Configuration saved successfully.')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save config')
    } finally {
      setSaving(false)
    }
  }

  return (
    <>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 24 }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 24, fontWeight: 700, color: '#1a1a2e' }}>Configuration</h1>
          <p style={{ margin: '6px 0 0', fontSize: 14, color: '#95a0b4' }}>
            Configure token validity and auto-refresh settings per service.
          </p>
        </div>
        <button
          onClick={handleSave}
          disabled={saving}
          style={{
            background: '#297EF2', color: '#fff', border: 'none', borderRadius: 7,
            padding: '10px 20px', fontSize: 14, fontWeight: 600, cursor: saving ? 'default' : 'pointer',
            opacity: saving ? 0.7 : 1,
          }}
        >
          {saving ? 'Saving...' : 'Save'}
        </button>
      </div>

      {/* Feedback */}
      {error && (
        <div style={{ marginBottom: 16, padding: '10px 14px', background: '#fee2e2', borderRadius: 6, color: '#991b1b', fontSize: 13 }}>
          {error}
        </div>
      )}
      {success && (
        <div style={{ marginBottom: 16, padding: '10px 14px', background: '#e8f5e9', borderRadius: 6, color: '#1b5e20', fontSize: 13 }}>
          {success}
        </div>
      )}

      {/* Service cards */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '48px 24px', color: '#95a0b4', fontSize: 14 }}>
          Loading configuration...
        </div>
      ) : services.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '48px 24px', color: '#95a0b4', fontSize: 14 }}>
          No services configured.
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {services.map(s => (
            <div key={s.name} style={{ background: '#fff', border: '1px solid #e8ecf0', borderRadius: 10, padding: '20px 24px' }}>
              {/* Service name */}
              <div style={{ fontSize: 15, fontWeight: 700, fontFamily: 'monospace', color: '#1a1a2e', marginBottom: 16 }}>
                {s.name}
              </div>

              <div style={{ display: 'flex', gap: 24, flexWrap: 'wrap', alignItems: 'center' }}>
                {/* Auto-refresh toggle */}
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: 14, color: '#333' }}>
                  <input
                    type="checkbox"
                    checked={s.auto_refresh}
                    onChange={e => updateService(s.name, 'auto_refresh', e.target.checked)}
                    style={{ width: 16, height: 16, accentColor: '#297EF2', cursor: 'pointer' }}
                  />
                  Auto-refresh
                </label>

                {/* Token validity */}
                <label style={{ display: 'flex', flexDirection: 'column', gap: 4, fontSize: 13 }}>
                  <span style={{ color: '#95a0b4', fontWeight: 600 }}>Token Validity</span>
                  <select
                    value={s.token_validity}
                    onChange={e => updateService(s.name, 'token_validity', e.target.value)}
                    style={{ border: '1px solid #e8ecf0', borderRadius: 6, padding: '6px 10px', fontSize: 13, color: '#1a1a2e', background: '#fff', cursor: 'pointer' }}
                  >
                    {VALIDITY_OPTIONS.map(o => (
                      <option key={o.value} value={o.value}>{o.label}</option>
                    ))}
                  </select>
                </label>

                {/* Refresh margin */}
                <label style={{ display: 'flex', flexDirection: 'column', gap: 4, fontSize: 13 }}>
                  <span style={{ color: '#95a0b4', fontWeight: 600 }}>Refresh Margin</span>
                  <select
                    value={s.refresh_margin}
                    onChange={e => updateService(s.name, 'refresh_margin', e.target.value)}
                    style={{ border: '1px solid #e8ecf0', borderRadius: 6, padding: '6px 10px', fontSize: 13, color: '#1a1a2e', background: '#fff', cursor: 'pointer' }}
                  >
                    {MARGIN_OPTIONS.map(o => (
                      <option key={o.value} value={o.value}>{o.label}</option>
                    ))}
                  </select>
                </label>
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  )
}
