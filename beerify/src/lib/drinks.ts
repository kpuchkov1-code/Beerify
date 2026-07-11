import type { DrinkPreset, LoggedDrink, Target, TargetId } from '../types'

const ETHANOL_DENSITY = 0.789
const UK_UNIT_GRAMS = 8

function preset(
  id: string,
  name: string,
  category: DrinkPreset['category'],
  icon: DrinkPreset['icon'],
  volumeMl: number,
  abv: number,
  absorptionMin: number,
): DrinkPreset {
  const pct = abv * 100
  return {
    id,
    name,
    category,
    icon,
    volumeMl,
    abv,
    absorptionMin,
    detail: `${volumeMl}ml · ${Number.isInteger(pct) ? pct : pct.toFixed(1)}%`,
    source: 'built-in',
  }
}

function brandedPreset(
  id: string,
  brand: string,
  name: string,
  icon: DrinkPreset['icon'],
  volumeMl: number,
  abv: number,
  domain: string,
): DrinkPreset {
  return {
    ...preset(id, name, 'beer', icon, volumeMl, abv, icon === 'stout' ? 38 : 32),
    brand,
    logoUrl: `https://www.google.com/s2/favicons?domain=${domain}&sz=128`,
  }
}

export const BUILT_IN_PRESETS: DrinkPreset[] = [
  preset('lager-pint', 'Lager pint', 'beer', 'pint', 568, 0.04, 35),
  preset('lager-bottle', 'Lager bottle', 'beer', 'bottle', 330, 0.05, 30),
  preset('lager-can', 'Lager can', 'beer', 'can', 440, 0.045, 32),
  preset('ipa-pint', 'IPA pint', 'beer', 'ipa', 568, 0.06, 40),
  preset('stout-pint', 'Stout pint', 'beer', 'stout', 568, 0.042, 38),
  preset('ale-pint', 'Ale pint', 'beer', 'ale', 568, 0.045, 38),
  preset('cider-pint', 'Cider pint', 'cider', 'cider', 568, 0.045, 36),
  preset('red-wine', 'Red wine', 'wine', 'wine-red', 175, 0.13, 30),
  preset('white-wine', 'White wine', 'wine', 'wine-white', 175, 0.12, 30),
  preset('sparkling', 'Fizz', 'wine', 'sparkling', 125, 0.12, 25),
  preset('single-spirit', 'Single spirit', 'spirit', 'spirit', 25, 0.4, 15),
  preset('double-spirit', 'Double spirit', 'spirit', 'spirit', 50, 0.4, 20),
  preset('cocktail', 'Cocktail', 'cocktail', 'cocktail', 200, 0.1, 30),
  preset('shot', 'Shot', 'shot', 'shot', 25, 0.4, 12),
  preset('alcopop', 'Alcopop', 'beer', 'alcopop', 275, 0.055, 28),
  preset('zero-beer', 'Low / no beer', 'soft', 'zero', 330, 0.005, 20),
  brandedPreset('guinness-draught', 'Guinness', 'Draught pint', 'stout', 568, 0.042, 'guinness.com'),
  brandedPreset('stella-pint', 'Stella Artois', 'Lager pint', 'pint', 568, 0.046, 'stellaartois.com'),
  brandedPreset('budweiser-bottle', 'Budweiser', 'Lager bottle', 'bottle', 330, 0.045, 'budweiser.com'),
  brandedPreset('carlsberg-pint', 'Carlsberg', 'Danish Pilsner pint', 'pint', 568, 0.034, 'carlsberg.com'),
  brandedPreset('corona-bottle', 'Corona Extra', 'Lager bottle', 'bottle', 330, 0.045, 'corona.com'),
  brandedPreset('peroni-bottle', 'Peroni', 'Nastro Azzurro bottle', 'bottle', 330, 0.05, 'peroniitalia.com'),
  brandedPreset('brewdog-punk', 'BrewDog', 'Punk IPA can', 'ipa', 440, 0.054, 'brewdog.com'),
  brandedPreset('heineken-bottle', 'Heineken', 'Lager bottle', 'bottle', 330, 0.05, 'heineken.com'),
  brandedPreset('coors-pint', 'Coors', 'Lager pint', 'pint', 568, 0.04, 'coorslight.com'),
  brandedPreset('moretti-pint', 'Birra Moretti', 'Lager pint', 'pint', 568, 0.046, 'birramoretti.com'),
]

export const DEFAULT_FAVORITES = ['guinness-draught', 'stella-pint', 'corona-bottle', 'brewdog-punk']

export function gramsOfAlcohol(drink: Pick<DrinkPreset, 'volumeMl' | 'abv'>): number {
  return drink.volumeMl * drink.abv * ETHANOL_DENSITY
}

export function unitsOfAlcohol(drink: Pick<DrinkPreset, 'volumeMl' | 'abv'>): number {
  return gramsOfAlcohol(drink) / UK_UNIT_GRAMS
}

export function logFromPreset(p: DrinkPreset, id: string, at: number): LoggedDrink {
  return {
    id,
    presetId: p.id,
    name: p.name,
    brand: p.brand,
    logoUrl: p.logoUrl,
    category: p.category,
    icon: p.icon,
    volumeMl: p.volumeMl,
    abv: p.abv,
    absorptionMin: p.absorptionMin,
    at,
    units: unitsOfAlcohol(p),
    grams: gramsOfAlcohol(p),
  }
}

export function allPresets(custom: DrinkPreset[]): DrinkPreset[] {
  return [...custom, ...BUILT_IN_PRESETS]
}

export function presetById(id: string, custom: DrinkPreset[] = []): DrinkPreset | undefined {
  return allPresets(custom).find((p) => p.id === id)
}

export const LEGACY_PRESET: Record<string, string> = {
  beer: 'lager-can',
  shot: 'shot',
  wine: 'red-wine',
  cocktail: 'cocktail',
}

export const TARGETS: Record<TargetId, Target> = {
  glow: {
    id: 'glow',
    label: 'Lightweight',
    emoji: '🙂',
    tagline: 'A couple and still making complete sense.',
    minBac: 0.01,
    maxBac: 0.03,
  },
  buzz: {
    id: 'buzz',
    label: 'Buzzing',
    emoji: '😏',
    tagline: 'Chatty, confident, absolutely staying out.',
    minBac: 0.03,
    maxBac: 0.05,
  },
  tipsy: {
    id: 'tipsy',
    label: 'Pissed',
    emoji: '😄',
    tagline: 'Volume up. Decisions increasingly freelance.',
    minBac: 0.05,
    maxBac: 0.07,
  },
  merry: {
    id: 'merry',
    label: 'Battered',
    emoji: '🥴',
    tagline: 'Operating mostly on confidence and vibes.',
    minBac: 0.07,
    maxBac: 0.09,
  },
  bignight: {
    id: 'bignight',
    label: 'Blackout',
    emoji: '🫠',
    tagline: 'Tomorrow gets the patch notes.',
    minBac: 0.09,
    maxBac: 0.11,
  },
}

export const TARGET_ORDER: TargetId[] = ['glow', 'buzz', 'tipsy', 'merry', 'bignight']

export function targetLabel(id: TargetId, labels?: Partial<Record<TargetId, string>>): string {
  return labels?.[id]?.trim() || TARGETS[id].label
}
