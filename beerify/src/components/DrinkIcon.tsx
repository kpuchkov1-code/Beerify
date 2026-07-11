import type { DrinkIconId } from '../types'

interface Props {
  icon: DrinkIconId
  size?: number
  title?: string
  logoUrl?: string
  brand?: string
}

export default function DrinkIcon({ icon, size = 42, title, logoUrl, brand }: Props) {
  if (logoUrl && brand) {
    return (
      <span className="brand-artwork" style={{ width: size, height: size }} title={title ?? brand} aria-hidden="true">
        <span>{brand.slice(0, 1)}</span>
        <img src={logoUrl} width={size} height={size} alt="" onError={(event) => { event.currentTarget.hidden = true }} />
      </span>
    )
  }
  const bottle = icon === 'bottle' || icon === 'alcopop' || icon === 'zero'
  const wine = icon === 'wine-red' || icon === 'wine-white' || icon === 'sparkling'
  const pint = ['pint', 'ipa', 'stout', 'cider', 'ale'].includes(icon)
  const fill = icon === 'stout' ? '#2a1710' : icon === 'wine-red' ? '#8d2235' : icon === 'wine-white' || icon === 'sparkling' ? '#f2d678' : icon === 'zero' ? '#4ab7a8' : '#ffb52d'

  return (
    <svg
      className={`drink-icon drink-icon--${icon}`}
      width={size}
      height={size}
      viewBox="0 0 48 48"
      role={title ? 'img' : undefined}
      aria-hidden={title ? undefined : true}
      aria-label={title}
    >
      {pint && (
        <>
          <path d="M10 8h25l-2.2 34H13z" fill="#f7f7f4" stroke="currentColor" strokeWidth="2.5" strokeLinejoin="round" />
          <path d="M13 17h19.2L30.8 39H14.5z" fill={fill} />
          <path d="M12 15c3-3 5 2 8-1s5 2 8-1 4 2 5 0" fill="none" stroke="#fff" strokeWidth="4" strokeLinecap="round" />
          {icon === 'ipa' && <path d="M20 22l7 10M27 22l-7 10" stroke="#fff2c5" strokeWidth="2" />}
        </>
      )}
      {bottle && (
        <>
          <path d="M19 4h10v9l4 6v24H15V19l4-6z" fill={icon === 'zero' ? '#2a655f' : '#2d5c3f'} stroke="currentColor" strokeWidth="2.5" strokeLinejoin="round" />
          <rect x="17" y="23" width="14" height="12" rx="2" fill={fill} />
          <path d="M20 8h8" stroke="#f7f7f4" strokeWidth="2" />
        </>
      )}
      {icon === 'can' && (
        <>
          <rect x="14" y="5" width="20" height="38" rx="5" fill="#d9ddd9" stroke="currentColor" strokeWidth="2.5" />
          <path d="M15 15h18v19H15z" fill={fill} />
          <path d="M20 9h8" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
        </>
      )}
      {wine && (
        <>
          <path d="M14 7h20l-2 14c-.6 5-3.8 8-8 8s-7.4-3-8-8z" fill="#f7f7f4" stroke="currentColor" strokeWidth="2.5" />
          <path d="M17 17h14l-.6 4c-.4 3.4-2.7 5.5-6.4 5.5s-6-2.1-6.4-5.5z" fill={fill} />
          <path d="M24 29v10m-7 4h14" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" />
        </>
      )}
      {icon === 'spirit' && (
        <>
          <path d="M13 17h22l-3 25H16z" fill="#f7f7f4" stroke="currentColor" strokeWidth="2.5" strokeLinejoin="round" />
          <path d="M16 29h16l-1.3 10H17.2z" fill="#c9853b" />
          <path d="M18 8h12l3 9H15z" fill="#edf0ec" stroke="currentColor" strokeWidth="2.5" />
        </>
      )}
      {icon === 'cocktail' && (
        <>
          <path d="M7 8h34L24 27z" fill="#e75d72" stroke="currentColor" strokeWidth="2.5" strokeLinejoin="round" />
          <path d="M24 27v12m-8 4h16" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" />
          <circle cx="34" cy="9" r="5" fill="#ffb52d" stroke="currentColor" strokeWidth="2" />
        </>
      )}
      {icon === 'shot' && (
        <>
          <path d="M14 12h20l-2 29H16z" fill="#f7f7f4" stroke="currentColor" strokeWidth="2.5" strokeLinejoin="round" />
          <path d="M17 26h14l-1 12H18z" fill="#72b7d6" />
        </>
      )}
    </svg>
  )
}
