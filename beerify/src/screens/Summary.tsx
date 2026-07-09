import { useMemo } from 'react'
import type { NightSession, Profile } from '../types'
import { DRINK_TYPES, TARGETS } from '../lib/drinks'
import { estimateBac, formatBac, minutesUntilBac } from '../lib/bac'
import { morningVerdict } from '../lib/coach'
import { formatNightDate, formatTime, formatUnits } from '../lib/format'

interface Props {
  session: NightSession
  profile: Profile
  onClose: () => void
}

const WEEKLY_GUIDELINE_UNITS = 14

export default function Summary({ session, profile, onClose }: Props) {
  const end = session.endedAt ?? Date.now()

  const stats = useMemo(() => {
    const totalUnits = session.drinks.reduce((sum, d) => sum + d.units, 0)

    let peak = 0
    let peakAt = session.startedAt
    for (let t = session.startedAt; t <= end; t += 5 * 60_000) {
      const b = estimateBac(session.drinks, profile, t)
      if (b > peak) {
        peak = b
        peakAt = t
      }
    }

    const soberInMin = minutesUntilBac(session.drinks, profile, end, 0.005)
    const soberAt = end + soberInMin * 60_000

    const byType = new Map<string, { count: number; units: number }>()
    for (const d of session.drinks) {
      const entry = byType.get(d.type) ?? { count: 0, units: 0 }
      entry.count += 1
      entry.units += d.units
      byType.set(d.type, entry)
    }

    return { totalUnits, peak, peakAt, soberAt, soberInMin, byType }
  }, [session, profile, end])

  const verdict = morningVerdict(session, profile)
  const target = TARGETS[session.targetId]
  const stillProcessing = stats.soberInMin > 5 && session.drinks.length > 0

  return (
    <div className="screen summary">
      <header className="summary__header">
        <span className="summary__sun">☀️</span>
        <h1>{verdict.headline}</h1>
        <p className="lead">{verdict.body}</p>
        <p className="summary__date">{formatNightDate(session.startedAt)}</p>
      </header>

      <div className="stat-grid">
        <div className="stat">
          <span className="stat__value">{formatUnits(stats.totalUnits)}</span>
          <span className="stat__label">units of alcohol</span>
        </div>
        <div className="stat">
          <span className="stat__value">{session.drinks.length}</span>
          <span className="stat__label">drinks logged</span>
        </div>
        <div className="stat">
          <span className="stat__value">{formatBac(stats.peak)}</span>
          <span className="stat__label">peak BAC% · {formatTime(stats.peakAt)}</span>
        </div>
        <div className="stat">
          <span className="stat__value">{session.waters.length} 💧</span>
          <span className="stat__label">water breaks</span>
        </div>
      </div>

      {session.drinks.length > 0 && (
        <section className="summary__breakdown">
          <h2>What you had</h2>
          <ul>
            {[...stats.byType.entries()].map(([typeId, entry]) => {
              const d = DRINK_TYPES[typeId as keyof typeof DRINK_TYPES]
              return (
                <li key={typeId}>
                  <span className="summary__breakdown-emoji">{d.emoji}</span>
                  <span>
                    {entry.count}× {d.label}
                  </span>
                  <span className="summary__breakdown-units">{formatUnits(entry.units)} units</span>
                </li>
              )
            })}
          </ul>
        </section>
      )}

      <section className="summary__notes">
        {stillProcessing && (
          <p>
            ⏳ Your body is still processing — you'll be fully clear around{' '}
            <strong>{formatTime(stats.soberAt)}</strong>. Take it easy until then.
          </p>
        )}
        <p>
          📊 That's <strong>{formatUnits(stats.totalUnits)}</strong> of the{' '}
          {WEEKLY_GUIDELINE_UNITS} units many health guidelines suggest as a weekly
          maximum{stats.totalUnits > WEEKLY_GUIDELINE_UNITS ? ' — a lighter week ahead would be smart' : ''}.
        </p>
        <p>
          🎯 Target was “{target.label}” {target.emoji}. {session.drinks.length > 0 ? 'Check the verdict above for how it went.' : 'Nothing logged, nothing to judge!'}
        </p>
        <p>💧 Water + a proper breakfast = the official Beerify recovery plan.</p>
      </section>

      <button className="btn btn--primary" onClick={onClose}>
        Got it — back home
      </button>
    </div>
  )
}
