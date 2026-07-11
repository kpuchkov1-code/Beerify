import type { SquadMember } from '../types'
import { avatarFor } from '../lib/room'
import { TARGETS } from '../lib/drinks'
import { formatBac } from '../lib/bac'
import { formatUnits } from '../lib/format'

const STATUS_LABEL: Record<string, string> = {
  sober: 'Off duty',
  warming: 'Loading',
  'in-zone': 'Brief achieved',
  over: 'Freelancing',
  'way-over': 'Cooked',
}

function timeAgo(epoch: number): string {
  const mins = Math.round((Date.now() - epoch) / 60_000)
  if (mins < 2) return 'just now'
  if (mins < 60) return `${mins}m ago`
  return `${Math.round(mins / 60)}h ago`
}

interface MemberRowProps {
  member: SquadMember
  isSelf: boolean
}

export function MemberRow({ member, isSelf }: MemberRowProps) {
  const target = TARGETS[member.targetId] ?? TARGETS.tipsy
  const stale = Date.now() - member.updatedAt > 10 * 60_000
  const resting = !member.inSession || stale
  const fillPct = Math.min(member.bac / 0.14, 1) * 100

  return (
    <li className={`squad__row ${member.status === 'way-over' && !resting ? 'squad__row--alert' : ''}`}>
      <span className="squad__avatar">{avatarFor(member.id)}</span>
      <span className="squad__who">
        <span className="squad__name">
          {member.name}
          {isSelf && <em> (you)</em>}
        </span>
        <span className="squad__detail">
          {resting
            ? `Resting · ${timeAgo(member.updatedAt)}`
            : `${STATUS_LABEL[member.status] ?? 'Out'} · ${member.drinks} drink${member.drinks === 1 ? '' : 's'} · ${formatUnits(member.units)} units`}
        </span>
      </span>
      {!resting && (
        <span className="squad__meter" title={`Estimated BAC ${formatBac(member.bac)}%`}>
          <span className="squad__meter-glass">
            <span className="squad__meter-fill" style={{ height: `${Math.max(fillPct, 4)}%` }} />
          </span>
          <span className="squad__meter-target">{target.emoji}</span>
        </span>
      )}
    </li>
  )
}
