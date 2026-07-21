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

function remember(key: string, value: unknown) {
  cache.set(key, { value, expiresAt: Date.now() + 10 * 60_000 })
  if (cache.size > 100) cache.delete(cache.keys().next().value as string)
}

export function OPTIONS() {
  return new Response(null, { status: 204, headers: { allow: 'GET, OPTIONS' } })
}

export async function GET(request: Request) {
  const url = new URL(request.url)
  const action = url.searchParams.get('action')

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
      const body = await response.json() as { elements?: Array<{ id?: number; lat?: number; lon?: number; center?: { lat?: number; lon?: number }; tags?: Record<string, string> }> }
      const venues = (body.elements ?? []).flatMap((item) => {
        const itemLat = item.lat ?? item.center?.lat
        const itemLng = item.lon ?? item.center?.lon
        const name = item.tags?.name?.trim()
        if (!name || !Number.isFinite(itemLat) || !Number.isFinite(itemLng)) return []
        return [{ id: String(item.id ?? `${itemLat}:${itemLng}`), name: name.slice(0, 80), lat: itemLat!, lng: itemLng!, type: item.tags?.amenity ?? 'pub', address: [item.tags?.['addr:housenumber'], item.tags?.['addr:street']].filter(Boolean).join(' ').slice(0, 100) }]
      }).slice(0, 60)
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
      if (!route || route.geometry?.type !== 'LineString' || !Array.isArray(route.geometry.coordinates)) throw new Error('Invalid route')
      const result = { distanceMeters: Math.max(0, Number(route.distance) || 0), durationSeconds: Math.max(0, Number(route.duration) || 0), geometry: { type: 'LineString', coordinates: route.geometry.coordinates } }
      remember(key, result)
      return json(result)
    } catch {
      return json({ error: 'Walking route is unavailable right now' }, 503)
    }
  }

  return json({ error: 'Unknown map action' }, 400)
}
