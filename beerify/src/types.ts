export type Sex = 'female' | 'male' | 'other'

/** How often the user drinks; used to tune alcohol elimination speed. */
export type Tolerance = 'rare' | 'monthly' | 'weekly' | 'frequent'

export interface Profile {
  name: string
  weightKg: number
  sex: Sex
  tolerance: Tolerance
  createdAt: number
}

export type DrinkTypeId = 'beer' | 'shot' | 'wine' | 'cocktail'

export interface DrinkType {
  id: DrinkTypeId
  label: string
  emoji: string
  volumeMl: number
  abv: number // 0..1
  /** minutes for the drink to be fully absorbed */
  absorptionMin: number
  detail: string
}

export interface LoggedDrink {
  id: string
  type: DrinkTypeId
  at: number // epoch ms
  units: number // UK units (10ml pure ethanol)
  grams: number // grams of pure ethanol
}

export type TargetId = 'glow' | 'buzz' | 'tipsy' | 'merry' | 'bignight'

export interface Target {
  id: TargetId
  label: string
  emoji: string
  tagline: string
  /** BAC band (in %) the user wants to sit in */
  minBac: number
  maxBac: number
  warning?: string
}

export interface NightSession {
  id: string
  startedAt: number
  targetId: TargetId
  drinks: LoggedDrink[]
  waters: number[] // epoch ms timestamps
  endedAt?: number
  reviewedAt?: number
}

/** The user's membership in a friends room. */
export interface RoomMembership {
  code: string
  memberId: string
}

/** A friend's live state as shared inside a room. */
export interface SquadMember {
  id: string
  name: string
  bac: number
  units: number
  drinks: number
  targetId: TargetId
  status: string
  inSession: boolean
  updatedAt: number
}

export interface RoomState {
  code: string
  createdAt: number
  members: SquadMember[]
}

export interface AppData {
  profile: Profile | null
  session: NightSession | null
  history: NightSession[]
  room: RoomMembership | null
}

export type CoachTone = 'cheer' | 'chill' | 'nudge' | 'warn'

export interface CoachMessage {
  tone: CoachTone
  text: string
  /** short actionable tip shown under the message */
  tip?: string
}
