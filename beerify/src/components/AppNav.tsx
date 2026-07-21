export type AppTab = 'tonight' | 'crew' | 'games' | 'pubs' | 'stats' | 'history' | 'profile'

interface Props {
  active: AppTab
  roomActive: boolean
  onChange: (tab: AppTab) => void
}

const MORE_ID = 'main-more-menu'

export default function AppNav({ active, roomActive, onChange }: Props) {
  function open(tab: AppTab) {
    const menu = document.getElementById(MORE_ID)
    if (menu?.matches(':popover-open')) menu.hidePopover()
    onChange(tab)
  }

  const moreActive = active === 'stats' || active === 'history' || active === 'profile'

  return (
    <>
      <nav className="app-nav" aria-label="Main navigation">
        <button className={active === 'tonight' ? 'app-nav__item app-nav__item--active' : 'app-nav__item'} aria-current={active === 'tonight' ? 'page' : undefined} onClick={() => onChange('tonight')}><span className="app-nav__icon" aria-hidden="true">☾</span><span>Tonight</span></button>
        <button className={active === 'crew' ? 'app-nav__item app-nav__item--active' : 'app-nav__item'} aria-current={active === 'crew' ? 'page' : undefined} onClick={() => onChange('crew')}><span className="app-nav__icon" aria-hidden="true">♟</span><span>Crew</span>{roomActive && <span className="app-nav__dot" aria-label="Room active" />}</button>
        <button className={active === 'games' ? 'app-nav__item app-nav__item--active' : 'app-nav__item'} aria-current={active === 'games' ? 'page' : undefined} onClick={() => onChange('games')}><span className="app-nav__icon" aria-hidden="true">♠</span><span>Games</span></button>
        <button className={active === 'pubs' ? 'app-nav__item app-nav__item--active' : 'app-nav__item'} aria-current={active === 'pubs' ? 'page' : undefined} onClick={() => onChange('pubs')}><span className="app-nav__icon" aria-hidden="true">⌖</span><span>Pubs</span></button>
        <button className={moreActive ? 'app-nav__item app-nav__item--active' : 'app-nav__item'} popoverTarget={MORE_ID}><span className="app-nav__icon" aria-hidden="true">•••</span><span>More</span></button>
      </nav>
      <div id={MORE_ID} className="active-night-more" popover="auto" aria-label="More destinations">
        <button aria-current={active === 'stats' ? 'page' : undefined} onClick={() => open('stats')}><span aria-hidden="true">↗</span><span><strong>Stats & badges</strong><small>Your totals, records and wins</small></span></button>
        <button aria-current={active === 'history' ? 'page' : undefined} onClick={() => open('history')}><span aria-hidden="true">▤</span><span><strong>History</strong><small>Past nights and recaps</small></span></button>
        <button aria-current={active === 'profile' ? 'page' : undefined} onClick={() => open('profile')}><span aria-hidden="true">●</span><span><strong>Profile</strong><small>Modes, look and preferences</small></span></button>
      </div>
    </>
  )
}
