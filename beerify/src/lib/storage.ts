import type { AppData } from '../types'

const KEY = 'beerify:v1'

const EMPTY: AppData = { profile: null, session: null, history: [] }

export function loadData(): AppData {
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return EMPTY
    const parsed = JSON.parse(raw) as Partial<AppData>
    return {
      profile: parsed.profile ?? null,
      session: parsed.session ?? null,
      history: parsed.history ?? [],
    }
  } catch {
    return EMPTY
  }
}

export function saveData(data: AppData): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(data))
  } catch {
    // Storage full or unavailable (private mode) — the app still works in-memory.
  }
}

export function newId(): string {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36)
}
