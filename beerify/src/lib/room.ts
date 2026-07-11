import { useCallback, useEffect, useRef, useState } from 'react'
import type {
  RoomEventType,
  RoomMembership,
  RoomReaction,
  RoomState,
  SquadMember,
  TargetId,
  LeaderboardMode,
} from '../types'
import { apiUrl, publicAppOrigin } from './platform'
import { newId } from './storage'

const AVATARS = ['🦊', '🐻', '🐼', '🦁', '🐨', '🐵', '🦄', '🐙', '🦖', '🐳', '🐹', '🐸']
const OUTBOX_KEY = 'beerify:room-outbox:v1'
const OUTBOX_TTL = 24 * 60 * 60 * 1000
const OUTBOX_LIMIT = 20
const roomCache = new Map<string, RoomState>()
let outboxQueue: Promise<void> = Promise.resolve()

export function avatarFor(id: string): string {
  let hash = 0
  for (const character of id) hash = (hash * 31 + character.charCodeAt(0)) | 0
  return AVATARS[(hash >>> 0) % AVATARS.length]
}

function credentials(isHost: boolean, memberId: string): RoomMembership {
  return { code: '', memberId, memberToken: newId(), isHost }
}

class RoomRequestError extends Error {
  readonly status: number

  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

async function request(path: string, init?: RequestInit): Promise<unknown> {
  const response = await fetch(apiUrl(path), {
    ...init,
    headers: { 'Content-Type': 'application/json', ...init?.headers },
  })
  const body = await response.json().catch(() => null) as { error?: string } | null
  if (!response.ok) throw new RoomRequestError(body?.error ?? `Request failed (${response.status})`, response.status)
  return body
}

export async function createRoom(
  name: string,
  member: Omit<SquadMember, 'id' | 'updatedAt'>,
  memberId: string,
  leaderboardMode: LeaderboardMode,
): Promise<{ membership: RoomMembership; room: RoomState }> {
  const membership = credentials(true, memberId)
  const body = await request('/api/room', {
    method: 'POST',
    body: JSON.stringify({
      action: 'create',
      name: `${name.split(' ')[0] || name}'s night`,
      memberToken: membership.memberToken,
      member: { ...member, id: membership.memberId },
      leaderboardMode,
    }),
  }) as { code: string; room: RoomState }
  membership.code = body.code
  return { membership, room: body.room }
}

export async function joinRoom(
  code: string,
  member: Omit<SquadMember, 'id' | 'updatedAt'>,
  memberId: string,
): Promise<{ membership: RoomMembership; room: RoomState }> {
  const membership = { ...credentials(false, memberId), code: code.trim().toUpperCase() }
  const room = await pushMember(membership, { ...member, id: membership.memberId })
  trackMetric('room_joined')
  return { membership, room }
}

export async function fetchRoom(code: string): Promise<RoomState> {
  return await request(`/api/room?code=${encodeURIComponent(code)}`) as RoomState
}

export async function pushMember(
  membership: RoomMembership,
  member: Omit<SquadMember, 'updatedAt'>,
): Promise<RoomState> {
  return await request('/api/room', {
    method: 'POST',
    body: JSON.stringify({ action: 'update', code: membership.code, memberToken: membership.memberToken, member }),
  }) as RoomState
}

export async function configureRoom(
  membership: RoomMembership,
  values: { name: string; theme: RoomState['theme']; labels: Partial<Record<TargetId, string>>; leaderboardMode: LeaderboardMode },
): Promise<RoomState> {
  return await request('/api/room', {
    method: 'POST',
    body: JSON.stringify({
      action: 'configure',
      code: membership.code,
      memberId: membership.memberId,
      memberToken: membership.memberToken,
      ...values,
    }),
  }) as RoomState
}

export async function sendRoomEvent(
  membership: RoomMembership,
  type: RoomEventType,
  detail: { refId?: string; text?: string; reaction?: RoomReaction; drink?: unknown } = {},
  clientEventId = newId(),
): Promise<RoomState> {
  const send = () => request('/api/room', {
      method: 'POST',
      body: JSON.stringify({
        action: 'event',
        code: membership.code,
        memberId: membership.memberId,
        memberToken: membership.memberToken,
        clientEventId,
        type,
        ...detail,
      }),
    }) as Promise<RoomState>
  try {
    return await send()
  } catch (error) {
    if (error instanceof RoomRequestError && error.status < 500) throw error
    await new Promise((resolve) => setTimeout(resolve, 400))
    return await send()
  }
}

export async function registerRoomPush(membership: RoomMembership, token: string, environment: 'sandbox' | 'production'): Promise<void> {
  await request('/api/room', {
    method: 'POST',
    body: JSON.stringify({ action: 'push-register', ...membership, token, environment }),
  })
}

export async function unregisterRoomPush(membership: RoomMembership): Promise<void> {
  await request('/api/room', {
    method: 'POST',
    body: JSON.stringify({ action: 'push-unregister', ...membership }),
  })
}

interface PendingDrinkEvent {
  id: string
  code: string
  memberId: string
  createdAt: number
  drink: unknown
}

function readOutbox(): PendingDrinkEvent[] {
  try {
    const parsed = JSON.parse(localStorage.getItem(OUTBOX_KEY) ?? '[]') as unknown
    if (!Array.isArray(parsed)) return []
    return parsed.filter((item): item is PendingDrinkEvent => Boolean(item && typeof item === 'object'
      && typeof item.id === 'string' && typeof item.code === 'string' && typeof item.memberId === 'string'
      && typeof item.createdAt === 'number' && item.createdAt > Date.now() - OUTBOX_TTL))
  } catch { return [] }
}

function writeOutbox(items: PendingDrinkEvent[]): void {
  try { localStorage.setItem(OUTBOX_KEY, JSON.stringify(items.slice(-OUTBOX_LIMIT))) } catch { /* The live room snapshot still carries totals. */ }
}

async function flushRoomOutboxNow(membership: RoomMembership): Promise<number> {
  const pending = readOutbox()
  const keep: PendingDrinkEvent[] = []
  for (const item of pending) {
    if (item.code !== membership.code || item.memberId !== membership.memberId) { keep.push(item); continue }
    try {
      await sendRoomEvent(membership, 'drink', { drink: item.drink }, item.id)
    } catch (error) {
      if (!(error instanceof RoomRequestError) || error.status >= 500 || error.status === 429) keep.push(item)
    }
  }
  writeOutbox(keep)
  return keep.filter((item) => item.code === membership.code && item.memberId === membership.memberId).length
}

export async function flushRoomOutbox(membership: RoomMembership): Promise<number> {
  let remaining = 0
  const work = outboxQueue.then(async () => { remaining = await flushRoomOutboxNow(membership) })
  outboxQueue = work.catch(() => {})
  await work
  return remaining
}

export async function queueRoomDrink(membership: RoomMembership, drink: unknown): Promise<boolean> {
  const item: PendingDrinkEvent = { id: newId(), code: membership.code, memberId: membership.memberId, createdAt: Date.now(), drink }
  writeOutbox([...readOutbox(), item])
  await flushRoomOutbox(membership)
  return !readOutbox().some((entry) => entry.id === item.id)
}

function clearRoomOutbox(membership: RoomMembership): void {
  writeOutbox(readOutbox().filter((item) => item.code !== membership.code || item.memberId !== membership.memberId))
}

export async function leaveRoom(membership: RoomMembership): Promise<void> {
  await request('/api/room', {
    method: 'POST',
    body: JSON.stringify({
      action: 'leave',
      code: membership.code,
      memberId: membership.memberId,
      memberToken: membership.memberToken,
    }),
  })
  clearRoomOutbox(membership)
}

export function inviteUrl(code: string): string {
  return `${publicAppOrigin()}/api/invite?code=${encodeURIComponent(code)}`
}

export function trackMetric(metric: 'invite_created' | 'invite_opened' | 'room_joined' | 'first_drink' | 'recap_shared'): void {
  fetch(apiUrl('/api/room'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action: 'metric', metric }),
    keepalive: true,
  }).catch(() => {})
}

interface UseRoomResult {
  room: RoomState | null
  error: string | null
  refresh: () => Promise<void>
}

export function useRoom(
  membership: RoomMembership | null,
  self: Omit<SquadMember, 'updatedAt'> | null,
  pollMs: number,
): UseRoomResult {
  const [room, setRoom] = useState<RoomState | null>(() => membership ? roomCache.get(membership.code) ?? null : null)
  const [error, setError] = useState<string | null>(null)
  const selfRef = useRef(self)
  const inFlight = useRef<Promise<void> | null>(null)
  const generation = useRef(0)
  selfRef.current = self

  const sync = useCallback(async () => {
    if (!membership) return
    if (inFlight.current) return await inFlight.current
    const currentGeneration = generation.current
    const task = (async () => {
      try {
        const snapshot = selfRef.current
        const state = snapshot?.inSession
          ? await pushMember(membership, snapshot)
          : await fetchRoom(membership.code)
        if (currentGeneration !== generation.current) return
        roomCache.set(membership.code, state)
        setRoom(state)
        setError(null)
        void flushRoomOutbox(membership)
      } catch (cause) {
        if (currentGeneration !== generation.current) return
        setError(cause instanceof Error ? cause.message : 'Could not reach the room')
      }
    })()
    inFlight.current = task
    try { await task } finally { if (inFlight.current === task) inFlight.current = null }
  }, [membership])

  useEffect(() => {
    generation.current += 1
    if (!membership) {
      setRoom(null)
      setError(null)
      return
    }
    setRoom(roomCache.get(membership.code) ?? null)
    void sync()
    const wake = () => { if (!document.hidden) void sync() }
    const id = setInterval(wake, pollMs)
    document.addEventListener('visibilitychange', wake)
    window.addEventListener('online', wake)
    window.addEventListener('beerify:room-push', wake)
    window.addEventListener('beerify:resume', wake)
    return () => {
      clearInterval(id)
      document.removeEventListener('visibilitychange', wake)
      window.removeEventListener('online', wake)
      window.removeEventListener('beerify:room-push', wake)
      window.removeEventListener('beerify:resume', wake)
      generation.current += 1
    }
  }, [membership, pollMs, sync])

  return { room, error, refresh: sync }
}
