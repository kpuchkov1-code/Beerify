import type { Target } from '../types'
import { formatBac } from '../lib/bac'
import type { ZoneStatus } from '../lib/coach'

interface Props {
  bac: number
  target: Target
  status: ZoneStatus
}

const GAUGE_MAX = 0.12

const STATUS_LABEL: Record<ZoneStatus, string> = {
  sober: 'Sober',
  warming: 'Warming up',
  'in-zone': 'In the zone',
  over: 'Over target',
  'way-over': 'Way over — stop',
}

export default function BacGauge({ bac, target, status }: Props) {
  const pct = Math.min(bac / GAUGE_MAX, 1) * 100
  const zoneStart = (target.minBac / GAUGE_MAX) * 100
  const zoneWidth = ((target.maxBac - target.minBac) / GAUGE_MAX) * 100

  return (
    <div className={`gauge gauge--${status}`}>
      <div className="gauge__readout">
        <span className="gauge__value">{formatBac(bac)}</span>
        <span className="gauge__unit">est. BAC%</span>
      </div>
      <div className="gauge__status">{STATUS_LABEL[status]}</div>
      <div className="gauge__track" role="img" aria-label={`Estimated blood alcohol ${formatBac(bac)} percent, ${STATUS_LABEL[status]}`}>
        <div
          className="gauge__zone"
          style={{ left: `${zoneStart}%`, width: `${zoneWidth}%` }}
        />
        <div className="gauge__fill" style={{ width: `${pct}%` }} />
        <div className="gauge__marker" style={{ left: `${pct}%` }} />
      </div>
      <div className="gauge__legend">
        <span>sober</span>
        <span className="gauge__legend-zone">
          {target.emoji} your zone
        </span>
        <span>too much</span>
      </div>
    </div>
  )
}
