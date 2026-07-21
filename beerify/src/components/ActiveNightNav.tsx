import type { AppTab } from './AppNav'

interface Props {
  active: AppTab
  roomActive: boolean
  onChange: (tab: AppTab) => void
}

const MORE_ID = 'active-night-more'

export default function ActiveNightNav({ active, roomActive, onChange }: Props) {
  function open(tab: AppTab) {
    const menu = document.getElementById(MORE_ID)
    if (menu?.matches(':popover-open')) menu.hidePopover()
    onChange(tab)
  }

  const moreActive = active === 'pubs' || active === 'stats' || active === 'history' || active === 'profile'

  return (
    <>
      <nav className="active-night-nav" aria-label="Active night navigation">
        <button className={active === 'tonight' ? 'active-night-nav__item active-night-nav__item--active' : 'active-night-nav__item'} aria-current={active === 'tonight' ? 'page' : undefined} onClick={() => onChange('tonight')}><span className="active-night-nav__icon" aria-hidden="true">🍺</span><span>Drinks</span></button>
        <button className={active === 'crew' ? 'active-night-nav__item active-night-nav__item--active' : 'active-night-nav__item'} aria-current={active === 'crew' ? 'page' : undefined} onClick={() => onChange('crew')}><span className="active-night-nav__icon" aria-hidden="true">♟</span><span>Crew</span>{roomActive && <span className="app-nav__dot" aria-label="Room active" />}</button>
        <button className={active === 'games' ? 'active-night-nav__item active-night-nav__item--active' : 'active-night-nav__item'} aria-current={active === 'games' ? 'page' : undefined} onClick={() => onChange('games')}><span className="active-night-nav__icon" aria-hidden="true">♠</span><span>Games</span></button>
        <button className={moreActive ? 'active-night-nav__item active-night-nav__item--active' : 'active-night-nav__item'} popoverTarget={MORE_ID}><span className="active-night-nav__icon" aria-hidden="true">•••</span><span>More</span></button>
      </nav>
      <div id={MORE_ID} className="active-night-more" popover="auto" aria-label="More destinations">
        <button aria-current={active === 'pubs' ? 'page' : undefined} onClick={() => open('pubs')}><span aria-hidden="true">⌖</span><span><strong>Pubs</strong><small>Map, crawl, golf and bingo</small></span></button>
        <button aria-current={active === 'stats' ? 'page' : undefined} onClick={() => open('stats')}><span aria-hidden="true">↗</span><span><strong>Stats & badges</strong><small>Totals, records and wins</small></span></button>
        <button aria-current={active === 'history' ? 'page' : undefined} onClick={() => open('history')}><span aria-hidden="true">▤</span><span><strong>History</strong><small>Past nights and recaps</small></span></button>
        <button aria-current={active === 'profile' ? 'page' : undefined} onClick={() => open('profile')}><span aria-hidden="true">●</span><span><strong>Profile</strong><small>Modes, look and preferences</small></span></button>
      </div>
    </>
  )
}
