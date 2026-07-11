import { useEffect, useState } from 'react'
import QRCode from 'qrcode'
import type { Profile, RoomEvent, RoomMembership, RoomReaction, SquadMember, TargetId } from '../types'
import { TARGET_ORDER, TARGETS } from '../lib/drinks'
import { configureRoom, createRoom, inviteUrl, joinRoom, leaveRoom, sendRoomEvent, trackMetric, useRoom } from '../lib/room'
import { MemberRow } from './Squad'
import DrinkIcon from './DrinkIcon'
import { nativeShare } from '../lib/native'

interface Props {
  profile: Profile
  membership: RoomMembership | null
  initialCode?: string
  onJoin: (membership: RoomMembership) => void
  onLeave: () => void
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
  return { name: profile.name, bac: 0, units: 0, drinks: 0, targetId: 'glow', status: 'sober', inSession: false }
}

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

export default function RoomPanel({ profile, membership, initialCode = '', onJoin, onLeave }: Props) {
  const [joinCode, setJoinCode] = useState(initialCode)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [qr, setQr] = useState('')
  const [order, setOrder] = useState('')
  const self = membership ? { id: membership.memberId, ...restingMember(profile) } : null
  const { room, error: roomError, refresh } = useRoom(membership, self, 5_000)
  const lastBuyer = room?.roundRota.at(-1)
  const lastBuyerIndex = room?.members.findIndex((member) => member.id === lastBuyer) ?? -1
  const suggestedBuyer = room?.members.length
    ? room.members[(lastBuyerIndex + 1) % room.members.length]
    : null

  useEffect(() => {
    if (!membership) return
    QRCode.toDataURL(inviteUrl(membership.code), { width: 260, margin: 1, color: { dark: '#10241cff', light: '#f7f7f4ff' } }).then(setQr).catch(() => {})
  }, [membership])

  async function handleCreate() {
    setBusy(true); setError(null)
    try {
      const result = await createRoom(profile.name, restingMember(profile))
      onJoin(result.membership)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not open a room')
    } finally { setBusy(false) }
  }

  async function handleJoin() {
    const code = joinCode.trim().toUpperCase()
    if (!/^[A-Z2-9]{6}$/.test(code)) { setError('Room codes use 6 letters or numbers'); return }
    setBusy(true); setError(null)
    try {
      const result = await joinRoom(code, restingMember(profile))
      onJoin(result.membership)
      setJoinCode('')
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not join that room')
    } finally { setBusy(false) }
  }

  async function emit(type: Parameters<typeof sendRoomEvent>[1], detail?: Parameters<typeof sendRoomEvent>[2]) {
    if (!membership) return
    setError(null)
    try { await sendRoomEvent(membership, type, detail); refresh() }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'The room missed that') }
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

  if (!membership) {
    return (
      <div className="room-entry">
        <section className="room-entry__create">
          <span className="room-entry__mark" aria-hidden="true">♟</span>
          <h2>Open tonight's room</h2>
          <p>One link for the order, the reactions and the evidence.</p>
          <button className="btn btn--primary btn--big" disabled={busy} onClick={handleCreate}>{busy ? 'Opening room…' : 'Create room'}</button>
        </section>
        <div className="room-entry__or"><span>or join the others</span></div>
        <div className="room-code-form">
          <label htmlFor="room-code">Room code</label>
          <div><input id="room-code" value={joinCode} maxLength={6} autoCapitalize="characters" autoCorrect="off" placeholder="ABC123" aria-invalid={Boolean(error)} aria-describedby={error ? 'room-entry-error' : undefined} onChange={(event) => setJoinCode(event.target.value.toUpperCase().replace(/[^A-Z2-9]/g, ''))} /><button className="btn btn--secondary" disabled={busy || joinCode.length !== 6} onClick={handleJoin}>Join</button></div>
        </div>
        {error && <p id="room-entry-error" className="field__error" role="alert">{error}</p>}
      </div>
    )
  }

  return (
    <div className={`crew-room crew-room--${room?.theme ?? 'green'}`}>
      <section className="room-ticket">
        <div><span className="room-ticket__label">TONIGHT'S ROOM</span><h2>{room?.name ?? 'Loading the room…'}</h2><strong>{membership.code}</strong></div>
        <button className="btn btn--primary" onClick={handleShare}>Invite crew</button>
      </section>

      {(error || roomError) && <p className="inline-error" role="alert">{error || roomError}</p>}

      <section className="crew-section">
        <div className="section-heading"><h2>Who's in</h2><span>{room?.members.length ?? 0}/{20}</span></div>
        <ul className="squad squad--room">
          {(room?.members ?? []).map((member) => <MemberRow key={member.id} member={member} isSelf={member.id === membership.memberId} />)}
        </ul>
      </section>

      <section className="ritual-panel">
        <div className="section-heading"><h2>Make some noise</h2></div>
        {suggestedBuyer && <p className="ritual-panel__rota"><strong>Round rota:</strong> {suggestedBuyer.name} is up next · {room?.roundRota.length ?? 0} bought so far</p>}
        <div className="reaction-grid">
          {REACTIONS.map((reaction) => <button key={reaction.id} onClick={() => emit('reaction', { reaction: reaction.id })}><span aria-hidden="true">{reaction.icon}</span><small>{reaction.label}</small></button>)}
        </div>
        <div className="ritual-actions">
          <button className="btn btn--secondary" onClick={() => emit('cheers-countdown')}>🍻 Drink up in 8</button>
          <button className="btn btn--primary" disabled={Boolean(room?.activeRound)} onClick={() => emit('round-invite')}>Open next round</button>
        </div>
      </section>

      {room?.activeRound && (
        <section className="round-ticket">
          <div className="section-heading"><h2>{room.activeRound.buyerName}'s round</h2><span>OPEN</span></div>
          <ul>{room.activeRound.orders.map((item) => <li key={item.memberId}><strong>{item.memberName}</strong><span>{item.order}</span></li>)}</ul>
          {room.activeRound.buyerId === membership.memberId ? (
            <button className="btn btn--primary" onClick={() => emit('round-bought', { refId: room.activeRound!.id })}>Mark round bought</button>
          ) : (
            <div className="round-order"><label htmlFor="round-order">Your order</label><div><input id="round-order" value={order} maxLength={80} placeholder="Pint of lager" onChange={(event) => setOrder(event.target.value)} /><button className="btn btn--secondary" disabled={!order.trim()} onClick={() => { emit('round-order', { refId: room.activeRound!.id, text: order }); setOrder('') }}>Send</button></div></div>
          )}
        </section>
      )}

      <section className="crew-section">
        <div className="section-heading"><h2>Live from the group chat</h2><span>{room?.events.length ?? 0}</span></div>
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
      </section>

      {membership.isHost && room && (
        <details className="host-settings">
          <summary>Host settings</summary>
          <form onSubmit={async (event) => {
            event.preventDefault()
            const form = new FormData(event.currentTarget)
            const labels = Object.fromEntries(TARGET_ORDER.map((id) => [id, String(form.get(id) ?? '')])) as Record<TargetId, string>
            try { await configureRoom(membership, { name: String(form.get('name') ?? room.name), theme: String(form.get('theme')) as 'green' | 'red' | 'blue', labels }); refresh() } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save room settings') }
          }}>
            <label className="field"><span className="field__label">Room name</span><input name="name" defaultValue={room.name} maxLength={36} /></label>
            <label className="field"><span className="field__label">Room colour</span><select name="theme" defaultValue={room.theme}><option value="green">Bottle green</option><option value="red">Pub red</option><option value="blue">Electric blue</option></select></label>
            <div className="slang-grid">{TARGET_ORDER.map((id) => <label key={id}><span>{TARGETS[id].label}</span><input name={id} defaultValue={room.labels[id] ?? ''} placeholder="Keep default" maxLength={24} /></label>)}</div>
            <button className="btn btn--secondary" type="submit">Save room style</button>
          </form>
        </details>
      )}

      <details className="qr-panel"><summary>Show invite QR</summary>{qr && <img src={qr} alt={`QR code for Beerify room ${membership.code}`} />}</details>
      <button className="danger-link" onClick={() => { leaveRoom(membership).catch(() => {}); onLeave() }}>Leave room</button>
    </div>
  )
}
