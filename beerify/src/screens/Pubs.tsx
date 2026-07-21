import { useEffect, useMemo, useRef, useState } from 'react'
import maplibregl, { type Map as MapLibreMap } from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import type { CrawlRoute, GameAction, GameKind, GameView, GeocodeResult, NightSession, PubCrawlDraft, PubCrawlStop, RoomMembership, VenueResult } from '../types'
import { endRoomGame, sendGameAction, setRoomCrawl, startRoomGame, useRoom, useRoomGame } from '../lib/room'

type PubView = 'plan' | 'discover' | 'golf' | 'bingo'
type VenueFilter = 'all' | 'pub' | 'bar' | 'nightclub'

const BINGO_PROMPTS = [
  'A dog in the pub', 'Someone orders a Guinness', 'A birthday group', 'A broken glass', 'Matching outfits',
  'A song everyone knows', 'A pub quiz poster', 'Someone taking a group selfie', 'A football shirt', 'An unusual cocktail',
  'Cheers with a stranger', 'FREE', 'A lime in a drink', 'Someone dancing', 'A round of shots',
  'A crisps debate', 'A live musician', 'A colourful pint', 'A dramatic story', 'A coat on a stool',
  'Last orders called', 'A queue at the bar', 'Someone says “one more”', 'A great pub sign', 'Water for the table',
]

const BASE_STYLE = {
  version: 8 as const,
  sources: { osm: { type: 'raster' as const, tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'], tileSize: 256, attribution: '© OpenStreetMap contributors' } },
  layers: [{ id: 'osm', type: 'raster' as const, source: 'osm' }],
}

function bingoCard(seed: string) {
  const items = [...BINGO_PROMPTS]
  let value = [...seed].reduce((sum, char) => sum + char.charCodeAt(0), 17)
  for (let index = items.length - 1; index > 0; index--) {
    value = (value * 48271) % 2147483647
    const swap = value % (index + 1)
    ;[items[index], items[swap]] = [items[swap], items[index]]
  }
  items[12] = 'FREE'
  return items
}

function hasBingo(cells: Set<number>) {
  const lines = [0, 1, 2, 3, 4].flatMap((row) => [[0, 1, 2, 3, 4].map((col) => row * 5 + col), [0, 1, 2, 3, 4].map((col) => col * 5 + row)])
  lines.push([0, 6, 12, 18, 24], [4, 8, 12, 16, 20])
  return lines.some((line) => line.every((cell) => cells.has(cell)))
}

function asStop(venue: VenueResult): PubCrawlStop {
  const { distanceMeters: _distance, ...stop } = venue
  return stop
}

function formatDistance(meters: number) {
  return meters < 1_000 ? `${Math.max(1, Math.round(meters / 10) * 10)} m` : `${(meters / 1_000).toFixed(1)} km`
}

async function mapRequest<T>(path: string, signal?: AbortSignal): Promise<T> {
  const response = await fetch(path, { signal })
  const body = await response.json() as T & { error?: string }
  if (!response.ok) throw new Error(body.error || 'Map request failed')
  return body
}

function venueDirectionsUrl(venue: PubCrawlStop) {
  return `https://www.google.com/maps/dir/?api=1&destination=${venue.lat},${venue.lng}&travelmode=walking`
}

function MapCanvas({ mode, venues, crawl, route, selectedId, reducedMotion, onSelect, onGeolocate }: {
  mode: 'plan' | 'discover'
  venues: VenueResult[]
  crawl: PubCrawlStop[]
  route: CrawlRoute | null
  selectedId: string | null
  reducedMotion: boolean
  onSelect: (id: string) => void
  onGeolocate: (position: { lat: number; lng: number; accuracy: number }) => void
}) {
  const node = useRef<HTMLDivElement>(null)
  const map = useRef<MapLibreMap | null>(null)
  const markers = useRef<maplibregl.Marker[]>([])
  const selectRef = useRef(onSelect)
  const locateRef = useRef(onGeolocate)
  selectRef.current = onSelect
  locateRef.current = onGeolocate

  useEffect(() => {
    if (!node.current || map.current) return
    const configuredStyle = import.meta.env.VITE_MAP_STYLE_URL as string | undefined
    const instance = new maplibregl.Map({
      container: node.current,
      style: (configuredStyle || BASE_STYLE) as never,
      center: [-0.12, 51.5],
      zoom: 12,
      attributionControl: false,
      maxTileCacheSize: 32,
      refreshExpiredTiles: false,
    })
    map.current = instance
    instance.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right')
    const locate = new maplibregl.GeolocateControl({ positionOptions: { enableHighAccuracy: false, maximumAge: 300_000 }, trackUserLocation: false, showAccuracyCircle: true, showUserLocation: true })
    locate.on('geolocate', (event) => locateRef.current({ lat: event.coords.latitude, lng: event.coords.longitude, accuracy: event.coords.accuracy }))
    instance.addControl(locate, 'top-right')
    instance.addControl(new maplibregl.AttributionControl({ compact: true }), 'bottom-right')
    let loaded = false
    const markLoaded = () => { loaded = true }
    const fallBack = () => {
      if (configuredStyle && !loaded && !instance.isStyleLoaded()) instance.setStyle(BASE_STYLE as never)
    }
    instance.once('load', markLoaded)
    instance.once('error', fallBack)
    return () => {
      markers.current.forEach((marker) => marker.remove())
      markers.current = []
      instance.remove()
      map.current = null
    }
  }, [])

  useEffect(() => {
    const instance = map.current
    if (!instance) return
    markers.current.forEach((marker) => marker.remove())
    const byId = new Map<string, PubCrawlStop>()
    for (const stop of crawl) byId.set(stop.id, stop)
    if (mode === 'discover') for (const venue of venues) byId.set(venue.id, venue)
    markers.current = [...byId.values()].map((venue) => {
      const crawlIndex = crawl.findIndex((stop) => stop.id === venue.id)
      const marker = document.createElement('button')
      marker.type = 'button'
      marker.className = `pub-marker${crawlIndex >= 0 ? ' pub-marker--crawl' : ''}${selectedId === venue.id ? ' pub-marker--selected' : ''}`
      const label = document.createElement('span')
      label.textContent = crawlIndex >= 0 ? String(crawlIndex + 1) : '•'
      marker.append(label)
      marker.setAttribute('aria-label', `${venue.name}${crawlIndex >= 0 ? `, stop ${crawlIndex + 1}` : ''}`)
      marker.addEventListener('click', () => selectRef.current(venue.id))
      return new maplibregl.Marker({ element: marker, anchor: 'bottom' }).setLngLat([venue.lng, venue.lat]).addTo(instance)
    })
  }, [crawl, mode, selectedId, venues])

  useEffect(() => {
    const instance = map.current
    if (!instance) return
    const points = mode === 'discover' && venues.length ? venues : crawl
    if (!points.length) return
    const bounds = new maplibregl.LngLatBounds()
    points.forEach((point) => bounds.extend([point.lng, point.lat]))
    instance.fitBounds(bounds, { padding: mode === 'discover' ? 56 : 40, maxZoom: 14, duration: reducedMotion ? 0 : 500 })
  }, [crawl, mode, reducedMotion, venues])

  useEffect(() => {
    const instance = map.current
    const venue = venues.find((item) => item.id === selectedId) ?? crawl.find((item) => item.id === selectedId)
    if (!instance || !venue) return
    if (reducedMotion) instance.jumpTo({ center: [venue.lng, venue.lat] })
    else instance.easeTo({ center: [venue.lng, venue.lat], duration: 350 })
  }, [crawl, reducedMotion, selectedId, venues])

  useEffect(() => {
    const instance = map.current
    if (!instance) return
    const apply = () => {
      if (instance.getLayer('crawl-route')) instance.removeLayer('crawl-route')
      if (instance.getLayer('crawl-route-case')) instance.removeLayer('crawl-route-case')
      if (instance.getSource('crawl-route')) instance.removeSource('crawl-route')
      if (!route) return
      const data = { type: 'Feature' as const, properties: {}, geometry: route.geometry }
      instance.addSource('crawl-route', { type: 'geojson', data })
      instance.addLayer({ id: 'crawl-route-case', type: 'line', source: 'crawl-route', paint: { 'line-color': '#061c14', 'line-width': 9, 'line-opacity': .78 } })
      instance.addLayer({ id: 'crawl-route', type: 'line', source: 'crawl-route', paint: { 'line-color': '#ffb21a', 'line-width': 5, 'line-opacity': .96 } })
    }
    if (instance.isStyleLoaded()) apply()
    else instance.once('style.load', apply)
    return () => { instance.off('style.load', apply) }
  }, [route])

  return <div className={`pub-map pub-map--${mode}`} ref={node} role="region" aria-label={mode === 'plan' ? 'Map of your ordered pub crawl' : 'Map of nearby pubs, bars and clubs'} />
}

function LivePanel({ membership, game, onGame, onError, kind }: { membership: RoomMembership; game: GameView | null; onGame: (game: GameView | null) => void; onError: (message: string) => void; kind: GameKind }) {
  if (game && game.kind !== kind) return <p className="status-message">{game.title} is already live in this room.</p>
  if (!game) return membership.isHost ? <button className="btn btn--secondary" onClick={async () => { try { onGame(await startRoomGame(membership, kind, 3)) } catch (error) { onError(error instanceof Error ? error.message : 'Could not start for the squad') } }}>Start for the squad</button> : <p className="status-message">Waiting for the host to start this for the squad.</p>
  const act = async (type: 'ready' | 'start' | 'advance' | 'end') => {
    try {
      if (type === 'end') { await endRoomGame(membership); onGame(null); return }
      onGame(await sendGameAction(membership, game, { type }))
    } catch (error) { onError(error instanceof Error ? error.message : 'The squad missed that action') }
  }
  return <div className="live-game-strip"><span className="status-badge status-badge--on">Live · {game.phase}</span><span>{game.players.filter((player) => !player.spectator).length} playing</span>{game.phase === 'lobby' && <button className="text-action" onClick={() => void act(game.canControl ? 'start' : 'ready')}>{game.canControl ? 'Begin when ready' : 'I’m ready'}</button>}{game.canControl && game.phase !== 'lobby' && <button className="text-action" onClick={() => void act('advance')}>Next round</button>}{game.canControl && <button className="text-action text-action--danger" onClick={() => void act('end')}>End</button>}</div>
}

interface Props {
  session: NightSession | null
  membership: RoomMembership | null
  draft: PubCrawlDraft | null
  reducedMotion: boolean
  onDraftChange: (crawl: PubCrawlStop[]) => void
  onCrawlChange: (crawl: PubCrawlStop[]) => void
  onOpenCrew: () => void
}

export default function Pubs({ session, membership, draft, reducedMotion, onDraftChange, onCrawlChange, onOpenCrew }: Props) {
  const isGroup = session?.nightMode === 'group'
  const [view, setView] = useState<PubView>('plan')
  const [venues, setVenues] = useState<VenueResult[]>(() => { try { return JSON.parse(localStorage.getItem('beerify-venues') || '[]') as VenueResult[] } catch { return [] } })
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [filter, setFilter] = useState<VenueFilter>('all')
  const [route, setRoute] = useState<CrawlRoute | null>(null)
  const [routeStatus, setRouteStatus] = useState<'idle' | 'loading' | 'ready' | 'fallback'>('idle')
  const [routeAttempt, setRouteAttempt] = useState(0)
  const [message, setMessage] = useState('')
  const [locating, setLocating] = useState(false)
  const [searching, setSearching] = useState(false)
  const [query, setQuery] = useState('')
  const [locations, setLocations] = useState<GeocodeResult[]>([])
  const [areaLabel, setAreaLabel] = useState('')
  const [accuracy, setAccuracy] = useState<number | null>(null)
  const [golfHole, setGolfHole] = useState(0)
  const [golfScores, setGolfScores] = useState<number[]>([])
  const [golfPars, setGolfPars] = useState<number[]>([3, 4, 5, 3, 4, 5, 3, 4, 5])
  const [golfDrinks, setGolfDrinks] = useState<string[]>([])
  const [checked, setChecked] = useState<Set<number>>(() => new Set([12]))
  const crawlSync = useRef<Promise<unknown>>(Promise.resolve())
  const live = useRoomGame(membership)
  const groupRoom = useRoom(membership, null, 3_000)
  const crawl = useMemo(() => isGroup ? groupRoom.room?.crawl ?? session?.pubCrawl ?? [] : session ? session.pubCrawl : draft?.stops ?? [], [draft?.stops, groupRoom.room?.crawl, isGroup, session])
  const card = useMemo(() => bingoCard(membership?.code ?? session?.id ?? new Date().toISOString().slice(0, 10)), [membership?.code, session?.id])
  const visibleVenues = useMemo(() => filter === 'all' ? venues : venues.filter((venue) => venue.type === filter), [filter, venues])
  const selectedVenue = venues.find((venue) => venue.id === selectedId) ?? null

  useEffect(() => {
    if (view !== 'discover' || !visibleVenues.length) return
    if (!selectedId || !visibleVenues.some((venue) => venue.id === selectedId)) setSelectedId(visibleVenues[0].id)
  }, [selectedId, view, visibleVenues])

  useEffect(() => {
    if (!isGroup || !groupRoom.room) return
    if (JSON.stringify(session?.pubCrawl ?? []) !== JSON.stringify(groupRoom.room.crawl)) onCrawlChange(groupRoom.room.crawl)
  }, [groupRoom.room, isGroup, onCrawlChange, session?.pubCrawl])

  useEffect(() => {
    if (!membership || live.game?.kind !== 'pub-bingo') return
    const progress = live.game.state.bingoByMember as Record<string, number[]> | undefined
    if (Array.isArray(progress?.[membership.memberId])) setChecked(new Set(progress[membership.memberId]))
  }, [live.game, membership])

  useEffect(() => {
    if (live.game?.kind === 'pub-golf') setView('golf')
    if (live.game?.kind === 'pub-bingo') setView('bingo')
  }, [live.game?.kind])

  useEffect(() => {
    if (crawl.length < 2) { setRoute(null); setRouteStatus('idle'); return }
    const controller = new AbortController()
    const timer = window.setTimeout(async () => {
      setRouteStatus('loading')
      try {
        const result = await mapRequest<CrawlRoute>(`/api/maps?action=route&points=${encodeURIComponent(crawl.map((stop) => `${stop.lng},${stop.lat}`).join(';'))}`, controller.signal)
        setRoute(result); setRouteStatus('ready')
      } catch (error) {
        if (controller.signal.aborted) return
        setRoute({ distanceMeters: 0, durationSeconds: 0, fallback: true, geometry: { type: 'LineString', coordinates: crawl.map((stop) => [stop.lng, stop.lat]) } })
        setRouteStatus('fallback')
        setMessage(`${error instanceof Error ? error.message : 'Route unavailable'}. Showing the stop order as a straight line.`)
      }
    }, 450)
    return () => { clearTimeout(timer); controller.abort() }
  }, [crawl, routeAttempt])

  async function loadNearby(position: { lat: number; lng: number }, label: string, nextAccuracy: number | null = null) {
    setLocating(true); setMessage(''); setAreaLabel(label); setAccuracy(nextAccuracy); setView('discover')
    try {
      const result = await mapRequest<{ venues: VenueResult[] }>(`/api/maps?action=nearby&lat=${position.lat}&lng=${position.lng}&radius=3000`)
      setVenues(result.venues); localStorage.setItem('beerify-venues', JSON.stringify(result.venues)); setSelectedId(result.venues[0]?.id ?? null)
      setMessage(result.venues.length ? `${result.venues.length} nearby places, closest first.` : 'No named pubs, bars or clubs were found in this area.')
    } catch (error) {
      setMessage(`${error instanceof Error ? error.message : 'Places unavailable'}.${venues.length ? ' Showing your cached list.' : ''}`)
    } finally { setLocating(false) }
  }

  function requestLocation() {
    setLocating(true); setMessage('')
    navigator.geolocation.getCurrentPosition(({ coords }) => {
      void loadNearby({ lat: coords.latitude, lng: coords.longitude }, 'Near you', coords.accuracy)
    }, () => {
      setMessage('Location was not shared. Search by town or postcode instead.'); setLocating(false); setView('discover')
    }, { enableHighAccuracy: false, timeout: 10_000, maximumAge: 300_000 })
  }

  async function searchArea(event: React.FormEvent) {
    event.preventDefault()
    if (query.trim().length < 2) return
    setSearching(true); setMessage('')
    try {
      const result = await mapRequest<{ locations: GeocodeResult[] }>(`/api/maps?action=geocode&q=${encodeURIComponent(query.trim())}`)
      setLocations(result.locations)
      if (!result.locations.length) setMessage('No matching town or postcode was found.')
    } catch (error) { setLocations([]); setMessage(error instanceof Error ? error.message : 'Town search is unavailable') }
    finally { setSearching(false) }
  }

  async function updateCrawl(next: PubCrawlStop[]) {
    if (isGroup && !membership?.isHost) { setMessage('Only the squad host can change the shared crawl.'); return }
    if (isGroup && live.game?.kind === 'pub-golf') { setMessage('End Pub Golf before changing its shared holes.'); return }
    if (!session) { onDraftChange(next); setMessage(next.length ? 'Draft crawl saved on this device.' : 'Draft cleared.'); return }
    if (!isGroup) { onCrawlChange(next); return }
    if (!membership) return
    const task = crawlSync.current.catch(() => undefined).then(() => setRoomCrawl(membership, next))
    crawlSync.current = task
    try {
      const room = await task
      onCrawlChange(room.crawl)
      await groupRoom.refresh()
      setMessage('Shared crawl updated for everyone.')
    } catch (error) { setMessage(error instanceof Error ? error.message : 'Could not sync the squad crawl') }
  }

  function moveStop(index: number, direction: -1 | 1) {
    const next = [...crawl]; const destination = index + direction
    if (destination < 0 || destination >= next.length) return
    ;[next[index], next[destination]] = [next[destination], next[index]]
    void updateCrawl(next)
  }

  function updateHole(index: number, values: Partial<Pick<PubCrawlStop, 'par' | 'drink'>>) {
    void updateCrawl(crawl.map((stop, stopIndex) => stopIndex === index ? { ...stop, ...values } : stop))
  }

  async function sendPubAction(action: GameAction) {
    if (!membership || !live.game) return
    try { live.setGame(await sendGameAction(membership, live.game, action)) } catch (error) { setMessage(error instanceof Error ? error.message : 'Could not update the live score') }
  }

  function toggleBingo(index: number) {
    if (index === 12) return
    const next = new Set(checked)
    if (next.has(index)) next.delete(index); else next.add(index)
    setChecked(next)
    if (live.game?.kind === 'pub-bingo') void sendPubAction({ type: 'bingo-toggle', value: index })
  }

  const mapsUrl = crawl.length ? `https://www.google.com/maps/dir/?api=1&destination=${crawl.at(-1)!.lat},${crawl.at(-1)!.lng}&waypoints=${crawl.slice(0, -1).map((stop) => `${stop.lat},${stop.lng}`).join('|')}&travelmode=walking` : 'https://maps.google.com'
  const appleMapsUrl = crawl.length ? `https://maps.apple.com/?daddr=${crawl.at(-1)!.lat},${crawl.at(-1)!.lng}&dirflg=w` : 'https://maps.apple.com/'
  const liveHoles = live.game?.kind === 'pub-golf' && Array.isArray(live.game.state.holes) ? live.game.state.holes as PubCrawlStop[] : []
  const golfStops = (liveHoles.length ? liveHoles : crawl).slice(0, 9)
  const bingoWinner = live.game?.kind === 'pub-bingo' ? live.game.players.find((player) => player.memberId === live.game?.state.bingoWinner)?.name : undefined
  const fullHouseWinner = live.game?.kind === 'pub-bingo' ? live.game.players.find((player) => player.memberId === live.game?.state.fullHouseWinner)?.name : undefined
  const golfByMember = live.game?.kind === 'pub-golf' && live.game.state.golfByMember && typeof live.game.state.golfByMember === 'object' ? live.game.state.golfByMember as Record<string, Record<string, { strokes: number; par: number }>> : {}
  const groupCanPlayGolf = !isGroup || live.game?.kind === 'pub-golf' && live.game.phase === 'playing'
  const groupCanPlayBingo = !isGroup || live.game?.kind === 'pub-bingo' && live.game.phase === 'playing'

  if (isGroup && !membership) return (
    <main className="screen pubs-screen">
      <header className="page-header page-header--stacked"><span className="page-kicker">SQUAD NIGHT</span><h1>Reconnect the crawl</h1><p>Your route is still part of this Squad night. Reconnect once to restore the shared plan on every phone.</p></header>
      <button className="btn btn--primary" onClick={onOpenCrew}>Reconnect in Crew</button>
    </main>
  )

  if (view === 'golf') return <main className="screen pubs-screen pub-game-focus">
    <header className="page-header"><button className="icon-btn" aria-label="Back to crawl" onClick={() => setView('plan')}>←</button><div><span className="page-kicker">PLAY THE CRAWL</span><h1>⛳ Pub Golf</h1><p>{golfStops.length} stops become tonight’s holes.</p></div></header>
    {isGroup && membership && <LivePanel membership={membership} game={live.game} onGame={live.setGame} onError={setMessage} kind="pub-golf" />}
    {message && <p className="status-message" role="status">{message}</p>}
    {golfStops.length >= 3 ? <>
      <article className="golf-hole"><span className="page-kicker">HOLE {golfHole + 1} · PAR {golfStops[golfHole]?.par ?? golfPars[golfHole]}</span><h2>{golfStops[golfHole]?.name}</h2><div className="preset-form__measure"><label className="field"><span className="field__label">Par</span><input type="number" min="1" max="9" disabled={isGroup && (!membership?.isHost || Boolean(live.game))} value={golfStops[golfHole]?.par ?? golfPars[golfHole]} onChange={(event) => { const value = Math.max(1, Math.min(9, Number(event.target.value))); const next = [...golfPars]; next[golfHole] = value; setGolfPars(next); if (isGroup && !live.game) updateHole(golfHole, { par: value }) }} /></label><label className="field"><span className="field__label">Your strokes / sips</span><input type="number" min="1" max="20" disabled={!groupCanPlayGolf} value={golfScores[golfHole] ?? ''} onChange={(event) => { const next = [...golfScores]; next[golfHole] = Math.max(1, Math.min(20, Number(event.target.value))); setGolfScores(next) }} /></label></div><label className="field"><span className="field__label">Hole drink</span><input disabled={isGroup && (!membership?.isHost || Boolean(live.game))} value={golfDrinks[golfHole] ?? golfStops[golfHole]?.drink ?? ''} placeholder="House lager" onChange={(event) => { const next = [...golfDrinks]; next[golfHole] = event.target.value.slice(0, 50); setGolfDrinks(next) }} onBlur={() => { if (isGroup && !live.game && golfDrinks[golfHole] !== undefined) updateHole(golfHole, { drink: golfDrinks[golfHole] }) }} /></label></article>
      <div className="button-row"><button className="btn btn--secondary" disabled={golfHole === 0} onClick={() => setGolfHole((value) => value - 1)}>Previous</button><button className="btn btn--primary" disabled={!golfScores[golfHole] || !groupCanPlayGolf} onClick={() => { const par = golfStops[golfHole]?.par ?? golfPars[golfHole]; const drink = golfStops[golfHole]?.drink ?? golfDrinks[golfHole] ?? 'House choice'; if (live.game?.kind === 'pub-golf' && golfScores[golfHole]) void sendPubAction({ type: 'golf-score', value: { hole: golfHole, strokes: golfScores[golfHole], par, drink } }); setGolfHole((value) => Math.min(golfStops.length - 1, value + 1)) }}>{golfHole === golfStops.length - 1 ? 'Finish hole' : 'Next hole'}</button></div>
      <p className="golf-total">Score: <strong>{golfScores.reduce((sum, score, index) => sum + (score ? score - (golfStops[index]?.par ?? golfPars[index]) : 0), 0) >= 0 ? '+' : ''}{golfScores.reduce((sum, score, index) => sum + (score ? score - (golfStops[index]?.par ?? golfPars[index]) : 0), 0)}</strong></p>
      {Object.keys(golfByMember).length > 0 && <div className="game-leaderboard"><h3>Live scoreboard</h3><ol>{live.game?.players.map((player) => { const holes = Object.values(golfByMember[player.memberId] ?? {}); const relative = holes.reduce((total, hole) => total + hole.strokes - hole.par, 0); return <li key={player.memberId}><span>{holes.length}</span><strong>{player.name}</strong><span>{relative >= 0 ? '+' : ''}{relative}</span></li> })}</ol></div>}
    </> : <section className="pub-empty"><strong>Add at least three stops first.</strong><p>Your ordered crawl becomes the Golf course.</p><button className="btn btn--primary" onClick={() => setView('discover')}>Add pubs</button></section>}
  </main>

  if (view === 'bingo') return <main className="screen pubs-screen pub-game-focus">
    <header className="page-header"><button className="icon-btn" aria-label="Back to crawl" onClick={() => setView('plan')}>←</button><div><span className="page-kicker">PUB GAME</span><h1>▦ Pub Bingo</h1><p>The same seeded card, tracked live for the squad.</p></div></header>
    {isGroup && membership && <LivePanel membership={membership} game={live.game} onGame={live.setGame} onError={setMessage} kind="pub-bingo" />}
    {message && <p className="status-message" role="status">{message}</p>}
    <div className="bingo-card" aria-label="Seeded pub bingo card">{card.map((prompt, index) => <button key={`${prompt}-${index}`} disabled={!groupCanPlayBingo} aria-pressed={checked.has(index)} className={checked.has(index) ? 'bingo-square bingo-square--checked' : 'bingo-square'} onClick={() => toggleBingo(index)}>{prompt}</button>)}</div>
    {bingoWinner && <div className="bingo-win" role="status">{bingoWinner} called the first BINGO!</div>}{fullHouseWinner && <div className="bingo-win" role="status">{fullHouseWinner} got the first FULL HOUSE!</div>}{!bingoWinner && hasBingo(checked) && <div className="bingo-win" role="status">BINGO! First line is yours. Keep going for a full house.</div>}{!fullHouseWinner && checked.size === 25 && <div className="bingo-win" role="status">FULL HOUSE!</div>}
    {live.game?.kind === 'pub-bingo' && <div className="game-leaderboard"><h3>Live progress</h3><ol>{[...live.game.players].sort((a, b) => b.score - a.score).map((player) => <li key={player.memberId}><span>✓</span><strong>{player.name}</strong><span>{player.score}/25</span></li>)}</ol></div>}
  </main>

  if (view === 'discover') return <main className="screen pubs-screen pubs-discover">
    <header className="page-header"><button className="icon-btn" aria-label="Back to crawl" onClick={() => setView('plan')}>←</button><div><span className="page-kicker">ADD A STOP</span><h1>Find pubs</h1><p>{areaLabel || 'Search an area or use your location.'}</p></div></header>
    <form className="pub-search" onSubmit={(event) => void searchArea(event)}><label htmlFor="pub-area-search">Town or postcode</label><div><input id="pub-area-search" value={query} maxLength={80} placeholder="Soho or W1D" autoComplete="postal-code" onChange={(event) => setQuery(event.target.value)} /><button className="btn btn--secondary" disabled={searching || query.trim().length < 2}>{searching ? 'Searching…' : 'Search'}</button></div></form>
    {locations.length > 0 && <ul className="area-results" aria-label="Matching areas">{locations.map((location) => <li key={location.id}><button onClick={() => { setLocations([]); setQuery(location.label); void loadNearby({ lat: location.lat, lng: location.lng }, location.label) }}>{location.label}<span>Search here →</span></button></li>)}</ul>}
    <div className="discovery-layout">
      <MapCanvas mode="discover" venues={visibleVenues} crawl={crawl} route={null} selectedId={selectedId} reducedMotion={reducedMotion} onSelect={(id) => { setSelectedId(id); requestAnimationFrame(() => document.getElementById(`venue-${id}`)?.scrollIntoView({ block: 'nearest', behavior: reducedMotion ? 'auto' : 'smooth' })) }} onGeolocate={(next) => void loadNearby(next, 'Near you', next.accuracy)} />
      <section className="venue-results" aria-label="Nearby venues">
        <div className="venue-results__bar"><div className="venue-filters" aria-label="Filter places">{([['all', 'All'], ['pub', 'Pubs'], ['bar', 'Bars'], ['nightclub', 'Clubs']] as const).map(([id, label]) => <button key={id} aria-pressed={filter === id} onClick={() => setFilter(id)}>{label}</button>)}</div><button className="text-action" disabled={locating} onClick={requestLocation}>{locating ? 'Locating…' : 'Near me'}</button></div>
        {accuracy !== null && <p className="map-context">Location accuracy about {formatDistance(accuracy)}.</p>}
        {(message || live.error || groupRoom.error) && <p className="status-message" role="status">{message || live.error || groupRoom.error}</p>}
        {selectedVenue && visibleVenues.some((venue) => venue.id === selectedVenue.id) && <article className="venue-card venue-card--selected"><span className="page-kicker">SELECTED</span><h2>{selectedVenue.name}</h2><p>{selectedVenue.address || selectedVenue.type} · {formatDistance(selectedVenue.distanceMeters)} away</p><div className="button-row"><button className="btn btn--primary" disabled={(isGroup && (!membership?.isHost || live.game?.kind === 'pub-golf')) || crawl.length >= 12 || crawl.some((stop) => stop.id === selectedVenue.id)} onClick={() => void updateCrawl([...crawl, asStop(selectedVenue)])}>{crawl.some((stop) => stop.id === selectedVenue.id) ? 'Added to crawl' : isGroup && !membership?.isHost ? 'Host adds stops' : 'Add to crawl'}</button><a className="btn btn--quiet" href={venueDirectionsUrl(selectedVenue)} target="_blank" rel="noreferrer">Directions ↗</a></div></article>}
        <div className="venue-list">{visibleVenues.map((venue) => <article id={`venue-${venue.id}`} className={selectedId === venue.id ? 'venue-row venue-row--selected' : 'venue-row'} key={venue.id}><button className="venue-row__select" aria-pressed={selectedId === venue.id} onClick={() => setSelectedId(venue.id)}><strong>{venue.name}</strong><small>{venue.address || venue.type} · {formatDistance(venue.distanceMeters)}</small></button><button className="text-action" disabled={(isGroup && (!membership?.isHost || live.game?.kind === 'pub-golf')) || crawl.length >= 12 || crawl.some((stop) => stop.id === venue.id)} onClick={() => void updateCrawl([...crawl, asStop(venue)])}>{crawl.some((stop) => stop.id === venue.id) ? 'Added' : '+ Crawl'}</button></article>)}</div>
        {!visibleVenues.length && !locating && <section className="pub-empty"><strong>No places to show yet.</strong><p>Search a town or postcode, or use your location.</p><button className="btn btn--primary" onClick={requestLocation}>Use my location</button></section>}
      </section>
    </div>
  </main>

  return <main className="screen pubs-screen pubs-plan">
    <header className="page-header page-header--stacked"><span className="page-kicker">{isGroup ? 'SHARED CRAWL' : session ? 'YOUR NIGHT' : 'PLAN AHEAD'}</span><h1>{isGroup ? 'Everyone, same route' : 'Your crawl'}</h1><p>{isGroup ? membership?.isHost ? 'You set the order once. Every phone follows the same shared plan.' : 'Follow the host’s live stop order and route.' : session ? 'Build the route, then turn it into a game.' : 'Save a route now and bring it into your next Solo or hosted Squad night.'}</p></header>
    {crawl.length ? <>
      <section className="crawl-map-shell"><MapCanvas mode="plan" venues={[]} crawl={crawl} route={route} selectedId={selectedId} reducedMotion={reducedMotion} onSelect={setSelectedId} onGeolocate={(next) => void loadNearby(next, 'Near you', next.accuracy)} /><div className="route-summary"><span><strong>{crawl.length}</strong><small>stops</small></span><span><strong>{routeStatus === 'loading' ? '…' : route && !route.fallback ? formatDistance(route.distanceMeters) : '—'}</strong><small>walking</small></span><span><strong>{routeStatus === 'loading' ? '…' : route && !route.fallback ? `${Math.round(route.durationSeconds / 60)} min` : '—'}</strong><small>estimate</small></span></div></section>
      {routeStatus === 'fallback' && <p className="status-message" role="status">Walking directions are unavailable. The map shows the stop order as a straight line. <button className="text-action" onClick={() => setRouteAttempt((value) => value + 1)}>Retry</button></p>}
      <section className="crawl-plan"><div className="section-heading"><h2>Stop order</h2><span>{crawl.length} / 12</span></div><ol className="crawl-list">{crawl.map((stop, index) => <li className={selectedId === stop.id ? 'crawl-stop crawl-stop--selected' : 'crawl-stop'} key={stop.id}><button className="crawl-stop__main" onClick={() => setSelectedId(stop.id)}><span>{index + 1}</span><span><strong>{stop.name}</strong><small>{stop.address || stop.type}</small></span></button><span className="crawl-stop__actions"><button disabled={index === 0 || (isGroup && (!membership?.isHost || live.game?.kind === 'pub-golf'))} aria-label={`Move ${stop.name} up`} onClick={() => moveStop(index, -1)}>↑</button><button disabled={index === crawl.length - 1 || (isGroup && (!membership?.isHost || live.game?.kind === 'pub-golf'))} aria-label={`Move ${stop.name} down`} onClick={() => moveStop(index, 1)}>↓</button><button disabled={isGroup && (!membership?.isHost || live.game?.kind === 'pub-golf')} aria-label={`Remove ${stop.name}`} onClick={() => void updateCrawl(crawl.filter((item) => item.id !== stop.id))}>×</button></span></li>)}</ol><button className="btn btn--primary btn--big" onClick={() => setView('discover')}>{isGroup && !membership?.isHost ? 'Browse nearby pubs' : 'Add pubs'}</button><div className="button-row"><a className="btn btn--secondary" href={mapsUrl} target="_blank" rel="noreferrer">Google route ↗</a><a className="btn btn--quiet" href={appleMapsUrl} target="_blank" rel="noreferrer">Apple Maps ↗</a></div></section>
    </> : <section className="pub-empty pub-empty--hero"><span aria-hidden="true">⌖</span><h2>Build tonight’s route</h2><p>Search ahead or start from where you are. You can add up to 12 stops.</p><div className="button-row"><button className="btn btn--primary" onClick={() => setView('discover')}>Search town or postcode</button><button className="btn btn--secondary" disabled={locating} onClick={requestLocation}>{locating ? 'Finding you…' : 'Use my location'}</button></div></section>}
    {(message || live.error || groupRoom.error) && routeStatus !== 'fallback' && <p className="status-message" role="status">{message || live.error || groupRoom.error}</p>}
    {session && <section className="pub-play"><div className="section-heading"><h2>Play on the crawl</h2><span>Optional</span></div><div className="pub-play__choices"><button disabled={crawl.length < 3} onClick={() => setView('golf')}><span>⛳</span><strong>Pub Golf</strong><small>{crawl.length < 3 ? 'Needs 3 stops' : `${Math.min(9, crawl.length)} holes ready`}</small></button><button onClick={() => setView('bingo')}><span>▦</span><strong>Pub Bingo</strong><small>Same card for everyone</small></button></div></section>}
  </main>
}
