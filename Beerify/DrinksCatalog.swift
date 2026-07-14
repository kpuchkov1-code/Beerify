//
//  DrinksCatalog.swift
//  Beerify
//
//  Static catalog of the four drink types and five target zones.
//

import Foundation

private let ETHANOL_DENSITY = 0.789
private let UK_UNIT_GRAMS = 8.0

enum DrinksCatalog {
    static let types: [DrinkTypeId: DrinkType] = [
        .beer: DrinkType(
            id: .beer, label: "Beer", emoji: "🍺",
            volumeMl: 500, abv: 0.05, absorptionMin: 35, detail: "500ml · 5%"),
        .shot: DrinkType(
            id: .shot, label: "Shot", emoji: "🥃",
            volumeMl: 40, abv: 0.4, absorptionMin: 15, detail: "40ml · 40%"),
        .wine: DrinkType(
            id: .wine, label: "Wine", emoji: "🍷",
            volumeMl: 175, abv: 0.13, absorptionMin: 30, detail: "175ml · 13%"),
        .cocktail: DrinkType(
            id: .cocktail, label: "Cocktail", emoji: "🍹",
            volumeMl: 200, abv: 0.14, absorptionMin: 30, detail: "~2 shots mixed"),
    ]

    static let tapOrder: [DrinkTypeId] = [.beer, .shot, .wine, .cocktail]

    static func gramsOfAlcohol(_ t: DrinkType) -> Double {
        t.volumeMl * t.abv * ETHANOL_DENSITY
    }

    static func unitsOfAlcohol(_ t: DrinkType) -> Double {
        gramsOfAlcohol(t) / UK_UNIT_GRAMS
    }

    // MARK: - Drink Variants

    /// All available drink variants, grouped by base type.
    static let allVariants: [DrinkVariant] = [
        // Beers
        DrinkVariant(id: "pint",        label: "Pint",           emoji: "🍺", baseType: .beer),
        DrinkVariant(id: "heineken",    label: "Heineken",       emoji: "🍺", baseType: .beer),
        DrinkVariant(id: "guinness",    label: "Guinness",       emoji: "🍺", baseType: .beer),
        DrinkVariant(id: "corona",      label: "Corona",         emoji: "🍺", baseType: .beer),
        DrinkVariant(id: "stella",      label: "Stella Artois",  emoji: "🍺", baseType: .beer),
        DrinkVariant(id: "ipa",         label: "IPA",            emoji: "🍺", baseType: .beer,
                     customAbv: 0.065, customDetail: "500ml · 6.5%"),
        DrinkVariant(id: "cider",       label: "Cider",          emoji: "🍎", baseType: .beer,
                     customAbv: 0.045, customDetail: "500ml · 4.5%"),
        DrinkVariant(id: "budweiser",   label: "Budweiser",      emoji: "🍺", baseType: .beer),
        DrinkVariant(id: "peroni",      label: "Peroni",         emoji: "🍺", baseType: .beer,
                     customAbv: 0.052, customDetail: "500ml · 5.2%"),
        DrinkVariant(id: "carlsberg",   label: "Carlsberg",      emoji: "🍺", baseType: .beer,
                     customAbv: 0.05, customDetail: "500ml · 5%"),
        DrinkVariant(id: "becks",       label: "Beck's",         emoji: "🍺", baseType: .beer),
        DrinkVariant(id: "moretti",     label: "Birra Moretti",  emoji: "🍺", baseType: .beer,
                     customAbv: 0.046, customDetail: "500ml · 4.6%"),
        DrinkVariant(id: "asahi",       label: "Asahi",          emoji: "🍺", baseType: .beer,
                     customAbv: 0.052, customDetail: "500ml · 5.2%"),
        DrinkVariant(id: "sapporo",     label: "Sapporo",        emoji: "🍺", baseType: .beer),
        DrinkVariant(id: "amstel",      label: "Amstel",         emoji: "🍺", baseType: .beer),
        DrinkVariant(id: "modelo",      label: "Modelo",         emoji: "🍺", baseType: .beer,
                     customAbv: 0.045, customDetail: "500ml · 4.5%"),
        DrinkVariant(id: "blue-moon",   label: "Blue Moon",      emoji: "🍺", baseType: .beer,
                     customAbv: 0.054, customDetail: "500ml · 5.4%"),
        DrinkVariant(id: "fosters",     label: "Foster's",       emoji: "🍺", baseType: .beer,
                     customAbv: 0.04, customDetail: "500ml · 4%"),
        DrinkVariant(id: "stout",       label: "Stout",          emoji: "🍺", baseType: .beer,
                     customAbv: 0.055, customDetail: "500ml · 5.5%"),
        DrinkVariant(id: "pale-ale",    label: "Pale Ale",       emoji: "🍺", baseType: .beer,
                     customAbv: 0.05, customDetail: "500ml · 5%"),
        DrinkVariant(id: "lager",       label: "Lager",          emoji: "🍺", baseType: .beer),
        DrinkVariant(id: "wheat-beer",  label: "Wheat Beer",     emoji: "🍺", baseType: .beer,
                     customAbv: 0.052, customDetail: "500ml · 5.2%"),

        // Shots
        DrinkVariant(id: "shot",        label: "Shot",           emoji: "🥃", baseType: .shot),
        DrinkVariant(id: "jager",       label: "Jagermeister",   emoji: "🦌", baseType: .shot,
                     customAbv: 0.35, customDetail: "40ml · 35%"),
        DrinkVariant(id: "tequila",     label: "Tequila",        emoji: "🌵", baseType: .shot),
        DrinkVariant(id: "vodka",       label: "Vodka",          emoji: "🧊", baseType: .shot),
        DrinkVariant(id: "whiskey",     label: "Whiskey",        emoji: "🥃", baseType: .shot),
        DrinkVariant(id: "sambuca",     label: "Sambuca",        emoji: "⭐", baseType: .shot,
                     customAbv: 0.38, customDetail: "40ml · 38%"),
        DrinkVariant(id: "rum",         label: "Rum",            emoji: "🥃", baseType: .shot),
        DrinkVariant(id: "fireball",    label: "Fireball",       emoji: "🔥", baseType: .shot,
                     customAbv: 0.33, customDetail: "40ml · 33%"),
        DrinkVariant(id: "absinthe",    label: "Absinthe",       emoji: "🧪", baseType: .shot,
                     customVolumeMl: 30, customAbv: 0.55, customDetail: "30ml · 55%"),
        DrinkVariant(id: "baileys",     label: "Baileys",        emoji: "🥛", baseType: .shot,
                     customVolumeMl: 50, customAbv: 0.17, customDetail: "50ml · 17%"),
        DrinkVariant(id: "limoncello",  label: "Limoncello",     emoji: "🍋", baseType: .shot,
                     customAbv: 0.28, customDetail: "40ml · 28%"),
        DrinkVariant(id: "disaronno",   label: "Disaronno",      emoji: "🥃", baseType: .shot,
                     customAbv: 0.28, customDetail: "40ml · 28%"),
        DrinkVariant(id: "patron",      label: "Patron",         emoji: "🌵", baseType: .shot),
        DrinkVariant(id: "bourbon",     label: "Bourbon",        emoji: "🥃", baseType: .shot,
                     customAbv: 0.45, customDetail: "40ml · 45%"),
        DrinkVariant(id: "schnapps",    label: "Schnapps",       emoji: "🍑", baseType: .shot,
                     customAbv: 0.20, customDetail: "40ml · 20%"),

        // Wine
        DrinkVariant(id: "red-wine",    label: "Red Wine",       emoji: "🍷", baseType: .wine),
        DrinkVariant(id: "white-wine",  label: "White Wine",     emoji: "🥂", baseType: .wine),
        DrinkVariant(id: "rose",        label: "Rose",           emoji: "🌸", baseType: .wine,
                     customAbv: 0.115, customDetail: "175ml · 11.5%"),
        DrinkVariant(id: "prosecco",    label: "Prosecco",       emoji: "🥂", baseType: .wine,
                     customAbv: 0.11, customDetail: "175ml · 11%"),
        DrinkVariant(id: "champagne",   label: "Champagne",      emoji: "🍾", baseType: .wine,
                     customAbv: 0.12, customDetail: "175ml · 12%"),
        DrinkVariant(id: "pinot-grigio",label: "Pinot Grigio",   emoji: "🥂", baseType: .wine,
                     customAbv: 0.125, customDetail: "175ml · 12.5%"),
        DrinkVariant(id: "malbec",      label: "Malbec",         emoji: "🍷", baseType: .wine,
                     customAbv: 0.14, customDetail: "175ml · 14%"),
        DrinkVariant(id: "sauvignon",   label: "Sauvignon Blanc",emoji: "🥂", baseType: .wine,
                     customAbv: 0.125, customDetail: "175ml · 12.5%"),
        DrinkVariant(id: "port",        label: "Port",           emoji: "🍷", baseType: .wine,
                     customVolumeMl: 75, customAbv: 0.20, customDetail: "75ml · 20%"),
        DrinkVariant(id: "mulled-wine", label: "Mulled Wine",    emoji: "🍷", baseType: .wine,
                     customVolumeMl: 200, customAbv: 0.10, customDetail: "200ml · 10%"),
        DrinkVariant(id: "cava",        label: "Cava",           emoji: "🥂", baseType: .wine,
                     customAbv: 0.115, customDetail: "175ml · 11.5%"),

        // Cocktails
        DrinkVariant(id: "cocktail",        label: "Cocktail",         emoji: "🍹", baseType: .cocktail),
        DrinkVariant(id: "margarita",       label: "Margarita",        emoji: "🍋", baseType: .cocktail),
        DrinkVariant(id: "mojito",          label: "Mojito",           emoji: "🌿", baseType: .cocktail,
                     customAbv: 0.10, customDetail: "~1.5 shots mixed"),
        DrinkVariant(id: "long-island",     label: "Long Island",      emoji: "🏝️", baseType: .cocktail,
                     customAbv: 0.22, customDetail: "~4 shots mixed"),
        DrinkVariant(id: "gin-tonic",       label: "G&T",              emoji: "🫧", baseType: .cocktail,
                     customAbv: 0.10, customDetail: "~1.5 shots mixed"),
        DrinkVariant(id: "espresso-martini",label: "Espresso Martini", emoji: "☕", baseType: .cocktail),
        DrinkVariant(id: "aperol-spritz",   label: "Aperol Spritz",    emoji: "🍊", baseType: .cocktail,
                     customAbv: 0.08, customDetail: "~1 shot mixed"),
        DrinkVariant(id: "pina-colada",     label: "Pina Colada",      emoji: "🍹", baseType: .cocktail,
                     customAbv: 0.12, customDetail: "~2 shots mixed"),
        DrinkVariant(id: "cosmopolitan",    label: "Cosmopolitan",     emoji: "🍸", baseType: .cocktail),
        DrinkVariant(id: "old-fashioned",   label: "Old Fashioned",    emoji: "🥃", baseType: .cocktail,
                     customVolumeMl: 100, customAbv: 0.30, customDetail: "~2 shots stirred"),
        DrinkVariant(id: "negroni",         label: "Negroni",          emoji: "🍸", baseType: .cocktail,
                     customVolumeMl: 100, customAbv: 0.24, customDetail: "~2 shots stirred"),
        DrinkVariant(id: "daiquiri",        label: "Daiquiri",         emoji: "🍹", baseType: .cocktail),
        DrinkVariant(id: "manhattan",       label: "Manhattan",        emoji: "🍸", baseType: .cocktail,
                     customVolumeMl: 100, customAbv: 0.28, customDetail: "~2 shots stirred"),
        DrinkVariant(id: "whiskey-sour",    label: "Whiskey Sour",     emoji: "🍋", baseType: .cocktail,
                     customAbv: 0.15, customDetail: "~1.5 shots mixed"),
        DrinkVariant(id: "dark-stormy",     label: "Dark & Stormy",    emoji: "🌊", baseType: .cocktail,
                     customAbv: 0.12, customDetail: "~1.5 shots mixed"),
        DrinkVariant(id: "moscow-mule",     label: "Moscow Mule",      emoji: "🫚", baseType: .cocktail,
                     customAbv: 0.10, customDetail: "~1.5 shots mixed"),
        DrinkVariant(id: "sangria",         label: "Sangria",          emoji: "🍷", baseType: .cocktail,
                     customAbv: 0.08, customDetail: "~1 shot mixed"),
        DrinkVariant(id: "tequila-sunrise", label: "Tequila Sunrise",  emoji: "🌅", baseType: .cocktail,
                     customAbv: 0.11, customDetail: "~1.5 shots mixed"),
        DrinkVariant(id: "sex-on-beach",    label: "Sex on the Beach", emoji: "🏖️", baseType: .cocktail,
                     customAbv: 0.12, customDetail: "~2 shots mixed"),
        DrinkVariant(id: "irish-coffee",    label: "Irish Coffee",     emoji: "☕", baseType: .cocktail,
                     customAbv: 0.10, customDetail: "~1 shot mixed"),
    ]

    static let variantsByCategory: [(label: String, variants: [DrinkVariant])] = {
        let cats: [(String, DrinkTypeId)] = [("Beers", .beer), ("Shots", .shot), ("Wine", .wine), ("Cocktails", .cocktail)]
        return cats.map { (label, typeId) in
            (label: label, variants: allVariants.filter { $0.baseType == typeId })
        }
    }()

    static let variantMap: [String: DrinkVariant] = {
        Dictionary(uniqueKeysWithValues: allVariants.map { ($0.id, $0) })
    }()

    /// The four classic drink IDs used as defaults when the user hasn't picked yet.
    static let defaultVariantIds: Set<String> = ["pint", "shot", "red-wine", "cocktail"]

    /// Build an effective DrinkType for a variant, applying any custom overrides.
    static func effectiveType(for variant: DrinkVariant) -> DrinkType {
        let base = types[variant.baseType]!
        return DrinkType(
            id: variant.baseType,
            label: variant.label,
            emoji: variant.emoji,
            volumeMl: variant.customVolumeMl ?? base.volumeMl,
            abv: variant.customAbv ?? base.abv,
            absorptionMin: base.absorptionMin,
            detail: variant.customDetail ?? base.detail
        )
    }
}

enum TargetsCatalog {
    static let all: [TargetId: Target] = [
        .glow: Target(
            id: .glow, label: "Light glow", emoji: "🙂",
            tagline: "Relaxed and clear-headed. One or two, tops.",
            minBac: 0.01, maxBac: 0.03, warning: nil),
        .buzz: Target(
            id: .buzz, label: "Gentle buzz", emoji: "😊",
            tagline: "Warm, chatty, fully in control.",
            minBac: 0.03, maxBac: 0.05, warning: nil),
        .tipsy: Target(
            id: .tipsy, label: "Happily tipsy", emoji: "😄",
            tagline: "Giggly and glowing, dance-floor ready.",
            minBac: 0.05, maxBac: 0.07, warning: nil),
        .merry: Target(
            id: .merry, label: "Properly merry", emoji: "🥳",
            tagline: "Loud laughs and bold dance moves.",
            minBac: 0.07, maxBac: 0.09,
            warning: "Above this point the fun drops off fast. Beerify will keep you honest."),
        .bignight: Target(
            id: .bignight, label: "Big night", emoji: "🤪",
            tagline: "The stories-for-years zone. Handle with care.",
            minBac: 0.09, maxBac: 0.11,
            warning: "This is a lot. Expect a rough morning. Eat well, drink water between rounds, and stay with friends."),
    ]

    static let order: [TargetId] = [.glow, .buzz, .tipsy, .merry, .bignight]

    static func target(_ id: TargetId) -> Target {
        all[id] ?? all[.tipsy]!
    }
}
