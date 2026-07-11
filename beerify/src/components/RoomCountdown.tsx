import { useEffect, useState } from 'react'
import type { RoomEvent } from '../types'

interface Props {
  events: RoomEvent[]
}

export default function RoomCountdown({ events }: Props) {
  const [now, setNow] = useState(() => Date.now())
  const countdown = events.filter((event) => event.type === 'cheers-countdown' && event.startsAt && event.startsAt > now - 2_000).at(-1)
  const countdownNumber = countdown?.startsAt ? Math.max(0, Math.ceil((countdown.startsAt - now) / 1_000)) : null

  useEffect(() => {
    if (!countdown?.startsAt) return
    const id = setInterval(() => setNow(Date.now()), 250)
    return () => clearInterval(id)
  }, [countdown?.startsAt])

  if (countdownNumber === null) return null

  return (
    <div className="cheers-overlay" role="status" aria-live="assertive">
      <span>{countdownNumber > 0 ? countdownNumber : '🍻'}</span>
      <strong>{countdownNumber > 0 ? `${countdown?.actorName ?? 'The room'} called drink up` : 'CHEERS'}</strong>
    </div>
  )
}
