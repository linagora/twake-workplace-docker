'use client'

import { useState } from 'react'
import { apiFetch } from '@/lib/api'
import { authHeaders, getCurrentUserEmail } from '@/lib/auth'

const SERVICES = [
  { id: 'twake-mail', label: 'TMail JMAP' },
  { id: 'twake-calendar', label: 'Calendar CalDAV' },
  { id: 'twake-chat', label: 'Matrix Chat' },
  { id: 'twake-drive', label: 'Cozy Drive' },
]

type Step = 'form' | 'display' | 'consent'
type TokenType = 'service' | 'umbrella'

interface Props {
  open: boolean
  onClose: () => void
  onCreated: () => void
}

interface CreateResult {
  token?: string           // normalized from access_token or umbrella_token
  access_token?: string    // from POST /tokens
  umbrella_token?: string  // from POST /umbrella-token
  service?: string
  expires_at?: string
  redirect_url?: string
  status?: string          // "consent_required" for 202
}

export default function CreateTokenDialog({ open, onClose, onCreated }: Props) {
  const [step, setStep] = useState<Step>('form')
  const [tokenType, setTokenType] = useState<TokenType>('service')
  const [selectedService, setSelectedService] = useState(SERVICES[0].id)
  const [selectedScopes, setSelectedScopes] = useState<string[]>([])
  const [name, setName] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [result, setResult] = useState<CreateResult>({})
  const [copied, setCopied] = useState(false)

  if (!open) return null

  function reset() {
    setStep('form')
    setTokenType('service')
    setSelectedService(SERVICES[0].id)
    setSelectedScopes([])
    setName('')
    setError('')
    setResult({})
    setCopied(false)
    setLoading(false)
  }

  function handleClose() {
    if (step === 'display' || step === 'consent') {
      onCreated()
    }
    reset()
    onClose()
  }

  function handleFormClose() {
    reset()
    onClose()
  }

  async function handleCreate() {
    setError('')
    setLoading(true)
    const email = getCurrentUserEmail()
    const headers = { ...authHeaders(), 'Content-Type': 'application/json' }

    try {
      if (tokenType === 'service') {
        const data = await apiFetch<CreateResult>('/tokens', {
          method: 'POST',
          headers,
          body: JSON.stringify({ service: selectedService, user: email, name: name || undefined }),
        })
        if (data.status === 'consent_required') {
          setResult(data)
          setStep('consent')
        } else {
          // Normalize: API returns access_token, we store as token
          setResult({ ...data, token: data.access_token ?? data.token })
          setStep('display')
        }
      } else {
        const resp = await fetch(
          `${process.env.NEXT_PUBLIC_API_URL ?? 'https://token-manager-api.twake.local'}/api/v1/umbrella-token`,
          {
            method: 'POST',
            headers,
            body: JSON.stringify({ services: selectedScopes, user: email, name: name || undefined }),
          }
        )
        if (resp.status === 202) {
          const data = await resp.json()
          setResult(data)
          setStep('consent')
        } else if (resp.ok) {
          const data = await resp.json()
          // Normalize: umbrella API returns umbrella_token
          setResult({ ...data, token: data.umbrella_token ?? data.token })
          setStep('display')
        } else {
          const text = await resp.text().catch(() => '')
          setError(`Error ${resp.status}: ${text}`)
        }
      }
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'An error occurred')
    } finally {
      setLoading(false)
    }
  }

  function toggleScope(id: string) {
    setSelectedScopes(prev =>
      prev.includes(id) ? prev.filter(s => s !== id) : [...prev, id]
    )
  }

  async function handleCopy() {
    if (result.token) {
      await navigator.clipboard.writeText(result.token)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    }
  }

  const overlayStyle: React.CSSProperties = {
    position: 'fixed',
    inset: 0,
    background: 'rgba(0, 0, 0, 0.5)',
    zIndex: 1000,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  }

  const dialogStyle: React.CSSProperties = {
    background: '#ffffff',
    borderRadius: 12,
    width: 520,
    maxWidth: '95vw',
    maxHeight: '90vh',
    overflowY: 'auto',
    boxShadow: '0 20px 60px rgba(0,0,0,0.2)',
  }

  const headerStyle: React.CSSProperties = {
    padding: '20px 24px 16px',
    borderBottom: '1px solid #e8ecf0',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  }

  const bodyStyle: React.CSSProperties = {
    padding: '20px 24px',
  }

  const footerStyle: React.CSSProperties = {
    padding: '16px 24px',
    borderTop: '1px solid #e8ecf0',
    display: 'flex',
    justifyContent: 'flex-end',
    gap: 10,
  }

  const primaryBtn: React.CSSProperties = {
    background: '#297EF2',
    color: '#ffffff',
    border: 'none',
    borderRadius: 6,
    padding: '9px 20px',
    fontSize: 14,
    fontWeight: 600,
    cursor: 'pointer',
  }

  const secondaryBtn: React.CSSProperties = {
    background: '#f1f5f9',
    color: '#475569',
    border: 'none',
    borderRadius: 6,
    padding: '9px 20px',
    fontSize: 14,
    fontWeight: 500,
    cursor: 'pointer',
  }

  const typeCardStyle = (active: boolean): React.CSSProperties => ({
    flex: 1,
    border: active ? '2px solid #297EF2' : '2px solid #e8ecf0',
    borderRadius: 8,
    padding: '12px 14px',
    cursor: 'pointer',
    background: active ? '#eef3fd' : '#f8fafc',
    transition: 'border-color 0.15s, background 0.15s',
  })

  // --- FORM STEP ---
  if (step === 'form') {
    return (
      <div style={overlayStyle} onClick={handleFormClose}>
        <div style={dialogStyle} onClick={e => e.stopPropagation()}>
          <div style={headerStyle}>
            <span style={{ fontSize: 17, fontWeight: 700, color: '#1a1a2e' }}>Create Token</span>
            <button onClick={handleFormClose} style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: 20, color: '#95a0b4' }}>×</button>
          </div>
          <div style={bodyStyle}>
            {/* Type toggle */}
            <div style={{ marginBottom: 20 }}>
              <div style={{ fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 8 }}>Token type</div>
              <div style={{ display: 'flex', gap: 10 }}>
                <div style={typeCardStyle(tokenType === 'service')} onClick={() => setTokenType('service')}>
                  <div style={{ fontWeight: 600, fontSize: 14, color: tokenType === 'service' ? '#297EF2' : '#1a1a2e', marginBottom: 2 }}>Service</div>
                  <div style={{ fontSize: 12, color: '#95a0b4' }}>Token for a single service</div>
                </div>
                <div style={typeCardStyle(tokenType === 'umbrella')} onClick={() => setTokenType('umbrella')}>
                  <div style={{ fontWeight: 600, fontSize: 14, color: tokenType === 'umbrella' ? '#297EF2' : '#1a1a2e', marginBottom: 2 }}>Umbrella</div>
                  <div style={{ fontSize: 12, color: '#95a0b4' }}>Token for multiple services</div>
                </div>
              </div>
            </div>

            {/* Service or scope selection */}
            {tokenType === 'service' ? (
              <div style={{ marginBottom: 20 }}>
                <label style={{ fontSize: 13, fontWeight: 600, color: '#475569', display: 'block', marginBottom: 6 }}>Service</label>
                <select
                  value={selectedService}
                  onChange={e => setSelectedService(e.target.value)}
                  style={{ width: '100%', padding: '9px 12px', border: '1px solid #e8ecf0', borderRadius: 6, fontSize: 14, color: '#1a1a2e', background: '#f8fafc' }}
                >
                  {SERVICES.map(s => <option key={s.id} value={s.id}>{s.label}</option>)}
                </select>
              </div>
            ) : (
              <div style={{ marginBottom: 20 }}>
                <div style={{ fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 8 }}>Services (select at least one)</div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                  {SERVICES.map(s => (
                    <label key={s.id} style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: 14 }}>
                      <input
                        type="checkbox"
                        checked={selectedScopes.includes(s.id)}
                        onChange={() => toggleScope(s.id)}
                        style={{ accentColor: '#297EF2' }}
                      />
                      {s.label}
                    </label>
                  ))}
                </div>
              </div>
            )}

            {/* Name input */}
            <div style={{ marginBottom: 8 }}>
              <label style={{ fontSize: 13, fontWeight: 600, color: '#475569', display: 'block', marginBottom: 6 }}>Name (optional)</label>
              <input
                type="text"
                value={name}
                onChange={e => setName(e.target.value)}
                placeholder="e.g. My laptop token"
                style={{ width: '100%', padding: '9px 12px', border: '1px solid #e8ecf0', borderRadius: 6, fontSize: 14, color: '#1a1a2e', background: '#f8fafc', boxSizing: 'border-box' }}
              />
            </div>

            {error && (
              <div style={{ marginTop: 12, padding: '10px 14px', background: '#fee2e2', borderRadius: 6, color: '#991b1b', fontSize: 13 }}>
                {error}
              </div>
            )}
          </div>
          <div style={footerStyle}>
            <button style={secondaryBtn} onClick={handleFormClose}>Cancel</button>
            <button
              style={{ ...primaryBtn, opacity: loading ? 0.7 : 1 }}
              onClick={handleCreate}
              disabled={loading || (tokenType === 'umbrella' && selectedScopes.length === 0)}
            >
              {loading ? 'Creating...' : 'Create'}
            </button>
          </div>
        </div>
      </div>
    )
  }

  // --- DISPLAY STEP ---
  if (step === 'display') {
    return (
      <div style={overlayStyle}>
        <div style={dialogStyle}>
          <div style={headerStyle}>
            <span style={{ fontSize: 17, fontWeight: 700, color: '#1a1a2e' }}>Token Created</span>
          </div>
          <div style={bodyStyle}>
            {/* Success icon */}
            <div style={{ textAlign: 'center', marginBottom: 20 }}>
              <div style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 56, height: 56, borderRadius: '50%', background: '#d1fae5', fontSize: 28 }}>
                ✓
              </div>
            </div>

            {/* Warning */}
            <div style={{ background: '#fffbeb', border: '1px solid #fcd34d', borderRadius: 8, padding: '12px 14px', marginBottom: 20, display: 'flex', gap: 10, alignItems: 'flex-start' }}>
              <span style={{ fontSize: 16 }}>⚠️</span>
              <span style={{ fontSize: 13, color: '#92400e', fontWeight: 500 }}>
                Copy this token now. It won&apos;t be shown again.
              </span>
            </div>

            {/* Token block */}
            {result.token && (
              <div style={{ marginBottom: 20 }}>
                <div style={{ fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 6 }}>Your token</div>
                <div style={{ background: '#f8fafc', border: '1px solid #e8ecf0', borderRadius: 6, padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 10 }}>
                  <code style={{ fontFamily: 'monospace', fontSize: 13, color: '#1a1a2e', flex: 1, wordBreak: 'break-all' }}>
                    {result.token}
                  </code>
                  <button
                    onClick={handleCopy}
                    style={{ ...secondaryBtn, padding: '6px 14px', fontSize: 12, whiteSpace: 'nowrap', flexShrink: 0 }}
                  >
                    {copied ? 'Copied!' : 'Copy'}
                  </button>
                </div>
              </div>
            )}

            {/* Service / expiry info */}
            <div style={{ display: 'flex', gap: 20, fontSize: 13, color: '#95a0b4' }}>
              {result.service && (
                <div><span style={{ fontWeight: 600, color: '#475569' }}>Service:</span> {result.service}</div>
              )}
              {result.expires_at && (
                <div><span style={{ fontWeight: 600, color: '#475569' }}>Expires:</span> {new Date(result.expires_at).toLocaleDateString()}</div>
              )}
            </div>
          </div>
          <div style={footerStyle}>
            <button style={primaryBtn} onClick={handleClose}>Done — I&apos;ve copied it</button>
          </div>
        </div>
      </div>
    )
  }

  // --- CONSENT STEP ---
  return (
    <div style={overlayStyle}>
      <div style={dialogStyle}>
        <div style={headerStyle}>
          <span style={{ fontSize: 17, fontWeight: 700, color: '#1a1a2e' }}>Authorization Required</span>
        </div>
        <div style={bodyStyle}>
          <div style={{ textAlign: 'center', marginBottom: 20 }}>
            <div style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 56, height: 56, borderRadius: '50%', background: '#dbeafe', fontSize: 28 }}>
              🔐
            </div>
          </div>
          <p style={{ fontSize: 14, color: '#475569', marginBottom: 20, textAlign: 'center' }}>
            This token requires authorization from an external service. Click the link below to grant access.
          </p>
          {result.redirect_url && (
            <div style={{ textAlign: 'center' }}>
              <a
                href={result.redirect_url}
                target="_blank"
                rel="noopener noreferrer"
                style={{ color: '#297EF2', fontWeight: 600, fontSize: 14 }}
              >
                Authorize access →
              </a>
            </div>
          )}
        </div>
        <div style={footerStyle}>
          <button style={secondaryBtn} onClick={handleClose}>Close</button>
        </div>
      </div>
    </div>
  )
}
