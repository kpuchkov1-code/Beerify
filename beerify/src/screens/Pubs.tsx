import { useEffect, useMemo, useRef, useState } from 'react'
import maplibregl, { type GeoJSONSource, type Map as MapLibreMap } from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import type { GameAction, GameKind, GameView, RoomMembership } from '../types'
import { endRoomGame, sendGameAction, startRoomGame, useRoomGame } from '../lib/room'

type Venue = { id: string; name: string; lat: number; lng: number; type: string; address?: string }
type Route = { distanceMeters: number; durationSeconds: number; geometry: { type: 'LineString'; coordinates: number[][] }; fallback?: boolean }
type PubTool = 'map' | 'crawl' | 'golf' | 'bingo'

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

async function mapRequest<T>(path: string): Promise<T> {
  const response = await fetch(path)
  const body = await response.json() as T & { error?: string }
  if (!response.ok) throw new Error(body.error || 'Map request failed')
  return body
}

function LivePanel({ membership, game, onGame, kind }: { membership: RoomMembership; game: GameView | null; onGame: (game: GameView | null) => void; kind: GameKind }) {
  if (game && game.kind !== kind) return <p className="status-message">{game.title} is already live in this room.</p>
  if (!game) return membership.isHost ? <button className="btn btn--secondary" onClick={async () => onGame(await startRoomGame(membership, kind, 3))}>Start for the room</button> : <p className="status-message">The room host can start this for everyone.</p>
  const act = async (type: 'ready' | 'start' | 'advance' | 'end') => {
    if (type === 'end') { await endRoomGame(membership); onGame(null); return }
    onGame(await sendGameAction(membership, game, { type }))
  }
  return <div className="live-game-strip"><span className="status-badge status-badge--on">Live · {game.phase}</span><span>{game.players.filter((player) => !player.spectator).length} playing</span>{game.phase === 'lobby' && <button className="text-action" onClick={() => void act(game.canControl ? 'start' : 'ready')}>{game.canControl ? 'Begin when ready' : 'I’m ready'}</button>}{game.canControl && game.phase !== 'lobby' && <button className="text-action" onClick={() => void act('advance')}>Next round</button>}{game.canControl && <button className="text-action text-action--danger" onClick={() => void act('end')}>End</button>}</div>
}

export default function Pubs({ membership }: { membership: RoomMembership | null }) {
  const [tool, setTool] = useState<PubTool>('map')
  const [position, setPosition] = useState<{ lat: number; lng: number } | null>(null)
  const [venues, setVenues] = useState<Venue[]>(() => { try { return JSON.parse(localStorage.getItem('beerify-venues') || '[]') as Venue[] } catch { return [] } })
  const [crawl, setCrawl] = useState<Venue[]>([])
  const [route, setRoute] = useState<Route | null>(null)
  const [message, setMessage] = useState('')
  const [locating, setLocating] = useState(false)
  const [golfHole, setGolfHole] = useState(0)
  const [golfScores, setGolfScores] = useState<number[]>([])
  const [golfPars, setGolfPars] = useState<number[]>([3, 4, 5, 3, 4, 5, 3, 4, 5])
  const [golfDrinks, setGolfDrinks] = useState<string[]>([])
  const [checked, setChecked] = useState<Set<number>>(() => new Set([12]))
  const mapNode = useRef<HTMLDivElement>(null)
  const map = useRef<MapLibreMap | null>(null)
  const markers = useRef<maplibregl.Marker[]>([])
  const live = useRoomGame(membership)
  const card = useMemo(() => bingoCard(membership?.code ?? new Date().toISOString().slice(0, 10)), [membership?.code])

  useEffect(() => {
    if (!membership || live.game?.kind !== 'pub-bingo') return
    const progress = live.game.state.bingoByMember as Record<string, number[]> | undefined
    if (Array.isArray(progress?.[membership.memberId])) setChecked(new Set(progress[membership.memberId]))
  }, [live.game, membership])

  useEffect(() => {
    if (!mapNode.current || map.current) return
    map.current = new maplibregl.Map({ container: mapNode.current, style: (import.meta.env.VITE_MAP_STYLE_URL || BASE_STYLE) as never, center: [-0.12, 51.5], zoom: 12, attributionControl: false, maxTileCacheSize: 32, refreshExpiredTiles: false })
    map.current.addControl(new maplibregl.AttributionControl({ compact: false }))
    return () => { markers.current.forEach((marker) => marker.remove()); map.current?.remove(); map.current = null }
  }, [])

  useEffect(() => {
    const instance = map.current
    if (!instance) return
    markers.current.forEach((marker) => marker.remove())
    markers.current = venues.map((venue) => new maplibregl.Marker({ color: crawl.some((stop) => stop.id === venue.id) ? '#f6bd4b' : '#173f35' }).setLngLat([venue.lng, venue.lat]).setPopup(new maplibregl.Popup({ offset: 16 }).setText(venue.name)).addTo(instance))
    if (position) instance.flyTo({ center: [position.lng, position.lat], zoom: 13 })
  }, [venues, position, crawl])

  useEffect(() => {
    const instance = map.current
    if (!instance || !route) return
    const apply = () => {
      const data = { type: 'Feature' as const, properties: {}, geometry: route.geometry }
      const source = instance.getSource('crawl-route') as GeoJSONSource | undefined
      if (source) source.setData(data)
      else { instance.addSource('crawl-route', { type: 'geojson', data }); instance.addLayer({ id: 'crawl-route', type: 'line', source: 'crawl-route', paint: { 'line-color': '#f6bd4b', 'line-width': 5, 'line-opacity': .9 } }) }
    }
    if (instance.isStyleLoaded()) apply()
    else instance.once('load', apply)
  }, [route])

  function requestLocation() {
    setLocating(true); setMessage('')
    navigator.geolocation.getCurrentPosition(async ({ coords }) => {
      const next = { lat: coords.latitude, lng: coords.longitude }
      setPosition(next)
      try {
        const result = await mapRequest<{ venues: Venue[] }>(`/api/maps?action=nearby&lat=${next.lat}&lng=${next.lng}&radius=3000`)
        setVenues(result.venues); localStorage.setItem('beerify-venues', JSON.stringify(result.venues)); setMessage(`${result.venues.length} nearby places found.`)
      } catch (error) { setMessage(`${error instanceof Error ? error.message : 'Places unavailable'}. Showing your cached list.`) }
      setLocating(false)
    }, () => { setMessage('Location was not shared. You can still use cached places and external maps.'); setLocating(false) }, { enableHighAccuracy: false, timeout: 10_000, maximumAge: 300_000 })
  }

  async function calculateRoute() {
    if (crawl.length < 2) return
    try { setRoute(await mapRequest<Route>(`/api/maps?action=route&points=${encodeURIComponent(crawl.map((stop) => `${stop.lng},${stop.lat}`).join(';'))}`)); setMessage('Walking route ready.') }
    catch (error) { setRoute({ distanceMeters: 0, durationSeconds: 0, fallback: true, geometry: { type: 'LineString', coordinates: crawl.map((stop) => [stop.lng, stop.lat]) } }); setMessage(`${error instanceof Error ? error.message : 'Route unavailable'}. The map keeps a straight-stop plan and external directions still work.`) }
  }

  function moveStop(index: number, direction: -1 | 1) {
    const next = [...crawl]; const destination = index + direction
    if (destination < 0 || destination >= next.length) return
    const current = next[index]
    next[index] = next[destination]
    next[destination] = current
    setCrawl(next); setRoute(null)
  }

  async function sendPubAction(action: GameAction) {
    if (!membership || !live.game) return
    try { live.setGame(await sendGameAction(membership, live.game, action)) } catch (error) { setMessage(error instanceof Error ? error.message : 'Could not update the live score') }
  }

  function toggleBingo(index: number) {
    if (index === 12) return
    const next = new Set(checked)
    const adding = !next.has(index)
    if (adding) next.add(index)
    else next.delete(index)
    setChecked(next)
    if (live.game?.kind === 'pub-bingo') void sendPubAction({ type: 'bingo-toggle', value: index })
  }

  const mapsUrl = crawl.length ? `https://www.google.com/maps/dir/?api=1&destination=${crawl.at(-1)!.lat},${crawl.at(-1)!.lng}&waypoints=${crawl.slice(0, -1).map((stop) => `${stop.lat},${stop.lng}`).join('|')}&travelmode=walking` : 'https://maps.google.com'
  const appleMapsUrl = crawl.length ? `https://maps.apple.com/?daddr=${crawl.at(-1)!.lat},${crawl.at(-1)!.lng}&dirflg=w` : 'https://maps.apple.com/'
  const golfStops = crawl.length ? crawl.slice(0, 9) : venues.slice(0, 3)
  const bingoWinner = live.game?.kind === 'pub-bingo' ? live.game.players.find((player) => player.memberId === live.game?.state.bingoWinner)?.name : undefined
  const fullHouseWinner = live.game?.kind === 'pub-bingo' ? live.game.players.find((player) => player.memberId === live.game?.state.fullHouseWinner)?.name : undefined
  const golfByMember = live.game?.kind === 'pub-golf' && live.game.state.golfByMember && typeof live.game.state.golfByMember === 'object' ? live.game.state.golfByMember as Record<string, Record<string, { strokes: number; par: number }>> : {}

  return (
    <main className="screen pubs-screen">
      <header className="page-header page-header--stacked"><span className="page-kicker">OUT OUT</span><h1>Pub tools</h1><p>Find somewhere, build the crawl, or turn the route into a game.</p></header>
      <div className="segmented-control pub-tool-tabs" aria-label="Choose a pub tool">{(['map', 'crawl', 'golf', 'bingo'] as PubTool[]).map((item) => <button key={item} aria-pressed={tool === item} onClick={() => setTool(item)}>{item === 'map' ? 'Map' : item === 'crawl' ? 'Crawl' : item === 'golf' ? 'Golf' : 'Bingo'}</button>)}</div>

      <div className="pub-map" ref={mapNode} aria-label="Map of nearby pubs, bars and clubs" />
      <p className="map-attribution">Map data © OpenStreetMap contributors. Nearby results and routes may be incomplete.</p>
      {message && <p className="status-message" role="status">{message}</p>}

      {tool === 'map' && <section className="pub-tool-panel"><button className="btn btn--primary" disabled={locating} onClick={requestLocation}>{locating ? 'Finding your area…' : 'Use my location'}</button><div className="venue-list">{venues.slice(0, 16).map((venue) => <article key={venue.id}><span><strong>{venue.name}</strong><small>{venue.address || venue.type}</small></span><button className="text-action" disabled={crawl.length >= 12 || crawl.some((stop) => stop.id === venue.id)} onClick={() => setCrawl([...crawl, venue])}>{crawl.some((stop) => stop.id === venue.id) ? 'Added' : '+ Crawl'}</button></article>)}</div></section>}

      {tool === 'crawl' && <section className="pub-tool-panel"><div className="section-heading"><h2>Your crawl</h2><span>{crawl.length} / 12 stops</span></div>{crawl.length ? <ol className="crawl-list">{crawl.map((stop, index) => <li key={stop.id}><strong>{stop.name}</strong><span><button aria-label={`Move ${stop.name} up`} onClick={() => moveStop(index, -1)}>↑</button><button aria-label={`Move ${stop.name} down`} onClick={() => moveStop(index, 1)}>↓</button><button aria-label={`Remove ${stop.name}`} onClick={() => setCrawl(crawl.filter((item) => item.id !== stop.id))}>×</button></span></li>)}</ol> : <p className="empty-copy">Add places from the map to build a crawl.</p>}{route && <p>{route.fallback ? <strong>Straight-line fallback</strong> : <><strong>{(route.distanceMeters / 1000).toFixed(1)} km</strong> · about {Math.round(route.durationSeconds / 60)} minutes walking</>}</p>}<button className="btn btn--secondary" disabled={crawl.length < 2} onClick={() => void calculateRoute()}>Estimate route</button><div className="button-row"><a className="btn btn--quiet" href={appleMapsUrl} target="_blank" rel="noreferrer">Apple Maps ↗</a><a className="btn btn--quiet" href={mapsUrl} target="_blank" rel="noreferrer">Google Maps ↗</a></div></section>}

      {tool === 'golf' && <section className="pub-tool-panel"><div className="section-heading"><h2>Pub Golf</h2><span>3–9 holes</span></div>{membership && <LivePanel membership={membership} game={live.game} onGame={live.setGame} kind="pub-golf" />}{golfStops.length >= 3 ? <><article className="golf-hole"><span className="page-kicker">HOLE {golfHole + 1} · PAR {golfPars[golfHole]}</span><h3>{golfStops[golfHole]?.name}</h3><div className="preset-form__measure"><label className="field"><span className="field__label">Par</span><input type="number" min="1" max="9" value={golfPars[golfHole]} onChange={(event) => { const next = [...golfPars]; next[golfHole] = Math.max(1, Math.min(9, Number(event.target.value))); setGolfPars(next) }} /></label><label className="field"><span className="field__label">Your strokes / sips</span><input type="number" min="1" max="20" value={golfScores[golfHole] ?? ''} onChange={(event) => { const next = [...golfScores]; next[golfHole] = Math.max(1, Math.min(20, Number(event.target.value))); setGolfScores(next) }} /></label></div><label className="field"><span className="field__label">Hole drink</span><input value={golfDrinks[golfHole] ?? ''} placeholder="House lager" onChange={(event) => { const next = [...golfDrinks]; next[golfHole] = event.target.value.slice(0, 50); setGolfDrinks(next) }} /></label></article><div className="button-row"><button className="btn btn--secondary" disabled={golfHole === 0} onClick={() => setGolfHole((value) => value - 1)}>Previous</button><button className="btn btn--primary" disabled={!golfScores[golfHole]} onClick={() => { if (live.game?.kind === 'pub-golf' && golfScores[golfHole]) void sendPubAction({ type: 'golf-score', value: { hole: golfHole, strokes: golfScores[golfHole], par: golfPars[golfHole], drink: golfDrinks[golfHole] || 'House choice' } }); setGolfHole((value) => Math.min(golfStops.length - 1, value + 1)) }}>{golfHole === golfStops.length - 1 ? 'Finish hole' : 'Next hole'}</button></div><p className="golf-total">Score: <strong>{golfScores.reduce((sum, score, index) => sum + (score ? score - golfPars[index] : 0), 0) >= 0 ? '+' : ''}{golfScores.reduce((sum, score, index) => sum + (score ? score - golfPars[index] : 0), 0)}</strong></p>{Object.keys(golfByMember).length > 0 && <div className="game-leaderboard"><h3>Live scoreboard</h3><ol>{live.game?.players.map((player) => { const holes = Object.values(golfByMember[player.memberId] ?? {}); const relative = holes.reduce((total, hole) => total + hole.strokes - hole.par, 0); return <li key={player.memberId}><span>{holes.length}</span><strong>{player.name}</strong><span>{relative >= 0 ? '+' : ''}{relative}</span></li> })}</ol></div>}</> : <p className="empty-copy">Build a crawl with at least three stops first.</p>}</section>}

      {tool === 'bingo' && <section className="pub-tool-panel"><div className="section-heading"><h2>Pub Bingo</h2><span>{checked.size} / 25</span></div>{membership && <LivePanel membership={membership} game={live.game} onGame={live.setGame} kind="pub-bingo" />}<div className="bingo-card" aria-label="Seeded pub bingo card">{card.map((prompt, index) => <button key={`${prompt}-${index}`} aria-pressed={checked.has(index)} className={checked.has(index) ? 'bingo-square bingo-square--checked' : 'bingo-square'} onClick={() => toggleBingo(index)}>{prompt}</button>)}</div>{bingoWinner && <div className="bingo-win" role="status">{bingoWinner} called the first BINGO!</div>}{fullHouseWinner && <div className="bingo-win" role="status">{fullHouseWinner} got the first FULL HOUSE!</div>}{!bingoWinner && hasBingo(checked) && <div className="bingo-win" role="status">BINGO! First line is yours. Keep going for a full house.</div>}{!fullHouseWinner && checked.size === 25 && <div className="bingo-win" role="status">FULL HOUSE!</div>}{live.game?.kind === 'pub-bingo' && <div className="game-leaderboard"><h3>Live progress</h3><ol>{[...live.game.players].sort((a, b) => b.score - a.score).map((player) => <li key={player.memberId}><span>✓</span><strong>{player.name}</strong><span>{player.score}/25</span></li>)}</ol></div>}</section>}
    </main>
  )
}
