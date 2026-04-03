'use client'

interface Props {
  selectedCount: number
  tokenCount: number
  onRevoke: () => void
  onCancel: () => void
}

export default function BulkRevokeBar({ selectedCount, tokenCount, onRevoke, onCancel }: Props) {
  if (selectedCount === 0) return null

  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      background: '#fff8e1', border: '1px solid #ffc107',
      borderRadius: 8, padding: '12px 16px', marginBottom: 16,
    }}>
      {/* Warning icon */}
      <span style={{ fontSize: 18, flexShrink: 0 }}>⚠️</span>

      {/* Message */}
      <div style={{ flex: 1, fontSize: 14, color: '#7a5700', fontWeight: 500 }}>
        <strong>{selectedCount}</strong> {selectedCount === 1 ? 'user' : 'users'} selected
        {' — '}
        <strong>{tokenCount}</strong> active {tokenCount === 1 ? 'token' : 'tokens'} will be revoked
      </div>

      {/* Actions */}
      <button
        onClick={onCancel}
        style={{
          background: 'none', border: '1px solid #7a5700', color: '#7a5700',
          borderRadius: 6, padding: '6px 14px', fontSize: 13, fontWeight: 600, cursor: 'pointer',
        }}
      >
        Cancel
      </button>
      <button
        onClick={onRevoke}
        style={{
          background: '#c62828', color: '#fff', border: 'none',
          borderRadius: 6, padding: '6px 14px', fontSize: 13, fontWeight: 600, cursor: 'pointer',
        }}
      >
        Revoke
      </button>
    </div>
  )
}
