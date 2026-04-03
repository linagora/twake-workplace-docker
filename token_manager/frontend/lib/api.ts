const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? 'https://token-manager-api.twake.local'
const API_URL = `${API_BASE}/api/v1`

export async function apiFetch<T>(path: string, options?: RequestInit): Promise<T> {
  const headers: Record<string, string> = { ...options?.headers as Record<string, string> }

  // Only set Content-Type for requests with a body
  const method = (options?.method ?? 'GET').toUpperCase()
  if (options?.body && !headers['Content-Type']) {
    headers['Content-Type'] = 'application/json'
  }

  const response = await fetch(`${API_URL}${path}`, {
    ...options,
    headers,
  })
  if (!response.ok) throw new Error(`API error: ${response.status}`)
  if (response.status === 204) return undefined as T
  return response.json() as T
}
