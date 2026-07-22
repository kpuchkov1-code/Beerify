import type { NightSession } from '../types'
import AppIcon, { type IconName } from './AppIcon'

export type PrimaryTab = 'tonight' | 'games' | 'pubs' | 'nights' | 'crew' | 'you'

interface Props {
  active: PrimaryTab
  session: NightSession | null
  roomActive: boolean
  onChange: (tab: PrimaryTab) => void
}

export default function PrimaryNav({ active, session, roomActive, onChange }: Props) {
  const squad = session?.nightMode === 'group'
  const items: { id: PrimaryTab; label: string; icon: IconName; status?: boolean }[] = [
    { id: 'tonight', label: session ? 'Drinks' : 'Tonight', icon: session ? 'beer' : 'moon' },
    { id: 'games', label: 'Games', icon: 'gamepad' },
    { id: 'pubs', label: 'Pubs', icon: 'map' },
    squad ? { id: 'crew', label: 'Crew', icon: 'users', status: !roomActive } : { id: 'nights', label: 'Nights', icon: 'receipt' },
    { id: 'you', label: 'You', icon: 'user' },
  ]

  return <nav className="primary-nav" aria-label="Primary navigation">{items.map((item) => <button key={item.id} className={active === item.id ? 'primary-nav__item primary-nav__item--active' : 'primary-nav__item'} aria-current={active === item.id ? 'page' : undefined} onClick={() => onChange(item.id)}><AppIcon name={item.icon} size={22} /><span>{item.label}</span>{item.status && <span className="primary-nav__status" aria-label="Reconnect required" />}</button>)}</nav>
}
