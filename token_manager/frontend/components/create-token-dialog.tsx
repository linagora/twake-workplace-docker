'use client'

import { useState, useEffect } from 'react'
import { apiFetch } from '@/lib/api'
import { authHeaders, getCurrentUserEmail } from '@/lib/auth'

const SERVICES = [
  { id: 'twake-mail', label: 'TMail JMAP', endpoint: 'https://jmap.twake.local/jmap', scope: 'openid email profile', curlExample: (token: string) => `curl -sk -X POST https://jmap.twake.local/jmap \\\n  -H "Authorization: Bearer ${token}" \\\n  -H "Content-Type: application/json" \\\n  -d '{"using":["urn:ietf:params:jmap:core","urn:ietf:params:jmap:mail"],"methodCalls":[["Mailbox/get",{"accountId":"YOUR_ACCOUNT_ID","ids":null},"c1"]]}'` },
  { id: 'twake-calendar', label: 'Calendar CalDAV', endpoint: 'https://tcalendar-side-service.twake.local', scope: 'openid email profile', curlExample: (token: string) => `curl -sk -X PROPFIND https://tcalendar-side-service.twake.local/dav/principals/ \\\n  -H "Authorization: Bearer ${token}" \\\n  -H "Depth: 0"` },
  { id: 'twake-chat', label: 'Matrix Chat', endpoint: 'https://matrix.twake.local/_matrix/client/v3', scope: 'm.room.message', curlExample: (token: string) => `curl -sk https://matrix.twake.local/_matrix/client/v3/joined_rooms \\\n  -H "Authorization: Bearer ${token}"` },
  { id: 'twake-drive', label: 'Cozy Drive', endpoint: 'https://user1.twake.local/files/', scope: 'io.cozy.files', curlExample: (token: string) => `curl -sk https://user1.twake.local/files/io.cozy.files.root-dir \\\n  -H "Authorization: Bearer ${token}" \\\n  -H "Accept: application/vnd.api+json"` },
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
  scopes?: string[]        // from umbrella token creation
}

export default function CreateTokenDialog({ open, onClose, onCreated }: Props) {
  const [step, setStep] = useState<Step>('form')
  const [tokenType, setTokenType] = useState<TokenType>('service')
  const [selectedService, setSelectedService] = useState(SERVICES[0].id)
  const [selectedScopes, setSelectedScopes] = useState<string[]>([])
  const [name, setName] = useState('')
  const [loading, setLoading] = useState(false)
  const [displayTab, setDisplayTab] = useState<'token' | 'usage'>('token')
  const [jmapAccountId, setJmapAccountId] = useState('')

  // Compute JMAP accountId (SHA-256 of email) when entering display step
  useEffect(() => {
    if (step === 'display') {
      const email = getCurrentUserEmail()
      if (email && typeof crypto !== 'undefined' && crypto.subtle) {
        crypto.subtle.digest('SHA-256', new TextEncoder().encode(email))
          .then(buf => {
            const hash = Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('')
            setJmapAccountId(hash)
          })
          .catch(() => setJmapAccountId(email))
      }
    }
  }, [step])
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
    setDisplayTab('token')
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
            body: JSON.stringify({ scopes: selectedScopes, user: email, name: name || undefined }),
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
    width: 680,
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
            {/* Warning */}
            <div style={{ background: '#fffbeb', border: '1px solid #fcd34d', borderRadius: 8, padding: '10px 14px', marginBottom: 16, display: 'flex', gap: 10, alignItems: 'center' }}>
              <span style={{ fontSize: 14 }}>⚠️</span>
              <span style={{ fontSize: 13, color: '#92400e', fontWeight: 500 }}>Copy this token now. It won&apos;t be shown again.</span>
            </div>

            {/* Tabs */}
            <div style={{ display: 'flex', gap: 0, borderBottom: '2px solid #e8ecf0', marginBottom: 16 }}>
              {(['token', 'usage'] as const).map(tab => (
                <button key={tab} onClick={() => setDisplayTab(tab)} style={{
                  padding: '8px 20px', fontSize: 13, fontWeight: 600, cursor: 'pointer',
                  background: 'none', border: 'none', borderBottom: displayTab === tab ? '2px solid #297EF2' : '2px solid transparent',
                  color: displayTab === tab ? '#297EF2' : '#95a0b4', marginBottom: -2,
                }}>
                  {tab === 'token' ? '🔑 Token' : '📋 Usage'}
                </button>
              ))}
            </div>

            {displayTab === 'token' && (
              <>
                {/* Token block */}
                {result.token && (
                  <div style={{ marginBottom: 16 }}>
                    <div style={{ fontSize: 12, fontWeight: 600, color: '#475569', marginBottom: 6 }}>Your token</div>
                    <div style={{ background: '#f8fafc', border: '1px solid #e8ecf0', borderRadius: 6, padding: '10px 12px', display: 'flex', alignItems: 'flex-start', gap: 10 }}>
                      <code style={{ fontFamily: 'monospace', fontSize: 12, color: '#1a1a2e', flex: 1, wordBreak: 'break-all', lineHeight: 1.4 }}>
                        {result.token}
                      </code>
                      <button onClick={handleCopy} style={{ ...secondaryBtn, padding: '5px 12px', fontSize: 11, whiteSpace: 'nowrap', flexShrink: 0 }}>
                        {copied ? '✓ Copied' : 'Copy'}
                      </button>
                    </div>
                  </div>
                )}
                {/* Info grid */}
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '4px 16px', fontSize: 12, color: '#95a0b4' }}>
                  {result.service && <div><span style={{ fontWeight: 600, color: '#475569' }}>Service:</span> {result.service}</div>}
                  {result.expires_at && <div><span style={{ fontWeight: 600, color: '#475569' }}>Expires:</span> {new Date(result.expires_at).toLocaleDateString()}</div>}
                </div>
              </>
            )}

            {displayTab === 'usage' && (() => {
              const isUmbrella = tokenType === 'umbrella' || result.token?.startsWith('twt_')
              const svcId = result.service ?? selectedService
              const svc = SERVICES.find(s => s.id === svcId)
              const proxyBase = 'https://token-manager-api.twake.local/api/v1/proxy'
              const tkn = result.token ?? 'YOUR_TOKEN'

              // For umbrella tokens: show proxy-based curl for each scope
              // For service tokens: show direct curl
              let curlCmd: string
              if (isUmbrella) {
                const scopes = result.scopes ?? selectedScopes
                const firstScope = scopes[0] ?? 'twake-mail'
                const pathMap: Record<string, string> = {
                  'twake-mail': 'jmap',
                  'twake-calendar': 'dav/principals/',
                  'twake-chat': 'joined_rooms',
                  'twake-drive': 'files/io.cozy.files.root-dir',
                }
                const path = pathMap[firstScope] ?? ''
                curlCmd = `# Umbrella tokens must go through the Token Manager proxy\ncurl -sk ${proxyBase}/${firstScope}/${path} \\\n  -H "Authorization: Bearer ${tkn}"`
                if (scopes.length > 1) {
                  curlCmd += `\n\n# Other services available with this token:\n${scopes.slice(1).map(s => `# ${proxyBase}/${s}/...`).join('\n')}`
                }
              } else {
                curlCmd = svc?.curlExample?.(tkn).replace(/YOUR_ACCOUNT_ID/g, jmapAccountId || 'YOUR_ACCOUNT_ID') ?? ''
              }

              return (
                <>
                  {isUmbrella ? (
                    <div style={{ background: '#eff6ff', border: '1px solid #93c5fd', borderRadius: 8, padding: '10px 14px', marginBottom: 16, fontSize: 12, color: '#1e40af' }}>
                      💡 Umbrella tokens must be used via the <strong>Token Manager proxy</strong>, not directly against service APIs.
                    </div>
                  ) : (
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '6px 16px', fontSize: 12, color: '#95a0b4', marginBottom: 16 }}>
                      {svc?.endpoint && <div><span style={{ fontWeight: 600, color: '#475569' }}>Endpoint:</span><br/><code style={{ fontSize: 11 }}>{svc.endpoint}</code></div>}
                      {svc?.scope && <div><span style={{ fontWeight: 600, color: '#475569' }}>OIDC Scope:</span><br/><code style={{ fontSize: 11 }}>{svc.scope}</code></div>}
                    </div>
                  )}
                  <div>
                    <div style={{ fontSize: 12, fontWeight: 600, color: '#475569', marginBottom: 6 }}>Example curl command</div>
                    <div style={{ background: '#1e293b', borderRadius: 6, padding: '12px 14px', position: 'relative' }}>
                      <pre id="curl-example-code" style={{ margin: 0, fontSize: 11, color: '#e2e8f0', fontFamily: 'monospace', whiteSpace: 'pre-wrap', wordBreak: 'break-all', lineHeight: 1.6 }}>
{curlCmd}
                      </pre>
                      <button onClick={() => { navigator.clipboard.writeText(curlCmd) }} style={{
                        position: 'absolute', top: 8, right: 8, background: '#334155', border: '1px solid #475569',
                        color: '#e2e8f0', borderRadius: 4, padding: '3px 8px', fontSize: 11, cursor: 'pointer',
                      }}>
                        Copy
                      </button>
                    </div>
                  </div>
                </>
              )
            })()}
          </div>
          <div style={footerStyle}>
            {displayTab === 'token' ? (
              <button style={primaryBtn} onClick={handleClose}>Done — I&apos;ve copied it</button>
            ) : (
              <button style={primaryBtn} onClick={() => {
                const pre = document.getElementById('curl-example-code')
                const cmd = pre?.textContent ?? ''
                navigator.clipboard.writeText(cmd)
                setCopied(true)
                setTimeout(() => setCopied(false), 2000)
              }}>
                {copied ? '✓ Curl copied!' : 'Copy curl'}
              </button>
            )}
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
