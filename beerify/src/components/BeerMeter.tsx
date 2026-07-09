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

function toPct(bac: number): number {
  return Math.min(bac / GAUGE_MAX, 1) * 100
}

export default function BeerMeter({ bac, incoming, target, status }: Props) {
  const pct = toPct(bac)
  const incomingPct = toPct(Math.max(incoming, bac))
  const zoneBottom = toPct(target.minBac)
  const zoneHeight = toPct(target.maxBac) - zoneBottom
  const showIncoming = incomingPct - pct > 1
  const hasBeer = pct > 0.5
  const displayed = formatBac(bac)

  return (
    <div className={`meter meter--${status}`}>
      <div className="mug">
        <div className="mug__handle" />
        <div className="mug__glass">
          <div
            className="mug__zone"
            style={{ bottom: `${zoneBottom}%`, height: `${zoneHeight}%` }}
          >
            <span className="mug__zone-tag">{target.emoji} zone</span>
          </div>
          {showIncoming && (
            <div className="mug__incoming" style={{ height: `${incomingPct}%` }} />
          )}
          <div
            className={`mug__liquid ${hasBeer ? '' : 'mug__liquid--empty'}`}
            style={{ height: `${Math.max(pct, hasBeer ? 4 : 0)}%` }}
          >
            <div className="mug__foam">
              <span />
              <span />
              <span />
              <span />
              <span />
            </div>
            <span className="mug__bubble mug__bubble--1" />
            <span className="mug__bubble mug__bubble--2" />
            <span className="mug__bubble mug__bubble--3" />
            <span className="mug__bubble mug__bubble--4" />
            <span className="mug__bubble mug__bubble--5" />
          </div>
          {!hasBeer && !showIncoming && <span className="mug__empty-hint">🌵</span>}
        </div>
        <div className="mug__base" />
      </div>

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
