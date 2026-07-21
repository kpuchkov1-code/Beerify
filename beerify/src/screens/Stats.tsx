import type { NightSession, Profile } from '../types'
import { BADGES, earnedBadgeIds } from '../lib/badges'
import { calculateStats } from '../lib/stats'

interface Props {
  history: NightSession[]
  profile: Profile
}

const CATEGORY_LABELS: Record<string, string> = {
  beer: 'Beer', cider: 'Cider', wine: 'Wine', spirit: 'Spirits', cocktail: 'Cocktails', shot: 'Shots', soft: 'Low / no',
}

export default function Stats({ history, profile }: Props) {
  const stats = calculateStats(history)
  const categories = Object.entries(stats.categories).sort((a, b) => b[1] - a[1])
  const earned = new Set(earnedBadgeIds(history, profile))

  return (
    <main className="screen stats-screen">
      <header className="page-header page-header--stacked"><span className="page-kicker">YOUR FORM</span><h1>Stats & badges</h1><p>Calculated from your saved nights. No duplicate scoreboard hiding behind it.</p></header>

      <section className="stats-grid" aria-label="Personal totals">
        <article><strong>{stats.nights}</strong><span>nights</span></article>
        <article><strong>{stats.drinks}</strong><span>drinks</span></article>
        <article><strong>{stats.totalUnits.toFixed(1)}</strong><span>total units</span></article>
        <article><strong>{stats.weekUnits.toFixed(1)}</strong><span>units · 7 days</span></article>
      </section>

      <section className="settings-section">
        <div className="section-heading"><h2>Your mix</h2></div>
        {categories.length ? <div className="category-breakdown">{categories.map(([category, count]) => <div key={category}><span>{CATEGORY_LABELS[category] ?? category}</span><span className="category-breakdown__bar"><i style={{ width: `${Math.max(8, count / stats.drinks * 100)}%` }} /></span><strong>{count}</strong></div>)}</div> : <p className="empty-copy">Your drink breakdown appears after your first completed night.</p>}
      </section>

      <section className="settings-section">
        <div className="section-heading"><h2>Records</h2></div>
        <dl className="records-list"><div><dt>Most drinks in a night</dt><dd>{stats.mostDrinks}</dd></div><div><dt>Longest night</dt><dd>{stats.longestNightHours ? `${stats.longestNightHours.toFixed(1)}h` : '—'}</dd></div><div><dt>Water logged</dt><dd>{stats.waters}</dd></div><div><dt>Driver / sober nights</dt><dd>{stats.alcoholFreeNights}</dd></div></dl>
      </section>

      <section className="settings-section">
        <div className="section-heading"><h2>Badge cabinet</h2><span className="status-badge status-badge--on">{earned.size} / {BADGES.length}</span></div>
        <div className="badge-grid">{BADGES.map((badge) => <article key={badge.id} className={earned.has(badge.id) ? 'badge-card badge-card--earned' : 'badge-card'}><span aria-hidden="true">{badge.emoji}</span><div><strong>{badge.title}</strong><small>{badge.subtitle}</small></div></article>)}</div>
      </section>
    </main>
  )
}
