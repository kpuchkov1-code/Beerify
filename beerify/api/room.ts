import { createHash, randomInt, randomUUID } from 'node:crypto'
import { Redis } from '@upstash/redis'

const ROOM_TTL_SECONDS = 24 * 60 * 60
const MEMBER_LIMIT = 20
const EVENT_LIMIT = 50
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
const TARGETS = new Set(['glow', 'buzz', 'tipsy', 'merry', 'bignight'])
const STATUSES = new Set(['sober', 'warming', 'in-zone', 'over', 'way-over'])
const REACTIONS = new Set(['cheers', 'on-my-way', 'get-another', 'scenes', 'water-run', 'food'])
const EVENT_TYPES = new Set(['drink', 'reaction', 'cheers-countdown', 'round-invite', 'round-order', 'round-bought'])
const ICONS = new Set(['pint', 'bottle', 'can', 'ipa', 'stout', 'cider', 'ale', 'wine-red', 'wine-white', 'sparkling', 'spirit', 'cocktail', 'shot', 'alcopop', 'zero'])

interface RoomMeta {
  code: string
  name: string
  createdAt: number
  theme: 'green' | 'red' | 'blue'
  labels: Record<string, string>
  hostMemberId: string
}

interface StoredMember {
  id: string
  name: string
  bac: number
  units: number
  drinks: number
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

function validCredential(id: unknown, token: unknown): id is string {
  return typeof id === 'string' && /^[0-9a-f-]{36}$/.test(id)
    && typeof token === 'string' && /^[0-9a-f-]{36}$/.test(token)
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
  const [members, events] = await Promise.all([readMembers(code), readEvents(code)])
  const bought = events.filter((event) => event.type === 'round-bought').map((event) => event.actorId)
  return {
    ...meta,
    members: Object.values(members).map(publicMember).sort((a, b) => a.name.localeCompare(b.name)),
    events: events.map(publicEvent),
    activeRound: activeRound(events),
    roundRota: bought.slice(-MEMBER_LIMIT),
  }
}

async function refreshRoom(code: string): Promise<void> {
  await Promise.all([
    db().expire(metaKey(code), ROOM_TTL_SECONDS),
    db().expire(membersKey(code), ROOM_TTL_SECONDS),
    db().expire(eventsKey(code), ROOM_TTL_SECONDS),
  ])
}

async function authenticate(code: string, memberId: string, memberToken: string): Promise<StoredMember | null> {
  const member = await db().hget<StoredMember>(membersKey(code), memberId)
  return member?.tokenHash === tokenHash(memberToken) ? member : null
}

async function addEvent(code: string, event: StoredEvent): Promise<void> {
  const key = eventsKey(code)
  await db().zadd(key, { score: event.at, member: event })
  const count = await db().zcard(key)
  if (count > EVENT_LIMIT) await db().zremrangebyrank(key, 0, count - EVENT_LIMIT - 1)
  await db().expire(key, ROOM_TTL_SECONDS)
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
      const next = { ...meta, name: cleanText(payload.name, 36) ?? meta.name, labels, theme }
      await db().set(metaKey(code), next, { ex: ROOM_TTL_SECONDS })
      return json(200, await buildRoom(code))
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
      const latest = [...events].reverse().find((event) => event.actorId === memberId)
      if (latest && Date.now() - latest.at < 5_000) return json(429, { error: 'Give the room a second' })

      const event: StoredEvent = {
        id: randomUUID(),
        type,
        actorId: member.id,
        actorName: member.name,
        at: Date.now(),
        refId: cleanText(payload.refId, 80) ?? undefined,
        text: cleanText(payload.text, 80) ?? undefined,
      }
      if (type === 'reaction') {
        if (typeof payload.reaction !== 'string' || !REACTIONS.has(payload.reaction)) return json(400, { error: 'Unknown reaction' })
        event.reaction = payload.reaction
      }
      if (type === 'cheers-countdown') event.startsAt = Date.now() + 8_000
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
      await refreshRoom(code)
      return json(200, await buildRoom(code))
    }

    if (payload.action === 'leave') {
      const code = normalizeCode(payload.code)
      const memberId = typeof payload.memberId === 'string' ? payload.memberId : ''
      const memberToken = typeof payload.memberToken === 'string' ? payload.memberToken : ''
      if (!code || !validCredential(memberId, memberToken)) return json(400, { error: 'Invalid room credentials' })
      if (!(await authenticate(code, memberId, memberToken))) return json(403, { error: 'Room credentials were rejected' })
      await db().hdel(membersKey(code), memberId)
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
