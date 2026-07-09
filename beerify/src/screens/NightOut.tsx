import { useEffect, useMemo, useState } from 'react'
import type { DrinkTypeId, NightSession, Profile, RoomMembership } from '../types'
import { DRINK_TYPES, TARGETS } from '../lib/drinks'
import { estimateBac, peakBacAhead } from '../lib/bac'
import { coachMessage, zoneStatus } from '../lib/coach'
import { formatTime, formatUnits } from '../lib/format'
import BeerMeter from '../components/BeerMeter'
import { useRoom } from '../lib/room'
import { MemberRow } from '../components/Squad'

interface Props {
  session: NightSession
  profile: Profile
  membership: RoomMembership | null
  onLogDrink: (type: DrinkTypeId) => void
  onLogWater: () => void
  onUndo: () => void
  onEndNight: () => void
}

const TAP_ORDER: DrinkTypeId[] = ['beer', 'shot', 'wine', 'cocktail']

export default function NightOut({
  session,
  profile,
  membership,
  onLogDrink,
  onLogWater,
  onUndo,
  onEndNight,
}: Props) {
  const [now, setNow] = useState(() => Date.now())
  const [confirmEnd, setConfirmEnd] = useState(false)
  const [burst, setBurst] = useState<{ key: number; emoji: string; source: string } | null>(null)

  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 5_000)
    return () => clearInterval(id)
  }, [])

  const bac = useMemo(() => estimateBac(session.drinks, profile, now), [session.drinks, profile, now])
  const incoming = useMemo(
    () => peakBacAhead(session.drinks, profile, now, 60),
    [session.drinks, profile, now],
  )
  const status = zoneStatus(bac, session)
  const coach = useMemo(() => coachMessage(session, profile, now), [session, profile, now])
  const target = TARGETS[session.targetId]
  const totalUnits = session.drinks.reduce((sum, d) => sum + d.units, 0)
  const blocked = status === 'way-over'

  const selfSnapshot = membership
    ? {
        id: membership.memberId,
        name: profile.name,
        bac,
        units: totalUnits,
        drinks: session.drinks.length,
        targetId: session.targetId,
        status,
        inSession: true,
      }
    : null
  const { room, refresh: syncRoom } = useRoom(membership, selfSnapshot, 20_000)

  function tap(id: DrinkTypeId) {
    onLogDrink(id)
    setNow(Date.now())
    setBurst({ key: Date.now(), emoji: DRINK_TYPES[id].emoji, source: id })
    if (navigator.vibrate) navigator.vibrate(30)
    setTimeout(syncRoom, 400)
  }

  function tapWater() {
    onLogWater()
    setNow(Date.now())
    setBurst({ key: Date.now(), emoji: '💧', source: 'water' })
    if (navigator.vibrate) navigator.vibrate(15)
  }

  return (
    <div className={`screen night night--${status}`}>
      <header className="night__header">
        <div>
          <h1>Night out</h1>
          <span className="night__target">
            {target.emoji} {target.label}
          </span>
        </div>
        <button className="btn btn--quiet" onClick={() => setConfirmEnd(true)}>
          End night
        </button>
      </header>

      <BeerMeter bac={bac} incoming={incoming} target={target} status={status} />

      <div className={`coach coach--${coach.tone}`} role="status" aria-live="polite">
        <span className="coach__avatar">🤖</span>
        <div>
          <p className="coach__text">{coach.text}</p>
          {coach.tip && <p className="coach__tip">{coach.tip}</p>}
        </div>
      </div>

      {blocked && (
        <div className="night__blocked">
          Drink logging is paused. You are well past your zone, so it is water only for now. 💧
        </div>
      )}

      <h2 className="section-title">Tap what you're having</h2>
      <div className="tap-grid">
        {TAP_ORDER.map((id) => {
          const d = DRINK_TYPES[id]
          return (
            <button
              key={id}
              className="tap-btn"
              disabled={blocked}
              onClick={() => tap(id)}
              aria-label={`Log one ${d.label}`}
            >
              <span className="tap-btn__emoji">{d.emoji}</span>
              <span className="tap-btn__label">{d.label}</span>
              <span className="tap-btn__detail">{d.detail}</span>
              {burst?.source === id && (
                <span className="tap-btn__burst" key={burst.key} aria-hidden="true">
                  {burst.emoji}
                </span>
              )}
            </button>
          )
        })}
      </div>

      <button className="tap-btn tap-btn--water" onClick={tapWater} aria-label="Log a water">
        <span className="tap-btn__emoji">💧</span>
        <span className="tap-btn__water-text">
          <span className="tap-btn__label">Water break</span>
          <span className="tap-btn__detail">Your liver's best friend</span>
        </span>
        {burst?.source === 'water' && (
          <span className="tap-btn__burst" key={burst.key} aria-hidden="true">
            {burst.emoji}
          </span>
        )}
      </button>

      <div className="night__meta">
        <span>
          {session.drinks.length} drink{session.drinks.length === 1 ? '' : 's'} · {formatUnits(totalUnits)} units
          {session.waters.length > 0 && ` · ${session.waters.length} 💧`}
        </span>
        {session.drinks.length > 0 && (
          <button className="btn btn--quiet btn--small" onClick={onUndo}>
            Undo last
          </button>
        )}
      </div>

      {membership && room && (
        <section className="night__squad">
          <h2 className="section-title">Your room · {membership.code}</h2>
          {room.members.length > 1 ? (
            <ul className="squad card">
              {room.members.map((m) => (
                <MemberRow key={m.id} member={m} isSelf={m.id === membership.memberId} />
              ))}
            </ul>
          ) : (
            <p className="night__squad-empty">No friends in the room yet. They'll pop up here.</p>
          )}
        </section>
      )}

      {session.drinks.length > 0 && (
        <ul className="night__log">
          {[...session.drinks]
            .sort((a, b) => b.at - a.at)
            .slice(0, 6)
            .map((d) => (
              <li key={d.id}>
                <span>{DRINK_TYPES[d.type].emoji}</span>
                <span>{DRINK_TYPES[d.type].label}</span>
                <span className="night__log-time">{formatTime(d.at)}</span>
              </li>
            ))}
        </ul>
      )}

      {confirmEnd && (
        <div className="sheet-backdrop" onClick={() => setConfirmEnd(false)}>
          <div className="sheet" onClick={(e) => e.stopPropagation()}>
            <h2>Calling it a night?</h2>
            <p>
              We'll save tonight and have your summary of units, peak and all, waiting for you in
              the morning. ☀️
            </p>
            <button className="btn btn--primary" onClick={onEndNight}>
              End night, sleep tight 😴
            </button>
            <button className="btn btn--quiet" onClick={() => setConfirmEnd(false)}>
              Keep going
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
