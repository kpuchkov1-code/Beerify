import test from 'node:test'
import assert from 'node:assert/strict'
import { newId, normalizeData } from './storage'
import { BUILT_IN_PRESETS } from './drinks'

test('normalizes legacy profiles and drink records', () => {
  const data = normalizeData({
    profile: { name: ' Sam ', weightKg: 80, sex: 'male', tolerance: 'frequent', createdAt: 1 },
    session: {
      id: 'night', startedAt: 10, targetId: 'merry', waters: [],
      drinks: [{ id: 'drink', type: 'beer', at: 20, units: 999, grams: 999 }],
    },
    history: [],
  }, 100)
  assert.equal(data.profile?.name, 'Sam')
  assert.equal(data.profile?.drinkerLevel, 'weekend')
  assert.equal('tolerance' in (data.profile ?? {}), false)
  assert.equal(data.session?.drinks[0].presetId, 'lager-can')
  assert.ok((data.session?.drinks[0].units ?? 0) < 3)
})

test('new profiles start on the lightweight setting', () => {
  assert.equal(normalizeData(null, 100).preferences.lastTargetId, 'glow')
})

test('creates ids when randomUUID is unavailable in a LAN WebView', () => {
  const descriptor = Object.getOwnPropertyDescriptor(globalThis.crypto, 'randomUUID')
  Object.defineProperty(globalThis.crypto, 'randomUUID', { configurable: true, value: undefined })
  try {
    assert.match(newId(), /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
  } finally {
    if (descriptor) Object.defineProperty(globalThis.crypto, 'randomUUID', descriptor)
    else Reflect.deleteProperty(globalThis.crypto, 'randomUUID')
  }
})

test('ships branded beer presets with icon fallbacks', () => {
  const branded = BUILT_IN_PRESETS.filter((preset) => preset.brand)
  assert.ok(branded.length >= 10)
  assert.ok(branded.every((preset) => preset.logoUrl?.startsWith('https://')))
})

test('rejects corrupt profile and old insecure room memberships', () => {
  const data = normalizeData({
    profile: { name: '', weightKg: -1, sex: 'unknown' },
    room: { code: 'ABCD', memberId: 'old' },
  }, 100)
  assert.equal(data.profile, null)
  assert.equal(data.room, null)
})

test('preserves valid six-character credentialled rooms', () => {
  const id = '11111111-1111-4111-8111-111111111111'
  const token = '22222222-2222-4222-8222-222222222222'
  const data = normalizeData({ room: { code: 'ABC234', memberId: id, memberToken: token, isHost: true } }, 100)
  assert.deepEqual(data.room, { code: 'ABC234', memberId: id, memberToken: token, isHost: true })
})
