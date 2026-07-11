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
    let id: ReturnType<typeof setInterval> | null = null
    const update = () => {
      if (id) clearInterval(id)
      id = null
      setNow(Date.now())
      if (!document.hidden) id = setInterval(() => setNow(Date.now()), 250)
    }
    update()
    document.addEventListener('visibilitychange', update)
    return () => { if (id) clearInterval(id); document.removeEventListener('visibilitychange', update) }
  }, [countdown?.startsAt])

  if (countdownNumber === null) return null

  return (
    <div className="cheers-overlay" role="status" aria-live="assertive">
      <span>{countdownNumber > 0 ? countdownNumber : '🍻'}</span>
      <strong>{countdownNumber > 0 ? `${countdown?.actorName ?? 'The room'} called drink up` : 'CHEERS'}</strong>
    </div>
  )
}
