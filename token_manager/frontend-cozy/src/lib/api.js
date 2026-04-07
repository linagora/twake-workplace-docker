import { authHeaders } from './auth.js'

export const API_URL = 'https://token-manager-api.twake.local/api/v1'

export class ApiError extends Error {
  constructor(status, message) {
    super(message)
    this.status = status
    this.name = 'ApiError'
  }
}

export async function apiFetch(path, options = {}) {
  const headers = { ...authHeaders(), ...(options.headers ?? {}) }
  if (options.body && !headers['Content-Type']) headers['Content-Type'] = 'application/json'

  const response = await fetch(`${API_URL}${path}`, { ...options, headers })

  if (!response.ok) {
    let message = `API error ${response.status}`
    try {
      const text = await response.text()
      if (text) {
        try {
          const json = JSON.parse(text)
          message = json.message ?? json.error ?? text
        } catch {
          message = text
        }
      }
    } catch { /* ignore */ }
    throw new ApiError(response.status, message)
  }

  if (response.status === 204) return undefined
  return response.json()
}
