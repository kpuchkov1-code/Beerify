import type { NightSession, Profile } from '../types'
import AppIcon from '../components/AppIcon'
import { BADGES, earnedBadgeIds } from '../lib/badges'
import { TARGETS } from '../lib/drinks'
import { formatNightDate, formatUnits } from '../lib/format'
import { calculateStats } from '../lib/stats'

interface Props {
  history: NightSession[]
  profile: Profile
  onOpenSummary: (session: NightSession) => void
}

const CATEGORY_LABELS: Record<string, string> = {
  beer: 'Beer', cider: 'Cider', wine: 'Wine', spirit: 'Spirits', cocktail: 'Cocktails', shot: 'Shots', soft: 'Low / no',
}

export default function Nights({ history, profile, onOpenSummary }: Props) {
  const nights = [...history].sort((a, b) => b.startedAt - a.startedAt)
  const newest = nights[0]
  const stats = calculateStats(history)
  const categories = Object.entries(stats.categories).sort((a, b) => b[1] - a[1])
  const earned = earnedBadgeIds(history, profile)

  return <main className="screen nights-screen">
    <header className="page-header page-header--stacked">
      <span className="page-kicker">YOUR HISTORY</span>
      <h1>Your nights</h1>
      <p>The useful numbers, memorable rounds, and every recap in one place.</p>
    </header>

    <section className="nights-overview" aria-label="Night overview">
      <article><strong>{formatUnits(stats.weekUnits)}</strong><span>units · 7 days</span></article>
      <article><strong>{stats.nights}</strong><span>total nights</span></article>
      <article><strong>{stats.drinks}</strong><span>total drinks</span></article>
    </section>

    {newest ? <section className="nights-latest">
      <div className="section-heading"><div><span className="page-kicker">LATEST</span><h2>{formatNightDate(newest.startedAt)}</h2></div></div>
      <button className="nights-latest__receipt" onClick={() => onOpenSummary(newest)}>
        <span className="nights-latest__icon"><AppIcon name="receipt" /></span>
        <span><strong>{TARGETS[newest.targetId].label}</strong><small>{newest.drinks.length} drinks · {formatUnits(newest.drinks.reduce((sum, drink) => sum + drink.units, 0))} units</small></span>
        <span>View recap</span>
      </button>
    </section> : <div className="empty-state nights-empty"><AppIcon name="moon" size={30} /><h2>No nights yet</h2><p>Finish a night and your first recap will appear here.</p></div>}

    {nights.length > 1 && <section className="nights-section">
      <div className="section-heading"><h2>Past nights</h2></div>
      <ol className="receipt-list">
        {nights.slice(1).map((session, index) => <li key={session.id}>
          <button onClick={() => onOpenSummary(session)}>
            <span className="receipt-list__number">{String(nights.length - index - 1).padStart(2, '0')}</span>
            <span><strong>{formatNightDate(session.startedAt)}</strong><small>{TARGETS[session.targetId].label} · {session.drinks.length} drinks</small></span>
            <span>{formatUnits(session.drinks.reduce((sum, drink) => sum + drink.units, 0))}u</span>
          </button>
        </li>)}
      </ol>
    </section>}

    <section className="nights-section">
      <div className="section-heading"><h2>Records</h2></div>
      <dl className="records-list"><div><dt>Most drinks in a night</dt><dd>{stats.mostDrinks}</dd></div><div><dt>Longest night</dt><dd>{stats.longestNightHours ? `${stats.longestNightHours.toFixed(1)}h` : '—'}</dd></div><div><dt>Water logged</dt><dd>{stats.waters}</dd></div><div><dt>Driver / sober nights</dt><dd>{stats.alcoholFreeNights}</dd></div></dl>
    </section>

    <section className="nights-section">
      <div className="section-heading"><h2>Your mix</h2></div>
      {categories.length ? <div className="category-breakdown">{categories.map(([category, count]) => <div key={category}><span>{CATEGORY_LABELS[category] ?? category}</span><span className="category-breakdown__bar"><i style={{ width: `${Math.max(8, count / stats.drinks * 100)}%` }} /></span><strong>{count}</strong></div>)}</div> : <p className="empty-copy">Your drink breakdown appears after your first completed night.</p>}
    </section>

    <details className="nights-disclosure">
      <summary><span><AppIcon name="check" size={20} />Badge cabinet</span><span>{earned.size} / {BADGES.length}<AppIcon name="chevron-down" size={18} /></span></summary>
      <div className="badge-grid">{BADGES.map((badge) => <article key={badge.id} className={earned.has(badge.id) ? 'badge-card badge-card--earned' : 'badge-card'}><span aria-hidden="true">{badge.emoji}</span><div><strong>{badge.title}</strong><small>{badge.subtitle}</small></div></article>)}</div>
    </details>
  </main>
}
