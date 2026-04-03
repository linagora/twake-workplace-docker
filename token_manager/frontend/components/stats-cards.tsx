'use client'

interface StatItem {
  label: string
  value: number | string
  color?: string
}

interface Props {
  stats: StatItem[]
}

export default function StatsCards({ stats }: Props) {
  return (
    <div style={{
      display: 'grid',
      gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
      gap: 16,
    }}>
      {stats.map((stat, i) => (
        <div
          key={i}
          style={{
            background: '#ffffff',
            border: '1px solid #e8ecf0',
            borderRadius: 10,
            padding: '20px 20px',
          }}
        >
          <div style={{
            fontSize: 28,
            fontWeight: 700,
            color: stat.color ?? '#297EF2',
            marginBottom: 6,
            lineHeight: 1,
          }}>
            {stat.value}
          </div>
          <div style={{ fontSize: 13, color: '#95a0b4', fontWeight: 500 }}>
            {stat.label}
          </div>
        </div>
      ))}
    </div>
  )
}
