import type { DrinkPreset, DrinkServe, DrinkStyle, LoggedDrink, Target, TargetId } from '../types'

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
  style?: DrinkStyle,
  serve?: DrinkServe,
  country?: string,
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
    style,
    serve,
    country,
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
  country: string,
  style: DrinkStyle,
  serve: DrinkServe,
): DrinkPreset {
  return {
    ...preset(id, name, style === 'cider' ? 'cider' : 'beer', icon, volumeMl, abv, style === 'cider' ? 62 : style === 'stout' || style === 'ipa' || style === 'ale' || style === 'lager' ? 62 : 36, style, serve, country),
    brand,
    logoUrl: `https://www.google.com/s2/favicons?domain=${domain}&sz=128`,
  }
}

export const BUILT_IN_PRESETS: DrinkPreset[] = [
  preset('lager-pint', 'Lager pint', 'beer', 'pint', 568, .04, 62, 'lager', 'pint'),
  preset('lager-bottle', 'Lager bottle', 'beer', 'bottle', 330, .045, 62, 'lager', 'bottle'),
  preset('lager-can', 'Lager can', 'beer', 'can', 440, .045, 62, 'lager', 'can'),
  preset('ipa-pint', 'IPA pint', 'beer', 'ipa', 568, .05, 62, 'ipa', 'pint'),
  preset('ipa-can', 'IPA can', 'beer', 'ipa', 440, .05, 62, 'ipa', 'can'),
  preset('stout-pint', 'Stout pint', 'beer', 'stout', 568, .042, 62, 'stout', 'pint'),
  preset('stout-can', 'Stout can', 'beer', 'stout', 440, .042, 62, 'stout', 'can'),
  preset('ale-pint', 'Ale pint', 'beer', 'ale', 568, .043, 62, 'ale', 'pint'),
  preset('cider-pint', 'Cider pint', 'cider', 'cider', 568, .045, 62, 'cider', 'pint'),
  preset('cider-bottle', 'Cider bottle', 'cider', 'cider', 500, .04, 62, 'cider', 'bottle'),
  preset('red-wine-125', 'Red wine 125ml', 'wine', 'wine-red', 125, .13, 54, 'red-wine', '125ml'),
  preset('red-wine', 'Red wine 175ml', 'wine', 'wine-red', 175, .13, 54, 'red-wine', '175ml'),
  preset('red-wine-250', 'Red wine 250ml', 'wine', 'wine-red', 250, .13, 54, 'red-wine', '250ml'),
  preset('white-wine-125', 'White wine 125ml', 'wine', 'wine-white', 125, .12, 54, 'white-wine', '125ml'),
  preset('white-wine', 'White wine 175ml', 'wine', 'wine-white', 175, .12, 54, 'white-wine', '175ml'),
  preset('white-wine-250', 'White wine 250ml', 'wine', 'wine-white', 250, .12, 54, 'white-wine', '250ml'),
  preset('sparkling', 'Fizz 125ml', 'wine', 'sparkling', 125, .12, 54, 'sparkling', '125ml'),
  preset('single-spirit', 'Single spirit', 'spirit', 'spirit', 25, .4, 36, 'spirit', 'single'),
  preset('double-spirit', 'Double spirit', 'spirit', 'spirit', 50, .4, 36, 'spirit', 'double'),
  preset('cocktail', 'Cocktail', 'cocktail', 'cocktail', 200, .1, 36, 'cocktail', 'cocktail'),
  preset('shot', 'Shot', 'shot', 'shot', 25, .4, 36, 'shot', 'shot'),
  preset('alcopop', 'Alcopop', 'beer', 'alcopop', 275, .055, 62, 'lager', 'bottle'),
  preset('zero-beer', 'Low / no beer', 'soft', 'zero', 330, .005, 62, 'low-no', 'bottle'),

  brandedPreset('guinness-draught', 'Guinness', 'Draught pint', 'stout', 568, .042, 'guinness.com', 'Ireland', 'stout', 'pint'),
  brandedPreset('guinness-can', 'Guinness', 'Draught can', 'stout', 440, .041, 'guinness.com', 'Ireland', 'stout', 'can'),
  brandedPreset('stella-pint', 'Stella Artois', 'Lager pint', 'pint', 568, .046, 'stellaartois.com', 'Belgium', 'lager', 'pint'),
  brandedPreset('stella-bottle', 'Stella Artois', 'Lager bottle', 'bottle', 330, .046, 'stellaartois.com', 'Belgium', 'lager', 'bottle'),
  brandedPreset('stella-can', 'Stella Artois', 'Lager can', 'can', 440, .046, 'stellaartois.com', 'Belgium', 'lager', 'can'),
  brandedPreset('peroni-pint', 'Peroni', 'Nastro Azzurro pint', 'pint', 568, .05, 'peroniitalia.com', 'Italy', 'lager', 'pint'),
  brandedPreset('peroni-bottle', 'Peroni', 'Nastro Azzurro bottle', 'bottle', 330, .05, 'peroniitalia.com', 'Italy', 'lager', 'bottle'),
  brandedPreset('peroni-can', 'Peroni', 'Nastro Azzurro can', 'can', 440, .05, 'peroniitalia.com', 'Italy', 'lager', 'can'),
  brandedPreset('asahi-pint', 'Asahi Super Dry', 'Lager pint', 'pint', 568, .05, 'asahibeer.co.uk', 'Japan', 'lager', 'pint'),
  brandedPreset('asahi-bottle', 'Asahi Super Dry', 'Lager bottle', 'bottle', 330, .05, 'asahibeer.co.uk', 'Japan', 'lager', 'bottle'),
  brandedPreset('asahi-can', 'Asahi Super Dry', 'Lager can', 'can', 330, .05, 'asahibeer.co.uk', 'Japan', 'lager', 'can'),
  brandedPreset('heineken-pint', 'Heineken', 'Lager pint', 'pint', 568, .05, 'heineken.com', 'Netherlands', 'lager', 'pint'),
  brandedPreset('heineken-bottle', 'Heineken', 'Lager bottle', 'bottle', 330, .05, 'heineken.com', 'Netherlands', 'lager', 'bottle'),
  brandedPreset('heineken-can', 'Heineken', 'Lager can', 'can', 440, .05, 'heineken.com', 'Netherlands', 'lager', 'can'),
  brandedPreset('moretti-pint', 'Birra Moretti', 'Lager pint', 'pint', 568, .046, 'birramoretti.com', 'Italy', 'lager', 'pint'),
  brandedPreset('moretti-bottle', 'Birra Moretti', 'Lager bottle', 'bottle', 330, .046, 'birramoretti.com', 'Italy', 'lager', 'bottle'),
  brandedPreset('madri-pint', 'Madrí Excepcional', 'Lager pint', 'pint', 568, .046, 'madriexcepcional.com', 'Spain', 'lager', 'pint'),
  brandedPreset('madri-can', 'Madrí Excepcional', 'Lager can', 'can', 440, .046, 'madriexcepcional.com', 'Spain', 'lager', 'can'),
  brandedPreset('modelo-bottle', 'Modelo Especial', 'Lager bottle', 'bottle', 355, .045, 'modelousa.com', 'Mexico', 'lager', 'bottle'),
  brandedPreset('modelo-can', 'Modelo Especial', 'Lager can', 'can', 355, .045, 'modelousa.com', 'Mexico', 'lager', 'can'),
  brandedPreset('corona-bottle', 'Corona Extra', 'Lager bottle', 'bottle', 330, .045, 'corona.com', 'Mexico', 'lager', 'bottle'),
  brandedPreset('corona-can', 'Corona Extra', 'Lager can', 'can', 330, .045, 'corona.com', 'Mexico', 'lager', 'can'),
  brandedPreset('budweiser-pint', 'Budweiser', 'Lager pint', 'pint', 568, .045, 'budweiser.com', 'USA', 'lager', 'pint'),
  brandedPreset('budweiser-bottle', 'Budweiser', 'Lager bottle', 'bottle', 330, .045, 'budweiser.com', 'USA', 'lager', 'bottle'),
  brandedPreset('budweiser-can', 'Budweiser', 'Lager can', 'can', 440, .045, 'budweiser.com', 'USA', 'lager', 'can'),
  brandedPreset('coors-pint', 'Coors', 'Lager pint', 'pint', 568, .04, 'coorslight.com', 'USA', 'lager', 'pint'),
  brandedPreset('coors-can', 'Coors', 'Lager can', 'can', 440, .04, 'coorslight.com', 'USA', 'lager', 'can'),
  brandedPreset('carlsberg-pint', 'Carlsberg', 'Lager pint', 'pint', 568, .034, 'carlsberg.com', 'Denmark', 'lager', 'pint'),
  brandedPreset('carlsberg-can', 'Carlsberg', 'Lager can', 'can', 440, .034, 'carlsberg.com', 'Denmark', 'lager', 'can'),
  brandedPreset('carling-pint', 'Carling', 'Lager pint', 'pint', 568, .04, 'carling.com', 'England', 'lager', 'pint'),
  brandedPreset('carling-can', 'Carling', 'Lager can', 'can', 440, .04, 'carling.com', 'England', 'lager', 'can'),
  brandedPreset('san-miguel-pint', 'San Miguel', 'Lager pint', 'pint', 568, .05, 'sanmiguel.com', 'Spain', 'lager', 'pint'),
  brandedPreset('san-miguel-bottle', 'San Miguel', 'Lager bottle', 'bottle', 330, .05, 'sanmiguel.com', 'Spain', 'lager', 'bottle'),
  brandedPreset('amstel-pint', 'Amstel', 'Lager pint', 'pint', 568, .041, 'amstel.com', 'Netherlands', 'lager', 'pint'),
  brandedPreset('amstel-bottle', 'Amstel', 'Lager bottle', 'bottle', 330, .034, 'amstel.com', 'Netherlands', 'lager', 'bottle'),
  brandedPreset('cruzcampo-pint', 'Cruzcampo', 'Lager pint', 'pint', 568, .044, 'cruzcampo.es', 'Spain', 'lager', 'pint'),
  brandedPreset('cruzcampo-can', 'Cruzcampo', 'Lager can', 'can', 440, .044, 'cruzcampo.es', 'Spain', 'lager', 'can'),
  brandedPreset('camden-hells-pint', 'Camden Hells', 'Lager pint', 'pint', 568, .046, 'camdentownbrewery.com', 'England', 'lager', 'pint'),
  brandedPreset('camden-hells-can', 'Camden Hells', 'Lager can', 'can', 330, .046, 'camdentownbrewery.com', 'England', 'lager', 'can'),
  brandedPreset('estrella-pint', 'Estrella Damm', 'Lager pint', 'pint', 568, .046, 'estrelladamm.com', 'Spain', 'lager', 'pint'),
  brandedPreset('estrella-bottle', 'Estrella Damm', 'Lager bottle', 'bottle', 330, .046, 'estrelladamm.com', 'Spain', 'lager', 'bottle'),
  brandedPreset('red-stripe-pint', 'Red Stripe', 'Lager pint', 'pint', 568, .047, 'redstripebeer.com', 'Jamaica', 'lager', 'pint'),
  brandedPreset('red-stripe-can', 'Red Stripe', 'Lager can', 'can', 440, .047, 'redstripebeer.com', 'Jamaica', 'lager', 'can'),
  brandedPreset('pilsner-pint', 'Pilsner Urquell', 'Pilsner pint', 'pint', 568, .044, 'pilsnerurquell.com', 'Czechia', 'lager', 'pint'),
  brandedPreset('pilsner-bottle', 'Pilsner Urquell', 'Pilsner bottle', 'bottle', 330, .044, 'pilsnerurquell.com', 'Czechia', 'lager', 'bottle'),
  brandedPreset('tsingtao-pint', 'Tsingtao', 'Lager pint', 'pint', 568, .047, 'tsingtaobeer.com', 'China', 'lager', 'pint'),
  brandedPreset('tsingtao-bottle', 'Tsingtao', 'Lager bottle', 'bottle', 330, .047, 'tsingtaobeer.com', 'China', 'lager', 'bottle'),

  brandedPreset('neck-oil-pint', 'Neck Oil', 'Session IPA pint', 'ipa', 568, .043, 'beavertownbrewery.co.uk', 'England', 'ipa', 'pint'),
  brandedPreset('neck-oil-can', 'Neck Oil', 'Session IPA can', 'ipa', 330, .043, 'beavertownbrewery.co.uk', 'England', 'ipa', 'can'),
  brandedPreset('brewdog-punk-pint', 'BrewDog Punk IPA', 'IPA pint', 'ipa', 568, .054, 'brewdog.com', 'Scotland', 'ipa', 'pint'),
  brandedPreset('brewdog-punk', 'BrewDog Punk IPA', 'IPA can', 'ipa', 440, .054, 'brewdog.com', 'Scotland', 'ipa', 'can'),
  brandedPreset('hazy-jane-can', 'Hazy Jane', 'New England IPA can', 'ipa', 440, .05, 'brewdog.com', 'Scotland', 'ipa', 'can'),
  brandedPreset('doom-bar-pint', 'Doom Bar', 'Amber ale pint', 'ale', 568, .043, 'sharpbrewery.co.uk', 'England', 'ale', 'pint'),
  brandedPreset('london-pride-pint', 'London Pride', 'Ale pint', 'ale', 568, .041, 'fullersbrewery.co.uk', 'England', 'ale', 'pint'),
  brandedPreset('john-smiths-pint', "John Smith's", 'Extra Smooth pint', 'ale', 568, .034, 'johnsmiths.co.uk', 'England', 'ale', 'pint'),

  brandedPreset('strongbow-pint', 'Strongbow', 'Cider pint', 'cider', 568, .045, 'strongbow.com', 'England', 'cider', 'pint'),
  brandedPreset('strongbow-can', 'Strongbow', 'Cider can', 'cider', 440, .045, 'strongbow.com', 'England', 'cider', 'can'),
  brandedPreset('inchs-pint', "Inch's", 'Cider pint', 'cider', 568, .045, 'inchescider.co.uk', 'England', 'cider', 'pint'),
  brandedPreset('inchs-can', "Inch's", 'Cider can', 'cider', 440, .045, 'inchescider.co.uk', 'England', 'cider', 'can'),
  brandedPreset('thatchers-pint', 'Thatchers Gold', 'Cider pint', 'cider', 568, .048, 'thatcherscider.co.uk', 'England', 'cider', 'pint'),
  brandedPreset('thatchers-can', 'Thatchers Gold', 'Cider can', 'cider', 440, .048, 'thatcherscider.co.uk', 'England', 'cider', 'can'),
  brandedPreset('magners-pint', 'Magners', 'Cider pint', 'cider', 568, .045, 'magners.com', 'Ireland', 'cider', 'pint'),
  brandedPreset('magners-bottle', 'Magners', 'Cider bottle', 'cider', 568, .045, 'magners.com', 'Ireland', 'cider', 'bottle'),
  brandedPreset('old-mout-bottle', 'Old Mout', 'Fruit cider bottle', 'cider', 500, .04, 'oldmoutcider.co.uk', 'New Zealand', 'cider', 'bottle'),
  brandedPreset('rekorderlig-bottle', 'Rekorderlig', 'Fruit cider bottle', 'cider', 500, .04, 'rekorderlig.com', 'Sweden', 'cider', 'bottle'),
  brandedPreset('kopparberg-bottle', 'Kopparberg', 'Fruit cider bottle', 'cider', 500, .04, 'kopparberg.co.uk', 'Sweden', 'cider', 'bottle'),

  preset('gin-tonic', 'Gin & tonic', 'cocktail', 'cocktail', 200, .05, 36, 'cocktail', 'cocktail'),
  preset('mojito', 'Mojito', 'cocktail', 'cocktail', 200, .12, 36, 'cocktail', 'cocktail'),
  preset('pornstar-martini', 'Pornstar Martini', 'cocktail', 'cocktail', 180, .14, 36, 'cocktail', 'cocktail'),
  preset('espresso-martini', 'Espresso Martini', 'cocktail', 'cocktail', 150, .16, 36, 'cocktail', 'cocktail'),
  preset('aperol-spritz', 'Aperol Spritz', 'cocktail', 'cocktail', 200, .09, 36, 'cocktail', 'cocktail'),
  preset('long-island', 'Long Island Iced Tea', 'cocktail', 'cocktail', 250, .18, 36, 'cocktail', 'cocktail'),
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
    style: p.style,
    serve: p.serve,
    country: p.country,
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
    maxBac: 0.025,
  },
  buzz: {
    id: 'buzz',
    label: 'Buzzing',
    emoji: '😏',
    tagline: 'Chatty, confident, absolutely staying out.',
    minBac: 0.025,
    maxBac: 0.04,
  },
  wavy: {
    id: 'wavy',
    label: 'Wavy',
    emoji: '🌊',
    tagline: 'The playlist has become a personal statement.',
    minBac: 0.04,
    maxBac: 0.055,
  },
  tipsy: {
    id: 'tipsy',
    label: 'Pissed',
    emoji: '😄',
    tagline: 'Volume up. Decisions increasingly freelance.',
    minBac: 0.055,
    maxBac: 0.07,
  },
  smashed: {
    id: 'smashed',
    label: 'Smashed',
    emoji: '🫨',
    tagline: 'Every story now needs a second witness.',
    minBac: 0.07,
    maxBac: 0.085,
  },
  merry: {
    id: 'merry',
    label: 'Battered',
    emoji: '🥴',
    tagline: 'Operating mostly on confidence and vibes.',
    minBac: 0.085,
    maxBac: 0.1,
  },
  bignight: {
    id: 'bignight',
    label: 'Blackout',
    emoji: '🫠',
    tagline: 'Tomorrow gets the patch notes.',
    minBac: 0.1,
    maxBac: 0.12,
  },
}

export const TARGET_ORDER: TargetId[] = ['glow', 'buzz', 'wavy', 'tipsy', 'smashed', 'merry', 'bignight']

export function targetLabel(id: TargetId, labels?: Partial<Record<TargetId, string>>): string {
  return labels?.[id]?.trim() || TARGETS[id].label
}
