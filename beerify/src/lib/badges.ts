import type { NightSession, Profile } from '../types'
import { estimateBac } from './bac'
import { TARGETS } from './drinks'

export interface Badge {
  id: string
  emoji: string
  title: string
  subtitle: string
}

export const BADGES: Badge[] = [
  { id: 'first-night', emoji: '🌙', title: 'First Night', subtitle: 'Log your first session' },
  { id: 'first-shot', emoji: '🥃', title: 'First Shot', subtitle: 'Log a shot' },
  { id: 'hydration-hero', emoji: '💧', title: 'Hydration Hero', subtitle: 'Three waters in one night' },
  { id: 'home-before-midnight', emoji: '🕛', title: 'Home by Midnight', subtitle: 'Wrap a drinking night before midnight' },
  { id: 'marathoner', emoji: '🏃', title: 'Marathoner', subtitle: 'Ten drinks in one night' },
  { id: 'in-the-zone', emoji: '🎯', title: 'In the Zone', subtitle: 'Hit the target without overshooting' },
  { id: 'designated-driver', emoji: '🚗', title: 'Designated Driver', subtitle: 'Go 45 minutes with zero alcohol' },
  { id: 'streak-5', emoji: '🔥', title: '5-Night Streak', subtitle: 'Log five consecutive calendar days' },
  { id: 'sommelier', emoji: '🍷', title: 'Sommelier', subtitle: 'Wine only for a night' },
  { id: 'brewmaster', emoji: '🍺', title: 'Brewmaster', subtitle: 'Beer or cider only for a night' },
  { id: 'mixologist', emoji: '🍹', title: 'Mixologist', subtitle: 'Cocktails only for a night' },
  { id: 'explorer', emoji: '🌍', title: 'Explorer', subtitle: 'Four drink families in one night' },
]

function hasFiveDayStreak(history: NightSession[]): boolean {
  const days = [...new Set(history.map((session) => new Date(new Date(session.startedAt).setHours(0, 0, 0, 0)).getTime()))].sort((a, b) => a - b)
  let streak = 1
  for (let index = 1; index < days.length; index++) {
    streak = days[index] - days[index - 1] === 86_400_000 ? streak + 1 : 1
    if (streak >= 5) return true
  }
  return false
}

function hitTargetCleanly(session: NightSession, profile: Profile): boolean {
  if (!session.drinks.length) return false
  const target = TARGETS[session.targetId]
  const end = session.endedAt ?? session.updatedAt
  let hit = false
  for (let at = session.startedAt; at <= end; at += 5 * 60_000) {
    const bac = estimateBac(session.drinks, profile, at, session.mealState)
    if (bac > target.maxBac) return false
    if (bac >= target.minBac) hit = true
  }
  return hit
}

export function earnedBadgeIds(history: NightSession[], profile: Profile): Set<string> {
  const earned = new Set<string>()
  if (history.length) earned.add('first-night')
  if (history.some((session) => session.drinks.some((drink) => drink.category === 'shot'))) earned.add('first-shot')
  if (history.some((session) => session.waters.length >= 3)) earned.add('hydration-hero')
  if (history.some((session) => {
    if (!session.drinks.length || !session.endedAt) return false
    const midnight = new Date(session.startedAt); midnight.setHours(24, 0, 0, 0)
    return session.endedAt < midnight.getTime()
  })) earned.add('home-before-midnight')
  if (history.some((session) => session.drinks.length >= 10)) earned.add('marathoner')
  if (history.some((session) => hitTargetCleanly(session, profile))) earned.add('in-the-zone')
  if (history.some((session) => session.participationMode === 'driver' && !session.drinks.length && (session.endedAt ?? session.updatedAt) - session.startedAt >= 45 * 60_000)) earned.add('designated-driver')
  if (hasFiveDayStreak(history)) earned.add('streak-5')
  for (const session of history) {
    const categories = new Set(session.drinks.map((drink) => drink.category))
    if (categories.size === 1 && categories.has('wine')) earned.add('sommelier')
    if (categories.size > 0 && [...categories].every((category) => category === 'beer' || category === 'cider')) earned.add('brewmaster')
    if (categories.size === 1 && categories.has('cocktail')) earned.add('mixologist')
    const families = new Set(session.drinks.map((drink) => drink.category === 'cider' ? 'beer' : drink.category === 'shot' ? 'spirit' : drink.category))
    if (families.size >= 4) earned.add('explorer')
  }
  return earned
}
