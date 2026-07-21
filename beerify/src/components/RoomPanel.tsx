import { useEffect, useState } from 'react'
import type { LeaderboardMetric, LeaderboardMode, NightSession, Profile, RoomEvent, RoomMembership, RoomReaction, SquadMember, TargetId } from '../types'
import { TARGET_ORDER, TARGETS } from '../lib/drinks'
import { configureRoom, inviteUrl, leaveRoom, sendRoomEvent, trackMetric, useRoom } from '../lib/room'
import { estimateBacRange } from '../lib/bac'
import { zoneStatus } from '../lib/coach'
import { MemberRow } from './Squad'
import DrinkIcon from './DrinkIcon'
import RoomCountdown from './RoomCountdown'
import { nativeShare } from '../lib/native'
import RoomSetup from './RoomSetup'

interface Props {
  profile: Profile
  membership: RoomMembership | null
  session: NightSession | null
  initialCode?: string
  onJoin: (membership: RoomMembership) => void
  onLeave: () => void
  onOpenTonight: () => void
  lockMembership?: boolean
}

const REACTIONS: { id: RoomReaction; label: string; icon: string }[] = [
  { id: 'cheers', label: 'Cheers', icon: '🍻' },
  { id: 'on-my-way', label: 'On my way', icon: '🏃' },
  { id: 'get-another', label: 'Get another?', icon: '➕' },
  { id: 'scenes', label: 'Scenes', icon: '🎬' },
  { id: 'water-run', label: 'Water run', icon: '💧' },
  { id: 'food', label: 'Food?', icon: '🍟' },
]

function restingMember(profile: Profile): Omit<SquadMember, 'id' | 'updatedAt'> {
  return { name: profile.name, bac: 0, units: 0, drinks: 0, distinctDrinks: 0, targetId: 'glow', status: 'sober', inSession: false }
}

function currentMember(profile: Profile, session: NightSession | null): Omit<SquadMember, 'id' | 'updatedAt'> {
  if (!session) return restingMember(profile)
  const bac = estimateBacRange(session.drinks, profile, Date.now(), session.mealState).likely
  return {
    name: profile.name,
    bac,
    units: session.drinks.reduce((sum, drink) => sum + drink.units, 0),
    drinks: session.drinks.length,
    distinctDrinks: new Set(session.drinks.map((drink) => drink.presetId)).size,
    targetId: session.targetId,
    status: zoneStatus(bac, session),
    inSession: true,
  }
}

const LEADERBOARD_LABELS: Record<LeaderboardMetric, string> = { rounds: 'Round Boss', reactions: 'Hype Merchant', activity: 'Most Active', variety: 'Menu Explorer', drinks: 'Drinks', units: 'Units', bac: 'Current BAC' }
const LEADERBOARD_OPTIONS: { id: LeaderboardMode; label: string; detail: string }[] = [
  { id: 'social', label: 'Drinks', detail: 'Drink count and units' },
  { id: 'balanced', label: 'Social', detail: 'Drinks, reactions, rounds and variety' },
  { id: 'chaos', label: 'Chaos', detail: 'Everything, including current BAC' },
]

function eventCopy(event: RoomEvent): string {
  if (event.type === 'drink' && event.drink) return `logged ${event.drink.brand || event.drink.name}`
  if (event.type === 'reaction') return REACTIONS.find((item) => item.id === event.reaction)?.label ?? 'reacted'
  if (event.type === 'cheers-countdown') return 'called a drink-up countdown'
  if (event.type === 'round-invite') return 'opened the next round'
  if (event.type === 'round-order') return `ordered ${event.text}`
  if (event.type === 'round-bought') return 'bought the round'
  return event.text ?? event.type
}

function timeAgo(at: number): string {
  const minutes = Math.max(0, Math.floor((Date.now() - at) / 60_000))
  return minutes < 1 ? 'now' : minutes < 60 ? `${minutes}m` : `${Math.floor(minutes / 60)}h`
}

export default function RoomPanel({ profile, membership, session, initialCode = '', onJoin, onLeave, onOpenTonight, lockMembership = false }: Props) {
  const [busy, setBusy] = useState(false)
  const [eventBusy, setEventBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [qr, setQr] = useState('')
  const [order, setOrder] = useState('')
  const member = currentMember(profile, session)
  const self = membership ? { id: membership.memberId, ...member } : null
  const { room, error: roomError, refresh } = useRoom(membership, self, 5_000)
  const lastBuyer = room?.roundRota.at(-1)
  const lastBuyerIndex = room?.members.findIndex((member) => member.id === lastBuyer) ?? -1
  const suggestedBuyer = room?.members.length
    ? room.members[(lastBuyerIndex + 1) % room.members.length]
    : null
  const hasLeaderboardEntries = Boolean(room && Object.values(room.leaderboard.categories).some((entries) => entries?.length))

  useEffect(() => { setQr('') }, [membership])

  async function loadQr(open: boolean) {
    if (!open || qr || !membership) return
    try {
      const { default: QRCode } = await import('qrcode')
      setQr(await QRCode.toDataURL(inviteUrl(membership.code), { width: 260, margin: 1, color: { dark: '#10241cff', light: '#f7f7f4ff' } }))
    } catch { setError('Could not make the invite QR') }
  }

  async function emit(type: Parameters<typeof sendRoomEvent>[1], detail?: Parameters<typeof sendRoomEvent>[2]): Promise<boolean> {
    if (!membership || eventBusy) return false
    setError(null)
    setEventBusy(type)
    try { await sendRoomEvent(membership, type, detail); await refresh(); return true }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'The room missed that'); return false }
    finally { setEventBusy(null) }
  }

  async function handleShare() {
    if (!membership) return
    const url = inviteUrl(membership.code)
    const text = `Get in my Beerify room ${membership.code}: ${url}`
    try {
      if (await nativeShare('Join my Beerify room', text, url)) { /* Native share sheet opened. */ }
      else if (navigator.share) await navigator.share({ title: 'Join my Beerify room', text, url })
      else await navigator.clipboard.writeText(text)
      trackMetric('invite_created')
    } catch { /* The share sheet was dismissed. */ }
  }

  async function shareLeaderboard() {
    if (!room) return
    const canvas = document.createElement('canvas'); canvas.width = 1080; canvas.height = 1350
    const context = canvas.getContext('2d')!; context.fillStyle = '#10241c'; context.fillRect(0, 0, 1080, 1350)
    context.fillStyle = '#f1ba3e'; context.font = '900 72px Archivo, sans-serif'; context.fillText('BEERIFY LEADERBOARD', 70, 130)
    context.fillStyle = '#f5f7f2'; context.font = '800 54px Archivo, sans-serif'; context.fillText(room.name, 70, 220)
    let y = 330
    for (const [metric, entries] of Object.entries(room.leaderboard.categories)) {
      if (!entries?.length) continue
      context.fillStyle = '#f1ba3e'; context.font = '800 32px Archivo, sans-serif'; context.fillText(LEADERBOARD_LABELS[metric as LeaderboardMetric].toUpperCase(), 70, y); y += 52
      context.fillStyle = '#f5f7f2'; context.font = '700 38px Archivo, sans-serif'
      entries.slice(0, 3).forEach((entry, index) => { context.fillText(`${index + 1}. ${entry.name}`, 90, y); context.fillText(String(Number(entry.value.toFixed(3))), 840, y); y += 50 })
      y += 28; if (y > 1220) break
    }
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/png')); if (!blob) return
    const file = new File([blob], 'beerify-leaderboard.png', { type: 'image/png' })
    if (navigator.canShare?.({ files: [file] })) await navigator.share({ files: [file], title: `${room.name} leaderboard` })
    else { const url = URL.createObjectURL(blob); const anchor = document.createElement('a'); anchor.href = url; anchor.download = file.name; anchor.click(); URL.revokeObjectURL(url) }
  }

  if (!membership) {
    return <RoomSetup profileName={profile.name} member={member} initialCode={initialCode} onJoined={onJoin} />
  }

  return (
    <div className={`crew-room crew-room--${room?.theme ?? 'green'}`}>
      <section className="room-ticket">
        <div><span className="room-ticket__label">TONIGHT'S ROOM</span><h2>{room?.name ?? 'Loading the room…'}</h2><strong>{membership.code}</strong></div>
        <button className="btn btn--primary" onClick={handleShare}>Invite crew</button>
      </section>

      {!session && <section className="room-start-callout">
        <div><h2>Ready to start?</h2><p>Set your vibe, then every drink will count towards this room.</p></div>
        <button className="btn btn--primary" onClick={onOpenTonight}>Start logging drinks</button>
      </section>}

      {(error || roomError) && <p className="inline-error" role="alert">{error || roomError}</p>}
      {session && room && <RoomCountdown events={room.events} />}

      <section className="ritual-panel ritual-panel--primary">
        <div className="section-heading"><h2>Make some noise</h2><span>Live actions</span></div>
        {suggestedBuyer && <p className="ritual-panel__rota"><strong>Round rota:</strong> {suggestedBuyer.name} is up next · {room?.roundRota.length ?? 0} bought so far</p>}
        <div className="reaction-grid">
          {REACTIONS.map((reaction) => <button key={reaction.id} disabled={Boolean(eventBusy)} aria-busy={eventBusy === 'reaction'} onClick={() => void emit('reaction', { reaction: reaction.id })}><span aria-hidden="true">{reaction.icon}</span><small>{reaction.label}</small></button>)}
        </div>
        <div className="ritual-actions">
          <button className="btn btn--secondary" disabled={Boolean(eventBusy)} aria-busy={eventBusy === 'cheers-countdown'} onClick={() => void emit('cheers-countdown')}>{eventBusy === 'cheers-countdown' ? 'Calling drink up…' : '🍻 Drink up in 8'}</button>
          <button className="btn btn--primary" disabled={Boolean(room?.activeRound || eventBusy)} aria-busy={eventBusy === 'round-invite'} onClick={() => void emit('round-invite')}>{eventBusy === 'round-invite' ? 'Opening round…' : 'Open next round'}</button>
        </div>
      </section>

      <section className="crew-section">
        <div className="section-heading"><h2>Who's in</h2><span>{room?.members.length ?? 0}/{20}</span></div>
        <ul className="squad squad--room">
          {(room?.members ?? []).map((member) => <MemberRow key={member.id} member={member} isSelf={member.id === membership.memberId} />)}
        </ul>
      </section>

      {room && <details className="crew-disclosure"><summary><span>Leaderboard</span><small>{hasLeaderboardEntries ? 'Current room rankings' : 'No scores yet'}</small></summary><section className="leaderboard-panel">
        <div className="section-heading"><h2>Room rankings</h2><button className="text-action" onClick={shareLeaderboard}>Share card</button></div>
        <p className="leaderboard-panel__mode">{LEADERBOARD_OPTIONS.find((option) => option.id === room.leaderboardMode)?.label} mode</p>
        {hasLeaderboardEntries ? <div className="leaderboard-categories">{Object.entries(room.leaderboard.categories).map(([metric, entries]) => entries?.length ? <article key={metric}><h3>{LEADERBOARD_LABELS[metric as LeaderboardMetric]}</h3><ol>{entries.map((entry, index) => <li key={entry.memberId}><span><b>{index + 1}</b>{entry.name}</span><strong>{metric === 'bac' ? entry.value.toFixed(3).replace(/^0/, '') : metric === 'units' ? `${entry.value.toFixed(1)}u` : entry.value}</strong></li>)}</ol></article> : null)}</div> : <p className="leaderboard-empty">No scores yet. Start logging drinks and the first rankings will appear here.</p>}
      </section></details>}

      {room?.activeRound && (
        <section className="round-ticket">
          <div className="section-heading"><h2>{room.activeRound.buyerName}'s round</h2><span>OPEN</span></div>
          <ul>{room.activeRound.orders.map((item) => <li key={item.memberId}><strong>{item.memberName}</strong><span>{item.order}</span></li>)}</ul>
          {room.activeRound.buyerId === membership.memberId ? (
            <button className="btn btn--primary" disabled={Boolean(eventBusy)} aria-busy={eventBusy === 'round-bought'} onClick={() => void emit('round-bought', { refId: room.activeRound!.id })}>Mark round bought</button>
          ) : (
            <div className="round-order"><label htmlFor="round-order">Your order</label><div><input id="round-order" value={order} maxLength={80} placeholder="Pint of lager" onChange={(event) => setOrder(event.target.value)} /><button className="btn btn--secondary" disabled={!order.trim() || Boolean(eventBusy)} aria-busy={eventBusy === 'round-order'} onClick={async () => { if (await emit('round-order', { refId: room.activeRound!.id, text: order })) setOrder('') }}>Send</button></div></div>
          )}
        </section>
      )}

      <details className="crew-disclosure"><summary><span>Squad activity</span><small>{room?.events.length ?? 0} moments</small></summary><section className="crew-section">
        <div className="section-heading"><h2>Live from the squad chat</h2><span>{room?.events.length ?? 0}</span></div>
        {(room?.events.length ?? 0) === 0 ? <p className="empty-copy">The room is suspiciously quiet. Log a drink or start a round.</p> : (
          <ol className="moment-feed">
            {[...(room?.events ?? [])].reverse().map((event) => (
              <li key={event.id}>
                <span className="moment-feed__avatar">{event.drink ? <DrinkIcon icon={event.drink.icon} size={32} /> : event.type === 'reaction' ? REACTIONS.find((item) => item.id === event.reaction)?.icon : '🍻'}</span>
                <span><strong>{event.actorName}</strong><small>{eventCopy(event)}</small></span><time>{timeAgo(event.at)}</time>
              </li>
            ))}
          </ol>
        )}
      </section></details>

      {membership.isHost && room && (
        <details className="host-settings">
          <summary>Host settings</summary>
          <form onSubmit={async (event) => {
            event.preventDefault()
            const form = new FormData(event.currentTarget)
            const labels = Object.fromEntries(TARGET_ORDER.map((id) => [id, String(form.get(id) ?? '')])) as Record<TargetId, string>
            try { await configureRoom(membership, { name: String(form.get('name') ?? room.name), theme: String(form.get('theme')) as 'green' | 'red' | 'blue', labels, leaderboardMode: String(form.get('leaderboardMode')) as LeaderboardMode }); await refresh() } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save room settings') }
          }}>
            <label className="field"><span className="field__label">Room name</span><input name="name" defaultValue={room.name} maxLength={36} /></label>
            <label className="field"><span className="field__label">Room colour</span><select name="theme" defaultValue={room.theme}><option value="green">Bottle green</option><option value="red">Pub red</option><option value="blue">Electric blue</option></select></label>
            <label className="field"><span className="field__label">Leaderboard</span><select name="leaderboardMode" defaultValue={room.leaderboardMode}>{LEADERBOARD_OPTIONS.map((option) => <option key={option.id} value={option.id}>{option.label}</option>)}</select></label>
            <div className="slang-grid">{TARGET_ORDER.map((id) => <label key={id}><span>{TARGETS[id].label}</span><input name={id} defaultValue={room.labels[id] ?? ''} placeholder="Keep default" maxLength={24} /></label>)}</div>
            <button className="btn btn--secondary" type="submit">Save room style</button>
          </form>
        </details>
      )}

      <details className="qr-panel" onToggle={(event) => void loadQr(event.currentTarget.open)}><summary>Show invite QR</summary>{qr && <img src={qr} alt={`QR code for Beerify room ${membership.code}`} />}</details>
      {lockMembership ? <p className="locked-room-copy">Squad mode is locked for this night. End the night to close your room.</p> : <button className="danger-link" disabled={busy} onClick={async () => { setBusy(true); setError(null); try { await leaveRoom(membership); onLeave() } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not leave the room') } finally { setBusy(false) } }}>Leave room</button>}
    </div>
  )
}
