import type { Target } from '../types'
import { formatBac } from '../lib/bac'
import type { ZoneStatus } from '../lib/coach'

interface Props {
  bac: number
  /** BAC once everything already drunk has been absorbed */
  incoming: number
  target: Target
  status: ZoneStatus
}

const GAUGE_MAX = 0.14

const STATUS_LABEL: Record<ZoneStatus, string> = {
  sober: 'Sober',
  warming: 'Warming up',
  'in-zone': 'In your zone',
  over: 'Over your zone',
  'way-over': 'Too far. Stop',
}

export default function BacGauge({ bac, incoming, target, status }: Props) {
  const pct = Math.min(bac / GAUGE_MAX, 1) * 100
  const incomingPct = Math.min(Math.max(incoming, bac) / GAUGE_MAX, 1) * 100
  const zoneStart = (target.minBac / GAUGE_MAX) * 100
  const zoneWidth = ((target.maxBac - target.minBac) / GAUGE_MAX) * 100
  const showIncoming = incomingPct - pct > 0.5

  return (
    <div className={`gauge gauge--${status}`}>
      <div className="gauge__top">
        <div className="gauge__readout">
          <span className="gauge__value">{formatBac(bac)}</span>
          <span className="gauge__unit">est. BAC %</span>
        </div>
        <span className="gauge__status">{STATUS_LABEL[status]}</span>
      </div>
      <div
        className="gauge__track"
        role="img"
        aria-label={`Estimated blood alcohol ${formatBac(bac)} percent. ${STATUS_LABEL[status]}`}
      >
        <div className="gauge__zone" style={{ left: `${zoneStart}%`, width: `${zoneWidth}%` }} />
        {showIncoming && (
          <div className="gauge__incoming" style={{ width: `${incomingPct}%` }} />
        )}
        <div className="gauge__fill" style={{ width: `${pct}%` }} />
      </div>
      <div className="gauge__legend">
        <span>Sober</span>
        <span className="gauge__legend-zone">{target.emoji} Your zone</span>
        <span>Too much</span>
      </div>
      {showIncoming && (
        <p className="gauge__hint">The lighter bar is alcohol still kicking in.</p>
      )}
    </div>
  )
}
