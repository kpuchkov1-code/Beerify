import { useMemo, useState } from 'react'
import type { MealState, NightSession, Preferences, Profile, RoomMembership, TargetId } from '../types'
import { allPresets, TARGETS, TARGET_ORDER } from '../lib/drinks'
import { formatNightDate, formatUnits } from '../lib/format'
import DrinkIcon from '../components/DrinkIcon'

interface Props {
  profile: Profile
  history: NightSession[]
  preferences: Preferences
  membership: RoomMembership | null
  onStartNight: (target: TargetId, meal: MealState) => void
  onOpenSummary: (session: NightSession) => void
  onOpenCrew: () => void
}

export default function Home({ profile, history, preferences, membership, onStartNight, onOpenSummary, onOpenCrew }: Props) {
  const [target, setTarget] = useState<TargetId>(preferences.lastTargetId)
  const [meal, setMeal] = useState<MealState>('unknown')
  const targetIndex = TARGET_ORDER.indexOf(target)
  const recent = [...history].sort((a, b) => b.startedAt - a.startedAt)[0]
  const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60_000
  const weeklyUnits = history
    .filter((session) => session.startedAt >= sevenDaysAgo)
    .flatMap((session) => session.drinks)
    .reduce((sum, drink) => sum + drink.units, 0)
  const favorites = useMemo(() => {
    const presets = allPresets(preferences.customPresets)
    return preferences.favoritePresetIds.map((id) => presets.find((preset) => preset.id === id)).filter(Boolean).slice(0, 4)
  }, [preferences])

  return (
    <main className="screen home">
      <header className="home__header">
        <div className="brand-lockup brand-lockup--small"><span className="brand-lockup__mark">B</span><span>BEERIFY</span></div>
        <p className="home__hello">Alright, {profile.name.split(' ')[0]}?</p>
        <h1>How chaotic is tonight?</h1>
      </header>

      <section className="vibe-board" aria-labelledby="vibe-title">
        <div className="section-heading"><h2 id="vibe-title">Tonight's setting</h2><span>{TARGETS[target].emoji}</span></div>
        <div className="vibe-rail">
          <input
            className="vibe-range"
            type="range"
            min="0"
            max={TARGET_ORDER.length - 1}
            step="1"
            value={targetIndex}
            aria-label="Tonight's setting"
            aria-valuetext={TARGETS[target].label}
            onChange={(event) => setTarget(TARGET_ORDER[Number(event.target.value)])}
          />
          <div className="vibe-marks">
            {TARGET_ORDER.map((id, index) => (
              <button key={id} className={target === id ? 'vibe-mark vibe-mark--active' : 'vibe-mark'} aria-pressed={target === id} onClick={() => setTarget(id)}>
                <span className="vibe-mark__dot" aria-hidden="true">{index + 1}</span>
                <span><strong>{TARGETS[id].label}</strong>{target === id && <small>{TARGETS[id].tagline}</small>}</span>
              </button>
            ))}
          </div>
        </div>
        <fieldset className="meal-picker fieldset-reset"><legend>Drinking on</legend><div>{([['empty', 'Empty'], ['snack', 'A snack'], ['meal', 'A meal'], ['unknown', 'Not sure']] as const).map(([id, label]) => <button key={id} aria-pressed={meal === id} className={meal === id ? 'chip chip--active' : 'chip'} onClick={() => setMeal(id)}>{label}</button>)}</div></fieldset>
        <button className="btn btn--primary btn--big" onClick={() => onStartNight(target, meal)}>Start the night →</button>
      </section>

      <div className="home__split">
        <section className="stat-line">
          <span><strong>{formatUnits(weeklyUnits)}</strong> units</span>
          <span>logged in 7 days</span>
        </section>
        <button className="crew-callout" onClick={onOpenCrew}>
          <span className="crew-callout__avatars" aria-hidden="true">🦊 🐻 🐸</span>
          <span><strong>{membership ? `Room ${membership.code}` : 'Get the crew in'}</strong><small>{membership ? 'Open the live room' : 'Create or join in one tap'}</small></span>
          <span aria-hidden="true">→</span>
        </button>
      </div>

      {favorites.length > 0 && (
        <section className="favourites-preview">
          <div className="section-heading"><h2>Your usual suspects</h2><span>{favorites.length} saved</span></div>
          <div className="drink-row">
            {favorites.map((preset) => preset && (
              <div className="drink-token" key={preset.id}>
                <DrinkIcon icon={preset.icon} size={40} logoUrl={preset.logoUrl} brand={preset.brand} />
                <span className="drink-token__copy"><strong>{preset.brand || preset.name}</strong><small>{preset.detail}</small></span>
              </div>
            ))}
          </div>
        </section>
      )}

      {recent && (
        <button className="night-receipt-preview" onClick={() => onOpenSummary(recent)}>
          <span><small>LAST NIGHT</small><strong>{formatNightDate(recent.startedAt)}</strong></span>
          <span>{TARGETS[recent.targetId].label} · {recent.drinks.length} drinks</span>
          <span aria-hidden="true">→</span>
        </button>
      )}
    </main>
  )
}
