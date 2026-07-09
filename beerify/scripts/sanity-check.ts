/** Quick manual sanity check of the BAC engine. Run: npx tsx scripts/sanity-check.ts */
import { estimateBac, minutesUntilBac } from '../src/lib/bac'
import { DRINK_TYPES, gramsOfAlcohol, unitsOfAlcohol } from '../src/lib/drinks'
import type { LoggedDrink, Profile } from '../src/types'

const profile: Profile = { name: 'Test', weightKg: 80, sex: 'male', createdAt: 0 }
const t0 = Date.now()

function drink(type: keyof typeof DRINK_TYPES, minutesAgoStart: number): LoggedDrink {
  const d = DRINK_TYPES[type]
  return {
    id: type + minutesAgoStart,
    type,
    at: t0 + minutesAgoStart * 60_000,
    units: unitsOfAlcohol(d),
    grams: gramsOfAlcohol(d),
  }
}

console.log('units per drink:')
for (const d of Object.values(DRINK_TYPES)) {
  console.log(`  ${d.emoji} ${d.label}: ${unitsOfAlcohol(d).toFixed(2)} units, ${gramsOfAlcohol(d).toFixed(1)}g`)
}

const twoBeers = [drink('beer', 0), drink('beer', 30)]
for (const mins of [15, 30, 60, 90, 120, 240]) {
  const bac = estimateBac(twoBeers, profile, t0 + mins * 60_000)
  console.log(`2 beers (0min, 30min), t=${mins}min -> BAC ${bac.toFixed(4)}%`)
}

const bigNight = [drink('beer', 0), drink('shot', 20), drink('shot', 25), drink('beer', 60), drink('cocktail', 90)]
for (const mins of [30, 60, 90, 120, 180]) {
  const bac = estimateBac(bigNight, profile, t0 + mins * 60_000)
  console.log(`big night, t=${mins}min -> BAC ${bac.toFixed(4)}%`)
}

console.log(
  'minutes until sober after big night (from t=120min):',
  minutesUntilBac(bigNight, profile, t0 + 120 * 60_000, 0.005),
)
