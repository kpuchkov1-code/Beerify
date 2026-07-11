export type AppTab = 'tonight' | 'crew' | 'history' | 'profile'

interface Props {
  active: AppTab
  roomActive: boolean
  onChange: (tab: AppTab) => void
}

const ITEMS: { id: AppTab; label: string; icon: string }[] = [
  { id: 'tonight', label: 'Tonight', icon: '☾' },
  { id: 'crew', label: 'Crew', icon: '♟' },
  { id: 'history', label: 'History', icon: '▤' },
  { id: 'profile', label: 'Profile', icon: '●' },
]

export default function AppNav({ active, roomActive, onChange }: Props) {
  return (
    <nav className="app-nav" aria-label="Main navigation">
      {ITEMS.map((item) => (
        <button
          key={item.id}
          className={active === item.id ? 'app-nav__item app-nav__item--active' : 'app-nav__item'}
          aria-current={active === item.id ? 'page' : undefined}
          onClick={() => onChange(item.id)}
        >
          <span className="app-nav__icon" aria-hidden="true">{item.icon}</span>
          <span>{item.label}</span>
          {item.id === 'crew' && roomActive && <span className="app-nav__dot" aria-label="Room active" />}
        </button>
      ))}
    </nav>
  )
}
