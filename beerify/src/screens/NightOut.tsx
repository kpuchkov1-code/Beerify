import { useEffect, useMemo, useRef, useState } from 'react'
import type { DrinkPreset, LoggedDrink, NightSession, Preferences, Profile, RoomMembership, RoomState } from '../types'
import { allPresets, gramsOfAlcohol, TARGETS, targetLabel, unitsOfAlcohol } from '../lib/drinks'
import { estimateBacRange, peakBacAhead } from '../lib/bac'
import { coachMessage, zoneStatus } from '../lib/coach'
import { formatTime, formatUnits } from '../lib/format'
import BeerMeter from '../components/BeerMeter'
import DrinkIcon from '../components/DrinkIcon'
import { queueRoomDrink, sendRoomEvent, useRoom } from '../lib/room'
import { MemberRow } from '../components/Squad'
import { nativeTap } from '../lib/native'
import RoomCountdown from '../components/RoomCountdown'

interface Props {
  session: NightSession
  profile: Profile
  preferences: Preferences
  membership: RoomMembership | null
  onLogDrink: (presetId: string) => LoggedDrink | null
  onLogWater: () => void
  onUndo: () => void
  onUpdateDrink: (drink: LoggedDrink) => void
  onEndNight: (room?: RoomState | null) => void
  onToggleFavorite: (presetId: string) => void
  onSavePreset: (preset: DrinkPreset) => void
  onOpenCrew: () => void
}

export default function NightOut({ session, profile, preferences, membership, onLogDrink, onLogWater, onUndo, onUpdateDrink, onEndNight, onToggleFavorite, onOpenCrew }: Props) {
  const [now, setNow] = useState(() => Date.now())
  const [drinkType, setDrinkType] = useState<DrinkPreset | null>(null)
  const [burst, setBurst] = useState<string | null>(null)
  const [editing, setEditing] = useState<LoggedDrink | null>(null)
  const [minutesAgo, setMinutesAgo] = useState('0')
  const [roomBusy, setRoomBusy] = useState<string | null>(null)
  const [roomActionError, setRoomActionError] = useState<string | null>(null)
  const endDialog = useRef<HTMLDialogElement>(null)
  const drinksDialog = useRef<HTMLDialogElement>(null)
  const editDialog = useRef<HTMLDialogElement>(null)

  useEffect(() => {
    let id: ReturnType<typeof setInterval> | null = null
    const update = () => {
      if (id) clearInterval(id)
      id = null
      if (!document.hidden) {
        setNow(Date.now())
        id = setInterval(() => setNow(Date.now()), 5_000)
      }
    }
    update()
    document.addEventListener('visibilitychange', update)
    return () => { if (id) clearInterval(id); document.removeEventListener('visibilitychange', update) }
  }, [])

  const bacRange = useMemo(() => estimateBacRange(session.drinks, profile, now, session.mealState), [session.drinks, profile, now, session.mealState])
  const bac = bacRange.likely
  const incoming = useMemo(() => peakBacAhead(session.drinks, profile, now, 60, session.mealState), [session.drinks, profile, now, session.mealState])
  const status = zoneStatus(bac, session)
  const coach = useMemo(() => coachMessage(session, profile, now, preferences.coachPersonality), [session, profile, now, preferences.coachPersonality])
  const target = TARGETS[session.targetId]
  const totalUnits = session.drinks.reduce((sum, drink) => sum + drink.units, 0)
  const alcoholLocked = session.participationMode !== 'drinking'
  const rideUrl = useMemo(() => {
    try {
      const url = new URL(preferences.rideHomeUrl)
      if (url.protocol !== 'https:') return ''
      if (preferences.homeAddress) url.searchParams.set(url.hostname.includes('uber') ? 'dropoff[formatted_address]' : 'destination', preferences.homeAddress)
      return url.toString()
    } catch { return '' }
  }, [preferences.rideHomeUrl, preferences.homeAddress])
  const presets = useMemo(() => allPresets(preferences.customPresets), [preferences.customPresets])
  const quickIds = [...preferences.favoritePresetIds, ...preferences.recentPresetIds]
  const quick = [...new Set(quickIds)].map((id) => presets.find((preset) => preset.id === id)).filter((preset): preset is DrinkPreset => Boolean(preset)).slice(0, 4)
  const drinkTypes = presets.filter((preset) => !preset.brand && preset.source === 'built-in')
  const brands = drinkType ? presets.filter((preset) => preset.brand && preset.style === drinkType.style && preset.serve === drinkType.serve) : []

  const self = membership ? {
    id: membership.memberId,
    name: profile.name,
    bac,
    units: totalUnits,
    drinks: session.drinks.length,
    distinctDrinks: new Set(session.drinks.map((drink) => drink.presetId)).size,
    targetId: session.targetId,
    status,
    inSession: true,
  } : null
  const { room, error: roomError, refresh } = useRoom(membership, self, 5_000)

  async function roomAction(type: Parameters<typeof sendRoomEvent>[1], detail?: Parameters<typeof sendRoomEvent>[2]) {
    if (!membership || roomBusy) return
    setRoomBusy(type); setRoomActionError(null)
    try { await sendRoomEvent(membership, type, detail); await refresh() }
    catch (error) { setRoomActionError(error instanceof Error ? error.message : 'The room missed that') }
    finally { setRoomBusy(null) }
  }

  async function log(presetId: string) {
    if (alcoholLocked) return
    const logged = onLogDrink(presetId)
    if (!logged) return
    setNow(Date.now())
    setBurst(logged.id)
    setTimeout(() => setBurst(null), 900)
    if (preferences.haptics) {
      nativeTap('medium')
      if (navigator.vibrate) navigator.vibrate(30)
    }
    if (membership) {
      const delivered = await queueRoomDrink(membership, { name: logged.name, brand: logged.brand, icon: logged.icon, units: logged.units })
      if (delivered) await refresh()
      else setRoomActionError('Drink saved. The room update will retry when you reconnect.')
    }
  }

  function water() {
    onLogWater()
    if (preferences.haptics) {
      nativeTap()
      if (navigator.vibrate) navigator.vibrate(15)
    }
  }

  const displayTarget = session.participationMode === 'driver' ? 'Designated Driver' : session.participationMode === 'sober' ? 'Sober mode' : targetLabel(session.targetId, room?.labels)

  return (
    <main className={`screen night night--${status} ${preferences.reducedMotion ? 'reduce-motion' : ''} ${preferences.bigThumbMode ? 'big-thumb-mode' : ''}`}>
      <header className="night-bar">
        <div><span>{displayTarget} · {session.nightMode === 'group' ? 'Squad' : 'Solo'}</span><strong>{formatUnits(totalUnits)}u · {session.drinks.length} drinks</strong></div>
        <div className="night-bar__bac"><span>LIKELY</span><strong>{bac.toFixed(3).replace(/^0/, '')}</strong></div>
        <button className="icon-btn icon-btn--light" aria-label="End the night" onClick={() => endDialog.current?.showModal()}>×</button>
      </header>

      <section className="night-stage">
        {alcoholLocked ? <div className="water-mode-stage"><span aria-hidden="true">{session.participationMode === 'driver' ? '🚗' : '🌱'}</span><div><strong>{session.waters.length}</strong><small>waters logged</small></div><button className="btn btn--primary" onClick={water}>Log water</button></div> : <>
        <BeerMeter bac={bac} incoming={incoming} target={{ ...target, label: displayTarget }} status={status} />
        <p className="bac-range">Plausible now: {bacRange.low.toFixed(3).replace(/^0/, '')}–{bacRange.high.toFixed(3).replace(/^0/, '')}% · {bacRange.model === 'watson' ? 'personalised model' : 'basic profile range'}</p>
        </>}
        <div className={`hype-mate hype-mate--${coach.tone}`} role="status" aria-live="polite">
          <span className="hype-mate__badge">HYPE<br />MATE</span>
          <div><p>{coach.text}</p>{coach.tip && <small>{coach.tip}</small>}</div>
        </div>
        {rideUrl && <a className="ride-home-link" href={rideUrl} target="_blank" rel="noreferrer">Get a ride home <span>↗</span></a>}
      </section>

      {session.nightMode === 'group' && !membership && <section className="group-reconnect"><div><strong>Squad connection lost</strong><small>Your night is still in Squad mode. Rejoin once to resume shared drinks, games and crawl.</small></div><button className="btn btn--secondary" onClick={onOpenCrew}>Reconnect</button></section>}

      {membership && room && (
        <section className="night-crew-strip">
          <div className="section-heading"><h2>{room.name}</h2><span>{room.members.length} in</span></div>
          <ul className="squad squad--compact">{room.members.map((member) => <MemberRow key={member.id} member={member} isSelf={member.id === membership.memberId} />)}</ul>
          <div className="night-crew-actions">
            <button disabled={Boolean(roomBusy)} aria-busy={roomBusy === 'reaction'} onClick={() => void roomAction('reaction', { reaction: 'cheers' })}>🍻 Cheers</button>
            <button disabled={Boolean(roomBusy)} aria-busy={roomBusy === 'cheers-countdown'} onClick={() => void roomAction('cheers-countdown')}>{roomBusy === 'cheers-countdown' ? 'Calling…' : '⏱ Drink up'}</button>
            <button disabled={Boolean(room.activeRound || roomBusy)} aria-busy={roomBusy === 'round-invite'} onClick={() => void roomAction('round-invite')}>{room.activeRound ? 'Round open' : roomBusy === 'round-invite' ? 'Opening…' : '＋ Next round'}</button>
          </div>
        </section>
      )}
      {membership && (roomActionError || roomError) && <p className="inline-error" role="alert">{roomActionError || roomError}</p>}

      <section className="quick-log" aria-labelledby="quick-log-title">
        <div className="section-heading"><h2 id="quick-log-title">{alcoholLocked ? `${session.participationMode === 'driver' ? 'Driver' : 'Sober'} mode` : 'Tap the order'}</h2>{!alcoholLocked && <button className="text-action" onClick={() => { setDrinkType(null); drinksDialog.current?.showModal() }}>Choose drink</button>}</div>
        {alcoholLocked ? <p className="mode-lock-copy">Alcohol logging is locked for this night. Waters still count.</p> : <div className="quick-log__grid">
          {quick.map((preset) => (
            <button key={preset.id} className="quick-drink" onClick={() => log(preset.id)} aria-label={`Log ${preset.brand || preset.name}`}>
              <DrinkIcon icon={preset.icon} size={48} logoUrl={preset.logoUrl} brand={preset.brand} />
              <span><strong>{preset.brand || preset.name}</strong><small>{preset.detail}</small></span>
              {burst && session.drinks.at(-1)?.presetId === preset.id && <span className="quick-drink__burst" aria-hidden="true">+1</span>}
            </button>
          ))}
        </div>}
        <div className="quick-log__utility">
          <button onClick={water}>💧 <span>Water</span></button>
          <button disabled={!session.drinks.length} onClick={() => session.drinks.at(-1) && log(session.drinks.at(-1)!.presetId)}>↻ <span>Repeat last</span></button>
          <button disabled={!session.drinks.length} onClick={onUndo}>↶ <span>Undo</span></button>
        </div>
      </section>

      {session.drinks.length > 0 && (
        <section className="live-tab">
          <div className="section-heading"><h2>Tonight's tab</h2><span>{formatUnits(totalUnits)} units</span></div>
          <ol>{[...session.drinks].reverse().slice(0, 8).map((drink) => <li key={drink.id}><DrinkIcon icon={drink.icon} size={30} logoUrl={drink.logoUrl} brand={drink.brand} /><span><strong>{drink.brand || drink.name}</strong><small>{formatTime(drink.at)}</small></span><button className="edit-drink" onClick={() => { setEditing({ ...drink }); setMinutesAgo(String(Math.max(0, Math.round((Date.now() - drink.at) / 60_000)))); editDialog.current?.showModal() }}>Edit</button><span>{formatUnits(drink.units)}u</span></li>)}</ol>
        </section>
      )}

      {room && <RoomCountdown events={room.events} />}

      <dialog ref={drinksDialog} className="native-dialog drink-dialog" aria-labelledby="all-drinks-title">
        <div className="dialog-sheet dialog-sheet--tall">
          <div className="dialog-heading"><div><h2 id="all-drinks-title">{drinkType ? 'Which brand?' : 'What did you drink?'}</h2><p>{drinkType ? drinkType.name : 'Pick the drink first. Brand comes next.'}</p></div><button className="icon-btn" aria-label="Close drinks" onClick={() => drinksDialog.current?.close()}>×</button></div>
          {drinkType ? (
            <div className="brand-step">
              <button className="brand-step__back" onClick={() => setDrinkType(null)}>← Change drink</button>
              <div className="drink-catalogue">
                {brands.map((preset) => {
                  const favorite = preferences.favoritePresetIds.includes(preset.id)
                  return <div className="catalogue-row" key={preset.id}><button className="catalogue-row__main" onClick={() => { log(preset.id); drinksDialog.current?.close() }}><DrinkIcon icon={preset.icon} size={38} logoUrl={preset.logoUrl} brand={preset.brand} /><span><strong>{preset.brand}</strong><small>{preset.name} · {preset.detail}</small></span><span>{formatUnits(preset.volumeMl * preset.abv * 0.789 / 8)}u</span></button><button className="catalogue-row__star" aria-label={`${favorite ? 'Remove' : 'Add'} ${preset.brand} ${favorite ? 'from' : 'to'} favourites`} aria-pressed={favorite} onClick={() => onToggleFavorite(preset.id)}>{favorite ? '★' : '☆'}</button></div>
                })}
                <button className="other-brand" onClick={() => { log(drinkType.id); drinksDialog.current?.close() }}>
                  <DrinkIcon icon={drinkType.icon} size={38} />
                  <span><strong>Other brand</strong><small>Use the standard {drinkType.detail.toLowerCase()} pour</small></span>
                  <span>→</span>
                </button>
              </div>
            </div>
          ) : (
            <div className="drink-type-grid">
              {drinkTypes.map((preset) => <button key={preset.id} onClick={() => setDrinkType(preset)}><DrinkIcon icon={preset.icon} size={42} /><span><strong>{preset.name}</strong><small>{preset.detail}</small></span><span aria-hidden="true">›</span></button>)}
            </div>
          )}
        </div>
      </dialog>

      <dialog ref={editDialog} className="native-dialog" aria-labelledby="edit-drink-title">
        {editing && <div className="dialog-sheet"><div className="dialog-heading"><div><h2 id="edit-drink-title">Correct this drink</h2><p>Fixing the pour makes every estimate better.</p></div><button className="icon-btn" aria-label="Close edit drink" onClick={() => editDialog.current?.close()}>×</button></div>
          <label className="field"><span className="field__label">Brand</span><input value={editing.brand ?? ''} onChange={(event) => setEditing({ ...editing, brand: event.target.value || undefined })} /></label>
          <div className="preset-form__measure"><label className="field"><span className="field__label">Millilitres</span><input type="number" min="5" max="5000" value={editing.volumeMl} onChange={(event) => setEditing({ ...editing, volumeMl: Number(event.target.value) })} /></label><label className="field"><span className="field__label">ABV %</span><input type="number" min="0" max="100" step="0.1" value={Number((editing.abv * 100).toFixed(1))} onChange={(event) => setEditing({ ...editing, abv: Number(event.target.value) / 100 })} /></label></div>
          <label className="field"><span className="field__label">Minutes ago</span><input type="number" min="0" max="720" value={minutesAgo} onChange={(event) => setMinutesAgo(event.target.value)} /></label>
          <button className="btn btn--primary" onClick={() => { const at = Date.now() - Math.max(0, Number(minutesAgo) || 0) * 60_000; const measure = { volumeMl: editing.volumeMl, abv: editing.abv }; onUpdateDrink({ ...editing, at, units: unitsOfAlcohol(measure), grams: gramsOfAlcohol(measure) }); editDialog.current?.close() }}>Save correction</button>
        </div>}
      </dialog>

      <dialog ref={endDialog} className="native-dialog" aria-labelledby="end-night-title">
        <div className="dialog-sheet">
          <span className="dialog-mark" aria-hidden="true">▤</span>
          <h2 id="end-night-title">Close tonight's tab?</h2>
          <p>The full receipt, peak and group evidence will move into History.</p>
          <button className="btn btn--primary" onClick={() => onEndNight(room)}>End night and make recap</button>
          <button className="btn btn--quiet" autoFocus onClick={() => endDialog.current?.close()}>Keep the tab open</button>
        </div>
      </dialog>
    </main>
  )
}
