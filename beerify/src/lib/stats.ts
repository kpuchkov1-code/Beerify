import type { NightSession } from '../types'

export function calculateStats(history: NightSession[], now = Date.now()) {
  const drinks = history.flatMap((night) => night.drinks)
  const weekUnits = history.filter((night) => night.startedAt >= now - 7 * 86_400_000).flatMap((night) => night.drinks).reduce((sum, drink) => sum + drink.units, 0)
  return {
    nights: history.length,
    drinks: drinks.length,
    totalUnits: drinks.reduce((sum, drink) => sum + drink.units, 0),
    weekUnits,
    waters: history.reduce((sum, night) => sum + night.waters.length, 0),
    categories: drinks.reduce<Record<string, number>>((totals, drink) => ({ ...totals, [drink.category]: (totals[drink.category] ?? 0) + 1 }), {}),
    mostDrinks: history.reduce((best, night) => Math.max(best, night.drinks.length), 0),
    longestNightHours: history.reduce((best, night) => Math.max(best, ((night.endedAt ?? night.updatedAt) - night.startedAt) / 3_600_000), 0),
    alcoholFreeNights: history.filter((night) => night.participationMode !== 'drinking').length,
  }
}
