import { createClient, type Session, type SupabaseClient } from '@supabase/supabase-js'
import type { AppData, NightSession } from '../types'
import { apiUrl, isNative } from './platform'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined
let client: SupabaseClient | null = null

export function accountEnabled(): boolean {
  return Boolean(url && key)
}

export function supabase(): SupabaseClient | null {
  if (!accountEnabled()) return null
  client ??= createClient(url!, key!, { auth: { persistSession: true, autoRefreshToken: true } })
  return client
}

export async function currentSession(): Promise<Session | null> {
  const db = supabase()
  if (!db) return null
  return (await db.auth.getSession()).data.session ?? null
}

export async function sendMagicLink(email: string): Promise<void> {
  const db = supabase()
  if (!db) throw new Error('Account sync is not configured on this deployment')
  const { error } = await db.auth.signInWithOtp({ email, options: { emailRedirectTo: isNative ? 'beerify://auth/callback' : location.origin } })
  if (error) throw error
}

export async function signOut(): Promise<void> {
  const { error } = await supabase()?.auth.signOut() ?? { error: null }
  if (error) throw error
}

function mergeSessions(local: NightSession[], cloud: NightSession[]): NightSession[] {
  const sessions = new Map<string, NightSession>()
  for (const session of [...cloud, ...local]) {
    const current = sessions.get(session.id)
    if (!current || session.updatedAt >= current.updatedAt) sessions.set(session.id, session)
  }
  return [...sessions.values()].sort((a, b) => a.startedAt - b.startedAt)
}

export function mergeCloudData(local: AppData, cloud: Partial<AppData> | null): AppData {
  if (!cloud) return local
  const profile = !cloud.profile || (local.profile?.updatedAt ?? 0) >= cloud.profile.updatedAt
    ? local.profile
    : cloud.profile
  const preferences = (local.preferences.updatedAt >= (cloud.preferences?.updatedAt ?? 0))
    ? local.preferences
    : cloud.preferences!
  const session = !cloud.session || (local.session?.updatedAt ?? 0) >= cloud.session.updatedAt
    ? local.session
    : cloud.session
  return {
    ...local,
    profile,
    preferences,
    session,
    history: mergeSessions(local.history, cloud.history ?? []),
    room: local.room,
  }
}

export async function syncAccountData(local: AppData): Promise<AppData> {
  const db = supabase()
  const session = await currentSession()
  if (!db || !session) return local
  const { data, error } = await db.from('user_data').select('payload').eq('user_id', session.user.id).maybeSingle()
  if (error) throw error
  const merged = mergeCloudData(local, data?.payload as Partial<AppData> | null)
  const payload = { profile: merged.profile, preferences: merged.preferences, session: merged.session, history: merged.history }
  const { error: saveError } = await db.from('user_data').upsert({ user_id: session.user.id, payload, updated_at: new Date().toISOString() })
  if (saveError) throw saveError
  return merged
}

export async function deleteCloudAccount(): Promise<void> {
  const session = await currentSession()
  if (!session) return
  const response = await fetch(apiUrl('/api/account'), {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${session.access_token}` },
  })
  if (!response.ok) {
    const body = await response.json().catch(() => null) as { error?: string } | null
    throw new Error(body?.error ?? 'Could not delete the account')
  }
  await signOut()
}
