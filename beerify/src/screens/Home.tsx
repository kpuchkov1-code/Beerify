import { useState } from 'react'
import type { NightSession, Profile, TargetId } from '../types'
import { TARGETS, TARGET_ORDER } from '../lib/drinks'
import { formatNightDate, formatUnits } from '../lib/format'

interface Props {
  profile: Profile
  history: NightSession[]
  unreviewed: NightSession | null
  onStartNight: (target: TargetId) => void
  onOpenSummary: (session: NightSession) => void
}

export default function Home({ profile, history, unreviewed, onStartNight, onOpenSummary }: Props) {
  const [target, setTarget] = useState<TargetId>('tipsy')
  const firstName = profile.name.split(' ')[0]
  const hour = new Date().getHours()
  const greeting = hour < 12 ? 'Morning' : hour < 18 ? 'Afternoon' : 'Evening'

  return (
    <div className="screen home">
      <header className="home__header">
        <h1>
          {greeting}, {firstName} 👋
        </h1>
        <p className="lead">How merry are we getting tonight?</p>
      </header>

      {unreviewed && (
        <button className="card card--highlight" onClick={() => onOpenSummary(unreviewed)}>
          <span className="card--highlight__emoji">☀️</span>
          <span className="card--highlight__text">
            <strong>Your night recap is ready</strong>
            <small>{formatNightDate(unreviewed.startedAt)} · Tap to see your units</small>
          </span>
          <span className="chevron">›</span>
        </button>
      )}

      <h2 className="section-title">Tonight's vibe</h2>
      <div className="target-picker">
        {TARGET_ORDER.map((id) => {
          const t = TARGETS[id]
          const active = target === id
          return (
            <button
              key={id}
              className={`target-card ${active ? 'target-card--active' : ''}`}
              onClick={() => setTarget(id)}
            >
              <span className="target-card__emoji">{t.emoji}</span>
              <span className="target-card__text">
                <span className="target-card__label">{t.label}</span>
                <span className="target-card__tagline">{t.tagline}</span>
              </span>
              <span className={`target-card__check ${active ? 'target-card__check--on' : ''}`}>
                ✓
              </span>
            </button>
          )
        })}
      </div>

      {TARGETS[target].warning && <p className="target-warning">⚠️ {TARGETS[target].warning}</p>}

      <button className="btn btn--primary btn--big" onClick={() => onStartNight(target)}>
        Start night out 🌙
      </button>

      {history.length > 0 && (
        <section className="history">
          <h2 className="section-title">Past nights</h2>
          <div className="history__list">
            {[...history]
              .sort((a, b) => b.startedAt - a.startedAt)
              .slice(0, 10)
              .map((s) => {
                const units = s.drinks.reduce((sum, d) => sum + d.units, 0)
                return (
                  <button key={s.id} className="history__row" onClick={() => onOpenSummary(s)}>
                    <span className="history__emoji">{TARGETS[s.targetId].emoji}</span>
                    <span className="history__date">{formatNightDate(s.startedAt)}</span>
                    <span className="history__units">{formatUnits(units)} units</span>
                    <span className="chevron">›</span>
                  </button>
                )
              })}
          </div>
        </section>
      )}

      <p className="fine-print">
        Beerify estimates are a friendly guide, not a breathalyser. Never drink and drive.
      </p>
    </div>
  )
}
