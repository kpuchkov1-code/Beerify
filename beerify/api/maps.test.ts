import test from 'node:test'
import assert from 'node:assert/strict'
import { GET } from './maps'

test('map proxy rejects unbounded and malformed nearby requests', async () => {
  const badRadius = await GET(new Request('http://local/api/maps?action=nearby&lat=51.5&lng=-0.1&radius=9000'))
  assert.equal(badRadius.status, 400)
  const missing = await GET(new Request('http://local/api/maps?action=nearby'))
  assert.equal(missing.status, 400)
})

test('map proxy accepts only 2–12 valid route points', async () => {
  const one = await GET(new Request('http://local/api/maps?action=route&points=-0.1,51.5'))
  assert.equal(one.status, 400)
  const malformed = await GET(new Request('http://local/api/maps?action=route&points=nope;also-nope'))
  assert.equal(malformed.status, 400)
})

test('map proxy returns a safe fallback error when a provider fails', async () => {
  const previous = process.env.VENUE_SERVICE_URL
  process.env.VENUE_SERVICE_URL = 'http://127.0.0.1:1/unavailable'
  try {
    const response = await GET(new Request('http://local/api/maps?action=nearby&lat=51.523&lng=-0.141&radius=1000'))
    assert.equal(response.status, 503)
    assert.deepEqual(await response.json(), { error: 'Nearby places are unavailable right now' })
  } finally {
    if (previous === undefined) delete process.env.VENUE_SERVICE_URL
    else process.env.VENUE_SERVICE_URL = previous
  }
})
