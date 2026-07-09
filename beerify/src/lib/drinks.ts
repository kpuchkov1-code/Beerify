import type { DrinkType, DrinkTypeId, Target, TargetId } from '../types'

const ETHANOL_DENSITY = 0.789 // g/ml
const UK_UNIT_GRAMS = 8 // 1 UK unit = 10ml = 8g pure ethanol

export const DRINK_TYPES: Record<DrinkTypeId, DrinkType> = {
  beer: {
    id: 'beer',
    label: 'Beer',
    emoji: '🍺',
    volumeMl: 500,
    abv: 0.05,
    absorptionMin: 35,
    detail: '500ml · 5%',
  },
  shot: {
    id: 'shot',
    label: 'Shot',
    emoji: '🥃',
    volumeMl: 40,
    abv: 0.4,
    absorptionMin: 15,
    detail: '40ml · 40%',
  },
  wine: {
    id: 'wine',
    label: 'Wine',
    emoji: '🍷',
    volumeMl: 175,
    abv: 0.13,
    absorptionMin: 30,
    detail: '175ml · 13%',
  },
  cocktail: {
    id: 'cocktail',
    label: 'Cocktail',
    emoji: '🍹',
    volumeMl: 200,
    abv: 0.14,
    absorptionMin: 30,
    detail: '~2 shots mixed',
  },
}

export function gramsOfAlcohol(type: DrinkType): number {
  return type.volumeMl * type.abv * ETHANOL_DENSITY
}

export function unitsOfAlcohol(type: DrinkType): number {
  return gramsOfAlcohol(type) / UK_UNIT_GRAMS
}

export const TARGETS: Record<TargetId, Target> = {
  buzz: {
    id: 'buzz',
    label: 'Gentle buzz',
    emoji: '😊',
    tagline: 'Warm, chatty, fully in control.',
    minBac: 0.02,
    maxBac: 0.04,
  },
  tipsy: {
    id: 'tipsy',
    label: 'Happily tipsy',
    emoji: '😄',
    tagline: 'Giggly and glowing, dance-floor ready.',
    minBac: 0.04,
    maxBac: 0.06,
  },
  merry: {
    id: 'merry',
    label: 'Properly merry',
    emoji: '🥳',
    tagline: 'Big night energy. Pace yourself!',
    minBac: 0.06,
    maxBac: 0.08,
    warning: 'Above this point the fun drops off fast. Beerify will keep you honest.',
  },
}

export const TARGET_ORDER: TargetId[] = ['buzz', 'tipsy', 'merry']
