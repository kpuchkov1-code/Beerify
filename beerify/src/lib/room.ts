import { useCallback, useEffect, useRef, useState } from 'react'
import type { RoomMembership, RoomState, SquadMember } from '../types'

const AVATARS = ['🦊', '🐻', '🐼', '🦁', '🐨', '🐵', '🦄', '🐙', '🦖', '🐳', '🐹', '🐸']

export function avatarFor(id: string): string {
  let hash = 0
  for (const ch of id) hash = (hash * 31 + ch.charCodeAt(0)) | 0
  return AVATARS[Math.abs(hash) % AVATARS.length]
}

export function newMemberId(): string {
  return Math.random().toString(36).slice(2, 12) + Date.now().toString(36)
}

async function request(path: string, init?: RequestInit): Promise<unknown> {
  const res = await fetch(path, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...init?.headers },
  })
  const body = (await res.json().catch(() => null)) as { error?: string } | null
  if (!res.ok) throw new Error(body?.error ?? `Request failed (${res.status})`)
  return body
}

export async function createRoom(): Promise<string> {
  const body = (await request('/api/room', {
    method: 'POST',
    body: JSON.stringify({ action: 'create' }),
  })) as { code: string }
  return body.code
}

export async function fetchRoom(code: string): Promise<RoomState> {
  return (await request(`/api/room?code=${encodeURIComponent(code)}`)) as RoomState
}

export async function pushMember(
  code: string,
  member: Omit<SquadMember, 'updatedAt'>,
): Promise<RoomState> {
  return (await request('/api/room', {
    method: 'POST',
    body: JSON.stringify({ action: 'update', code, member }),
  })) as RoomState
}

export async function leaveRoom(code: string, memberId: string): Promise<void> {
  await request('/api/room', {
    method: 'POST',
    body: JSON.stringify({ action: 'leave', code, memberId }),
  })
}

interface UseRoomResult {
  room: RoomState | null
  error: string | null
  refresh: () => void
}

/** Polls the room and (optionally) pushes the user's own live snapshot. */
export function useRoom(
  membership: RoomMembership | null,
  self: Omit<SquadMember, 'updatedAt'> | null,
  pollMs: number,
): UseRoomResult {
  const [room, setRoom] = useState<RoomState | null>(null)
  const [error, setError] = useState<string | null>(null)
  const selfRef = useRef(self)
  selfRef.current = self

  const sync = useCallback(async () => {
    if (!membership) return
    try {
      const state = selfRef.current
        ? await pushMember(membership.code, selfRef.current)
        : await fetchRoom(membership.code)
      setRoom(state)
      setError(null)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not reach the room')
    }
  }, [membership])

  useEffect(() => {
    if (!membership) {
      setRoom(null)
      return
    }
    sync()
    const id = setInterval(sync, pollMs)
    return () => clearInterval(id)
  }, [membership, sync, pollMs])

  return { room, error, refresh: sync }
}
