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
  assert.equal(data.session?.participationMode, 'drinking')
  assert.equal(data.session?.nightMode, 'solo')
  assert.deepEqual(data.session?.pubCrawl, [])
  assert.equal(data.preferences.lastParticipationMode, 'drinking')
  assert.equal(data.preferences.spiciness, 3)
  assert.equal(data.pubCrawlDraft, null)
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

test('migrates an active legacy room into a locked group night', () => {
  const data = normalizeData({
    session: { id: 'night', startedAt: 10, targetId: 'glow', drinks: [], waters: [] },
    room: { code: 'ABC234', memberId: '11111111-1111-4111-8111-111111111111', memberToken: '22222222-2222-4222-8222-222222222222' },
  }, 100)
  assert.equal(data.session?.nightMode, 'group')
  assert.equal(data.session?.roomCode, 'ABC234')
})

test('normalizes the persisted night mode and crawl plan', () => {
  const data = normalizeData({ session: {
    id: 'group-night', startedAt: 10, targetId: 'glow', nightMode: 'group', participationMode: 'driver', drinks: [], waters: [],
    roomCode: 'ABC234',
    pubCrawl: [
      { id: 'one', name: 'One', lat: 51.5, lng: -0.12, type: 'pub', par: 99, drink: ' Lager ' },
      { id: 'bad', name: 'Bad', lat: 999, lng: 0, type: 'pub' },
    ],
  } }, 100)
  assert.equal(data.session?.nightMode, 'group')
  assert.equal(data.session?.participationMode, 'driver')
  assert.deepEqual(data.session?.pubCrawl, [{ id: 'one', name: 'One', lat: 51.5, lng: -0.12, type: 'pub', address: undefined, par: 9, drink: 'Lager' }])
})

test('normalizes a saved crawl draft independently from the active night', () => {
  const data = normalizeData({
    pubCrawlDraft: {
      updatedAt: 42,
      stops: [
        { id: 'draft-one', name: 'Draft One', lat: 51.5, lng: -0.12, type: 'pub' },
        { id: 'bad', name: 'Bad', lat: -999, lng: 0, type: 'bar' },
      ],
    },
  }, 100)
  assert.deepEqual(data.pubCrawlDraft, {
    updatedAt: 42,
    stops: [{ id: 'draft-one', name: 'Draft One', lat: 51.5, lng: -0.12, type: 'pub', address: undefined, par: undefined, drink: undefined }],
  })
})
