import { createHash, randomInt, randomUUID } from 'node:crypto'
import { Redis } from '@upstash/redis'
import { waitUntil } from '@vercel/functions'
import { planRoomPushes, sendPlannedPushes, type PushRegistration } from './apns'
import type { GameAction, GameKind, GamePhase, GamePlayer, GameView } from '../src/types'
import { gameByKind, promptFor } from '../src/lib/games'

const ROOM_TTL_SECONDS = 24 * 60 * 60
const MEMBER_LIMIT = 20
const EVENT_LIMIT = 50
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
const TARGETS = new Set(['glow', 'buzz', 'wavy', 'tipsy', 'smashed', 'merry', 'bignight'])
const LEADERBOARD_MODES = new Set(['social', 'balanced', 'chaos'])
const STATUSES = new Set(['sober', 'warming', 'in-zone', 'over', 'way-over'])
const REACTIONS = new Set(['cheers', 'on-my-way', 'get-another', 'scenes', 'water-run', 'food'])
const EVENT_TYPES = new Set(['drink', 'reaction', 'cheers-countdown', 'round-invite', 'round-order', 'round-bought'])
const ICONS = new Set(['pint', 'bottle', 'can', 'ipa', 'stout', 'cider', 'ale', 'wine-red', 'wine-white', 'sparkling', 'spirit', 'cocktail', 'shot', 'alcopop', 'zero'])
const UUID = /^[0-9a-f-]{36}$/
const GAME_KINDS = new Set<GameKind>([
  'heads-up', 'psych', 'hot-takes', 'bomb-pass', 'medusa', 'bus-driver', 'dare-ladder', 'flip-cup', 'who-said-it', 'id-game',
  'higher-lower', 'kings-cup', 'would-you-rather', 'most-likely-to', 'never-have-i-ever', 'truth-or-dare', 'trivia',
  'two-truths-lie', 'categories', 'emoji-charades', 'roulette', 'guess-bac', 'pub-golf', 'pub-bingo',
])

interface RoomMeta {
  code: string
  name: string
  createdAt: number
  theme: 'green' | 'red' | 'blue'
  labels: Record<string, string>
  hostMemberId: string
  leaderboardMode?: 'social' | 'balanced' | 'chaos'
}

interface StoredMember {
  id: string
  name: string
  bac: number
  units: number
  drinks: number
  distinctDrinks: number
  targetId: string
  status: string
  inSession: boolean
  updatedAt: number
  tokenHash: string
}

interface StoredEvent {
  id: string
  type: string
  actorId: string
  actorName: string
  at: number
  refId?: string
  text?: string
  reaction?: string
  drink?: { name: string; brand?: string; icon: string; units: number }
  startsAt?: number
}

interface StoredGame {
  id: string
  kind: GameKind
  title: string
  phase: GamePhase
  hostMemberId: string
  createdAt: number
  updatedAt: number
  revision: number
  round: number
  spiciness: number
  seed: number
  players: GamePlayer[]
  state: Record<string, unknown>
  privateByMember: Record<string, Record<string, unknown>>
  processedActionIds: string[]
  endsAt?: number
  pausedPhase?: GamePhase
}

let client: Redis | null = null
let localClient: Redis | null = null

class MemoryRedis {
  strings = new Map<string, unknown>()
  hashes = new Map<string, Map<string, unknown>>()
  sorted = new Map<string, { score: number; member: unknown }[]>()
  expires = new Map<string, number>()

  purge(key: string) {
    const expiresAt = this.expires.get(key)
    if (!expiresAt || expiresAt > Date.now()) return
    this.strings.delete(key); this.hashes.delete(key); this.sorted.delete(key); this.expires.delete(key)
  }

  async get<T>(key: string): Promise<T | null> {
    this.purge(key)
    return (this.strings.get(key) as T | undefined) ?? null
  }

  async set(key: string, value: unknown, options?: { nx?: boolean; ex?: number }): Promise<string | null> {
    this.purge(key)
    if (options?.nx && this.strings.has(key)) return null
    this.strings.set(key, value)
    if (options?.ex) this.expires.set(key, Date.now() + options.ex * 1000)
    return 'OK'
  }

  async hgetall<T>(key: string): Promise<T | null> {
    this.purge(key)
    const hash = this.hashes.get(key)
    return hash ? Object.fromEntries(hash) as T : null
  }

  async hget<T>(key: string, field: string): Promise<T | null> {
    this.purge(key)
    return (this.hashes.get(key)?.get(field) as T | undefined) ?? null
  }

  async hset(key: string, values: Record<string, unknown>): Promise<number> {
    this.purge(key)
    const hash = this.hashes.get(key) ?? new Map<string, unknown>()
    let added = 0
    for (const [field, value] of Object.entries(values)) { if (!hash.has(field)) added++; hash.set(field, value) }
    this.hashes.set(key, hash)
    return added
  }

  async hdel(key: string, ...fields: string[]): Promise<number> {
    this.purge(key)
    const hash = this.hashes.get(key)
    return hash ? fields.reduce((count, field) => count + Number(hash.delete(field)), 0) : 0
  }

  async del(...keys: string[]): Promise<number> {
    let removed = 0
    for (const key of keys) {
      removed += Number(this.strings.delete(key)) + Number(this.hashes.delete(key)) + Number(this.sorted.delete(key))
      this.expires.delete(key)
    }
    return removed
  }

  async hincrby(key: string, field: string, amount: number): Promise<number> {
    const current = Number(await this.hget(key, field) ?? 0) + amount
    await this.hset(key, { [field]: current })
    return current
  }

  async zadd(key: string, value: { score: number; member: unknown }): Promise<number> {
    this.purge(key)
    const entries = this.sorted.get(key) ?? []
    entries.push(value)
    entries.sort((a, b) => a.score - b.score)
    this.sorted.set(key, entries)
    return 1
  }

  async zrange<T>(key: string, start: number, stop: number): Promise<T> {
    this.purge(key)
    const entries = this.sorted.get(key) ?? []
    const end = stop < 0 ? entries.length + stop + 1 : stop + 1
    return entries.slice(start, end).map((entry) => entry.member) as T
  }

  async zcard(key: string): Promise<number> { this.purge(key); return this.sorted.get(key)?.length ?? 0 }

  async zremrangebyrank(key: string, start: number, stop: number): Promise<number> {
    this.purge(key)
    const entries = this.sorted.get(key) ?? []
    const removed = entries.splice(start, stop - start + 1).length
    this.sorted.set(key, entries)
    return removed
  }

  async expire(key: string, seconds: number): Promise<number> {
    this.purge(key)
    if (!this.strings.has(key) && !this.hashes.has(key) && !this.sorted.has(key)) return 0
    this.expires.set(key, Date.now() + seconds * 1000)
    return 1
  }
}

function db(): Redis {
  if (!client) {
    const url = process.env.UPSTASH_REDIS_REST_URL
    const token = process.env.UPSTASH_REDIS_REST_TOKEN
    if ((!url || !token) && process.env.BEERIFY_LOCAL_DEV === '1') {
      // ponytail: one-process memory storage keeps local Crew usable; production still requires Redis.
      localClient ??= new MemoryRedis() as unknown as Redis
      return localClient
    }
    if (!url || !token) throw new Error('Redis is not configured')
    client = new Redis({ url, token, signal: () => AbortSignal.timeout(4_000) })
  }
  return client
}

function metaKey(code: string): string { return `beerify:room:${code}` }
function membersKey(code: string): string { return `${metaKey(code)}:members` }
function eventsKey(code: string): string { return `${metaKey(code)}:events` }
function statsKey(code: string): string { return `${metaKey(code)}:stats` }
function pushesKey(code: string): string { return `${metaKey(code)}:push` }
function gameKey(code: string): string { return `${metaKey(code)}:game` }
function gameLockKey(code: string): string { return `${gameKey(code)}:lock` }

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'Access-Control-Allow-Origin': '*' },
  })
}

export function OPTIONS(): Response {
  return new Response(null, { status: 204, headers: {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  } })
}

function normalizeCode(value: unknown): string | null {
  if (typeof value !== 'string') return null
  const code = value.trim().toUpperCase()
  return /^[A-Z2-9]{6}$/.test(code) ? code : null
}

function cleanText(value: unknown, max: number): string | null {
  if (typeof value !== 'string') return null
  const clean = value.trim().slice(0, max)
  return clean || null
}

function clamp(value: unknown, min: number, max: number): number {
  const number = typeof value === 'number' && Number.isFinite(value) ? value : 0
  return Math.min(max, Math.max(min, number))
}

function tokenHash(token: string): string {
  return createHash('sha256').update(token).digest('hex')
}

function validId(value: unknown): value is string {
  return typeof value === 'string' && UUID.test(value)
}

function validCredential(id: unknown, token: unknown): id is string {
  return validId(id) && validId(token)
}

function sanitizeMember(value: unknown, token: string): StoredMember | null {
  if (typeof value !== 'object' || value === null) return null
  const m = value as Record<string, unknown>
  const name = cleanText(m.name, 30)
  if (!validCredential(m.id, token) || !name) return null
  const targetId = typeof m.targetId === 'string' && TARGETS.has(m.targetId) ? m.targetId : 'glow'
  const status = typeof m.status === 'string' && STATUSES.has(m.status) ? m.status : 'sober'
  return {
    id: m.id,
    name,
    bac: clamp(m.bac, 0, 0.5),
    units: clamp(m.units, 0, 200),
    drinks: Math.round(clamp(m.drinks, 0, 200)),
    distinctDrinks: Math.round(clamp(m.distinctDrinks, 0, 200)),
    targetId,
    status,
    inSession: Boolean(m.inSession),
    updatedAt: Date.now(),
    tokenHash: tokenHash(token),
  }
}

function publicMember(member: StoredMember): Omit<StoredMember, 'tokenHash'> {
  const { tokenHash: _secret, ...safe } = member
  return safe
}

function publicEvent(event: StoredEvent): StoredEvent {
  return event
}

async function readMeta(code: string): Promise<RoomMeta | null> {
  return db().get<RoomMeta>(metaKey(code))
}

async function readMembers(code: string): Promise<Record<string, StoredMember>> {
  const stored = await db().hgetall<Record<string, StoredMember>>(membersKey(code))
  const members = stored ?? {}
  const staleIds = Object.entries(members)
    .filter(([, member]) => !member || member.updatedAt < Date.now() - ROOM_TTL_SECONDS * 1000)
    .map(([id]) => id)
  if (staleIds.length) await db().hdel(membersKey(code), ...staleIds)
  for (const id of staleIds) delete members[id]
  return members
}

async function readEvents(code: string): Promise<StoredEvent[]> {
  return await db().zrange<StoredEvent[]>(eventsKey(code), 0, -1) ?? []
}

function activeRound(events: StoredEvent[]) {
  const invitations = events.filter((event) => event.type === 'round-invite')
  const invite = invitations.at(-1)
  if (!invite || events.some((event) => event.type === 'round-bought' && event.refId === invite.id)) return null
  return {
    id: invite.id,
    buyerId: invite.actorId,
    buyerName: invite.actorName,
    createdAt: invite.at,
    orders: events
      .filter((event) => event.type === 'round-order' && event.refId === invite.id && event.text)
      .map((event) => ({ memberId: event.actorId, memberName: event.actorName, order: event.text! })),
  }
}

async function buildRoom(code: string): Promise<unknown | null> {
  const meta = await readMeta(code)
  if (!meta) return null
  const [members, events, stats, game] = await Promise.all([readMembers(code), readEvents(code), db().hgetall<Record<string, number>>(statsKey(code)), readGame(code)])
  const bought = events.filter((event) => event.type === 'round-bought').map((event) => event.actorId)
  const publicMembers = Object.values(members).map(publicMember).sort((a, b) => a.name.localeCompare(b.name))
  const rank = (read: (member: Omit<StoredMember, 'tokenHash'>) => number) => publicMembers
    .map((member) => ({ memberId: member.id, name: member.name, value: read(member) }))
    .filter((entry) => entry.value > 0)
    .sort((a, b) => b.value - a.value || a.name.localeCompare(b.name)).slice(0, 3)
  const mode = meta.leaderboardMode ?? 'balanced'
  const drinks = {
    drinks: rank((member) => member.drinks),
    units: rank((member) => member.units),
  }
  const social = {
    ...drinks,
    rounds: rank((member) => Number(stats?.[`${member.id}:rounds`] ?? 0)),
    reactions: rank((member) => Number(stats?.[`${member.id}:reactions`] ?? 0)),
    activity: rank((member) => Number(stats?.[`${member.id}:activity`] ?? 0)),
    variety: rank((member) => member.distinctDrinks),
  }
  const categories = mode === 'social' ? drinks : { ...social, ...(mode === 'chaos' ? { bac: rank((member) => member.bac) } : {}) }
  const gameLeaderboard = publicMembers.map((member) => ({
    memberId: member.id,
    name: member.name,
    score: Number(stats?.[`${member.id}:game-score`] ?? 0),
    games: Number(stats?.[`${member.id}:games`] ?? 0),
  })).filter((entry) => entry.score || entry.games).sort((a, b) => b.score - a.score || a.name.localeCompare(b.name))
  return {
    ...meta,
    leaderboardMode: mode,
    leaderboard: { mode, categories },
    members: publicMembers,
    events: events.map(publicEvent),
    activeRound: activeRound(events),
    roundRota: bought.slice(-MEMBER_LIMIT),
    activeGame: game ? gameSummary(game) : undefined,
    gameLeaderboard,
  }
}

async function refreshRoom(code: string): Promise<void> {
  await Promise.all([
    db().expire(metaKey(code), ROOM_TTL_SECONDS),
    db().expire(membersKey(code), ROOM_TTL_SECONDS),
    db().expire(eventsKey(code), ROOM_TTL_SECONDS),
    db().expire(statsKey(code), ROOM_TTL_SECONDS),
    db().expire(pushesKey(code), ROOM_TTL_SECONDS),
    db().expire(gameKey(code), ROOM_TTL_SECONDS),
  ])
}

async function authenticate(code: string, memberId: string, memberToken: string): Promise<StoredMember | null> {
  const member = await db().hget<StoredMember>(membersKey(code), memberId)
  return member?.tokenHash === tokenHash(memberToken) ? member : null
}

async function touchMember(code: string, member: StoredMember): Promise<StoredMember> {
  const next = { ...member, updatedAt: Date.now() }
  await db().hset(membersKey(code), { [member.id]: next })
  return next
}

function gameSummary(game: StoredGame) {
  return { id: game.id, kind: game.kind, title: game.title, phase: game.phase, participantCount: game.players.length, hostMemberId: game.hostMemberId, updatedAt: game.updatedAt }
}

async function readGame(code: string): Promise<StoredGame | null> {
  return await db().get<StoredGame>(gameKey(code))
}

async function saveGame(code: string, game: StoredGame): Promise<void> {
  await db().set(gameKey(code), game, { ex: ROOM_TTL_SECONDS })
}

function publicGameState(game: StoredGame): Record<string, unknown> {
  const { answer: _answer, choices: _choices, submissions: _submissions, ...safe } = game.state
  const choices = _choices && typeof _choices === 'object' ? Object.values(_choices as Record<string, unknown>) : []
  const counts = choices.reduce<Record<string, number>>((result, value) => {
    const key = String(value); result[key] = (result[key] ?? 0) + 1; return result
  }, {})
  return {
    ...safe,
    responseCount: choices.length + (_submissions && typeof _submissions === 'object' ? Object.keys(_submissions).length : 0),
    ...(game.phase === 'reveal' || game.phase === 'finished' ? {
      counts,
      answer: _answer,
      submissions: _submissions && typeof _submissions === 'object' ? Object.values(_submissions as Record<string, unknown>) : [],
    } : {}),
  }
}

function gameView(game: StoredGame, memberId: string): GameView {
  const choices = game.state.choices && typeof game.state.choices === 'object' ? game.state.choices as Record<string, unknown> : {}
  const submissions = game.state.submissions && typeof game.state.submissions === 'object' ? game.state.submissions as Record<string, unknown> : {}
  const self = game.players.find((player) => player.memberId === memberId)
  return {
    ...gameSummary(game), revision: game.revision, serverNow: Date.now(), round: game.round, spiciness: game.spiciness,
    players: game.players, state: publicGameState(game), endsAt: game.endsAt, canControl: game.hostMemberId === memberId,
    privateState: { ...game.privateByMember[memberId], choice: choices[memberId], submission: submissions[memberId], ready: self?.ready, spectator: self?.spectator },
  }
}

function beginGameRound(game: StoredGame, now: number): StoredGame {
  const definition = gameByKind(game.kind)
  const prompt = definition ? promptFor(game.kind, game.spiciness, game.seed, game.round) : { text: game.kind === 'pub-golf' ? 'Play the current hole.' : 'Complete a square.', level: 1 }
  const options = definition?.mechanic === 'vote' && !prompt.options?.length ? game.players.filter((player) => !player.spectator).map((player) => player.name) : prompt.options ?? []
  const roundState = { prompt: prompt.text, options, answer: prompt.answer, choices: {}, submissions: {} }
  return {
    ...game,
    phase: 'playing',
    updatedAt: now,
    revision: game.revision + 1,
    endsAt: definition?.seconds ? now + definition.seconds * 1000 : undefined,
    state: game.kind === 'pub-golf' || game.kind === 'pub-bingo' ? { ...game.state, ...roundState } : roundState,
    privateByMember: {},
    players: game.players.map((player) => player.spectator ? { ...player, spectator: false, ready: true } : player),
    pausedPhase: undefined,
  }
}

function completedBingo(cells: number[]): boolean {
  const checked = new Set(cells)
  const lines = [0, 1, 2, 3, 4].flatMap((row) => [[0, 1, 2, 3, 4].map((column) => row * 5 + column), [0, 1, 2, 3, 4].map((column) => column * 5 + row)])
  lines.push([0, 6, 12, 18, 24], [4, 8, 12, 16, 20])
  return lines.some((line) => line.every((cell) => checked.has(cell)))
}

async function reconcileGamePresence(code: string, game: StoredGame, currentMember: StoredMember): Promise<StoredGame> {
  const now = Date.now()
  const members = await readMembers(code)
  let next = game
  if (!game.players.some((player) => player.memberId === currentMember.id)) {
    next = { ...next, players: [...next.players, { memberId: currentMember.id, name: currentMember.name, ready: false, score: 0, spectator: true }], revision: next.revision + 1, updatedAt: now }
  }
  const host = members[next.hostMemberId]
  if (currentMember.id === next.hostMemberId && next.phase === 'paused') {
    next = { ...next, phase: next.pausedPhase && next.pausedPhase !== 'paused' ? next.pausedPhase : 'playing', pausedPhase: undefined, revision: next.revision + 1, updatedAt: now }
  } else if (currentMember.id !== next.hostMemberId && (!host || host.updatedAt < now - 60_000) && next.phase !== 'paused' && next.phase !== 'finished') {
    next = { ...next, pausedPhase: next.phase, phase: 'paused', endsAt: undefined, revision: next.revision + 1, updatedAt: now }
  }
  if (next !== game) await saveGame(code, next)
  return next
}

async function advanceExpiredGame(code: string, game: StoredGame): Promise<StoredGame> {
  if (game.phase !== 'playing' || !game.endsAt || game.endsAt > Date.now()) return game
  const next = { ...game, phase: 'reveal' as const, endsAt: undefined, updatedAt: Date.now(), revision: game.revision + 1 }
  await saveGame(code, next)
  return next
}

async function withGameLock<T>(code: string, task: () => Promise<T>): Promise<T> {
  const token = randomUUID()
  const locked = await db().set(gameLockKey(code), token, { nx: true, ex: 3 })
  if (!locked) throw new Error('GAME_BUSY')
  try { return await task() }
  finally {
    const current = await db().get<string>(gameLockKey(code))
    if (current === token) await db().del(gameLockKey(code))
  }
}

async function addEvent(code: string, event: StoredEvent): Promise<void> {
  const key = eventsKey(code)
  await db().zadd(key, { score: event.at, member: event })
  const count = await db().zcard(key)
  if (count > EVENT_LIMIT) await db().zremrangebyrank(key, 0, count - EVENT_LIMIT - 1)
  await db().expire(key, ROOM_TTL_SECONDS)
}

async function sendEventPush(code: string, event: StoredEvent, buyerId?: string): Promise<void> {
  const registrations = await db().hgetall<Record<string, PushRegistration>>(pushesKey(code)) ?? {}
  const pushes = planRoomPushes(code, event, registrations, buyerId)
  const invalid = await sendPlannedPushes(pushes)
  if (invalid.length) await db().hdel(pushesKey(code), ...invalid)
}

function runAfterResponse(task: Promise<void>): void {
  const safe = task.catch((error) => console.error('Room notification failed', error instanceof Error ? error.message : 'unknown error'))
  try { waitUntil(safe) } catch { void safe }
}

export async function GET(request: Request): Promise<Response> {
  try {
    const code = normalizeCode(new URL(request.url).searchParams.get('code'))
    if (!code) return json(400, { error: 'Room codes have 6 letters or numbers' })
    const room = await buildRoom(code)
    return room ? json(200, room) : json(404, { error: 'That room has expired or does not exist' })
  } catch (error) {
    console.error(error)
    return json(503, { error: 'Rooms are temporarily unavailable' })
  }
}

export async function POST(request: Request): Promise<Response> {
  let payload: Record<string, unknown>
  try {
    const parsed = await request.json()
    if (typeof parsed !== 'object' || parsed === null) return json(400, { error: 'Request body must be an object' })
    payload = parsed as Record<string, unknown>
  } catch {
    return json(400, { error: 'Request body must be valid JSON' })
  }

  try {
    if (payload.action === 'create') {
      const memberToken = typeof payload.memberToken === 'string' ? payload.memberToken : ''
      const member = sanitizeMember(payload.member, memberToken)
      if (!member) return json(400, { error: 'Your room profile is incomplete' })
      const roomName = cleanText(payload.name, 36) ?? `${member.name}'s night`

      for (let attempt = 0; attempt < 8; attempt++) {
        let code = ''
        for (let index = 0; index < 6; index++) code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)]
        const meta: RoomMeta = {
          code,
          name: roomName,
          createdAt: Date.now(),
          theme: 'green',
          labels: {},
          hostMemberId: member.id,
          leaderboardMode: typeof payload.leaderboardMode === 'string' && LEADERBOARD_MODES.has(payload.leaderboardMode) ? payload.leaderboardMode as RoomMeta['leaderboardMode'] : 'balanced',
        }
        const created = await db().set(metaKey(code), meta, { nx: true, ex: ROOM_TTL_SECONDS })
        if (!created) continue
        await db().hset(membersKey(code), { [member.id]: member })
        await refreshRoom(code)
        return json(200, { room: await buildRoom(code), code })
      }
      return json(503, { error: 'Could not open a room. Try again.' })
    }

    if (payload.action === 'update') {
      const code = normalizeCode(payload.code)
      const memberToken = typeof payload.memberToken === 'string' ? payload.memberToken : ''
      const member = sanitizeMember(payload.member, memberToken)
      if (!code || !member || !(await readMeta(code))) return json(404, { error: 'That room has expired' })
      const members = await readMembers(code)
      const existing = members[member.id]
      if (existing && existing.tokenHash !== member.tokenHash) return json(403, { error: 'That room identity belongs to another device' })
      if (!existing && Object.keys(members).length >= MEMBER_LIMIT) return json(409, { error: 'This room is full' })
      await db().hset(membersKey(code), { [member.id]: member })
      await refreshRoom(code)
      return json(200, await buildRoom(code))
    }

    if (payload.action === 'configure') {
      const code = normalizeCode(payload.code)
      const memberId = typeof payload.memberId === 'string' ? payload.memberId : ''
      const memberToken = typeof payload.memberToken === 'string' ? payload.memberToken : ''
      if (!code || !validCredential(memberId, memberToken)) return json(400, { error: 'Invalid room credentials' })
      const [meta, member] = await Promise.all([readMeta(code), authenticate(code, memberId, memberToken)])
      if (!meta) return json(404, { error: 'That room has expired' })
      if (!member || meta.hostMemberId !== memberId) return json(403, { error: 'Only the room host can change this' })
      const labels = typeof payload.labels === 'object' && payload.labels !== null
        ? Object.fromEntries(Object.entries(payload.labels as Record<string, unknown>)
            .filter(([key, value]) => TARGETS.has(key) && cleanText(value, 24))
            .map(([key, value]) => [key, cleanText(value, 24)!]))
        : meta.labels
      const theme = payload.theme === 'red' || payload.theme === 'blue' ? payload.theme : 'green'
      const leaderboardMode = typeof payload.leaderboardMode === 'string' && LEADERBOARD_MODES.has(payload.leaderboardMode) ? payload.leaderboardMode as RoomMeta['leaderboardMode'] : meta.leaderboardMode ?? 'balanced'
      const next = { ...meta, name: cleanText(payload.name, 36) ?? meta.name, labels, theme, leaderboardMode }
      await db().set(metaKey(code), next, { ex: ROOM_TTL_SECONDS })
      return json(200, await buildRoom(code))
    }

    if (payload.action === 'push-register') {
      const code = normalizeCode(payload.code)
      const memberId = typeof payload.memberId === 'string' ? payload.memberId : ''
      const memberToken = typeof payload.memberToken === 'string' ? payload.memberToken : ''
      const token = typeof payload.token === 'string' && /^[a-f0-9]{32,256}$/i.test(payload.token) ? payload.token.toLowerCase() : ''
      const environment = payload.environment === 'sandbox' ? 'sandbox' : payload.environment === 'production' ? 'production' : null
      if (!code || !token || !environment || !validCredential(memberId, memberToken)) return json(400, { error: 'Invalid push registration' })
      if (!(await authenticate(code, memberId, memberToken))) return json(403, { error: 'Room credentials were rejected' })
      await db().hset(pushesKey(code), { [memberId]: { token, environment } })
      await refreshRoom(code)
      return json(200, { ok: true })
    }

    if (payload.action === 'push-unregister') {
      const code = normalizeCode(payload.code)
      const memberId = typeof payload.memberId === 'string' ? payload.memberId : ''
      const memberToken = typeof payload.memberToken === 'string' ? payload.memberToken : ''
      if (!code || !validCredential(memberId, memberToken)) return json(400, { error: 'Invalid push registration' })
      if (!(await authenticate(code, memberId, memberToken))) return json(403, { error: 'Room credentials were rejected' })
      await db().hdel(pushesKey(code), memberId)
      return json(200, { ok: true })
    }

    if (payload.action === 'event') {
      const code = normalizeCode(payload.code)
      const memberId = typeof payload.memberId === 'string' ? payload.memberId : ''
      const memberToken = typeof payload.memberToken === 'string' ? payload.memberToken : ''
      const type = typeof payload.type === 'string' && EVENT_TYPES.has(payload.type) ? payload.type : null
      if (!code || !type || !validCredential(memberId, memberToken)) return json(400, { error: 'Invalid room event' })
      const member = await authenticate(code, memberId, memberToken)
      if (!member) return json(403, { error: 'Room credentials were rejected' })
      const events = await readEvents(code)
      const clientEventId = validId(payload.clientEventId) ? payload.clientEventId : null
      if (clientEventId && events.some((event) => event.id === clientEventId && event.actorId === memberId)) return json(200, await buildRoom(code))
      const now = Date.now()
      if (type === 'reaction' && events.some((event) => event.type === type && event.actorId === memberId && now - event.at < 750)) return json(429, { error: 'Give that reaction a second' })
      if (type === 'cheers-countdown' && events.some((event) => event.type === type && now - event.at < 5_000)) return json(429, { error: 'A drink-up countdown just started' })
      const round = activeRound(events)
      if (type === 'round-invite' && round) return json(409, { error: 'A round is already open' })
      if ((type === 'round-order' || type === 'round-bought') && (!round || payload.refId !== round.id)) return json(409, { error: 'That round is no longer open' })
      if (type === 'round-bought' && round?.buyerId !== memberId) return json(403, { error: 'Only the round buyer can close it' })

      const event: StoredEvent = {
        id: clientEventId ?? randomUUID(),
        type,
        actorId: member.id,
        actorName: member.name,
        at: now,
        refId: cleanText(payload.refId, 80) ?? undefined,
        text: cleanText(payload.text, 80) ?? undefined,
      }
      if (type === 'reaction') {
        if (typeof payload.reaction !== 'string' || !REACTIONS.has(payload.reaction)) return json(400, { error: 'Unknown reaction' })
        event.reaction = payload.reaction
      }
      if (type === 'cheers-countdown') event.startsAt = now + 8_000
      if (type === 'round-invite') event.refId = event.id
      if (type === 'round-order' && !event.refId) return json(400, { error: 'Choose an active round' })
      if (type === 'drink') {
        const drink = typeof payload.drink === 'object' && payload.drink !== null ? payload.drink as Record<string, unknown> : null
        const name = cleanText(drink?.name, 40)
        const icon = typeof drink?.icon === 'string' && ICONS.has(drink.icon) ? drink.icon : 'pint'
        if (!name) return json(400, { error: 'Drink name is missing' })
        event.drink = { name, brand: cleanText(drink?.brand, 40) ?? undefined, icon, units: clamp(drink?.units, 0, 20) }
      }
      await addEvent(code, event)
      await db().hincrby(statsKey(code), `${member.id}:activity`, 1)
      if (type === 'reaction') await db().hincrby(statsKey(code), `${member.id}:reactions`, 1)
      if (type === 'round-bought') await db().hincrby(statsKey(code), `${member.id}:rounds`, 1)
      await refreshRoom(code)
      const room = await buildRoom(code)
      runAfterResponse(sendEventPush(code, event, round?.buyerId))
      return json(200, room)
    }

    if (payload.action === 'game-start') {
      const code = normalizeCode(payload.code)
      const memberId = typeof payload.memberId === 'string' ? payload.memberId : ''
      const memberToken = typeof payload.memberToken === 'string' ? payload.memberToken : ''
      const kind = typeof payload.kind === 'string' && GAME_KINDS.has(payload.kind as GameKind) ? payload.kind as GameKind : null
      if (!code || !kind || !validCredential(memberId, memberToken)) return json(400, { error: 'Invalid game setup' })
      const [meta, member, current, members] = await Promise.all([readMeta(code), authenticate(code, memberId, memberToken), readGame(code), readMembers(code)])
      if (!meta) return json(404, { error: 'That room has expired' })
      if (!member || meta.hostMemberId !== memberId) return json(403, { error: 'Only the room host can start a game' })
      if (current) return json(409, { error: 'A room game is already active' })
      const now = Date.now()
      const definition = gameByKind(kind)
      const game: StoredGame = {
        id: randomUUID(), kind, title: definition?.title ?? (kind === 'pub-golf' ? 'Pub Golf' : 'Pub Bingo'), phase: 'lobby', hostMemberId: memberId,
        createdAt: now, updatedAt: now, revision: 0, round: 0, spiciness: Math.round(clamp(payload.spiciness, 1, 5)), seed: randomInt(1, 0x7fffffff),
        players: Object.values(members).map((player) => ({ memberId: player.id, name: player.name, ready: player.id === memberId, score: 0 })),
        state: {}, privateByMember: {}, processedActionIds: [],
      }
      await saveGame(code, game); await refreshRoom(code)
      return json(200, gameView(game, memberId))
    }

    if (payload.action === 'game-state') {
      const code = normalizeCode(payload.code)
      const memberId = typeof payload.memberId === 'string' ? payload.memberId : ''
      const memberToken = typeof payload.memberToken === 'string' ? payload.memberToken : ''
      if (!code || !validCredential(memberId, memberToken)) return json(400, { error: 'Invalid room credentials' })
      const authenticated = await authenticate(code, memberId, memberToken)
      if (!authenticated) return json(403, { error: 'Room credentials were rejected' })
      const member = await touchMember(code, authenticated)
      const stored = await readGame(code)
      if (!stored) return json(404, { error: 'No room game is active' })
      const game = await reconcileGamePresence(code, await advanceExpiredGame(code, stored), member)
      await refreshRoom(code)
      return json(200, gameView(game, memberId))
    }

    if (payload.action === 'game-action') {
      const code = normalizeCode(payload.code)
      const memberId = typeof payload.memberId === 'string' ? payload.memberId : ''
      const memberToken = typeof payload.memberToken === 'string' ? payload.memberToken : ''
      const clientActionId = validId(payload.clientActionId) ? payload.clientActionId : null
      const gameAction = payload.gameAction && typeof payload.gameAction === 'object' ? payload.gameAction as GameAction : null
      if (!code || !clientActionId || !gameAction || !validCredential(memberId, memberToken)) return json(400, { error: 'Invalid game action' })
      const authenticated = await authenticate(code, memberId, memberToken)
      if (!authenticated) return json(403, { error: 'Room credentials were rejected' })
      const member = await touchMember(code, authenticated)
      try {
        return await withGameLock(code, async () => {
          const stored = await readGame(code)
          if (!stored || payload.gameId !== stored.id) return json(404, { error: 'That game has ended' })
          let game = await reconcileGamePresence(code, await advanceExpiredGame(code, stored), member)
          if (game.processedActionIds.includes(clientActionId)) return json(200, gameView(game, memberId))
          if (payload.expectedRevision !== game.revision) return json(409, { error: 'The game moved on; your screen has been refreshed', game: gameView(game, memberId) })
          const playerIndex = game.players.findIndex((player) => player.memberId === memberId)
          if (playerIndex < 0) return json(403, { error: 'You are spectating until the next game' })
          const now = Date.now()
          const control = game.hostMemberId === memberId
          const actionType = gameAction.type
          if (game.players[playerIndex].spectator && actionType !== 'claim-host') return json(403, { error: 'You are spectating until the next round' })

          if (actionType === 'ready' && game.phase === 'lobby') {
            game.players[playerIndex] = { ...game.players[playerIndex], ready: true }
          } else if (actionType === 'start' && game.phase === 'lobby') {
            if (!control) return json(403, { error: 'Only the game host can start the round' })
            const minimum = gameByKind(game.kind)?.minPlayers ?? 1
            if (game.players.filter((player) => player.ready).length < minimum) return json(409, { error: `This game needs ${minimum} ready players` })
            game = beginGameRound(game, now)
          } else if ((actionType === 'choose' || actionType === 'submit') && game.phase === 'playing') {
            const raw = typeof gameAction.value === 'string' || typeof gameAction.value === 'number' ? String(gameAction.value) : ''
            const value = cleanText(raw, actionType === 'submit' ? 240 : 80)
            if (!value) return json(400, { error: 'Your answer is empty' })
            const field = actionType === 'choose' ? 'choices' : 'submissions'
            const responses = game.state[field] && typeof game.state[field] === 'object' ? game.state[field] as Record<string, string> : {}
            responses[memberId] = value
            game.state = { ...game.state, [field]: responses }
            game.privateByMember[memberId] = { ...game.privateByMember[memberId], [actionType === 'choose' ? 'choice' : 'submission']: value }
            if (actionType === 'choose' && typeof game.state.answer === 'number' && Array.isArray(game.state.options) && game.state.options[game.state.answer] === value) {
              game.players[playerIndex] = { ...game.players[playerIndex], score: game.players[playerIndex].score + 1 }
            }
            if (Object.keys(responses).length >= game.players.filter((player) => player.ready).length) game.phase = 'reveal'
          } else if (actionType === 'score' && game.phase === 'playing') {
            game.players[playerIndex] = { ...game.players[playerIndex], score: game.players[playerIndex].score + Math.round(clamp(gameAction.value, 0, 100)) }
          } else if (actionType === 'golf-score' && game.kind === 'pub-golf' && game.phase === 'playing') {
            const hole = Math.round(clamp(gameAction.value.hole, 0, 8))
            const strokes = Math.round(clamp(gameAction.value.strokes, 1, 20))
            const par = Math.round(clamp(gameAction.value.par, 1, 9))
            const golfByMember = game.state.golfByMember && typeof game.state.golfByMember === 'object' ? game.state.golfByMember as Record<string, Record<string, unknown>> : {}
            const playerHoles = golfByMember[memberId] && typeof golfByMember[memberId] === 'object' ? golfByMember[memberId] : {}
            playerHoles[String(hole)] = { strokes, par, drink: cleanText(gameAction.value.drink, 50) ?? 'House choice' }
            golfByMember[memberId] = playerHoles
            const entries = Object.values(playerHoles) as Array<{ strokes?: number; par?: number }>
            game.players[playerIndex] = { ...game.players[playerIndex], score: entries.reduce((total, entry) => total + Math.max(0, (entry.par ?? 0) + 3 - (entry.strokes ?? 0)), 0) }
            game.state = { ...game.state, golfByMember }
          } else if (actionType === 'bingo-toggle' && game.kind === 'pub-bingo' && game.phase === 'playing') {
            const cell = Math.round(clamp(gameAction.value, 0, 24))
            const bingoByMember = game.state.bingoByMember && typeof game.state.bingoByMember === 'object' ? game.state.bingoByMember as Record<string, number[]> : {}
            const cells = new Set(Array.isArray(bingoByMember[memberId]) ? bingoByMember[memberId] : [12])
            if (cell !== 12) {
              if (cells.has(cell)) cells.delete(cell)
              else cells.add(cell)
            }
            cells.add(12)
            const progress = [...cells].sort((a, b) => a - b)
            bingoByMember[memberId] = progress
            game.players[playerIndex] = { ...game.players[playerIndex], score: progress.length }
            game.state = {
              ...game.state,
              bingoByMember,
              bingoWinner: game.state.bingoWinner || (completedBingo(progress) ? memberId : undefined),
              fullHouseWinner: game.state.fullHouseWinner || (progress.length === 25 ? memberId : undefined),
            }
          } else if ((actionType === 'advance' || actionType === 'skip') && (game.phase === 'playing' || game.phase === 'reveal')) {
            if (!control) return json(403, { error: 'Only the game host can move the round on' })
            game = beginGameRound({ ...game, round: game.round + 1 }, now)
          } else if (actionType === 'claim-host') {
            const members = await readMembers(code)
            const host = members[game.hostMemberId]
            if (host && host.updatedAt > now - 60_000) return json(409, { error: 'The host is still connected' })
            const oldestConnected = game.players.find((player) => !player.spectator && members[player.memberId]?.updatedAt > now - 60_000)
            if (!oldestConnected || oldestConnected.memberId !== memberId) return json(403, { error: 'The oldest connected player can claim control first' })
            game.hostMemberId = memberId
            game.phase = game.phase === 'paused' ? (game.pausedPhase && game.pausedPhase !== 'paused' ? game.pausedPhase : 'playing') : game.phase
            game.pausedPhase = undefined
          } else {
            return json(409, { error: 'That action is not available in this phase' })
          }

          game.updatedAt = now
          game.revision += 1
          game.processedActionIds = [...game.processedActionIds, clientActionId].slice(-100)
          await saveGame(code, game); await refreshRoom(code)
          return json(200, gameView(game, memberId))
        })
      } catch (error) {
        if (error instanceof Error && error.message === 'GAME_BUSY') return json(409, { error: 'Another player moved first; try again' })
        throw error
      }
    }

    if (payload.action === 'game-end') {
      const code = normalizeCode(payload.code)
      const memberId = typeof payload.memberId === 'string' ? payload.memberId : ''
      const memberToken = typeof payload.memberToken === 'string' ? payload.memberToken : ''
      if (!code || !validCredential(memberId, memberToken)) return json(400, { error: 'Invalid game request' })
      const [member, game] = await Promise.all([authenticate(code, memberId, memberToken), readGame(code)])
      if (!member) return json(403, { error: 'Room credentials were rejected' })
      if (!game) return json(200, { ok: true })
      if (game.hostMemberId !== memberId) return json(403, { error: 'Only the game host can end this game' })
      await Promise.all(game.players.map(async (player) => {
        await db().hincrby(statsKey(code), `${player.memberId}:game-score`, player.score)
        await db().hincrby(statsKey(code), `${player.memberId}:games`, 1)
      }))
      await db().del(gameKey(code)); await refreshRoom(code)
      return json(200, { ok: true })
    }

    if (payload.action === 'leave') {
      const code = normalizeCode(payload.code)
      const memberId = typeof payload.memberId === 'string' ? payload.memberId : ''
      const memberToken = typeof payload.memberToken === 'string' ? payload.memberToken : ''
      if (!code || !validCredential(memberId, memberToken)) return json(400, { error: 'Invalid room credentials' })
      if (!(await authenticate(code, memberId, memberToken))) return json(403, { error: 'Room credentials were rejected' })
      await Promise.all([db().hdel(membersKey(code), memberId), db().hdel(pushesKey(code), memberId)])
      return json(200, { ok: true })
    }

    if (payload.action === 'metric') {
      const metric = cleanText(payload.metric, 40)
      if (!metric || !['invite_created', 'invite_opened', 'room_joined', 'first_drink', 'recap_shared'].includes(metric)) return json(400, { error: 'Unknown metric' })
      const day = new Date().toISOString().slice(0, 10)
      await db().hincrby(`beerify:metrics:${day}`, metric, 1)
      await db().expire(`beerify:metrics:${day}`, 90 * 24 * 60 * 60)
      return json(200, { ok: true })
    }

    return json(400, { error: 'Unknown room action' })
  } catch (error) {
    console.error(error)
    return json(503, { error: 'Rooms are temporarily unavailable' })
  }
}
