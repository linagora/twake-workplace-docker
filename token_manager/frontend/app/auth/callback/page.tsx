'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { setOidcToken } from '@/lib/auth'

const OIDC_ISSUER = process.env.NEXT_PUBLIC_OIDC_ISSUER ?? 'https://auth.twake.local'
const CLIENT_ID = process.env.NEXT_PUBLIC_OIDC_CLIENT_ID ?? 'token-manager'
const REDIRECT_URI = process.env.NEXT_PUBLIC_OIDC_REDIRECT_URI ?? 'https://token-manager.twake.local/auth/callback'

export default function AuthCallbackPage() {
  const router = useRouter()
  const [error, setError] = useState('')

  useEffect(() => {
    async function handleCallback() {
      if (typeof window === 'undefined') return

      const params = new URLSearchParams(window.location.search)
      const code = params.get('code')
      const state = params.get('state')
      const savedState = sessionStorage.getItem('oidc_state')

      if (!code) {
        setError('No authorization code received.')
        return
      }

      if (!state || state !== savedState) {
        setError('State mismatch — possible CSRF attack. Please try again.')
        return
      }

      sessionStorage.removeItem('oidc_state')

      try {
        const body = new URLSearchParams({
          grant_type: 'authorization_code',
          code,
          redirect_uri: REDIRECT_URI,
          client_id: CLIENT_ID,
        })

        const response = await fetch(`${OIDC_ISSUER}/oauth2/token`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: body.toString(),
        })

        if (!response.ok) {
          const text = await response.text().catch(() => '')
          setError(`Token exchange failed (${response.status}): ${text}`)
          return
        }

        const data = await response.json()
        setOidcToken(data.access_token)
        router.replace('/tokens')
      } catch (e: unknown) {
        setError(e instanceof Error ? e.message : 'Token exchange failed.')
      }
    }

    handleCallback()
  }, [router])

  if (error) {
    return (
      <div style={{
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
        minHeight: '100vh', fontFamily: 'system-ui, sans-serif', color: '#1a1a2e',
      }}>
        <div style={{
          maxWidth: 480, width: '100%', padding: '32px 24px',
          background: '#fff', border: '1px solid #e8ecf0', borderRadius: 12,
          textAlign: 'center',
        }}>
          <div style={{ fontSize: 32, marginBottom: 16 }}>⚠️</div>
          <h2 style={{ margin: '0 0 12px', fontSize: 20, fontWeight: 700, color: '#c62828' }}>
            Authentication Error
          </h2>
          <p style={{ margin: '0 0 20px', fontSize: 14, color: '#666', lineHeight: 1.5 }}>
            {error}
          </p>
          <a
            href="/tokens"
            style={{
              display: 'inline-block', background: '#297EF2', color: '#fff',
              borderRadius: 7, padding: '10px 20px', fontSize: 14, fontWeight: 600,
              textDecoration: 'none',
            }}
          >
            Back to Tokens
          </a>
        </div>
      </div>
    )
  }

  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      minHeight: '100vh', fontFamily: 'system-ui, sans-serif', color: '#95a0b4',
      fontSize: 15,
    }}>
      Completing authentication...
    </div>
  )
}
