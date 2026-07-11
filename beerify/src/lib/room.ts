import { useCallback, useEffect, useRef, useState } from 'react'
import type {
  RoomEventType,
  RoomMembership,
  RoomReaction,
  RoomState,
  SquadMember,
  TargetId,
} from '../types'
import { apiUrl, publicAppOrigin } from './platform'
import { newId } from './storage'

const AVATARS = ['🦊', '🐻', '🐼', '🦁', '🐨', '🐵', '🦄', '🐙', '🦖', '🐳', '🐹', '🐸']

export function avatarFor(id: string): string {
  let hash = 0
  for (const character of id) hash = (hash * 31 + character.charCodeAt(0)) | 0
  return AVATARS[(hash >>> 0) % AVATARS.length]
}

function credentials(isHost: boolean): RoomMembership {
  return { code: '', memberId: newId(), memberToken: newId(), isHost }
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
): Promise<{ membership: RoomMembership; room: RoomState }> {
  const membership = credentials(true)
  const body = await request('/api/room', {
    method: 'POST',
    body: JSON.stringify({
      action: 'create',
      name: `${name.split(' ')[0] || name}'s night`,
      memberToken: membership.memberToken,
      member: { ...member, id: membership.memberId },
    }),
  }) as { code: string; room: RoomState }
  membership.code = body.code
  return { membership, room: body.room }
}

export async function joinRoom(
  code: string,
  member: Omit<SquadMember, 'id' | 'updatedAt'>,
): Promise<{ membership: RoomMembership; room: RoomState }> {
  const membership = { ...credentials(false), code: code.trim().toUpperCase() }
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
  values: { name: string; theme: RoomState['theme']; labels: Partial<Record<TargetId, string>> },
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
): Promise<RoomState> {
  return await request('/api/room', {
    method: 'POST',
    body: JSON.stringify({
      action: 'event',
      code: membership.code,
      memberId: membership.memberId,
      memberToken: membership.memberToken,
      type,
      ...detail,
    }),
  }) as RoomState
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
  refresh: () => void
}

export function useRoom(
  membership: RoomMembership | null,
  self: Omit<SquadMember, 'updatedAt'> | null,
  pollMs: number,
): UseRoomResult {
  const [room, setRoom] = useState<RoomState | null>(null)
  const [error, setError] = useState<string | null>(null)
  const selfRef = useRef(self)
  const inFlight = useRef(false)
  const generation = useRef(0)
  selfRef.current = self

  const sync = useCallback(async () => {
    if (!membership || inFlight.current) return
    const currentGeneration = generation.current
    inFlight.current = true
    try {
      const snapshot = selfRef.current
      const state = snapshot?.inSession
        ? await pushMember(membership, snapshot)
        : await fetchRoom(membership.code)
      if (currentGeneration !== generation.current) return
      setRoom(state)
      setError(null)
    } catch (cause) {
      if (currentGeneration !== generation.current) return
      setError(cause instanceof Error ? cause.message : 'Could not reach the room')
    } finally {
      inFlight.current = false
    }
  }, [membership])

  useEffect(() => {
    generation.current += 1
    if (!membership) {
      setRoom(null)
      setError(null)
      return
    }
    const initial = selfRef.current
    if (initial) {
      pushMember(membership, initial).then(setRoom).catch((cause) => {
        setError(cause instanceof Error ? cause.message : 'Could not reach the room')
      })
    } else {
      sync()
    }
    const id = setInterval(sync, pollMs)
    return () => {
      clearInterval(id)
      generation.current += 1
    }
  }, [membership, pollMs, sync])

  return { room, error, refresh: () => { void sync() } }
}
