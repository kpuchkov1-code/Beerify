import assert from 'node:assert/strict'
import test from 'node:test'
import { planRoomPushes, type PushEvent, type PushRegistration } from './apns'

const registrations: Record<string, PushRegistration> = {
  ana: { token: 'a'.repeat(64), environment: 'sandbox' },
  ben: { token: 'b'.repeat(64), environment: 'production' },
  cy: { token: 'c'.repeat(64), environment: 'production' },
}

function event(type: string, values: Partial<PushEvent> = {}): PushEvent {
  return { id: 'event-id', type, actorId: 'ana', actorName: 'Ana', ...values }
}

test('essential room calls target the intended members', () => {
  assert.deepEqual(planRoomPushes('ABC234', event('cheers-countdown', { startsAt: Date.now() + 8_000 }), registrations).map((push) => push.memberId), ['ben', 'cy'])
  assert.deepEqual(planRoomPushes('ABC234', event('round-invite'), registrations).map((push) => push.memberId), ['ben', 'cy'])
  assert.deepEqual(planRoomPushes('ABC234', event('round-order', { actorId: 'cy', text: 'lager' }), registrations, 'ben').map((push) => push.memberId), ['ben'])
  assert.deepEqual(planRoomPushes('ABC234', event('round-bought'), registrations).map((push) => push.memberId), ['ben', 'cy'])
})

test('routine room activity never creates a remote alert', () => {
  assert.equal(planRoomPushes('ABC234', event('drink'), registrations).length, 0)
  assert.equal(planRoomPushes('ABC234', event('reaction'), registrations).length, 0)
})

test('countdowns expire promptly and carry only routing metadata', () => {
  const startsAt = Date.now() + 8_000
  const [push] = planRoomPushes('ABC234', event('cheers-countdown', { startsAt }), registrations)
  assert.equal(push.expiration, Math.floor((startsAt + 2_000) / 1_000))
  assert.equal(push.collapseId, 'room:ABC234:cheers-countdown')
  assert.deepEqual(Object.keys(push.payload).sort(), ['aps', 'eventId', 'eventType', 'room'])
})
