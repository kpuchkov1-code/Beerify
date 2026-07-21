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

test('geocoding validates queries and sanitizes provider results', async () => {
  const invalid = await GET(new Request('http://local/api/maps?action=geocode&q=x'))
  assert.equal(invalid.status, 400)
  const previousKey = process.env.MAPTILER_API_KEY
  const previousFetch = globalThis.fetch
  process.env.MAPTILER_API_KEY = 'test-key'
  globalThis.fetch = async () => new Response(JSON.stringify({ features: [
    { id: 'place.london', place_name: 'London, England', geometry: { type: 'Point', coordinates: [-0.1276, 51.5072] }, bbox: [-0.52, 51.28, 0.34, 51.7] },
    { id: 'bad', place_name: 'Bad', geometry: { type: 'Point', coordinates: [999, 999] } },
  ] }), { status: 200, headers: { 'content-type': 'application/json' } })
  try {
    const response = await GET(new Request('http://local/api/maps?action=geocode&q=London'))
    assert.equal(response.status, 200)
    assert.deepEqual(await response.json(), { locations: [{ id: 'place.london', label: 'London, England', lat: 51.5072, lng: -0.1276, bbox: [-0.52, 51.28, 0.34, 51.7] }] })
  } finally {
    globalThis.fetch = previousFetch
    if (previousKey === undefined) delete process.env.MAPTILER_API_KEY
    else process.env.MAPTILER_API_KEY = previousKey
  }
})

test('nearby places are deduplicated and sorted by distance', async () => {
  const previousFetch = globalThis.fetch
  globalThis.fetch = async () => new Response(JSON.stringify({ elements: [
    { type: 'node', id: 2, lat: 51.52, lon: -0.1, tags: { name: 'Far Bar', amenity: 'bar' } },
    { type: 'node', id: 1, lat: 51.5002, lon: -0.1001, tags: { name: 'Near Pub', amenity: 'pub', 'addr:housenumber': '1', 'addr:street': 'High Street' } },
    { type: 'way', id: 3, center: { lat: 51.5002, lon: -0.1001 }, tags: { name: 'Near Pub', amenity: 'pub' } },
  ] }), { status: 200, headers: { 'content-type': 'application/json' } })
  try {
    const response = await GET(new Request('http://local/api/maps?action=nearby&lat=51.5&lng=-0.1&radius=1250'))
    assert.equal(response.status, 200)
    const body = await response.json() as { venues: Array<{ name: string; address?: string; distanceMeters: number }> }
    assert.deepEqual(body.venues.map((venue) => venue.name), ['Near Pub', 'Far Bar'])
    assert.equal(body.venues[0].address, '1 High Street')
    assert.ok(body.venues[0].distanceMeters < body.venues[1].distanceMeters)
  } finally { globalThis.fetch = previousFetch }
})
