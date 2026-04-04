function formatTime(iso) {
  try {
    return new Date(iso).toLocaleString()
  } catch {
    return iso
  }
}

export default function AuditTable({ entries }) {
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
    padding: '11px 14px',
    fontSize: 14,
    borderBottom: '1px solid #e8ecf0',
    color: '#1a1a2e',
  }

  if (entries.length === 0) {
    return (
      <div style={{ textAlign: 'center', padding: '48px 24px', color: '#95a0b4', fontSize: 14, border: '1px solid #e8ecf0', borderRadius: 8, background: '#ffffff' }}>
        No audit logs found.
      </div>
    )
  }

  return (
    <div style={{ overflowX: 'auto', border: '1px solid #e8ecf0', borderRadius: 8 }}>
      <table style={{ width: '100%', borderCollapse: 'collapse', background: '#ffffff' }}>
        <thead>
          <tr>
            <th style={thStyle}>Time</th>
            <th style={thStyle}>Service</th>
            <th style={thStyle}>Action</th>
            <th style={thStyle}>IP</th>
          </tr>
        </thead>
        <tbody>
          {entries.map((entry, i) => (
            <tr key={i}>
              <td style={{ ...tdStyle, color: '#95a0b4', fontSize: 13 }}>{formatTime(entry.createdAt)}</td>
              <td style={tdStyle}>{entry.service ?? '—'}</td>
              <td style={tdStyle}>{entry.action}</td>
              <td style={{ ...tdStyle, color: '#95a0b4', fontSize: 13, fontFamily: 'monospace' }}>{entry.ip ?? '—'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
