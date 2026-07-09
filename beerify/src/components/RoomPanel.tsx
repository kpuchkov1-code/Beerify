import { useState } from 'react'
import type { Profile, RoomMembership } from '../types'
import { createRoom, fetchRoom, leaveRoom, newMemberId, useRoom } from '../lib/room'
import { MemberRow } from './Squad'

interface Props {
  profile: Profile
  membership: RoomMembership | null
  onJoin: (membership: RoomMembership) => void
  onLeave: () => void
}

/** Room management shown on the home screen. */
export default function RoomPanel({ profile, membership, onJoin, onLeave }: Props) {
  const [joinCode, setJoinCode] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // From home we report a "resting" snapshot so friends see we're not out.
  const self = membership
    ? {
        id: membership.memberId,
        name: profile.name,
        bac: 0,
        units: 0,
        drinks: 0,
        targetId: 'tipsy' as const,
        status: 'sober',
        inSession: false,
      }
    : null
  const { room, error: roomError } = useRoom(membership, self, 30_000)

  async function handleCreate() {
    setBusy(true)
    setError(null)
    try {
      const code = await createRoom()
      onJoin({ code, memberId: newMemberId() })
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not create a room')
    } finally {
      setBusy(false)
    }
  }

  async function handleJoin() {
    const code = joinCode.trim().toUpperCase()
    if (code.length !== 4) {
      setError('Room codes are 4 characters')
      return
    }
    setBusy(true)
    setError(null)
    try {
      await fetchRoom(code)
      onJoin({ code, memberId: newMemberId() })
      setJoinCode('')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not join that room')
    } finally {
      setBusy(false)
    }
  }

  async function handleLeave() {
    if (membership) {
      leaveRoom(membership.code, membership.memberId).catch(() => {
        // Best effort: the membership TTL cleans up if this fails.
      })
    }
    onLeave()
  }

  async function handleShare() {
    if (!membership) return
    const text = `Join my Beerify room tonight! Code: ${membership.code} · ${location.origin}`
    if (navigator.share) {
      navigator.share({ text }).catch(() => {})
    } else {
      await navigator.clipboard.writeText(text)
    }
  }

  if (!membership) {
    return (
      <section className="room-panel">
        <h2 className="section-title">Drink with friends</h2>
        <div className="card room-panel__card">
          <p className="room-panel__pitch">
            👯 Make a room, share the code, and keep an eye on each other's mugs all night.
          </p>
          <button className="btn btn--primary" disabled={busy} onClick={handleCreate}>
            Create a room
          </button>
          <div className="room-panel__join">
            <input
              type="text"
              value={joinCode}
              placeholder="CODE"
              maxLength={4}
              autoCapitalize="characters"
              autoCorrect="off"
              onChange={(e) => setJoinCode(e.target.value.toUpperCase())}
            />
            <button className="btn btn--secondary" disabled={busy || joinCode.length !== 4} onClick={handleJoin}>
              Join
            </button>
          </div>
          {error && <p className="field__error">{error}</p>}
        </div>
      </section>
    )
  }

  return (
    <section className="room-panel">
      <h2 className="section-title">Your room</h2>
      <div className="card room-panel__card">
        <div className="room-panel__code-row">
          <div>
            <span className="room-panel__code">{membership.code}</span>
            <span className="room-panel__code-hint">share this code</span>
          </div>
          <button className="btn btn--secondary btn--small" onClick={handleShare}>
            Share 📤
          </button>
        </div>
        {roomError && !room && <p className="field__error">{roomError}</p>}
        <ul className="squad">
          {(room?.members ?? []).map((m) => (
            <MemberRow key={m.id} member={m} isSelf={m.id === membership.memberId} />
          ))}
        </ul>
        {room && room.members.length <= 1 && (
          <p className="room-panel__empty">Just you so far. Send the code to your crew!</p>
        )}
        <button className="btn btn--quiet" onClick={handleLeave}>
          Leave room
        </button>
      </div>
    </section>
  )
}
