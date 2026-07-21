import type { CrawlRoute, GeocodeResult, VenueResult } from '../src/types'

type CacheEntry = { expiresAt: number; value: unknown }

const cache = new Map<string, CacheEntry>()
const JSON_HEADERS = { 'content-type': 'application/json', 'cache-control': 'public, max-age=120, s-maxage=600' }

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: JSON_HEADERS })
}

function numberIn(value: string | null | undefined, min: number, max: number): number | null {
  if (value === null || value === undefined || !value.trim()) return null
  const parsed = Number(value)
  return Number.isFinite(parsed) && parsed >= min && parsed <= max ? parsed : null
}

function cached(key: string): unknown | null {
  const entry = cache.get(key)
  if (!entry || entry.expiresAt < Date.now()) return null
  return entry.value
}

function remember(key: string, value: unknown, ttl = 10 * 60_000) {
  cache.set(key, { value, expiresAt: Date.now() + ttl })
  if (cache.size > 100) cache.delete(cache.keys().next().value as string)
}

function distanceMeters(first: { lat: number; lng: number }, second: { lat: number; lng: number }) {
  const radians = (degrees: number) => degrees * Math.PI / 180
  const dLat = radians(second.lat - first.lat)
  const dLng = radians(second.lng - first.lng)
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(radians(first.lat)) * Math.cos(radians(second.lat)) * Math.sin(dLng / 2) ** 2
  return Math.round(6_371_000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)))
}

function validBbox(value: unknown): [number, number, number, number] | undefined {
  if (!Array.isArray(value) || value.length !== 4) return undefined
  const [west, south, east, north] = value.map(Number)
  return [west, south, east, north].every(Number.isFinite) && west >= -180 && east <= 180 && south >= -90 && north <= 90
    ? [west, south, east, north]
    : undefined
}

export function OPTIONS() {
  return new Response(null, { status: 204, headers: { allow: 'GET, OPTIONS' } })
}

export async function GET(request: Request) {
  const url = new URL(request.url)
  const action = url.searchParams.get('action')

  if (action === 'geocode') {
    const query = (url.searchParams.get('q') ?? '').trim().replace(/\s+/g, ' ')
    if (query.length < 2 || query.length > 80) return json({ error: 'Enter a town or postcode' }, 400)
    const key = `geocode:${query.toLocaleLowerCase('en-GB')}`
    const hit = cached(key)
    if (hit) return json(hit)
    const apiKey = process.env.MAPTILER_API_KEY
    if (!apiKey) return json({ error: 'Town search is not configured' }, 503)
    try {
      const endpoint = (process.env.GEOCODING_SERVICE_URL || 'https://api.maptiler.com/geocoding').replace(/\/$/, '')
      const target = `${endpoint}/${encodeURIComponent(query)}.json?key=${encodeURIComponent(apiKey)}&limit=5&types=municipality,locality,place,postal_code&autocomplete=false`
      const response = await fetch(target, { signal: AbortSignal.timeout(8_000) })
      if (!response.ok) throw new Error('Geocoding service unavailable')
      const body = await response.json() as { features?: Array<{ id?: unknown; text?: unknown; place_name?: unknown; geometry?: { type?: unknown; coordinates?: unknown }; bbox?: unknown }> }
      const locations = (body.features ?? []).flatMap((feature): GeocodeResult[] => {
        const coordinates = feature.geometry?.coordinates
        if (feature.geometry?.type !== 'Point' || !Array.isArray(coordinates) || coordinates.length < 2) return []
        const lng = Number(coordinates[0]); const lat = Number(coordinates[1])
        const label = typeof feature.place_name === 'string' ? feature.place_name.trim() : typeof feature.text === 'string' ? feature.text.trim() : ''
        if (!label || !Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) return []
        return [{ id: String(feature.id ?? `${lng}:${lat}`).slice(0, 120), label: label.slice(0, 140), lat, lng, bbox: validBbox(feature.bbox) }]
      }).slice(0, 5)
      const result = { locations }
      remember(key, result, 60 * 60_000)
      return json(result)
    } catch {
      return json({ error: 'Town search is unavailable right now' }, 503)
    }
  }

  if (action === 'nearby') {
    const lat = numberIn(url.searchParams.get('lat'), -90, 90)
    const lng = numberIn(url.searchParams.get('lng'), -180, 180)
    const radius = numberIn(url.searchParams.get('radius') ?? '2500', 250, 5_000)
    if (lat === null || lng === null || radius === null) return json({ error: 'Invalid map bounds' }, 400)
    const key = `nearby:${lat.toFixed(3)}:${lng.toFixed(3)}:${Math.round(radius / 250)}`
    const hit = cached(key)
    if (hit) return json(hit)

    const query = `[out:json][timeout:12];(nwr(around:${radius},${lat},${lng})[amenity~"^(pub|bar|nightclub)$"];);out center tags 60;`
    try {
      const endpoint = process.env.VENUE_SERVICE_URL || 'https://overpass-api.de/api/interpreter'
      const response = await fetch(endpoint, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ data: query }), signal: AbortSignal.timeout(14_000) })
      if (!response.ok) throw new Error('Venue service unavailable')
      const body = await response.json() as { elements?: Array<{ id?: number; type?: string; lat?: number; lon?: number; center?: { lat?: number; lon?: number }; tags?: Record<string, string> }> }
      const seen = new Set<string>()
      const venues = (body.elements ?? []).flatMap((item): VenueResult[] => {
        const itemLat = item.lat ?? item.center?.lat
        const itemLng = item.lon ?? item.center?.lon
        const name = item.tags?.name?.trim()
        if (!name || !Number.isFinite(itemLat) || !Number.isFinite(itemLng)) return []
        const duplicateKey = `${name.toLocaleLowerCase('en-GB')}:${itemLat!.toFixed(4)}:${itemLng!.toFixed(4)}`
        if (seen.has(duplicateKey)) return []
        seen.add(duplicateKey)
        const address = [item.tags?.['addr:housenumber'], item.tags?.['addr:street'], item.tags?.['addr:city']].filter(Boolean).join(' ')
        return [{
          id: `${item.type ?? 'osm'}:${item.id ?? `${itemLat}:${itemLng}`}`.slice(0, 100),
          name: name.slice(0, 80),
          lat: itemLat!,
          lng: itemLng!,
          type: item.tags?.amenity ?? 'pub',
          address: address ? address.slice(0, 160) : undefined,
          distanceMeters: distanceMeters({ lat, lng }, { lat: itemLat!, lng: itemLng! }),
        }]
      }).sort((a, b) => a.distanceMeters - b.distanceMeters).slice(0, 24)
      const result = { venues }
      remember(key, result)
      return json(result)
    } catch {
      return json({ error: 'Nearby places are unavailable right now' }, 503)
    }
  }

  if (action === 'route') {
    const points = (url.searchParams.get('points') ?? '').split(';').flatMap((point) => {
      const [lngText, latText] = point.split(',')
      const lat = numberIn(latText, -90, 90)
      const lng = numberIn(lngText, -180, 180)
      return lat === null || lng === null ? [] : [{ lat, lng }]
    })
    if (points.length < 2 || points.length > 12) return json({ error: 'A route needs 2–12 valid stops' }, 400)
    const encoded = points.map((point) => `${point.lng},${point.lat}`).join(';')
    const key = `route:${encoded}`
    const hit = cached(key)
    if (hit) return json(hit)
    try {
      const endpoint = (process.env.ROUTE_SERVICE_URL || 'https://routing.openstreetmap.de/routed-foot/route/v1/driving').replace(/\/$/, '')
      const response = await fetch(`${endpoint}/${encoded}?overview=full&geometries=geojson&steps=false`, { signal: AbortSignal.timeout(10_000) })
      if (!response.ok) throw new Error('Route service unavailable')
      const body = await response.json() as { routes?: Array<{ distance?: number; duration?: number; geometry?: { type?: string; coordinates?: unknown[] } }> }
      const route = body.routes?.[0]
      const coordinates = route?.geometry?.coordinates?.flatMap((coordinate) => {
        if (!Array.isArray(coordinate) || coordinate.length < 2) return []
        const lng = Number(coordinate[0]); const lat = Number(coordinate[1])
        return Number.isFinite(lat) && Number.isFinite(lng) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180 ? [[lng, lat]] : []
      }) ?? []
      if (!route || route.geometry?.type !== 'LineString' || coordinates.length < 2 || coordinates.length > 10_000) throw new Error('Invalid route')
      const result: CrawlRoute = { distanceMeters: Math.max(0, Number(route.distance) || 0), durationSeconds: Math.max(0, Number(route.duration) || 0), geometry: { type: 'LineString', coordinates } }
      remember(key, result)
      return json(result)
    } catch {
      return json({ error: 'Walking route is unavailable right now' }, 503)
    }
  }

  return json({ error: 'Unknown map action' }, 400)
}
