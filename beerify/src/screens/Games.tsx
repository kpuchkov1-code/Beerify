import { useEffect, useMemo, useRef, useState } from 'react'
import type { GameAction, GameKind, GameView, NightMode, RoomMembership, RoomState } from '../types'
import { createLocalGame, GAME_DEFINITIONS, gameByKind, promptFor, reduceLocalGame, type LocalGameState } from '../lib/games'
import { endRoomGame, fetchRoom, sendGameAction, startRoomGame, useRoomGame } from '../lib/room'

type GameFilter = 'all' | 'fast' | 'social' | 'quiz' | 'classic'

const GAME_FILTERS: { id: GameFilter; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'fast', label: 'Fast' },
  { id: 'social', label: 'Social' },
  { id: 'quiz', label: 'Quiz' },
  { id: 'classic', label: 'Classic' },
]

function matchesFilter(mechanic: string, filter: GameFilter) {
  if (filter === 'all') return true
  if (filter === 'fast') return mechanic === 'timer'
  if (filter === 'social') return mechanic === 'vote' || mechanic === 'submit'
  if (filter === 'quiz') return mechanic === 'trivia'
  return mechanic === 'prompt' || mechanic === 'choice'
}

interface Props {
  nightMode: NightMode
  membership: RoomMembership | null
  room: RoomState | null
  spiciness: number
  onSpiciness: (value: number) => void
  onOpenCrew: () => void
}

export default function Games({ nightMode, membership, room, spiciness, onSpiciness, onOpenCrew }: Props) {
  const [roomState, setRoomState] = useState(room)
  const [selected, setSelected] = useState<GameKind | null>(null)
  const [local, setLocal] = useState<LocalGameState | null>(null)
  const [answer, setAnswer] = useState('')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const [query, setQuery] = useState('')
  const [filter, setFilter] = useState<GameFilter>('all')
  const [now, setNow] = useState(Date.now())
  const motionLock = useRef(0)
  const { game, error, setGame } = useRoomGame(membership)
  const activeKind = game?.kind && game.kind !== 'pub-golf' && game.kind !== 'pub-bingo' ? game.kind : selected
  const definition = activeKind ? gameByKind(activeKind) : undefined
  const visibleGames = useMemo(() => {
    const needle = query.trim().toLocaleLowerCase('en-GB')
    return GAME_DEFINITIONS.filter((entry) => matchesFilter(entry.mechanic, filter) && (!needle || `${entry.title} ${entry.subtitle}`.toLocaleLowerCase('en-GB').includes(needle)))
  }, [filter, query])

  useEffect(() => {
    setRoomState(room)
    if (!membership) return
    let active = true
    const refresh = () => { void fetchRoom(membership.code).then((next) => { if (active) setRoomState(next) }).catch(() => {}) }
    refresh()
    const timer = setInterval(refresh, document.hidden ? 15_000 : 5_000)
    return () => { active = false; clearInterval(timer) }
  }, [membership, room])

  useEffect(() => {
    if (!game || game.kind === 'pub-golf' || game.kind === 'pub-bingo') return
    setSelected(game.kind)
    setLocal(null)
  }, [game])

  useEffect(() => {
    if (!(local?.phase === 'playing' && local.endsAt)) return
    const timer = setInterval(() => setNow(Date.now()), 250)
    return () => clearInterval(timer)
  }, [local?.phase, local?.endsAt])

  useEffect(() => {
    if (activeKind !== 'heads-up' || local?.phase !== 'playing') return
    const onMotion = (event: DeviceMotionEvent) => {
      const z = event.accelerationIncludingGravity?.z
      if (typeof z !== 'number' || Date.now() - motionLock.current < 900) return
      if (z < -6) { motionLock.current = Date.now(); setLocal((state) => state ? reduceLocalGame(reduceLocalGame(state, { type: 'score', value: 1 }), { type: 'advance' }) : state) }
      if (z > 7) { motionLock.current = Date.now(); setLocal((state) => state ? reduceLocalGame(state, { type: 'advance' }) : state) }
    }
    window.addEventListener('devicemotion', onMotion)
    return () => window.removeEventListener('devicemotion', onMotion)
  }, [activeKind, local?.phase])

  async function requestMotion() {
    const motion = DeviceMotionEvent as unknown as { requestPermission?: () => Promise<'granted' | 'denied'> }
    try { if (motion.requestPermission) await motion.requestPermission() } catch { /* Tap controls remain available. */ }
  }

  function openLocal(kind: GameKind) {
    setSelected(kind); setLocal(createLocalGame(kind, spiciness)); setMessage(''); setAnswer('')
  }

  async function startLive(kind: GameKind) {
    if (!membership) return
    setBusy(true); setMessage('')
    try { setGame(await startRoomGame(membership, kind, spiciness)); setSelected(kind); setLocal(null) }
    catch (cause) { setMessage(cause instanceof Error ? cause.message : 'Could not start the room game') }
    finally { setBusy(false) }
  }

  async function remoteAction(action: GameAction) {
    if (!membership || !game) return
    setBusy(true); setMessage('')
    try { setGame(await sendGameAction(membership, game, action)); setAnswer('') }
    catch (cause) { setMessage(cause instanceof Error ? cause.message : 'The room missed that action') }
    finally { setBusy(false) }
  }

  async function closeRemote() {
    if (!membership) return
    setBusy(true)
    try { await endRoomGame(membership); setGame(null); setSelected(null) }
    catch (cause) { setMessage(cause instanceof Error ? cause.message : 'Could not end the game') }
    finally { setBusy(false) }
  }

  function closeGame() { setSelected(null); setLocal(null); setAnswer(''); setMessage('') }

  if (nightMode === 'group' && !membership) return (
    <main className="screen games-screen">
      <header className="page-header page-header--stacked"><span className="page-kicker">GROUP NIGHT</span><h1>Reconnect your crew</h1><p>This night stays in Group mode. Rejoin the room once and live games will appear here automatically.</p></header>
      <button className="btn btn--primary" onClick={onOpenCrew}>Reconnect in Crew</button>
    </main>
  )

  if (definition && (local || game?.kind === definition.kind)) {
    return <GamePlay
      definition={definition}
      local={local}
      remote={game?.kind === definition.kind ? game : null}
      answer={answer}
      now={now}
      busy={busy}
      message={message || error || ''}
      onAnswer={setAnswer}
      onLocal={(action) => {
        if (action.type === 'start' && definition.kind === 'heads-up') void requestMotion()
        setLocal((state) => state ? reduceLocalGame(state, action) : state); setAnswer('')
      }}
      onRemote={(action) => void remoteAction(action)}
      onClose={game?.kind === definition.kind ? () => void closeRemote() : closeGame}
    />
  }

  return (
    <main className="screen games-screen">
      <header className="page-header page-header--stacked"><span className="page-kicker">{nightMode === 'group' ? 'GROUP NIGHT' : 'PASS THE PHONE'}</span><h1>Pick your poison</h1><p>{nightMode === 'group' ? 'The host starts once. Everyone in the group gets the same live round.' : 'Local games stay on this phone for the whole night.'}</p></header>
      <section className="spice-control" aria-labelledby="spice-title">
        <div><strong id="spice-title">Spiciness {spiciness}/5</strong><small>{['', 'Family-safe', 'Mild', 'Medium', 'Spicy', 'Unfiltered'][spiciness]}</small></div>
        <input aria-label="Game spiciness" type="range" min="1" max="5" step="1" value={spiciness} onChange={(event) => onSpiciness(Number(event.target.value))} />
      </section>
      <section className="game-finder" aria-label="Find a game"><label htmlFor="game-search">Find a game</label><input id="game-search" type="search" value={query} placeholder="Search 22 games" onChange={(event) => setQuery(event.target.value)} /><div aria-label="Filter games">{GAME_FILTERS.map((item) => <button key={item.id} aria-pressed={filter === item.id} onClick={() => setFilter(item.id)}>{item.label}</button>)}</div></section>
      {roomState?.gameLeaderboard?.length ? <section className="game-leaderboard"><div className="section-heading"><h2>Room leaderboard</h2><span>{roomState.code}</span></div><ol>{roomState.gameLeaderboard.slice(0, 5).map((entry, index) => <li key={entry.memberId}><span>{index + 1}</span><strong>{entry.name}</strong><span>{entry.score} pts</span></li>)}</ol></section> : null}
      {game && (game.kind === 'pub-golf' || game.kind === 'pub-bingo') && <section className="active-game-card"><span className="status-badge status-badge--on">LIVE</span><strong>{game.title}</strong><small>Open Pubs to continue the shared game.</small></section>}
      <div className="game-list">
        {visibleGames.map((entry, index) => <article className={filter === 'all' && !query && index < 5 ? 'game-row game-row--featured' : 'game-row'} key={entry.kind}>
          <span className="game-row__emoji" aria-hidden="true">{entry.emoji}</span>
          <span><strong>{entry.title}</strong><small>{entry.subtitle}</small><em>{entry.minPlayers}+ players · {entry.mechanic}</em></span>
          <div>{nightMode === 'solo' ? <button className="btn btn--primary" onClick={() => openLocal(entry.kind)}>Play</button> : membership?.isHost ? <button className="btn btn--primary" disabled={busy || Boolean(game)} onClick={() => void startLive(entry.kind)}>Start for group</button> : <span className="game-row__waiting">Host starts</span>}</div>
        </article>)}
      </div>
      {!visibleGames.length && <p className="empty-copy">No games match that search. Try another name or filter.</p>}
    </main>
  )
}

interface GamePlayProps {
  definition: NonNullable<ReturnType<typeof gameByKind>>
  local: LocalGameState | null
  remote: GameView | null
  answer: string
  now: number
  busy: boolean
  message: string
  onAnswer: (value: string) => void
  onLocal: (action: GameAction) => void
  onRemote: (action: GameAction) => void
  onClose: () => void
}

function GamePlay({ definition, local, remote, answer, now, busy, message, onAnswer, onLocal, onRemote, onClose }: GamePlayProps) {
  const phase = remote?.phase ?? local?.phase ?? 'lobby'
  const round = remote?.round ?? local?.round ?? 0
  const prompt = remote ? String(remote.state.prompt ?? '') : local ? promptFor(local.kind, local.spiciness, local.seed, local.round).text : ''
  const promptDefinition = local ? promptFor(local.kind, local.spiciness, local.seed, local.round) : null
  const options = remote ? (Array.isArray(remote.state.options) ? remote.state.options.map(String) : []) : promptDefinition?.options ?? []
  const effectiveOptions = definition.mechanic === 'vote'
    ? remote ? remote.players.filter((player) => player.ready && !player.spectator).map((player) => player.name) : options.length ? options : ['Player 1', 'Player 2', 'Player 3', 'Player 4']
    : options
  const dispatch = remote ? onRemote : onLocal
  const endsAt = remote?.endsAt ?? local?.endsAt
  const seconds = endsAt ? Math.max(0, Math.ceil((endsAt - (remote ? remote.serverNow + (Date.now() - now) : now)) / 1000)) : null
  const responseCount = Number(remote?.state.responseCount ?? local?.submissions.length ?? 0)
  const counts = remote?.state.counts && typeof remote.state.counts === 'object' ? remote.state.counts as Record<string, number> : local?.votes ?? {}
  const submissions = remote && Array.isArray(remote.state.submissions) ? remote.state.submissions.map(String) : local?.submissions ?? []

  return (
    <main className="screen game-play">
      <header className="page-header"><button className="icon-btn" aria-label="Close game" onClick={onClose}>←</button><div><span className="page-kicker">ROUND {round + 1}{local ? ` · ${local.score} PTS` : ''}</span><h1>{definition.emoji} {definition.title}</h1><p>{remote ? `Live in room · ${remote.players.length} players` : 'Local pass-the-phone game'}</p></div></header>
      {remote && <ul className="game-roster" aria-label="Game players">{remote.players.map((player) => <li key={player.memberId}><span aria-hidden="true">{player.ready ? '●' : '○'}</span><strong>{player.name}{player.spectator ? ' · spectating' : ''}</strong><span>{player.score} pts</span></li>)}</ul>}
      {phase === 'lobby' ? <section className="game-setup"><h2>Ready up</h2><p>{definition.subtitle}</p>{remote ? <>{!remote.privateState?.ready && <button className="btn btn--secondary" disabled={busy} onClick={() => dispatch({ type: 'ready' })}>I’m ready</button>}{remote.canControl && <button className="btn btn--primary btn--big" disabled={busy} onClick={() => dispatch({ type: 'start' })}>Start live round</button>}</> : <button className="btn btn--primary btn--big" onClick={() => dispatch({ type: 'start' })}>Start game</button>}</section> : phase === 'paused' ? <section className="game-setup"><h2>Host disconnected</h2><p>The game is paused. If they do not return, the oldest connected player can take over after 60 seconds.</p><button className="btn btn--primary" disabled={busy} onClick={() => dispatch({ type: 'claim-host' })}>Claim game host</button></section> : <>
        <section className="game-prompt" aria-live="polite"><span>{seconds !== null ? `${seconds}s` : `Round ${round + 1}`}</span><h2>{prompt}</h2>{responseCount > 0 && <small>{responseCount} response{responseCount === 1 ? '' : 's'} in</small>}</section>
        {phase === 'playing' && <div className="game-controls">
          {(definition.mechanic === 'choice' || definition.mechanic === 'trivia' || definition.mechanic === 'vote') && <div className="game-options">{effectiveOptions.map((option) => <button className="btn btn--secondary" disabled={busy || Boolean(remote?.privateState?.choice)} key={option} onClick={() => dispatch({ type: 'choose', value: option })}>{option}</button>)}</div>}
          {definition.mechanic === 'submit' && <form onSubmit={(event) => { event.preventDefault(); if (answer.trim()) dispatch({ type: 'submit', value: answer }) }}><label className="field"><span className="field__label">Your secret answer</span><input value={answer} maxLength={240} onChange={(event) => onAnswer(event.target.value)} /></label><button className="btn btn--primary" disabled={!answer.trim() || busy}>Lock it in</button></form>}
          {definition.mechanic === 'timer' && <div className="button-row"><button className="btn btn--primary btn--big" onClick={() => { dispatch({ type: 'score', value: 1 }); if (!remote) dispatch({ type: 'advance' }) }}>Got it +1</button>{(!remote || remote.canControl) && <button className="btn btn--secondary" onClick={() => dispatch({ type: 'skip' })}>Skip</button>}</div>}
          {definition.mechanic === 'prompt' && (!remote || remote.canControl) && <button className="btn btn--primary btn--big" onClick={() => dispatch({ type: 'advance' })}>Draw next</button>}
          {(remote?.canControl || (!remote && (definition.mechanic === 'choice' || definition.mechanic === 'vote'))) && definition.mechanic !== 'prompt' && <button className="btn btn--quiet" onClick={() => dispatch({ type: 'advance' })}>{remote ? 'Reveal / next round' : 'Reveal votes'}</button>}
        </div>}
        {phase === 'reveal' && <section className="game-reveal"><h2>Receipts</h2>{Object.keys(counts).length > 0 && <ul>{Object.entries(counts).sort((a, b) => b[1] - a[1]).map(([choice, count]) => <li key={choice}><strong>{choice}</strong><span>{count}</span></li>)}</ul>}{submissions.length > 0 && <ul>{submissions.map((submission, index) => <li key={`${submission}-${index}`}><span>“{submission}”</span></li>)}</ul>}{remote?.state.answer !== undefined && <p>Answer: <strong>{options[Number(remote.state.answer)] ?? String(remote.state.answer)}</strong></p>}{(!remote || remote.canControl) && <button className="btn btn--primary btn--big" onClick={() => dispatch({ type: 'advance' })}>Next round</button>}</section>}
      </>}
      {message && <p className="inline-error" role="alert">{message}</p>}
    </main>
  )
}
