/** Quick manual BAC engine readout. Run: npx tsx scripts/sanity-check.ts */
import { estimateBac, minutesUntilBac } from '../src/lib/bac'
import { BUILT_IN_PRESETS, logFromPreset, unitsOfAlcohol } from '../src/lib/drinks'
import type { Profile } from '../src/types'

const profile: Profile = { name: 'Test', weightKg: 80, sex: 'male', createdAt: 0, updatedAt: 0 }
const start = Date.now()
const lager = BUILT_IN_PRESETS.find((preset) => preset.id === 'lager-pint')!
const shot = BUILT_IN_PRESETS.find((preset) => preset.id === 'shot')!
const drinks = [logFromPreset(lager, 'lager', start), logFromPreset(shot, 'shot', start + 30 * 60_000)]

console.log('built-in units:')
for (const preset of BUILT_IN_PRESETS) console.log(`${preset.name}: ${unitsOfAlcohol(preset).toFixed(2)} units`)
for (const minutes of [1, 5, 30, 60, 120]) {
  console.log(`t=${minutes}min -> ${estimateBac(drinks, profile, start + minutes * 60_000).toFixed(4)}%`)
}
console.log('minutes below .005:', minutesUntilBac(drinks, profile, start + 60 * 60_000, 0.005))
