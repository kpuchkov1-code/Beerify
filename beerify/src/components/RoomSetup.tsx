import { useEffect, useState } from 'react'
import type { RoomMembership, SquadMember } from '../types'
import { createRoom, joinRoom } from '../lib/room'
import { newId } from '../lib/storage'

interface Props {
  profileName: string
  member: Omit<SquadMember, 'id' | 'updatedAt'>
  initialCode?: string
  onJoined: (membership: RoomMembership) => void
}

export default function RoomSetup({ profileName, member, initialCode = '', onJoined }: Props) {
  const [joinCode, setJoinCode] = useState(initialCode)
  const [busy, setBusy] = useState<'create' | 'join' | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => { if (initialCode) setJoinCode(initialCode) }, [initialCode])

  async function create() {
    setBusy('create'); setError(null)
    try { onJoined((await createRoom(profileName, member, newId(), 'balanced')).membership) }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not open a squad') }
    finally { setBusy(null) }
  }

  async function join() {
    const code = joinCode.trim().toUpperCase()
    if (!/^[A-Z2-9]{6}$/.test(code)) { setError('Room codes use 6 letters or numbers'); return }
    setBusy('join'); setError(null)
    try { onJoined((await joinRoom(code, member, newId())).membership) }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not join that squad') }
    finally { setBusy(null) }
  }

  return (
    <div className="room-entry" aria-busy={Boolean(busy)}>
      <section className="room-entry__create">
        <span className="room-entry__mark" aria-hidden="true">♟</span>
        <h2>Start a new squad</h2>
        <p>You host once. Drinks, games, the crawl and scores stay connected for the whole night.</p>
        <button className="btn btn--primary btn--big" disabled={Boolean(busy)} onClick={() => void create()}>{busy === 'create' ? 'Opening squad…' : 'Create squad'}</button>
      </section>
      <div className="room-entry__or"><span>or join your crew</span></div>
      <form className="room-code-form" onSubmit={(event) => { event.preventDefault(); void join() }}>
        <label htmlFor="room-code">Squad code</label>
        <div><input id="room-code" value={joinCode} maxLength={6} autoCapitalize="characters" autoCorrect="off" inputMode="text" placeholder="ABC123" aria-invalid={Boolean(error)} aria-describedby={error ? 'room-entry-error' : undefined} onChange={(event) => setJoinCode(event.target.value.toUpperCase().replace(/[^A-Z2-9]/g, ''))} /><button className="btn btn--secondary" disabled={Boolean(busy) || joinCode.length !== 6}>{busy === 'join' ? 'Joining…' : 'Join'}</button></div>
      </form>
      {error && <p id="room-entry-error" className="field__error" role="alert">{error}</p>}
    </div>
  )
}
