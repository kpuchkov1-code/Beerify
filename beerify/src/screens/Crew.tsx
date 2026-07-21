import type { NightSession, Profile, RoomMembership } from '../types'
import RoomPanel from '../components/RoomPanel'

interface Props {
  profile: Profile
  membership: RoomMembership | null
  session: NightSession | null
  initialCode: string
  onJoin: (membership: RoomMembership) => void
  onLeave: () => void
  onOpenTonight: () => void
}

export default function Crew({ profile, membership, session, initialCode, onJoin, onLeave, onOpenTonight }: Props) {
  if (!session) return (
    <main className="screen crew-screen">
      <header className="page-header page-header--stacked"><span className="page-kicker">START TOGETHER</span><h1>Crew starts with the night</h1><p>Choose Squad in Tonight, then create or join once. The connection will stay fixed until your recap.</p></header>
      <button className="btn btn--primary btn--big" onClick={onOpenTonight}>Set up tonight →</button>
    </main>
  )

  if (session.nightMode === 'solo') return (
    <main className="screen crew-screen">
      <header className="page-header page-header--stacked"><span className="page-kicker">SOLO NIGHT</span><h1>You chose solo</h1><p>Crew stays off for this night. Your drinks, local games and crawl still work normally.</p></header>
      <p className="locked-room-copy">Solo or Squad is chosen once so the rest of the night never changes underneath you.</p>
      <button className="btn btn--primary" onClick={onOpenTonight}>Back to drinks</button>
    </main>
  )

  return (
    <main className="screen crew-screen">
      <header className="page-header page-header--stacked"><span className="page-kicker">THE GROUP CHAT, LIVE</span><h1>Crew</h1><p>Sort the round. React to the evidence. Keep the night moving.</p></header>
      {!membership && <p className="status-message" role="status">Your saved squad connection expired. Rejoin with the same code, or create a replacement squad; this night will stay in Squad mode.</p>}
      <RoomPanel profile={profile} membership={membership} session={session} initialCode={initialCode} onJoin={onJoin} onLeave={onLeave} onOpenTonight={onOpenTonight} lockMembership />
    </main>
  )
}
