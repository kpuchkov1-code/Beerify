export type Sex = 'female' | 'male' | 'other'

export interface Profile {
  name: string
  weightKg: number
  sex: Sex
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

export type TargetId = 'buzz' | 'tipsy' | 'merry'

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

export interface AppData {
  profile: Profile | null
  session: NightSession | null
  history: NightSession[]
}

export type CoachTone = 'cheer' | 'chill' | 'nudge' | 'warn'

export interface CoachMessage {
  tone: CoachTone
  text: string
  /** short actionable tip shown under the message */
  tip?: string
}
