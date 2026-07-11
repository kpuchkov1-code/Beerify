import test from 'node:test'
import assert from 'node:assert/strict'
import type { Profile } from '../types'
import { estimateBac, minutesUntilBac, peakBacAhead } from './bac'
import { BUILT_IN_PRESETS, logFromPreset } from './drinks'

const profile: Profile = {
  name: 'Test', weightKg: 80, sex: 'male', drinkerLevel: 'weekend', createdAt: 0, updatedAt: 0,
}
const lager = BUILT_IN_PRESETS.find((preset) => preset.id === 'lager-pint')!

test('a drink that is still absorbing cannot report immediate clearance', () => {
  const drink = logFromPreset(lager, 'one', 0)
  const oneMinute = 60_000
  const current = estimateBac([drink], profile, oneMinute)
  const peak = peakBacAhead([drink], profile, oneMinute, 60)
  assert.ok(current > 0)
  assert.ok(peak > current)
  assert.ok(minutesUntilBac([drink], profile, oneMinute, 0.005) > 0)
})

test('clearance is not capped at twelve hours', () => {
  const drinks = Array.from({ length: 30 }, (_, index) => logFromPreset(lager, String(index), index * 15 * 60_000))
  assert.ok(minutesUntilBac(drinks, { ...profile, weightKg: 50, sex: 'female' }, 8 * 60 * 60_000, 0.005) > 720)
})

test('unsorted drink input produces the same estimate', () => {
  const first = logFromPreset(lager, 'first', 0)
  const second = logFromPreset(lager, 'second', 30 * 60_000)
  const at = 90 * 60_000
  assert.equal(estimateBac([first, second], profile, at), estimateBac([second, first], profile, at))
})
