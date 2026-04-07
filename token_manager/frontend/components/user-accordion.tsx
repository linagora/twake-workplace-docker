'use client'

import { useState } from 'react'

const AVATAR_COLORS = ['#297EF2', '#e65100', '#2e7d32', '#7b1fa2', '#c62828', '#0277bd']

function avatarColor(email: string): string {
  const code = email.charCodeAt(0) + email.charCodeAt(email.length - 1)
  return AVATAR_COLORS[code % AVATAR_COLORS.length]
}

function initials(name: string): string {
  const parts = name.split(/[\s@._-]+/).filter(Boolean)
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase()
  return name.slice(0, 2).toUpperCase()
}

export interface UserData {
  email: string
  name: string
  active: number
  umbrella: number
}

export interface TokenData {
  service: string
  status: string
  expires_at: string
  user?: string
  type?: string
  name?: string
  scopes?: string[]
  id?: string
}

interface Props {
  user: UserData
  tokens: TokenData[]
  selected: boolean
  expanded: boolean
  onToggleSelect: () => void
  onExpand: () => void
  onRevokeToken: (service: string, email: string) => void
  onRefreshToken: (service: string, email: string) => void
  onRevokeAll: (email: string) => void
}

export default function UserAccordion({
  user, tokens, selected, expanded,
  onToggleSelect, onExpand, onRevokeToken, onRefreshToken, onRevokeAll,
}: Props) {
  const [hovered, setHovered] = useState(false)
  const color = avatarColor(user.email)
  const userTokens = tokens.filter(t => t.status !== 'REVOKED')

  return (
    <div style={{
      border: '1px solid #e8ecf0',
      borderRadius: 10,
      marginBottom: 8,
      overflow: 'hidden',
      background: selected ? '#eef3fd' : hovered ? '#f8f9fc' : '#ffffff',
      transition: 'background 0.15s',
    }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      {/* Header row */}
      <div style={{ display: 'flex', alignItems: 'center', padding: '12px 16px', gap: 12, cursor: 'pointer' }}>
        {/* Checkbox */}
        <input
          type="checkbox"
          checked={selected}
          onChange={onToggleSelect}
          onClick={e => e.stopPropagation()}
          style={{ width: 16, height: 16, cursor: 'pointer', accentColor: '#297EF2' }}
        />

        {/* Avatar */}
        <div onClick={onExpand} style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 36, height: 36, borderRadius: '50%',
            background: color, color: '#fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 13, fontWeight: 700, flexShrink: 0,
          }}>
            {initials(user.name || user.email)}
          </div>

          {/* Info */}
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: '#1a1a2e', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {user.name}
            </div>
            <div style={{ fontSize: 12, color: '#95a0b4', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {user.email}
            </div>
          </div>

          {/* Badges */}
          <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexShrink: 0 }}>
            <span style={{ background: '#eef3fd', color: '#297EF2', borderRadius: 20, padding: '2px 10px', fontSize: 12, fontWeight: 600 }}>
              {user.active} active
            </span>
            <span style={{ background: '#f3e5f5', color: '#7b1fa2', borderRadius: 20, padding: '2px 10px', fontSize: 12, fontWeight: 600 }}>
              {user.umbrella} umbrella
            </span>
          </div>

          {/* Expand button */}
          <button onClick={(e) => { e.stopPropagation(); onExpand() }} style={{
            background: expanded ? '#eef3fd' : '#f5f6fa',
            border: `1px solid ${expanded ? '#297EF2' : '#d0d5dd'}`,
            borderRadius: 6, padding: '4px 10px', cursor: 'pointer',
            fontSize: 12, fontWeight: 600, color: expanded ? '#297EF2' : '#666',
            display: 'flex', alignItems: 'center', gap: 4,
            transition: 'all 0.15s',
          }}>
            <span style={{ transform: expanded ? 'rotate(180deg)' : 'rotate(0)', transition: 'transform 0.2s', fontSize: 14 }}>▼</span>
            {expanded ? 'Hide' : 'Show'}
          </button>
        </div>
      </div>

      {/* Expanded section */}
      {expanded && (
        <div style={{ borderTop: '1px solid #e8ecf0', padding: '16px' }}>
          {userTokens.length === 0 ? (
            <div style={{ color: '#95a0b4', fontSize: 13, textAlign: 'center', padding: '12px 0' }}>
              No active tokens
            </div>
          ) : (
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
              <thead>
                <tr style={{ color: '#95a0b4' }}>
                  <th style={{ textAlign: 'left', padding: '4px 8px', fontWeight: 600 }}>Service</th>
                  <th style={{ textAlign: 'left', padding: '4px 8px', fontWeight: 600 }}>Type</th>
                  <th style={{ textAlign: 'left', padding: '4px 8px', fontWeight: 600 }}>Status</th>
                  <th style={{ textAlign: 'left', padding: '4px 8px', fontWeight: 600 }}>Expires</th>
                  <th style={{ textAlign: 'right', padding: '4px 8px', fontWeight: 600 }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {userTokens.map((t, i) => {
                  const isUmbrella = t.type === 'umbrella'
                  return (
                  <tr key={`${t.service}-${i}`} style={{ borderTop: '1px solid #f0f2f5' }}>
                    <td style={{ padding: '8px 8px', fontFamily: 'monospace', color: '#1a1a2e' }}>{t.name ?? t.service}</td>
                    <td style={{ padding: '8px 8px' }}>
                      <span style={{
                        background: isUmbrella ? '#dbeafe' : '#d1fae5',
                        color: isUmbrella ? '#1e40af' : '#065f46',
                        borderRadius: 20, padding: '2px 8px', fontSize: 11, fontWeight: 600,
                      }}>
                        {isUmbrella ? 'Umbrella' : 'Service'}
                      </span>
                    </td>
                    <td style={{ padding: '8px 8px' }}>
                      <span style={{
                        background: t.status === 'ACTIVE' ? '#e8f5e9' : '#fff3e0',
                        color: t.status === 'ACTIVE' ? '#2e7d32' : '#e65100',
                        borderRadius: 20, padding: '2px 8px', fontSize: 11, fontWeight: 600,
                      }}>
                        {t.status}
                      </span>
                    </td>
                    <td style={{ padding: '8px 8px', color: '#95a0b4' }}>
                      {new Date(t.expires_at).toLocaleDateString()}
                    </td>
                    <td style={{ padding: '8px 8px', textAlign: 'right' }}>
                      {!isUmbrella && (
                        <button
                          onClick={() => onRefreshToken(t.service, user.email)}
                          style={{ marginRight: 6, background: 'none', border: '1px solid #297EF2', color: '#297EF2', borderRadius: 5, padding: '3px 10px', fontSize: 12, cursor: 'pointer' }}
                        >
                          Refresh
                        </button>
                      )}
                      <button
                        onClick={() => onRevokeToken(isUmbrella ? `umbrella:${t.id}` : t.service, user.email)}
                        style={{ background: 'none', border: '1px solid #c62828', color: '#c62828', borderRadius: 5, padding: '3px 10px', fontSize: 12, cursor: 'pointer' }}
                      >
                        Revoke
                      </button>
                    </td>
                  </tr>
                  )
                })}
              </tbody>
            </table>
          )}

          {/* Revoke all button */}
          <div style={{ marginTop: 12, textAlign: 'right' }}>
            <button
              onClick={() => onRevokeAll(user.email)}
              style={{
                background: '#c62828', color: '#fff', border: 'none', borderRadius: 6,
                padding: '7px 16px', fontSize: 13, fontWeight: 600, cursor: 'pointer',
              }}
            >
              Revoke all tokens for this user
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
