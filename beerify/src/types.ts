export type Sex = 'female' | 'male' | 'other'
export type DrinkerLevel = 'one-pint' | 'weekend' | 'regular' | 'full-time'

export const DRINKER_LEVELS: { id: DrinkerLevel; label: string; detail: string }[] = [
  { id: 'one-pint', label: 'One-pint wonder', detail: 'A cameo, then chips.' },
  { id: 'weekend', label: 'Weekend athlete', detail: 'Trains Friday and Saturday.' },
  { id: 'regular', label: 'Pub furniture', detail: 'Has a preferred stool.' },
  { id: 'full-time', label: 'Full-time alcoholic (allegedly)', detail: 'The group chat has filed paperwork.' },
]

export interface Profile {
  name: string
  weightKg: number
  sex: Sex
  drinkerLevel: DrinkerLevel
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
}

export type TargetId = 'glow' | 'buzz' | 'tipsy' | 'merry' | 'bignight'

export interface Target {
  id: TargetId
  label: string
  emoji: string
  tagline: string
  minBac: number
  maxBac: number
}

export interface NightSession {
  id: string
  startedAt: number
  updatedAt: number
  targetId: TargetId
  drinks: LoggedDrink[]
  waters: number[]
  roomName?: string
  roomEvents?: RoomEvent[]
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

export interface RoomState {
  code: string
  name: string
  createdAt: number
  theme: 'green' | 'red' | 'blue'
  labels: Partial<Record<TargetId, string>>
  hostMemberId: string
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
