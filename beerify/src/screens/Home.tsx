import { useMemo, useState } from 'react'
import type { MealState, NightMode, NightSession, ParticipationMode, Preferences, Profile, RoomMembership, SquadMember, TargetId } from '../types'
import { allPresets, TARGETS, TARGET_ORDER } from '../lib/drinks'
import { formatNightDate, formatUnits } from '../lib/format'
import DrinkIcon from '../components/DrinkIcon'
import RoomSetup from '../components/RoomSetup'
import { useRoom } from '../lib/room'

interface Props {
  profile: Profile
  history: NightSession[]
  preferences: Preferences
  membership: RoomMembership | null
  plannedStops: number
  initialCode?: string
  onStartNight: (target: TargetId, meal: MealState, participationMode: ParticipationMode, nightMode: NightMode) => Promise<void>
  onOpenSummary: (session: NightSession) => void
  onRoomJoin: (membership: RoomMembership) => void
  onRoomLeave: () => void
}

export default function Home({ profile, history, preferences, membership, plannedStops, initialCode = '', onStartNight, onOpenSummary, onRoomJoin, onRoomLeave }: Props) {
  const [target, setTarget] = useState<TargetId>(preferences.lastTargetId)
  const [meal, setMeal] = useState<MealState>('unknown')
  const [participationMode, setParticipationMode] = useState<ParticipationMode>(preferences.lastParticipationMode)
  const [nightMode, setNightMode] = useState<NightMode>(membership || initialCode ? 'group' : 'solo')
  const [starting, setStarting] = useState(false)
  const [startError, setStartError] = useState('')
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
  const restingMember: Omit<SquadMember, 'id' | 'updatedAt'> = { name: profile.name, bac: 0, units: 0, drinks: 0, distinctDrinks: 0, targetId: target, status: 'sober', inSession: false }
  const pendingSelf = membership ? { id: membership.memberId, ...restingMember } : null
  const pendingGroup = useRoom(nightMode === 'group' ? membership : null, pendingSelf, 5_000)
  const groupReady = nightMode === 'solo' || Boolean(membership && pendingGroup.room)

  return (
    <main className="screen home">
      <header className="home__header">
        <div className="brand-lockup brand-lockup--small"><span className="brand-lockup__mark">B</span><span>BEERIFY</span></div>
        <p className="home__hello">Alright, {profile.name.split(' ')[0]}?</p>
        <h1>How chaotic is tonight?</h1>
      </header>

      <section className="vibe-board" aria-label="Night setup">
        <fieldset className="night-mode-picker fieldset-reset">
          <legend>First: who is tonight with?</legend>
          <div className="night-mode-picker__options">
            <button type="button" aria-pressed={nightMode === 'solo'} onClick={() => setNightMode('solo')}><span aria-hidden="true">●</span><strong>Solo</strong><small>One phone, local games and your own crawl</small></button>
            <button type="button" aria-pressed={nightMode === 'group'} onClick={() => setNightMode('group')}><span aria-hidden="true">♟</span><strong>Group</strong><small>Shared crew, games, crawl and scores</small></button>
          </div>
          <p>Once the night starts, this stays fixed until the recap.</p>
        </fieldset>

        {nightMode === 'group' && (membership ? (
          <section className="group-ready" aria-label="Group ready">
            <span aria-hidden="true">✓</span>
            <div><strong>{pendingGroup.room ? 'Group connected' : 'Checking group…'}</strong><small>Code {membership.code} · shared for the whole night</small></div>
            <button type="button" className="text-action" onClick={onRoomLeave}>Change</button>
          </section>
        ) : <RoomSetup profileName={profile.name} member={restingMember} initialCode={initialCode} onJoined={onRoomJoin} />)}

        <fieldset className="participation-picker fieldset-reset">
          <legend>How are you joining in?</legend>
          <div>{([['drinking', '🍺 Drinking'], ['sober', '🌱 Sober'], ['driver', '🚗 Driver']] as const).map(([id, label]) => <button key={id} className={participationMode === id ? 'chip chip--active' : 'chip'} aria-pressed={participationMode === id} onClick={() => setParticipationMode(id)}>{label}</button>)}</div>
        </fieldset>
        {participationMode === 'drinking' && <>
        <div className="section-heading"><h2 id="vibe-title">Tonight's setting</h2><span>{TARGETS[target].emoji}</span></div>
        <div className="target-picker" aria-labelledby="vibe-title">{TARGET_ORDER.map((id, index) => <button key={id} aria-pressed={target === id} onClick={() => setTarget(id)}><span>{index + 1}</span><strong>{TARGETS[id].label}</strong></button>)}</div>
        <p className="target-picker__detail"><span aria-hidden="true">{TARGETS[target].emoji}</span><strong>{TARGETS[target].label}</strong> — {TARGETS[target].tagline}</p>
        <fieldset className="meal-picker fieldset-reset"><legend>Drinking on</legend><div>{([['empty', 'Empty'], ['snack', 'A snack'], ['meal', 'A meal'], ['unknown', 'Not sure']] as const).map(([id, label]) => <button key={id} aria-pressed={meal === id} className={meal === id ? 'chip chip--active' : 'chip'} onClick={() => setMeal(id)}>{label}</button>)}</div></fieldset>
        </>}
        {participationMode !== 'drinking' && <p className="mode-note">{participationMode === 'driver' ? 'Water-only logging. Your designated-driver badge unlocks after 45 minutes.' : 'Alcohol logging stays locked while waters and the night itself still count.'}</p>}
        {plannedStops > 0 && <p className="draft-handoff">⌖ {nightMode === 'group' && !membership?.isHost ? `Your ${plannedStops}-stop draft stays saved; this room’s route wins.` : `${plannedStops} planned stop${plannedStops === 1 ? '' : 's'} will come with you.`}</p>}
        <button className="btn btn--primary btn--big" disabled={!groupReady || starting} aria-describedby={!groupReady ? 'group-start-help' : undefined} onClick={async () => { setStarting(true); setStartError(''); try { await onStartNight(target, meal, participationMode, nightMode) } catch (error) { setStartError(error instanceof Error ? error.message : 'Could not start the night') } finally { setStarting(false) } }}>{starting ? 'Starting…' : `Start ${nightMode === 'group' ? 'group' : 'solo'} night →`}</button>
        {!groupReady && <p id="group-start-help" className="start-help">{membership ? 'Checking the group connection…' : 'Create or join a group above to start.'}</p>}
        {startError && <p className="status-message" role="alert">{startError}</p>}
      </section>

      <section className="stat-line">
        <span><strong>{formatUnits(weeklyUnits)}</strong> units</span>
        <span>logged in 7 days</span>
      </section>

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
