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
  return (
    <main className="screen crew-screen">
      <header className="page-header page-header--stacked"><span className="page-kicker">THE GROUP CHAT, LIVE</span><h1>Crew</h1><p>Sort the round. React to the evidence. Keep the night moving.</p></header>
      <RoomPanel profile={profile} membership={membership} session={session} initialCode={initialCode} onJoin={onJoin} onLeave={onLeave} onOpenTonight={onOpenTonight} />
    </main>
  )
}
