import type {
  AppData,
  DrinkCategory,
  DrinkIconId,
  DrinkPreset,
  DrinkServe,
  DrinkStyle,
  DrinkerLevel,
  LoggedDrink,
  NightSession,
  Preferences,
  Profile,
  RoomEvent,
  RoomMembership,
  Sex,
  MealState,
  RoomLeaderboard,
  TargetSnapshot,
  TargetId,
} from '../types'
import {
  BUILT_IN_PRESETS,
  DEFAULT_FAVORITES,
  LEGACY_PRESET,
  gramsOfAlcohol,
  presetById,
  unitsOfAlcohol,
} from './drinks'

const KEY = 'beerify:v2'
const LEGACY_KEY = 'beerify:v1'
const TARGETS = new Set<TargetId>(['glow', 'buzz', 'wavy', 'tipsy', 'smashed', 'merry', 'bignight'])
const SEXES = new Set<Sex>(['female', 'male', 'other'])
const DRINKER_LEVELS = new Set<DrinkerLevel>(['one-pint', 'weekend', 'regular', 'full-time'])
const CATEGORIES = new Set<DrinkCategory>(['beer', 'cider', 'wine', 'spirit', 'cocktail', 'shot', 'soft'])
const ICONS = new Set<DrinkIconId>([
  'pint', 'bottle', 'can', 'ipa', 'stout', 'cider', 'ale', 'wine-red', 'wine-white',
  'sparkling', 'spirit', 'cocktail', 'shot', 'alcopop', 'zero',
])
const STYLES = new Set<DrinkStyle>(['lager', 'stout', 'ipa', 'ale', 'cider', 'red-wine', 'white-wine', 'sparkling', 'spirit', 'cocktail', 'shot', 'low-no'])
const SERVES = new Set<DrinkServe>(['pint', 'bottle', 'can', '125ml', '175ml', '250ml', 'single', 'double', 'cocktail', 'shot'])
const MEALS = new Set<MealState>(['empty', 'snack', 'meal', 'unknown'])
const LEGACY_TARGETS: Record<Exclude<TargetId, 'wavy' | 'smashed'>, TargetSnapshot> = {
  glow: { id: 'glow', label: 'Lightweight', emoji: '🙂', minBac: .01, maxBac: .03 },
  buzz: { id: 'buzz', label: 'Buzzing', emoji: '😏', minBac: .03, maxBac: .05 },
  tipsy: { id: 'tipsy', label: 'Pissed', emoji: '😄', minBac: .05, maxBac: .07 },
  merry: { id: 'merry', label: 'Battered', emoji: '🥴', minBac: .07, maxBac: .09 },
  bignight: { id: 'bignight', label: 'Blackout', emoji: '🫠', minBac: .09, maxBac: .11 },
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : null
}

function finite(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value)
}

function text(value: unknown, max = 80): string | null {
  if (typeof value !== 'string') return null
  const clean = value.trim().slice(0, max)
  return clean || null
}

export function defaultPreferences(now = Date.now()): Preferences {
  return {
    favoritePresetIds: [...DEFAULT_FAVORITES],
    recentPresetIds: [],
    customPresets: [],
    lastTargetId: 'glow',
    reducedMotion: false,
    haptics: true,
    updatedAt: now,
  }
}

function normalizeProfile(value: unknown, now: number): Profile | null {
  const p = record(value)
  const name = text(p?.name, 30)
  if (!p || !name || !finite(p.weightKg) || p.weightKg < 35 || p.weightKg > 250) return null
  if (typeof p.sex !== 'string' || !SEXES.has(p.sex as Sex)) return null
  return {
    id: text(p.id, 100) ?? newId(),
    name,
    weightKg: p.weightKg,
    sex: p.sex as Sex,
    drinkerLevel: typeof p.drinkerLevel === 'string' && DRINKER_LEVELS.has(p.drinkerLevel as DrinkerLevel)
      ? p.drinkerLevel as DrinkerLevel
      : 'weekend',
    age: finite(p.age) && p.age >= 18 && p.age <= 100 ? p.age : undefined,
    heightCm: finite(p.heightCm) && p.heightCm >= 120 && p.heightCm <= 230 ? p.heightCm : undefined,
    createdAt: finite(p.createdAt) ? p.createdAt : now,
    updatedAt: finite(p.updatedAt) ? p.updatedAt : finite(p.createdAt) ? p.createdAt : now,
  }
}

function normalizePreset(value: unknown): DrinkPreset | null {
  const p = record(value)
  const id = text(p?.id, 80)
  const name = text(p?.name, 40)
  if (!p || !id || !name || typeof p.category !== 'string' || !CATEGORIES.has(p.category as DrinkCategory)) return null
  if (typeof p.icon !== 'string' || !ICONS.has(p.icon as DrinkIconId)) return null
  if (!finite(p.volumeMl) || p.volumeMl < 5 || p.volumeMl > 5000) return null
  if (!finite(p.abv) || p.abv < 0 || p.abv > 1) return null
  const brand = text(p.brand, 40) ?? undefined
  const logoUrl = typeof p.logoUrl === 'string' && p.logoUrl.startsWith('https://www.google.com/s2/favicons?')
    ? p.logoUrl.slice(0, 300)
    : undefined
  const absorptionMin = finite(p.absorptionMin)
    ? Math.min(180, Math.max(5, p.absorptionMin))
    : 30
  return {
    id,
    name,
    brand,
    logoUrl,
    category: p.category as DrinkCategory,
    icon: p.icon as DrinkIconId,
    volumeMl: p.volumeMl,
    abv: p.abv,
    absorptionMin,
    detail: `${p.volumeMl}ml · ${Number((p.abv * 100).toFixed(1))}%`,
    source: p.source === 'built-in' ? 'built-in' : 'custom',
    style: typeof p.style === 'string' && STYLES.has(p.style as DrinkStyle) ? p.style as DrinkStyle : undefined,
    serve: typeof p.serve === 'string' && SERVES.has(p.serve as DrinkServe) ? p.serve as DrinkServe : undefined,
    country: text(p.country, 40) ?? undefined,
  }
}

function normalizeDrink(value: unknown, custom: DrinkPreset[]): LoggedDrink | null {
  const d = record(value)
  const id = text(d?.id, 100)
  if (!d || !id || !finite(d.at)) return null

  const legacyId = typeof d.type === 'string' ? LEGACY_PRESET[d.type] : undefined
  const known = presetById(legacyId ?? (typeof d.presetId === 'string' ? d.presetId : ''), custom)
  const snapshot = known ?? normalizePreset(d)
  if (!snapshot) return null

  return {
    id,
    presetId: snapshot.id,
    name: text(d.name, 40) ?? snapshot.name,
    brand: text(d.brand, 40) ?? snapshot.brand,
    logoUrl: typeof d.logoUrl === 'string' && d.logoUrl.startsWith('https://www.google.com/s2/favicons?')
      ? d.logoUrl.slice(0, 300)
      : snapshot.logoUrl,
    category: snapshot.category,
    icon: snapshot.icon,
    volumeMl: snapshot.volumeMl,
    abv: snapshot.abv,
    absorptionMin: snapshot.absorptionMin,
    at: d.at,
    units: unitsOfAlcohol(snapshot),
    grams: gramsOfAlcohol(snapshot),
    style: typeof d.style === 'string' && STYLES.has(d.style as DrinkStyle) ? d.style as DrinkStyle : snapshot.style,
    serve: typeof d.serve === 'string' && SERVES.has(d.serve as DrinkServe) ? d.serve as DrinkServe : snapshot.serve,
    country: text(d.country, 40) ?? snapshot.country,
  }
}

function normalizeRoomEvent(value: unknown): RoomEvent | null {
  const event = record(value)
  const id = text(event?.id, 100)
  const actorId = text(event?.actorId, 100)
  const actorName = text(event?.actorName, 30)
  const types = new Set<RoomEvent['type']>(['drink', 'reaction', 'cheers-countdown', 'round-invite', 'round-order', 'round-bought'])
  if (!event || !id || !actorId || !actorName || !finite(event.at) || typeof event.type !== 'string' || !types.has(event.type as RoomEvent['type'])) return null
  return {
    id,
    type: event.type as RoomEvent['type'],
    actorId,
    actorName,
    at: event.at,
    refId: text(event.refId, 100) ?? undefined,
    text: text(event.text, 80) ?? undefined,
    reaction: typeof event.reaction === 'string' ? event.reaction as RoomEvent['reaction'] : undefined,
    startsAt: finite(event.startsAt) ? event.startsAt : undefined,
    drink: record(event.drink) && text(record(event.drink)?.name, 40)
      ? {
          name: text(record(event.drink)?.name, 40)!,
          brand: text(record(event.drink)?.brand, 40) ?? undefined,
          icon: typeof record(event.drink)?.icon === 'string' && ICONS.has(record(event.drink)!.icon as DrinkIconId)
            ? record(event.drink)!.icon as DrinkIconId
            : 'pint',
          units: finite(record(event.drink)?.units) ? record(event.drink)!.units as number : 0,
        }
      : undefined,
  }
}

function normalizeSession(value: unknown, custom: DrinkPreset[], now: number): NightSession | null {
  const s = record(value)
  const id = text(s?.id, 100)
  if (!s || !id || !finite(s.startedAt) || typeof s.targetId !== 'string' || !TARGETS.has(s.targetId as TargetId)) return null
  const drinks = Array.isArray(s.drinks)
    ? s.drinks.map((d) => normalizeDrink(d, custom)).filter((d): d is LoggedDrink => d !== null)
    : []
  const waters = Array.isArray(s.waters) ? s.waters.filter(finite) : []
  const snapshot = record(s.targetSnapshot)
  const legacy = LEGACY_TARGETS[s.targetId as keyof typeof LEGACY_TARGETS]
  const targetSnapshot = snapshot && typeof snapshot.id === 'string' && TARGETS.has(snapshot.id as TargetId)
    && text(snapshot.label, 24) && text(snapshot.emoji, 8) && finite(snapshot.minBac) && finite(snapshot.maxBac)
    ? { id: snapshot.id as TargetId, label: text(snapshot.label, 24)!, emoji: text(snapshot.emoji, 8)!, minBac: snapshot.minBac, maxBac: snapshot.maxBac }
    : legacy
  return {
    id,
    startedAt: s.startedAt,
    updatedAt: finite(s.updatedAt) ? s.updatedAt : finite(s.endedAt) ? s.endedAt : now,
    targetId: s.targetId as TargetId,
    targetSnapshot,
    mealState: typeof s.mealState === 'string' && MEALS.has(s.mealState as MealState) ? s.mealState as MealState : 'unknown',
    drinks,
    waters,
    roomName: text(s.roomName, 36) ?? undefined,
    roomEvents: Array.isArray(s.roomEvents)
      ? s.roomEvents.map(normalizeRoomEvent).filter((event): event is RoomEvent => event !== null)
      : undefined,
    roomMembers: Array.isArray(s.roomMembers) ? s.roomMembers.map(record).filter((member): member is Record<string, unknown> => Boolean(member && text(member.id, 100) && text(member.name, 30))).map((member) => ({ id: text(member.id, 100)!, name: text(member.name, 30)! })) : undefined,
    roomLeaderboard: record(s.roomLeaderboard) as unknown as RoomLeaderboard | undefined,
    roomConfig: record(s.roomConfig) as NightSession['roomConfig'],
    endedAt: finite(s.endedAt) ? s.endedAt : undefined,
    reviewedAt: finite(s.reviewedAt) ? s.reviewedAt : undefined,
  }
}

function normalizeRoom(value: unknown): RoomMembership | null {
  const room = record(value)
  if (!room || typeof room.code !== 'string' || !/^[A-Z2-9]{6}$/.test(room.code)) return null
  if (typeof room.memberId !== 'string' || typeof room.memberToken !== 'string') return null
  return {
    code: room.code,
    memberId: room.memberId,
    memberToken: room.memberToken,
    isHost: Boolean(room.isHost),
  }
}

function normalizePreferences(value: unknown, now: number): Preferences {
  const raw = record(value)
  const customPresets = Array.isArray(raw?.customPresets)
    ? raw.customPresets.map(normalizePreset).filter((p): p is DrinkPreset => p !== null && p.source === 'custom')
    : []
  const available = new Set([...BUILT_IN_PRESETS, ...customPresets].map((p) => p.id))
  const strings = (candidate: unknown) => Array.isArray(candidate)
    ? [...new Set(candidate.filter((v): v is string => typeof v === 'string' && available.has(v)))]
    : []
  const favoritePresetIds = strings(raw?.favoritePresetIds)
  const lastTargetId = typeof raw?.lastTargetId === 'string' && TARGETS.has(raw.lastTargetId as TargetId)
    ? raw.lastTargetId as TargetId
    : 'glow'
  return {
    favoritePresetIds: favoritePresetIds.length ? favoritePresetIds.slice(0, 8) : [...DEFAULT_FAVORITES],
    recentPresetIds: strings(raw?.recentPresetIds).slice(0, 8),
    customPresets,
    lastTargetId,
    reducedMotion: Boolean(raw?.reducedMotion),
    haptics: raw?.haptics !== false,
    updatedAt: finite(raw?.updatedAt) ? raw.updatedAt : now,
  }
}

export function normalizeData(value: unknown, now = Date.now()): AppData {
  const root = record(value)
  const preferences = normalizePreferences(root?.preferences, now)
  const custom = preferences.customPresets
  return {
    profile: normalizeProfile(root?.profile, now),
    session: normalizeSession(root?.session, custom, now),
    history: Array.isArray(root?.history)
      ? root.history.map((s) => normalizeSession(s, custom, now)).filter((s): s is NightSession => s !== null)
      : [],
    room: normalizeRoom(root?.room),
    preferences,
  }
}

export function loadData(): AppData {
  try {
    const raw = localStorage.getItem(KEY) ?? localStorage.getItem(LEGACY_KEY)
    return raw ? normalizeData(JSON.parse(raw)) : normalizeData(null)
  } catch {
    return normalizeData(null)
  }
}

export function saveData(data: AppData): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(data))
  } catch {
    // The current session still works in memory when storage is unavailable.
  }
}

export function newId(): string {
  try {
    if (typeof globalThis.crypto?.randomUUID === 'function') return globalThis.crypto.randomUUID()
  } catch { /* LAN WebViews are not secure contexts. */ }

  const bytes = new Uint8Array(16)
  if (globalThis.crypto?.getRandomValues) globalThis.crypto.getRandomValues(bytes)
  else for (let i = 0; i < bytes.length; i += 1) bytes[i] = Math.floor(Math.random() * 256)
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const hex = [...bytes].map((byte) => byte.toString(16).padStart(2, '0')).join('')
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
}
