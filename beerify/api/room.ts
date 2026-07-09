/**
 * Friends-room API backed by Vercel Edge Config.
 *
 * Reads go through the Edge Config data plane (edge-config.vercel.com), which
 * is built for high-volume reads and has no rate limits. Writes go through the
 * Vercel management API, which is rate limited, so write failures degrade
 * gracefully instead of erroring: the member's next heartbeat retries.
 *
 * Keys:
 *   room_<CODE>              -> { code, createdAt }
 *   room_<CODE>_m_<memberId> -> member snapshot
 *
 * Each member writes only their own key, so concurrent updates from a whole
 * squad never clobber each other.
 */

const MEMBER_TTL_MS = 24 * 60 * 60 * 1000
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'

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
}

interface RoomMeta {
  code: string
  createdAt: number
}

function env(name: string): string {
  const v = process.env[name]
  if (!v) throw new Error(`missing env ${name}`)
  return v
}

/** All items, read from the unlimited data plane. */
async function readAllItems(): Promise<Record<string, unknown>> {
  const res = await fetch(`https://edge-config.vercel.com/${env('EDGE_CONFIG_ID')}/items`, {
    headers: { Authorization: `Bearer ${env('EC_READ_TOKEN')}` },
  })
  if (!res.ok) throw new Error(`edge config read failed: ${res.status}`)
  return (await res.json()) as Record<string, unknown>
}

/**
 * Writes via the management API. Returns false when rate limited so callers
 * can degrade gracefully; the client retries on its next heartbeat.
 */
async function writeItems(
  items: { operation: 'upsert' | 'delete'; key: string; value?: unknown }[],
): Promise<boolean> {
  const res = await fetch(
    `https://api.vercel.com/v1/edge-config/${env('EDGE_CONFIG_ID')}/items?teamId=${env('EC_TEAM_ID')}`,
    {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${env('EC_API_TOKEN')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ items }),
    },
  )
  if (res.status === 429) return false
  if (!res.ok) throw new Error(`edge config write failed: ${res.status} ${await res.text()}`)
  return true
}

/**
 * Direct single-item read via the management API. Only used as a fallback for
 * the few seconds it takes a fresh room to replicate to the data plane.
 */
async function readItemDirect(key: string): Promise<unknown | null | undefined> {
  const res = await fetch(
    `https://api.vercel.com/v1/edge-config/${env('EDGE_CONFIG_ID')}/item/${key}?teamId=${env('EC_TEAM_ID')}`,
    { headers: { Authorization: `Bearer ${env('EC_API_TOKEN')}` } },
  )
  if (res.status === 204 || res.status === 404) return null
  if (res.status === 429) return undefined // unknown
  if (!res.ok) throw new Error(`edge config item read failed: ${res.status}`)
  const text = await res.text()
  if (!text) return null
  return (JSON.parse(text) as { value: unknown }).value
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  })
}

function normalizeCode(raw: unknown): string | null {
  if (typeof raw !== 'string') return null
  const code = raw.trim().toUpperCase()
  return /^[A-Z2-9]{4}$/.test(code) ? code : null
}

function clampNumber(v: unknown, min: number, max: number): number {
  const n = typeof v === 'number' && Number.isFinite(v) ? v : 0
  return Math.min(max, Math.max(min, n))
}

function sanitizeMember(raw: unknown): StoredMember | null {
  if (typeof raw !== 'object' || raw === null) return null
  const m = raw as Record<string, unknown>
  if (typeof m.id !== 'string' || !/^[a-z0-9]{6,40}$/.test(m.id)) return null
  if (typeof m.name !== 'string' || m.name.trim().length === 0) return null
  return {
    id: m.id,
    name: m.name.trim().slice(0, 24),
    bac: clampNumber(m.bac, 0, 0.5),
    units: clampNumber(m.units, 0, 100),
    drinks: Math.round(clampNumber(m.drinks, 0, 100)),
    targetId: typeof m.targetId === 'string' ? m.targetId.slice(0, 16) : 'tipsy',
    status: typeof m.status === 'string' ? m.status.slice(0, 16) : 'sober',
    inSession: Boolean(m.inSession),
    updatedAt: Date.now(),
  }
}

function buildRoom(
  items: Record<string, unknown>,
  code: string,
  extraMember?: StoredMember,
): { meta: RoomMeta | null; body: unknown } {
  const meta = (items[`room_${code}`] as RoomMeta | undefined) ?? null
  if (!meta) return { meta: null, body: null }

  const prefix = `room_${code}_m_`
  const cutoff = Date.now() - MEMBER_TTL_MS
  const byId = new Map<string, StoredMember>()
  for (const [key, value] of Object.entries(items)) {
    if (!key.startsWith(prefix)) continue
    const m = value as StoredMember
    if (m && m.updatedAt > cutoff) byId.set(m.id, m)
  }
  // The data plane replicates within seconds; merging the member we just
  // wrote hides that lag from the writer.
  if (extraMember) byId.set(extraMember.id, extraMember)

  const members = [...byId.values()].sort((a, b) => a.name.localeCompare(b.name))
  return { meta, body: { code: meta.code, createdAt: meta.createdAt, members } }
}

export async function GET(request: Request): Promise<Response> {
  try {
    const code = normalizeCode(new URL(request.url).searchParams.get('code'))
    if (!code) return json(400, { error: 'Invalid room code' })
    const items = await readAllItems()
    if (!items[`room_${code}`]) {
      const direct = await readItemDirect(`room_${code}`)
      if (!direct) return json(404, { error: 'Room not found' })
      items[`room_${code}`] = direct
    }
    return json(200, buildRoom(items, code).body)
  } catch (err) {
    console.error(err)
    return json(500, { error: 'Something went wrong' })
  }
}

export async function POST(request: Request): Promise<Response> {
  try {
    const payload = (await request.json()) as Record<string, unknown>

    if (payload.action === 'create') {
      const items = await readAllItems()
      for (let attempt = 0; attempt < 6; attempt++) {
        let code = ''
        for (let i = 0; i < 4; i++) {
          code += CODE_ALPHABET[Math.floor(Math.random() * CODE_ALPHABET.length)]
        }
        if (items[`room_${code}`]) continue
        const ok = await writeItems([
          { operation: 'upsert', key: `room_${code}`, value: { code, createdAt: Date.now() } },
        ])
        if (!ok) return json(503, { error: 'Busy right now, try again in a moment' })
        return json(200, { code })
      }
      return json(503, { error: 'Could not allocate a room code, try again' })
    }

    if (payload.action === 'update') {
      const code = normalizeCode(payload.code)
      const member = sanitizeMember(payload.member)
      if (!code || !member) return json(400, { error: 'Invalid payload' })

      const items = await readAllItems()
      if (!items[`room_${code}`]) {
        // A freshly created room can take a few seconds to replicate.
        const direct = await readItemDirect(`room_${code}`)
        if (direct === null) return json(404, { error: 'Room not found' })
        items[`room_${code}`] = direct ?? { code, createdAt: Date.now() }
      }

      // Rate-limited writes are dropped silently; the next heartbeat retries.
      await writeItems([{ operation: 'upsert', key: `room_${code}_m_${member.id}`, value: member }])
      return json(200, buildRoom(items, code, member).body)
    }

    if (payload.action === 'leave') {
      const code = normalizeCode(payload.code)
      const memberId = typeof payload.memberId === 'string' ? payload.memberId : ''
      if (!code || !/^[a-z0-9]{6,40}$/.test(memberId)) return json(400, { error: 'Invalid payload' })
      await writeItems([{ operation: 'delete', key: `room_${code}_m_${memberId}` }])
      return json(200, { ok: true })
    }

    return json(400, { error: 'Unknown action' })
  } catch (err) {
    console.error(err)
    return json(500, { error: 'Something went wrong' })
  }
}
