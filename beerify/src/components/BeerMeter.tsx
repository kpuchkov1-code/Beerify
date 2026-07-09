import type { Target } from '../types'
import { formatBac } from '../lib/bac'
import type { ZoneStatus } from '../lib/coach'

interface Props {
  bac: number
  /** highest BAC expected soon from drinks already in the belly */
  incoming: number
  target: Target
  status: ZoneStatus
}

const GAUGE_MAX = 0.14

const STATUS_LABEL: Record<ZoneStatus, string> = {
  sober: 'Sober',
  warming: 'Warming up',
  'in-zone': 'In your zone!',
  over: 'Over your zone',
  'way-over': 'Too far. Stop',
}

const STATUS_EMOJI: Record<ZoneStatus, string> = {
  sober: '🧊',
  warming: '🔥',
  'in-zone': '🎯',
  over: '🫗',
  'way-over': '🛑',
}

/* Interior of the glass in SVG coordinates */
const TOP = 22
const BOTTOM = 183
const HEIGHT = BOTTOM - TOP - 6 // headroom so a full mug still shows foam

function levelY(bac: number): number {
  const frac = Math.min(bac / GAUGE_MAX, 1)
  return BOTTOM - frac * HEIGHT
}

/** Two full sine periods, 75 units wide each half, used as a scrolling wave. */
const WAVE_TOP = 'M0 5 Q 9.4 0 18.75 5 T 37.5 5 T 56.25 5 T 75 5 T 93.75 5 T 112.5 5 T 131.25 5 T 150 5'
const WAVE = `${WAVE_TOP} V 200 H 0 Z`
/** Same wave crest but closed shallowly, for the foam band. */
const FOAM_BAND = `${WAVE_TOP} V 18 H 0 Z`

const BUBBLES = [
  { cx: 42, r: 3.4, depth: 120, dur: 3.2, delay: 0 },
  { cx: 55, r: 2.2, depth: 90, dur: 2.4, delay: -1.1 },
  { cx: 68, r: 3, depth: 140, dur: 3.8, delay: -2 },
  { cx: 82, r: 2.6, depth: 105, dur: 2.8, delay: -0.5 },
  { cx: 92, r: 2, depth: 75, dur: 2.2, delay: -1.6 },
]

export default function BeerMeter({ bac, incoming, target, status }: Props) {
  const surface = levelY(bac)
  const incomingSurface = levelY(Math.max(incoming, bac))
  const zoneTop = levelY(target.maxBac)
  const zoneBottom = levelY(target.minBac)
  const hasBeer = bac > 0.001
  const showIncoming = surface - incomingSurface > 2
  const displayed = formatBac(bac)

  return (
    <div className={`meter meter--${status}`}>
      <svg
        className="mug-svg"
        viewBox="0 0 168 208"
        role="img"
        aria-label={`Beer glass showing estimated blood alcohol ${displayed} percent. ${STATUS_LABEL[status]}`}
      >
        <defs>
          <clipPath id="mug-clip">
            <path d="M29 19 H104 V158 A23 23 0 0 1 81 181 H52 A23 23 0 0 1 29 158 Z" />
          </clipPath>
          <linearGradient id="beer-grad" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#ffc453" />
            <stop offset="0.6" stopColor="#ff9500" />
            <stop offset="1" stopColor="#ef7f00" />
          </linearGradient>
          <linearGradient id="glass-grad" x1="0" y1="0" x2="1" y2="0.15">
            <stop offset="0" stopColor="#fbfdff" />
            <stop offset="0.5" stopColor="#eef3f9" />
            <stop offset="1" stopColor="#f8fbff" />
          </linearGradient>
        </defs>

        {/* handle */}
        <path
          className="mug-svg__handle"
          d="M107 62 h16 a22 22 0 0 1 22 22 v22 a22 22 0 0 1 -22 22 h-16"
        />

        {/* glass body */}
        <path
          className="mug-svg__glass"
          d="M26 16 H107 V158 A26 26 0 0 1 81 184 H52 A26 26 0 0 1 26 158 Z"
          fill="url(#glass-grad)"
        />

        <g clipPath="url(#mug-clip)">
          {/* incoming (still absorbing) ghost fill */}
          {showIncoming && (
            <g
              className="mug-svg__incoming-group"
              style={{ transform: `translateY(${incomingSurface}px)` }}
            >
              <rect className="mug-svg__incoming" x="29" width="75" y="0" height="200" />
              <line className="mug-svg__incoming-line" x1="29" x2="104" y1="0" y2="0" />
            </g>
          )}

          {/* liquid, anchored at the surface so waves + bubbles ride the level */}
          <g
            className="mug-svg__liquid"
            style={{ transform: `translateY(${surface}px)`, opacity: hasBeer ? 1 : 0 }}
          >
            <g className="mug-svg__wave-back">
              <path d={WAVE} transform="translate(-46 -6.5)" fill="#ffd88a" opacity="0.9" />
            </g>
            <g className="mug-svg__wave">
              <path d={WAVE} transform="translate(-46 -2)" fill="url(#beer-grad)" />
            </g>
            {BUBBLES.map((b, i) => (
              <circle
                key={i}
                className="mug-svg__bubble"
                cx={b.cx}
                cy={0}
                r={b.r}
                style={
                  {
                    '--depth': `${b.depth}px`,
                    animationDuration: `${b.dur}s`,
                    animationDelay: `${b.delay}s`,
                  } as React.CSSProperties
                }
              />
            ))}
            {/* foam riding the surface */}
            <g className="mug-svg__foam">
              <path d={FOAM_BAND} transform="translate(-46 -10)" fill="#fffdf6" />
              <path d={FOAM_BAND} transform="translate(-84 -14) scale(1 0.7)" fill="#ffffff" opacity="0.85" />
            </g>
          </g>

          {/* target zone band */}
          <g className="mug-svg__zone">
            <rect x="29" width="75" y={zoneTop} height={zoneBottom - zoneTop} />
            <line x1="29" x2="104" y1={zoneTop} y2={zoneTop} />
            <line x1="29" x2="104" y1={zoneBottom} y2={zoneBottom} />
          </g>

          {/* glass shine */}
          <rect className="mug-svg__shine" x="36" y="26" width="9" height="140" rx="4.5" />
          <rect className="mug-svg__shine" x="50" y="26" width="4" height="140" rx="2" opacity="0.5" />
        </g>

        {/* zone tag riding the band */}
        <g
          className="mug-svg__zone-tag"
          transform={`translate(66.5 ${(zoneTop + zoneBottom) / 2}) rotate(-4)`}
        >
          <rect x="-31" y="-9.5" width="62" height="19" rx="9.5" />
          <text x="0" y="4">
            {target.emoji} zone
          </text>
        </g>

        {/* outline drawn last so it stays crisp above the liquid */}
        <path
          className="mug-svg__outline"
          d="M26 16 H107 V158 A26 26 0 0 1 81 184 H52 A26 26 0 0 1 26 158 Z"
        />
        <path className="mug-svg__base" d="M18 194 H115" />

        {!hasBeer && !showIncoming && (
          <text className="mug-svg__empty" x="66.5" y="160">
            🌵
          </text>
        )}
      </svg>

      <div className="meter__info">
        <span className="meter__value" key={displayed}>
          {displayed}
        </span>
        <span className="meter__unit">est. BAC %</span>
        <span className="meter__status" key={status}>
          {STATUS_EMOJI[status]} {STATUS_LABEL[status]}
        </span>
        {showIncoming && (
          <span className="meter__incoming-hint">
            <span className="meter__incoming-dot" /> more still kicking in
          </span>
        )}
      </div>
    </div>
  )
}
