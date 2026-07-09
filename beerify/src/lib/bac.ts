import type { LoggedDrink, Profile, Sex } from '../types'
import { DRINK_TYPES } from './drinks'

/**
 * Widmark-based BAC estimation with gradual absorption.
 *
 * Each drink's alcohol enters the bloodstream linearly over its absorption
 * window, while the liver eliminates at a constant rate (beta). This gives a
 * smooth, realistic curve instead of instant spikes.
 */

const BETA_PER_HOUR = 0.015 // % BAC eliminated per hour (population average)

function widmarkR(sex: Sex): number {
  if (sex === 'male') return 0.68
  if (sex === 'female') return 0.55
  return 0.615
}

/** Peak BAC contribution (%) of `grams` of ethanol for this body. */
function bacFromGrams(grams: number, profile: Profile): number {
  return (grams / (profile.weightKg * 1000 * widmarkR(profile.sex))) * 100
}

/**
 * Fraction of a drink absorbed `elapsedMin` minutes after it was logged.
 * Ease-out curve: alcohol shows up in the blood within minutes of a sip and
 * the tail of absorption is slow, which matches how drinks actually feel.
 */
function absorbedFraction(elapsedMin: number, absorptionMin: number): number {
  if (elapsedMin <= 0) return 0
  if (elapsedMin >= absorptionMin) return 1
  const x = elapsedMin / absorptionMin
  return 1 - (1 - x) * (1 - x)
}

/**
 * Estimate BAC (%) at time `at` given drinks so far.
 *
 * Elimination is applied to the total absorbed alcohol: the liver processes a
 * fixed amount per hour starting once alcohol is present. We approximate by
 * integrating in 1-minute steps from the first drink, with elimination scaled
 * to the actual elapsed time of each step (this is a guide, never a legal
 * measure).
 */
export function estimateBac(drinks: LoggedDrink[], profile: Profile, at: number): number {
  if (drinks.length === 0) return 0
  const sorted = [...drinks].sort((a, b) => a.at - b.at)
  const start = sorted[0].at
  if (at <= start) return 0

  const stepMs = 60 * 1000
  let bac = 0
  let prevAbsorbed = 0
  let prev = start

  for (let t = start; t < at; ) {
    t = Math.min(t + stepMs, at)
    const dtHours = (t - prev) / 3_600_000

    let absorbed = 0
    for (const d of sorted) {
      if (d.at > t) continue
      const type = DRINK_TYPES[d.type]
      const frac = absorbedFraction((t - d.at) / 60_000, type.absorptionMin)
      absorbed += bacFromGrams(d.grams * frac, profile)
    }

    bac = Math.max(0, bac + (absorbed - prevAbsorbed) - BETA_PER_HOUR * dtHours)
    prevAbsorbed = absorbed
    prev = t
  }

  return bac
}

/** BAC trend over the next `minutes` if no more drinks are logged. */
export function projectBac(
  drinks: LoggedDrink[],
  profile: Profile,
  from: number,
  minutes: number,
): number {
  return estimateBac(drinks, profile, from + minutes * 60_000)
}

/** Highest BAC reached in the next `horizonMin` minutes with no further drinks. */
export function peakBacAhead(
  drinks: LoggedDrink[],
  profile: Profile,
  from: number,
  horizonMin: number,
): number {
  let peak = 0
  for (let m = 0; m <= horizonMin; m += 5) {
    peak = Math.max(peak, estimateBac(drinks, profile, from + m * 60_000))
  }
  return peak
}

/** Minutes until BAC drops to `targetBac` with no further drinks (capped at 12h). */
export function minutesUntilBac(
  drinks: LoggedDrink[],
  profile: Profile,
  from: number,
  targetBac: number,
): number {
  const step = 10
  for (let m = 0; m <= 720; m += step) {
    if (estimateBac(drinks, profile, from + m * 60_000) <= targetBac) return m
  }
  return 720
}

export function formatBac(bac: number): string {
  return bac.toFixed(3).replace(/^0/, '')
}
