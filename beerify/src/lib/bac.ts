import type { BacRange, LoggedDrink, MealState, Profile, Sex } from '../types'

const BETA_LIKELY = 0.015
const BETA_LOW = 0.01
const BETA_HIGH = 0.025

function widmarkR(sex: Sex): number {
  if (sex === 'male') return 0.68
  if (sex === 'female') return 0.55
  return 0.615
}

function distribution(profile: Profile): { vd: number; uncertainty: number; model: BacRange['model']; completeness: BacRange['completeness'] } {
  if (profile.age && profile.heightCm && profile.sex !== 'other') {
    const tbw = profile.sex === 'male'
      ? 2.447 - .09516 * profile.age + .1074 * profile.heightCm + .3362 * profile.weightKg
      : -2.097 + .1069 * profile.heightCm + .2466 * profile.weightKg
    const bloodWater = profile.sex === 'male' ? .825 : .838
    return { vd: tbw / (profile.weightKg * bloodWater), uncertainty: profile.sex === 'male' ? .0986 : .15, model: 'watson', completeness: 'personalised' }
  }
  return { vd: widmarkR(profile.sex), uncertainty: profile.sex === 'other' ? .22 : .18, model: 'widmark', completeness: 'basic' }
}

function bacFromGrams(grams: number, profile: Profile, vd: number): number {
  return grams / (profile.weightKg * vd) / 10
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
  vd = distribution(profile).vd,
  beta = BETA_LIKELY,
  absorptionScale = 1,
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
      const absorptionMin = Math.min(120, Math.max(5, drink.absorptionMin * absorptionScale))
      const fraction = absorbedFraction((at - drink.at) / stepMs, absorptionMin)
      absorbed += bacFromGrams(drink.grams * fraction, profile, vd)
    }
    const elapsedHours = (at - previous) / 3_600_000
    bac = Math.max(0, bac + absorbed - previousAbsorbed - beta * elapsedHours)
    previousAbsorbed = absorbed
    previous = at
    visit?.(at, bac)
  }
  return bac
}

function mealScale(meal: MealState): number {
  return meal === 'empty' ? 1 : meal === 'snack' ? 1.25 : meal === 'meal' ? 1.5 : 1.25
}

export function estimateBac(drinks: LoggedDrink[], profile: Profile, at: number, meal: MealState = 'unknown'): number {
  return simulate(drinks, profile, at, undefined, distribution(profile).vd, BETA_LIKELY, mealScale(meal))
}

export function estimateBacRange(drinks: LoggedDrink[], profile: Profile, at: number, meal: MealState = 'unknown'): BacRange {
  const model = distribution(profile)
  const scale = mealScale(meal)
  const likely = simulate(drinks, profile, at, undefined, model.vd, BETA_LIKELY, scale)
  const low = simulate(drinks, profile, at, undefined, model.vd * (1 + model.uncertainty), BETA_HIGH, scale * 1.35)
  const high = simulate(drinks, profile, at, undefined, model.vd * (1 - model.uncertainty), BETA_LOW, scale * .75)
  return { low: Math.min(low, likely), likely, high: Math.max(high, likely), model: model.model, completeness: model.completeness }
}

/** A single chronological pass used by summaries and projections. */
export function bacTimeline(
  drinks: LoggedDrink[],
  profile: Profile,
  from: number,
  to: number,
  sampleMinutes = 5,
  meal: MealState = 'unknown',
): { at: number; bac: number }[] {
  if (to < from) return []
  const result: { at: number; bac: number }[] = []
  let next = from
  let lastAt = -1
  const model = distribution(profile)
  simulate(drinks, profile, to, (at, bac) => {
    if (at >= next) {
      result.push({ at, bac })
      lastAt = at
      next = at + sampleMinutes * 60_000
    }
  }, model.vd, BETA_LIKELY, mealScale(meal))
  if (lastAt !== to) result.push({ at: to, bac: estimateBac(drinks, profile, to, meal) })
  return result
}

export function projectBac(
  drinks: LoggedDrink[],
  profile: Profile,
  from: number,
  minutes: number,
  meal: MealState = 'unknown',
): number {
  return estimateBac(drinks, profile, from + minutes * 60_000, meal)
}

export function peakBacAhead(
  drinks: LoggedDrink[],
  profile: Profile,
  from: number,
  horizonMin: number,
  meal: MealState = 'unknown',
): number {
  const points = bacTimeline(drinks, profile, from, from + horizonMin * 60_000, 1, meal)
  return points.reduce((peak, point) => Math.max(peak, point.bac), 0)
}

export function fullyAbsorbedAt(drinks: LoggedDrink[], fallback: number, meal: MealState = 'unknown'): number {
  const scale = mealScale(meal)
  return drinks.reduce(
    (latest, drink) => Math.max(latest, drink.at + Math.min(120, drink.absorptionMin * scale) * 60_000),
    fallback,
  )
}

/** Minutes until the estimate is below target after all logged alcohol has landed. */
export function minutesUntilBac(
  drinks: LoggedDrink[],
  profile: Profile,
  from: number,
  targetBac: number,
  meal: MealState = 'unknown',
): number {
  if (drinks.length === 0) return 0
  const declineStartsAt = Math.max(from, fullyAbsorbedAt(drinks, from, meal))
  const bacAtDecline = estimateBac(drinks, profile, declineStartsAt, meal)
  const absorptionWait = (declineStartsAt - from) / 60_000
  const eliminationWait = Math.max(0, bacAtDecline - targetBac) / BETA_LIKELY * 60
  return Math.ceil(absorptionWait + eliminationWait)
}

export function formatBac(bac: number): string {
  return bac.toFixed(3).replace(/^0/, '')
}
