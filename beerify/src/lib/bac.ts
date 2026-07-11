import type { LoggedDrink, Profile, Sex } from '../types'

/** Conservative fixed rate; prior drinking frequency no longer lowers estimates. */
const BETA_PER_HOUR = 0.012

function widmarkR(sex: Sex): number {
  if (sex === 'male') return 0.68
  if (sex === 'female') return 0.55
  return 0.615
}

function bacFromGrams(grams: number, profile: Profile): number {
  return (grams / (profile.weightKg * 1000 * widmarkR(profile.sex))) * 100
}

function absorbedFraction(elapsedMin: number, absorptionMin: number): number {
  if (elapsedMin <= 0) return 0
  if (elapsedMin >= absorptionMin) return 1
  const x = elapsedMin / absorptionMin
  return 1 - (1 - x) * (1 - x)
}

function simulate(
  drinks: LoggedDrink[],
  profile: Profile,
  until: number,
  visit?: (at: number, bac: number) => void,
): number {
  if (drinks.length === 0) return 0
  const sorted = [...drinks].sort((a, b) => a.at - b.at)
  const start = sorted[0].at
  if (until <= start) return 0

  const stepMs = 60_000
  let bac = 0
  let previousAbsorbed = 0
  let previous = start

  for (let at = start; at < until; ) {
    at = Math.min(at + stepMs, until)
    let absorbed = 0
    for (const drink of sorted) {
      if (drink.at > at) break
      const fraction = absorbedFraction((at - drink.at) / stepMs, drink.absorptionMin)
      absorbed += bacFromGrams(drink.grams * fraction, profile)
    }
    const elapsedHours = (at - previous) / 3_600_000
    bac = Math.max(0, bac + absorbed - previousAbsorbed - BETA_PER_HOUR * elapsedHours)
    previousAbsorbed = absorbed
    previous = at
    visit?.(at, bac)
  }
  return bac
}

export function estimateBac(drinks: LoggedDrink[], profile: Profile, at: number): number {
  return simulate(drinks, profile, at)
}

/** A single chronological pass used by summaries and projections. */
export function bacTimeline(
  drinks: LoggedDrink[],
  profile: Profile,
  from: number,
  to: number,
  sampleMinutes = 5,
): { at: number; bac: number }[] {
  if (to < from) return []
  const result: { at: number; bac: number }[] = []
  let next = from
  let lastAt = -1
  simulate(drinks, profile, to, (at, bac) => {
    if (at >= next) {
      result.push({ at, bac })
      lastAt = at
      next = at + sampleMinutes * 60_000
    }
  })
  if (lastAt !== to) result.push({ at: to, bac: estimateBac(drinks, profile, to) })
  return result
}

export function projectBac(
  drinks: LoggedDrink[],
  profile: Profile,
  from: number,
  minutes: number,
): number {
  return estimateBac(drinks, profile, from + minutes * 60_000)
}

export function peakBacAhead(
  drinks: LoggedDrink[],
  profile: Profile,
  from: number,
  horizonMin: number,
): number {
  const points = bacTimeline(drinks, profile, from, from + horizonMin * 60_000, 1)
  return points.reduce((peak, point) => Math.max(peak, point.bac), 0)
}

export function fullyAbsorbedAt(drinks: LoggedDrink[], fallback: number): number {
  return drinks.reduce(
    (latest, drink) => Math.max(latest, drink.at + drink.absorptionMin * 60_000),
    fallback,
  )
}

/** Minutes until the estimate is below target after all logged alcohol has landed. */
export function minutesUntilBac(
  drinks: LoggedDrink[],
  profile: Profile,
  from: number,
  targetBac: number,
): number {
  if (drinks.length === 0) return 0
  const declineStartsAt = Math.max(from, fullyAbsorbedAt(drinks, from))
  const bacAtDecline = estimateBac(drinks, profile, declineStartsAt)
  const absorptionWait = (declineStartsAt - from) / 60_000
  const eliminationWait = Math.max(0, bacAtDecline - targetBac) / BETA_PER_HOUR * 60
  return Math.ceil(absorptionWait + eliminationWait)
}

export function formatBac(bac: number): string {
  return bac.toFixed(3).replace(/^0/, '')
}
