'use client'

import { useCallback, useEffect, useState } from 'react'
import RefreshConfig, { type ServiceConfig } from '@/components/refresh-config'
import { apiFetch } from '@/lib/api'
import { authHeaders } from '@/lib/auth'

export default function ConfigPage() {
  const [services, setServices] = useState<ServiceConfig[]>([])
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const loadConfig = useCallback(async () => {
    try {
      // API returns { services: { "twake-drive": {...}, "twake-mail": {...}, ... } }
      const data = await apiFetch<Record<string, any>>('/admin/config', {
        headers: authHeaders(),
      })
      const servicesObj = data.services ?? data
      const list = Object.entries(servicesObj).map(([name, cfg]: [string, any]) => ({
        name,
        auto_refresh: cfg.auto_refresh ?? false,
        token_validity: cfg.token_validity ?? '1h',
        refresh_margin: cfg.refresh_before_expiry ?? '15m',
      }))
      setServices(list)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load config')
    }
  }, [])

  useEffect(() => {
    void loadConfig()
  }, [loadConfig])

  const handleSave = async () => {
    setSaving(true)
    setError(null)
    setSaved(false)
    try {
      await apiFetch<void>('/admin/config', {
        method: 'PUT',
        headers: authHeaders(),
        body: JSON.stringify({ services }),
      })
      setSaved(true)
      setTimeout(() => setSaved(false), 3000)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Save failed')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Configuration</h2>
          <p className="mt-1 text-sm text-gray-500">
            Manage auto-refresh settings per service
          </p>
        </div>
        <button
          onClick={handleSave}
          disabled={saving}
          className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50 transition-colors"
        >
          {saving ? 'Saving...' : 'Save'}
        </button>
      </div>

      {error && (
        <div className="mb-4 rounded-md bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {saved && (
        <div className="mb-4 rounded-md bg-green-50 border border-green-200 px-4 py-3 text-sm text-green-700">
          Configuration saved.
        </div>
      )}

      {services.length === 0 && !error ? (
        <p className="text-sm text-gray-500">Loading...</p>
      ) : (
        <RefreshConfig services={services} onChange={setServices} />
      )}
    </div>
  )
}
