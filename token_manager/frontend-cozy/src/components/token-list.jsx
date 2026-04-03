const SERVICE_LABELS = {
  'twake-mail': 'TMail JMAP',
  'twake-calendar': 'Calendar CalDAV',
  'twake-chat': 'Matrix Chat',
  'twake-drive': 'Cozy Drive',
}

function maskToken(token) {
  if (token.length <= 10) return token
  return token.slice(0, 6) + '...' + token.slice(-4)
}

function getStatusColor(status) {
  switch (status?.toLowerCase()) {
    case 'active': return { bg: '#d1fae5', text: '#065f46' }
    case 'expiring': return { bg: '#fef3c7', text: '#92400e' }
    case 'failed': return { bg: '#fee2e2', text: '#991b1b' }
    default: return { bg: '#f1f5f9', text: '#475569' }
  }
}

export default function TokenList({ tokens, onRefresh, onRevoke }) {
  const visible = tokens.filter(t => t.status?.toLowerCase() !== 'revoked')

  const thStyle = {
    padding: '10px 14px',
    textAlign: 'left',
    fontSize: 12,
    fontWeight: 600,
    color: '#95a0b4',
    borderBottom: '1px solid #e8ecf0',
    whiteSpace: 'nowrap',
  }

  const tdStyle = {
    padding: '12px 14px',
    fontSize: 14,
    borderBottom: '1px solid #e8ecf0',
    verticalAlign: 'middle',
  }

  if (visible.length === 0) {
    return (
      <div style={{ textAlign: 'center', padding: '48px 24px', color: '#95a0b4', fontSize: 14 }}>
        No tokens yet.
      </div>
    )
  }

  return (
    <div style={{ overflowX: 'auto', border: '1px solid #e8ecf0', borderRadius: 8 }}>
      <table style={{ width: '100%', borderCollapse: 'collapse', background: '#ffffff' }}>
        <thead>
          <tr>
            <th style={thStyle}>Name / Service</th>
            <th style={thStyle}>Type</th>
            <th style={thStyle}>Token</th>
            <th style={thStyle}>Status</th>
            <th style={thStyle}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {visible.map((token, idx) => {
            const isService = token.type !== 'umbrella'
            const label = token.name
              ? token.name
              : isService
                ? (SERVICE_LABELS[token.service] ?? token.service)
                : (token.scopes ?? []).map(s => SERVICE_LABELS[s] ?? s).join(', ') || token.service
            const statusColors = getStatusColor(token.status)
            const displayToken = isService
              ? maskToken(token.service)
              : (token.scopes ? maskToken(token.scopes.join(',')) : '—')

            return (
              <tr key={`${token.type}-${token.id ?? token.service}-${idx}`} style={{ transition: 'background 0.1s' }}>
                <td style={tdStyle}>
                  <span style={{ fontWeight: 500, color: '#1a1a2e' }}>{label}</span>
                </td>
                <td style={tdStyle}>
                  <span style={{
                    display: 'inline-block',
                    padding: '2px 10px',
                    borderRadius: 999,
                    fontSize: 12,
                    fontWeight: 600,
                    background: isService ? '#d1fae5' : '#dbeafe',
                    color: isService ? '#065f46' : '#1e40af',
                  }}>
                    {isService ? 'Service' : 'Umbrella'}
                  </span>
                </td>
                <td style={tdStyle}>
                  <code style={{ fontFamily: 'monospace', fontSize: 13, color: '#475569', background: '#f8fafc', padding: '2px 6px', borderRadius: 4 }}>
                    {displayToken}
                  </code>
                </td>
                <td style={tdStyle}>
                  <span style={{
                    display: 'inline-block',
                    padding: '2px 10px',
                    borderRadius: 999,
                    fontSize: 12,
                    fontWeight: 600,
                    background: statusColors.bg,
                    color: statusColors.text,
                  }}>
                    {token.status ?? 'Unknown'}
                  </span>
                </td>
                <td style={tdStyle}>
                  <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                    {isService && onRefresh && (
                      <button
                        onClick={() => onRefresh(token.service)}
                        style={{
                          background: 'none',
                          border: '1px solid #297EF2',
                          color: '#297EF2',
                          borderRadius: 5,
                          padding: '3px 10px',
                          fontSize: 12,
                          cursor: 'pointer',
                        }}
                      >
                        Refresh
                      </button>
                    )}
                    <button
                      onClick={() => onRevoke(token.service, token.id, token.type)}
                      style={{
                        background: 'none',
                        border: '1px solid #c62828',
                        color: '#c62828',
                        borderRadius: 5,
                        padding: '3px 10px',
                        fontSize: 12,
                        cursor: 'pointer',
                      }}
                    >
                      Revoke
                    </button>
                  </div>
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
