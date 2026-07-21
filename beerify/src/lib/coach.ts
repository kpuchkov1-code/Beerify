import type { CoachMessage, CoachPersonality, NightSession, Profile, ZoneStatus } from '../types'
import { bacTimeline, estimateBac, fullyAbsorbedAt, minutesUntilBac, projectBac } from './bac'
import { TARGETS } from './drinks'

export type { ZoneStatus } from '../types'

function pick<T>(values: T[], seed: number): T {
  return values[Math.abs(seed) % values.length]
}

export function zoneStatus(bac: number, session: NightSession): ZoneStatus {
  const target = session.targetSnapshot ?? TARGETS[session.targetId]
  if (bac < 0.005) return 'sober'
  if (bac < target.minBac) return 'warming'
  if (bac <= target.maxBac) return 'in-zone'
  if (bac <= target.maxBac + 0.03) return 'over'
  return 'way-over'
}

function minutesSinceLastDrink(session: NightSession, now: number): number | null {
  const last = session.drinks.at(-1)
  return last ? (now - last.at) / 60_000 : null
}

function recentWater(session: NightSession, now: number): boolean {
  return session.waters.some((at) => now - at < 45 * 60_000)
}

function baseCoachMessage(session: NightSession, profile: Profile, now: number): CoachMessage {
  const bac = estimateBac(session.drinks, profile, now, session.mealState)
  const inThirty = projectBac(session.drinks, profile, now, 30, session.mealState)
  const rising = inThirty > bac + 0.002
  const status = zoneStatus(bac, session)
  const target = session.targetSnapshot ?? TARGETS[session.targetId]
  const seed = session.drinks.length * 7 + session.waters.length * 3 + Math.floor(now / 600_000)
  const sinceLast = minutesSinceLastDrink(session, now)
  const hadWater = recentWater(session, now)
  const firstName = profile.name.split(' ')[0] || 'mate'
  const credentialLine = {
    'one-pint': `One-pint wonder status: every tap is headline news.`,
    weekend: `Weekend athlete reporting for duty.`,
    regular: `Pub furniture has entered the building.`,
    'full-time': `Allegedly full-time. Still waiting for the first order.`,
  }[profile.drinkerLevel]

  if (session.drinks.length === 0) {
    return {
      tone: 'cheer',
      text: pick([
        `Night's young, ${firstName}. First order when you're ready.`,
        `${target.label} mode selected. Let's see where the plot goes.`,
        credentialLine,
      ], seed),
      tip: 'Log from the label for the best estimate.',
    }
  }

  if (status === 'sober') {
    return sinceLast !== null && sinceLast < 25
      ? { tone: 'cheer', text: `That one's still loading. Give it a minute before reviewing the patch.` }
      : { tone: 'chill', text: `Back near zero. A rare display of administrative competence.` }
  }

  if (status === 'warming') {
    return rising
      ? {
          tone: 'cheer',
          text: pick([
            `Booting up nicely. ${target.label} is on the way.`,
            `Still loading. No need to mash refresh.`,
            `The confidence update is installing now.`,
          ], seed),
          tip: sinceLast !== null && sinceLast < 10 ? 'That last one has barely landed.' : undefined,
        }
      : { tone: 'chill', text: `The buzz is clocking off. Your move.` }
  }

  if (status === 'in-zone') {
    const overshoot = rising && projectBac(session.drinks, profile, now, 45, session.mealState) > target.maxBac
    if (overshoot) {
      return {
        tone: 'nudge',
        text: `You're ${target.label.toLowerCase()} now, with more still loading. That's tomorrow's problem forming live.`,
        tip: hadWater ? undefined : 'Water buys the current plot a longer run.',
      }
    }
    const lines = session.targetId === 'merry'
      ? [`Operating entirely on vibes.`, `Battered: achieved with suspicious efficiency.`]
      : session.targetId === 'bignight'
        ? [`Blackout territory. Tomorrow gets the patch notes.`, `The timeline has become unreliable.`]
        : [`Bang on ${target.label.toLowerCase()}.`, `Exactly the chaos level requested.`]
    return { tone: 'cheer', text: pick(lines, seed), tip: hadWater ? undefined : 'A water keeps the group chat coherent.' }
  }

  const minsBack = minutesUntilBac(session.drinks, profile, now, target.maxBac, session.mealState)
  if (status === 'over') {
    return {
      tone: 'nudge',
      text: pick([
        `You've overshot the brief. Back in range in roughly ${minsBack} minutes.`,
        `Past ${target.label.toLowerCase()}. The sequel did not need this much budget.`,
        `The night has entered director's-cut territory.`,
      ], seed),
      tip: hadWater ? 'Water logged. Admin is happening.' : 'Water is the least boring useful button right now.',
    }
  }

  return {
    tone: 'warn',
    text: `You're cooked, ${firstName}. The app has seen enough evidence for one evening.`,
    tip: 'Stay with the group and switch the order.',
  }
}

export function coachMessage(session: NightSession, profile: Profile, now: number, personality: CoachPersonality = 'friend'): CoachMessage {
  const message = baseCoachMessage(session, profile, now)
  if (personality === 'elder') return { ...message, text: `A word from the elder: ${message.text}`, tip: message.tip ?? 'Pace the night; the next round will still be there.' }
  if (personality === 'gremlin') return { ...message, text: `Gremlin report: ${message.text}`, tip: message.tone === 'warn' ? message.tip : message.tip ?? 'Cause scenes, keep receipts.' }
  return message
}

export function morningVerdict(session: NightSession, profile: Profile): { headline: string; body: string } {
  if (session.drinks.length === 0) {
    return { headline: 'A clerical error? 🌙', body: 'Zero drinks logged. The room will need witnesses.' }
  }
  const target = session.targetSnapshot ?? TARGETS[session.targetId]
  const end = Math.max(session.endedAt ?? Date.now(), fullyAbsorbedAt(session.drinks, session.startedAt, session.mealState))
  const points = bacTimeline(session.drinks, profile, session.startedAt, end, 5, session.mealState)
  const peak = points.reduce((value, point) => Math.max(value, point.bac), 0)
  const overMinutes = points.filter((point) => point.bac > target.maxBac).length * 5

  if (peak <= target.maxBac && peak >= target.minBac) {
    return { headline: 'Nailed the brief 🎯', body: `Reached ${target.label} without producing a director's cut.` }
  }
  if (overMinutes <= 45) {
    return { headline: 'Strong showing 👏', body: `A little beyond ${target.label}, but the timeline remains publishable.` }
  }
  return { headline: 'Absolute cinema 🎬', body: `Target: ${target.label}. Result: several unrequested bonus scenes.` }
}
