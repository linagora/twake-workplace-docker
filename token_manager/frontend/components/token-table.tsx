'use client'

export interface Token {
  service: string
  user: string
  status: string
  expires_at: string
  granted_by?: string
  granted_at?: string
  auto_refresh?: boolean
  instance_url?: string
}

interface TokenTableProps {
  tokens: Token[]
  onRevoke: (service: string, user: string) => void
  onRefresh: (service: string, user: string) => void
}

function statusBadge(status: string, expiresAt: string) {
  const minutesLeft = (new Date(expiresAt).getTime() - Date.now()) / 60000

  if (status === 'EXPIRED' || status === 'REFRESH_FAILED') {
    return (
      <span className="inline-flex items-center rounded-full bg-red-100 px-2.5 py-0.5 text-xs font-medium text-red-700">
        {status}
      </span>
    )
  }
  if (status === 'ACTIVE' && minutesLeft < 15) {
    return (
      <span className="inline-flex items-center rounded-full bg-orange-100 px-2.5 py-0.5 text-xs font-medium text-orange-700">
        EXPIRING SOON
      </span>
    )
  }
  return (
    <span className="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-700">
      ACTIVE
    </span>
  )
}

export default function TokenTable({ tokens, onRevoke, onRefresh }: TokenTableProps) {
  if (tokens.length === 0) {
    return (
      <div className="rounded-lg border border-gray-200 bg-white p-8 text-center text-sm text-gray-500">
        No tokens found.
      </div>
    )
  }

  return (
    <div className="overflow-hidden rounded-lg border border-gray-200 bg-white">
      <table className="min-w-full divide-y divide-gray-200 text-sm">
        <thead className="bg-gray-50">
          <tr>
            <th className="px-4 py-3 text-left font-semibold text-gray-600">User</th>
            <th className="px-4 py-3 text-left font-semibold text-gray-600">Service</th>
            <th className="px-4 py-3 text-left font-semibold text-gray-600">Status</th>
            <th className="px-4 py-3 text-left font-semibold text-gray-600">Expires</th>
            <th className="px-4 py-3 text-right font-semibold text-gray-600">Actions</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-100">
          {tokens.map((token) => (
            <tr key={`${token.service}:${token.user}`} className="hover:bg-gray-50">
              <td className="px-4 py-3 text-gray-700">{token.user}</td>
              <td className="px-4 py-3 font-mono text-gray-700">{token.service}</td>
              <td className="px-4 py-3">{statusBadge(token.status, token.expires_at)}</td>
              <td className="px-4 py-3 text-gray-500">
                {new Date(token.expires_at).toLocaleString()}
              </td>
              <td className="px-4 py-3 text-right">
                <div className="flex justify-end gap-2">
                  <button
                    onClick={() => onRefresh(token.service, token.user)}
                    className="rounded px-2.5 py-1 text-xs font-medium text-indigo-600 border border-indigo-200 hover:bg-indigo-50 transition-colors"
                  >
                    Refresh
                  </button>
                  <button
                    onClick={() => onRevoke(token.service, token.user)}
                    className="rounded px-2.5 py-1 text-xs font-medium text-red-600 border border-red-200 hover:bg-red-50 transition-colors"
                  >
                    Revoke
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
