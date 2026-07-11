export type Sex = 'female' | 'male' | 'other'
export type DrinkerLevel = 'one-pint' | 'weekend' | 'regular' | 'full-time'

export const DRINKER_LEVELS: { id: DrinkerLevel; label: string; detail: string }[] = [
  { id: 'one-pint', label: 'One-pint wonder', detail: 'A cameo, then chips.' },
  { id: 'weekend', label: 'Weekend athlete', detail: 'Trains Friday and Saturday.' },
  { id: 'regular', label: 'Pub furniture', detail: 'Has a preferred stool.' },
  { id: 'full-time', label: 'Full-time alcoholic (allegedly)', detail: 'The group chat has filed paperwork.' },
]

export interface Profile {
  id: string
  name: string
  weightKg: number
  sex: Sex
  drinkerLevel: DrinkerLevel
  age?: number
  heightCm?: number
  createdAt: number
  updatedAt: number
}

export type DrinkCategory =
  | 'beer'
  | 'cider'
  | 'wine'
  | 'spirit'
  | 'cocktail'
  | 'shot'
  | 'soft'

export type DrinkStyle = 'lager' | 'stout' | 'ipa' | 'ale' | 'cider' | 'red-wine' | 'white-wine' | 'sparkling' | 'spirit' | 'cocktail' | 'shot' | 'low-no'
export type DrinkServe = 'pint' | 'bottle' | 'can' | '125ml' | '175ml' | '250ml' | 'single' | 'double' | 'cocktail' | 'shot'

export type DrinkIconId =
  | 'pint'
  | 'bottle'
  | 'can'
  | 'ipa'
  | 'stout'
  | 'cider'
  | 'ale'
  | 'wine-red'
  | 'wine-white'
  | 'sparkling'
  | 'spirit'
  | 'cocktail'
  | 'shot'
  | 'alcopop'
  | 'zero'

export interface DrinkPreset {
  id: string
  name: string
  brand?: string
  logoUrl?: string
  category: DrinkCategory
  icon: DrinkIconId
  volumeMl: number
  abv: number // 0..1
  absorptionMin: number
  detail: string
  source: 'built-in' | 'custom'
  style?: DrinkStyle
  serve?: DrinkServe
  country?: string
}

/** A complete snapshot: editing a preset never rewrites a past night. */
export interface LoggedDrink {
  id: string
  presetId: string
  name: string
  brand?: string
  logoUrl?: string
  category: DrinkCategory
  icon: DrinkIconId
  volumeMl: number
  abv: number
  absorptionMin: number
  at: number
  units: number
  grams: number
  style?: DrinkStyle
  serve?: DrinkServe
  country?: string
}

export type TargetId = 'glow' | 'buzz' | 'wavy' | 'tipsy' | 'smashed' | 'merry' | 'bignight'

export interface Target {
  id: TargetId
  label: string
  emoji: string
  tagline: string
  minBac: number
  maxBac: number
}

export interface TargetSnapshot { id: TargetId; label: string; emoji: string; minBac: number; maxBac: number }
export type MealState = 'empty' | 'snack' | 'meal' | 'unknown'
export interface BacRange { low: number; likely: number; high: number; model: 'watson' | 'widmark'; completeness: 'personalised' | 'basic' }

export interface NightSession {
  id: string
  startedAt: number
  updatedAt: number
  targetId: TargetId
  targetSnapshot?: TargetSnapshot
  mealState: MealState
  drinks: LoggedDrink[]
  waters: number[]
  roomName?: string
  roomEvents?: RoomEvent[]
  roomMembers?: Pick<SquadMember, 'id' | 'name'>[]
  roomLeaderboard?: RoomLeaderboard
  roomConfig?: Pick<RoomState, 'name' | 'theme' | 'labels' | 'leaderboardMode'>
  endedAt?: number
  reviewedAt?: number
}

export interface Preferences {
  favoritePresetIds: string[]
  recentPresetIds: string[]
  customPresets: DrinkPreset[]
  lastTargetId: TargetId
  reducedMotion: boolean
  haptics: boolean
  updatedAt: number
}

export interface RoomMembership {
  code: string
  memberId: string
  memberToken: string
  isHost: boolean
}

export type ZoneStatus = 'sober' | 'warming' | 'in-zone' | 'over' | 'way-over'

export interface SquadMember {
  id: string
  name: string
  bac: number
  units: number
  drinks: number
  distinctDrinks: number
  targetId: TargetId
  status: ZoneStatus
  inSession: boolean
  updatedAt: number
}

export type RoomReaction =
  | 'cheers'
  | 'on-my-way'
  | 'get-another'
  | 'scenes'
  | 'water-run'
  | 'food'

export type RoomEventType =
  | 'drink'
  | 'reaction'
  | 'cheers-countdown'
  | 'round-invite'
  | 'round-order'
  | 'round-bought'

export interface RoomEvent {
  id: string
  type: RoomEventType
  actorId: string
  actorName: string
  at: number
  refId?: string
  text?: string
  reaction?: RoomReaction
  drink?: Pick<LoggedDrink, 'name' | 'brand' | 'icon' | 'units'>
  startsAt?: number
}

export interface RoomRound {
  id: string
  buyerId: string
  buyerName: string
  createdAt: number
  orders: { memberId: string; memberName: string; order: string }[]
}

export type LeaderboardMode = 'social' | 'balanced' | 'chaos'
export type LeaderboardMetric = 'rounds' | 'reactions' | 'activity' | 'variety' | 'drinks' | 'units' | 'bac'
export interface LeaderboardEntry { memberId: string; name: string; value: number }
export interface RoomLeaderboard { mode: LeaderboardMode; categories: Partial<Record<LeaderboardMetric, LeaderboardEntry[]>> }

export interface RoomState {
  code: string
  name: string
  createdAt: number
  theme: 'green' | 'red' | 'blue'
  labels: Partial<Record<TargetId, string>>
  hostMemberId: string
  leaderboardMode: LeaderboardMode
  leaderboard: RoomLeaderboard
  members: SquadMember[]
  events: RoomEvent[]
  activeRound: RoomRound | null
  roundRota: string[]
}

export interface AppData {
  profile: Profile | null
  session: NightSession | null
  history: NightSession[]
  room: RoomMembership | null
  preferences: Preferences
}

export type CoachTone = 'cheer' | 'chill' | 'nudge' | 'warn'

export interface CoachMessage {
  tone: CoachTone
  text: string
  tip?: string
}
