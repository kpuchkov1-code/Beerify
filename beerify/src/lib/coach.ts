import type { CoachMessage, NightSession, Profile } from '../types'
import { estimateBac, minutesUntilBac, projectBac } from './bac'
import { TARGETS } from './drinks'

/**
 * Beerify's coach: a rule-based assistant that reads your BAC curve, your
 * target zone and your pacing, then talks to you like a friend who wants you
 * to have a great night AND a great morning.
 */

function pick<T>(arr: T[], seed: number): T {
  return arr[Math.abs(seed) % arr.length]
}

export type ZoneStatus = 'sober' | 'warming' | 'in-zone' | 'over' | 'way-over'

export function zoneStatus(bac: number, session: NightSession): ZoneStatus {
  const target = TARGETS[session.targetId]
  if (bac < 0.005) return 'sober'
  if (bac < target.minBac) return 'warming'
  if (bac <= target.maxBac) return 'in-zone'
  if (bac <= target.maxBac + 0.03) return 'over'
  return 'way-over'
}

function minutesSinceLastDrink(session: NightSession, now: number): number | null {
  if (session.drinks.length === 0) return null
  const last = Math.max(...session.drinks.map((d) => d.at))
  return (now - last) / 60_000
}

function recentWater(session: NightSession, now: number): boolean {
  return session.waters.some((w) => now - w < 45 * 60_000)
}

export function coachMessage(session: NightSession, profile: Profile, now: number): CoachMessage {
  const bac = estimateBac(session.drinks, profile, now)
  const inThirty = projectBac(session.drinks, profile, now, 30)
  const rising = inThirty > bac + 0.002
  const status = zoneStatus(bac, session)
  const target = TARGETS[session.targetId]
  const seed = session.drinks.length * 7 + session.waters.length * 3 + Math.floor(now / 600_000)
  const sinceLast = minutesSinceLastDrink(session, now)
  const hadWater = recentWater(session, now)
  const firstName = profile.name.split(' ')[0] || 'friend'

  if (status === 'sober') {
    if (session.drinks.length === 0) {
      return {
        tone: 'cheer',
        text: pick(
          [
            `Fresh night, ${firstName}! Tap a drink below when you start.`,
            `All set. Your target is “${target.label}” ${target.emoji}. Tap as you sip.`,
            `Ready when you are. First one's on you. 😉`,
          ],
          seed,
        ),
        tip: 'Eating before you drink slows absorption and smooths the ride.',
      }
    }
    if (sinceLast !== null && sinceLast < 25) {
      return {
        tone: 'cheer',
        text: pick(
          [
            `That one is on its way in. Give it a few minutes to land. 🚀`,
            `Nice. Your body is unpacking that drink right now.`,
            `Incoming! Watch the mug fill up as it hits.`,
          ],
          seed,
        ),
        tip: 'A drink takes 20 to 40 minutes to fully show up. No need to chase it.',
      }
    }
    return {
      tone: 'chill',
      text: pick(
        [`Pretty much sober again. Round two, or call it a night?`, `You've landed back at zero. Nicely done.`],
        seed,
      ),
    }
  }

  if (status === 'warming') {
    if (rising) {
      return {
        tone: 'cheer',
        text: pick(
          [
            `Warming up nicely. You're on track for “${target.label}” ${target.emoji}.`,
            `That last one is still kicking in. Cruise for a bit.`,
            `On the way up. No rush, the zone will come to you.`,
          ],
          seed,
        ),
        tip: rising && sinceLast !== null && sinceLast < 10 ? 'Give each drink ~30 min to land before judging it.' : undefined,
      }
    }
    return {
      tone: 'chill',
      text: pick(
        [
          `You're drifting below the zone. One more would top you back up.`,
          `Buzz is fading. Your call: another round, or ride it out?`,
        ],
        seed,
      ),
    }
  }

  if (status === 'in-zone') {
    if (rising) {
      const overshoot = projectBac(session.drinks, profile, now, 45) > target.maxBac
      if (overshoot) {
        return {
          tone: 'nudge',
          text: pick(
            [
              `You're in the zone, but what's in your system will push you past it. Skip the next round.`,
              `Perfect spot right now, and still climbing. Hold off a while to stay here.`,
            ],
            seed,
          ),
          tip: hadWater ? undefined : 'Grab a water. It buys you time in the zone.',
        }
      }
      return {
        tone: 'cheer',
        text: pick(
          [`You're IN the zone ${target.emoji}. This is the good stuff. Keep this pace.`, `Chef's kiss. Exactly where you wanted to be.`],
          seed,
        ),
        tip: hadWater ? undefined : 'A water between rounds keeps you here longer.',
      }
    }
    const minsLeft = minutesUntilBac(session.drinks, profile, now, target.minBac)
    return {
      tone: 'cheer',
      text: pick(
        [
          `In the zone and gliding. You've got ~${Math.round(minsLeft / 10) * 10} min before it fades.`,
          `Holding steady in “${target.label}”. You've mastered this.`,
        ],
        seed,
      ),
    }
  }

  if (status === 'over') {
    const minsBack = minutesUntilBac(session.drinks, profile, now, target.maxBac)
    return {
      tone: 'nudge',
      text: pick(
        [
          `You've floated past your zone. No more for now. You'll drift back in about ${minsBack} min.`,
          `A touch over target. Water, snack, dance break. Anything but another drink.`,
          `Past the sweet spot. Pause here and let your liver catch up (~${minsBack} min).`,
        ],
        seed,
      ),
      tip: hadWater ? 'Good hydration! Keep it up.' : 'Order a big water. Future-you says thanks.',
    }
  }

  return {
    tone: 'warn',
    text: pick(
      [
        `Well past your target, ${firstName}. Stop drinking, get water and food, and stay with friends.`,
        `This is over the fun line. No more alcohol tonight. Water and a mate nearby, please.`,
      ],
      seed,
    ),
    tip: 'If anyone feels unwell or unresponsive, get help immediately.',
  }
}

/** One-line verdict for the morning-after summary. */
export function morningVerdict(session: NightSession, profile: Profile): { headline: string; body: string } {
  const target = TARGETS[session.targetId]
  const end = session.endedAt ?? Date.now()
  const start = session.startedAt

  let peak = 0
  let inZoneMs = 0
  let overMs = 0
  const step = 5 * 60_000
  for (let t = start; t <= end; t += step) {
    const b = estimateBac(session.drinks, profile, t)
    peak = Math.max(peak, b)
    if (b >= target.minBac && b <= target.maxBac) inZoneMs += step
    if (b > target.maxBac) overMs += step
  }

  const inZoneMin = Math.round(inZoneMs / 60_000)
  const overMin = Math.round(overMs / 60_000)

  if (session.drinks.length === 0) {
    return {
      headline: 'A perfectly sober night 🌙',
      body: 'Zero drinks logged. Your liver sends a thank-you card.',
    }
  }
  if (overMin === 0 && inZoneMin > 0) {
    return {
      headline: 'Nailed it 🎯',
      body: `You spent about ${inZoneMin} minutes in your “${target.label}” zone and never overshot. Textbook night.`,
    }
  }
  if (overMin > 0 && overMin <= 45) {
    return {
      headline: 'Pretty solid 👏',
      body: `Mostly on target, with roughly ${overMin} minutes over the line. A water between rounds would've kept it perfect.`,
    }
  }
  if (overMin > 45) {
    return {
      headline: 'A big one 😅',
      body: `You were over your target for about ${overMin} minutes. Hydrate today, eat something real, and go easier next time.`,
    }
  }
  return {
    headline: 'Easy does it 😌',
    body: `You kept things light and never quite reached the “${target.label}” zone. Zero regrets guaranteed.`,
  }
}
