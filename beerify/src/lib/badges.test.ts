import test from 'node:test'
import assert from 'node:assert/strict'
import type { NightSession, Profile } from '../types'
import { BADGES, earnedBadgeIds } from './badges'
import { calculateStats } from './stats'

const profile: Profile = { id: 'p', name: 'Sam', weightKg: 75, sex: 'male', drinkerLevel: 'weekend', createdAt: 1, updatedAt: 1 }

function night(overrides: Partial<NightSession> = {}): NightSession {
  return { id: 'n', startedAt: 1_700_000_000_000, updatedAt: 1_700_003_600_000, endedAt: 1_700_003_600_000, targetId: 'glow', mealState: 'unknown', participationMode: 'drinking', drinks: [], waters: [], ...overrides }
}

test('derives all badge state from history', () => {
  const driver = night({ id: 'driver', participationMode: 'driver', startedAt: 1_700_010_000_000, endedAt: 1_700_013_000_000, updatedAt: 1_700_013_000_000, waters: [1, 2, 3] })
  const earned = earnedBadgeIds([driver], profile)
  assert.equal(BADGES.length, 12)
  assert.ok(earned.has('first-night'))
  assert.ok(earned.has('hydration-hero'))
  assert.ok(earned.has('designated-driver'))
})

test('calculates personal totals, seven-day units, categories, and records', () => {
  const recent = Date.now() - 60_000
  const history = [night({ startedAt: recent, updatedAt: recent + 7_200_000, endedAt: recent + 7_200_000, participationMode: 'sober', waters: [1], drinks: [{ id: 'd', presetId: 'lager', name: 'Lager', category: 'beer', icon: 'pint', volumeMl: 568, abv: .04, absorptionMin: 60, at: recent, units: 2.3, grams: 18.4 }] })]
  const stats = calculateStats(history)
  assert.equal(stats.nights, 1)
  assert.equal(stats.drinks, 1)
  assert.equal(stats.weekUnits, 2.3)
  assert.equal(stats.categories.beer, 1)
  assert.equal(stats.longestNightHours, 2)
  assert.equal(stats.alcoholFreeNights, 1)
})
