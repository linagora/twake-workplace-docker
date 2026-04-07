'use client'
import { useEffect, useState } from 'react'
export type ThemeMode = 'light' | 'dark'
export function useThemeMode(): [ThemeMode, () => void] {
  const [mode, setMode] = useState<ThemeMode>('light')
  useEffect(() => { const stored = localStorage.getItem('twake_theme') as ThemeMode | null; if (stored) setMode(stored) }, [])
  const toggle = () => { const next = mode === 'light' ? 'dark' : 'light'; setMode(next); localStorage.setItem('twake_theme', next) }
  return [mode, toggle]
}
interface ThemeToggleProps { mode: ThemeMode; onToggle: () => void }
export default function ThemeToggle({ mode, onToggle }: ThemeToggleProps) {
  return (
    <button onClick={onToggle} style={{ padding: '8px 16px', borderRadius: 8, border: '1px solid #ccc', background: 'transparent', cursor: 'pointer', fontSize: 13, width: '100%' }}>
      {mode === 'light' ? '🌙 Dark mode' : '☀️ Light mode'}
    </button>
  )
}
