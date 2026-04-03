const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? 'https://token-manager-api.twake.local'
const API_URL = `${API_BASE}/api/v1`

export class ApiError extends Error {
  status: number
  constructor(status: number, message: string) { super(message); this.status = status }
}

export async function apiFetch<T>(path: string, options?: RequestInit): Promise<T> {
  const headers: Record<string, string> = { ...options?.headers as Record<string, string> }
  if (options?.body && !headers['Content-Type']) headers['Content-Type'] = 'application/json'
  const response = await fetch(`${API_URL}${path}`, { ...options, headers })
  if (!response.ok) { const text = await response.text().catch(() => ''); throw new ApiError(response.status, `API error ${response.status}: ${text}`) }
  if (response.status === 204) return undefined as T
  return response.json() as T
}
