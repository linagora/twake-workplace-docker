'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { isAdmin, getCurrentUserEmail } from '@/lib/auth'

interface NavItem {
  label: string
  href: string
}

const MON_ESPACE: NavItem[] = [
  { label: 'My Tokens', href: '/tokens' },
  { label: 'Dashboard', href: '/dashboard' },
  { label: 'Audit Log', href: '/audit' },
]

const ADMINISTRATION: NavItem[] = [
  { label: 'Users & Tokens', href: '/admin/users' },
  { label: 'Global Audit Log', href: '/admin/audit' },
  { label: 'Configuration', href: '/admin/config' },
]

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const admin = isAdmin()
  const email = getCurrentUserEmail()

  const isActive = (href: string) => pathname === href || pathname.startsWith(href + '/')

  const navItemStyle = (href: string): React.CSSProperties => ({
    display: 'block',
    padding: '8px 16px',
    borderRadius: 6,
    fontSize: 14,
    fontWeight: isActive(href) ? 600 : 400,
    color: isActive(href) ? '#297EF2' : '#333333',
    background: isActive(href) ? '#eef3fd' : 'transparent',
    borderLeft: isActive(href) ? '3px solid #297EF2' : '3px solid transparent',
    textDecoration: 'none',
    transition: 'background 0.15s, color 0.15s',
    cursor: 'pointer',
  })

  return (
    <div style={{ display: 'flex', height: '100vh', overflow: 'hidden', background: '#f5f6fa', fontFamily: 'system-ui, sans-serif' }}>
      <aside style={{
        width: 240, minWidth: 240, background: '#ffffff',
        borderRight: '1px solid #e5e7eb', display: 'flex', flexDirection: 'column',
      }}>
        <div style={{ padding: '24px 20px 16px', borderBottom: '1px solid #e5e7eb' }}>
          <span style={{ fontSize: 18, fontWeight: 700, color: '#297EF2', letterSpacing: '-0.3px' }}>
            Token Manager
          </span>
        </div>

        <nav style={{ flex: 1, overflowY: 'auto', padding: '16px 8px' }}>
          <div style={{ marginBottom: 8 }}>
            <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: '0.08em', color: '#999', padding: '0 16px 6px', textTransform: 'uppercase' }}>
              Mon Espace
            </div>
            {MON_ESPACE.map(item => (
              <Link key={item.href} href={item.href} style={navItemStyle(item.href)}
                onMouseEnter={e => { if (!isActive(item.href)) (e.currentTarget as HTMLElement).style.background = '#eef3fd' }}
                onMouseLeave={e => { if (!isActive(item.href)) (e.currentTarget as HTMLElement).style.background = 'transparent' }}
              >
                {item.label}
              </Link>
            ))}
          </div>

          {admin && (
            <div style={{ marginTop: 16 }}>
              <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: '0.08em', color: '#999', padding: '0 16px 6px', textTransform: 'uppercase' }}>
                Administration
              </div>
              {ADMINISTRATION.map(item => (
                <Link key={item.href} href={item.href} style={navItemStyle(item.href)}
                  onMouseEnter={e => { if (!isActive(item.href)) (e.currentTarget as HTMLElement).style.background = '#eef3fd' }}
                  onMouseLeave={e => { if (!isActive(item.href)) (e.currentTarget as HTMLElement).style.background = 'transparent' }}
                >
                  {item.label}
                </Link>
              ))}
            </div>
          )}
        </nav>

        {email && (
          <div style={{ padding: '12px 16px', borderTop: '1px solid #e5e7eb' }}>
            <div style={{ fontSize: 12, color: '#999', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} title={email}>
              {email}
            </div>
          </div>
        )}
      </aside>

      <main style={{ flex: 1, overflowY: 'auto', padding: 24, color: '#1a1a2e' }}>
        {children}
      </main>
    </div>
  )
}
