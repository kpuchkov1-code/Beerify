//
//  DrinkIconView.swift
//  Beerify
//
//  Cartoonish hand-drawn-style drink icons, one per variant.
//  Each icon is built from SwiftUI shapes with brand-inspired palettes.
//

import SwiftUI

struct DrinkIconView: View {
    let variantId: String
    var size: CGFloat = 56

    var body: some View {
        icon
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private var icon: some View {
        switch variantId {
        // MARK: - Beers
        case "pint":        PintGlassIcon(fill: .pintGold, foam: .white, size: size)
        case "heineken":    BottleIcon(fill: .heinekenGreen, labelColor: .heinekenStar, capColor: .heinekenGreen, size: size)
        case "guinness":    PintGlassIcon(fill: .guinnessDark, foam: .guinnessCream, size: size)
        case "corona":      BottleIcon(fill: .coronaYellow, labelColor: .white, capColor: .coronaBlue, size: size, hasLime: true)
        case "stella":      ChaliceIcon(fill: .stellaGold, rimColor: .stellaRim, size: size)
        case "ipa":         PintGlassIcon(fill: .ipaAmber, foam: .ipaFoam, size: size)
        case "cider":       BottleIcon(fill: .ciderGreen, labelColor: .ciderRed, capColor: .ciderGreen, size: size, hasApple: true)
        case "budweiser":   BottleIcon(fill: .budRed, labelColor: .white, capColor: .budRed, size: size)
        case "peroni":      BottleIcon(fill: .peroniBlue, labelColor: .peroniGold, capColor: .peroniBlue, size: size)
        case "carlsberg":   BottleIcon(fill: .carlsbergGreen, labelColor: .white, capColor: .carlsbergGreen, size: size)
        case "becks":       BottleIcon(fill: .becksGreen, labelColor: .becksRed, capColor: .becksGreen, size: size)
        case "moretti":     BottleIcon(fill: .morettiGold, labelColor: .morettiGreen, capColor: .morettiGold, size: size)
        case "asahi":       BottleIcon(fill: .asahiSilver, labelColor: .asahiBlue, capColor: .asahiSilver, size: size)
        case "sapporo":     CanIcon(fill: .sapporoGold, labelColor: .sapporoDark, size: size)
        case "amstel":      BottleIcon(fill: .amstelGreen, labelColor: .amstelRed, capColor: .amstelGreen, size: size)
        case "modelo":      BottleIcon(fill: .modeloGold, labelColor: .modeloBlue, capColor: .modeloGold, size: size)
        case "blue-moon":   PintGlassIcon(fill: .blueMoonBlue, foam: .white, size: size)
        case "fosters":     CanIcon(fill: .fostersBlue, labelColor: .fostersGold, size: size)
        case "stout":       PintGlassIcon(fill: .guinnessDark, foam: .white, size: size)
        case "pale-ale":    PintGlassIcon(fill: .paleAleGold, foam: .ipaFoam, size: size)
        case "lager":       PintGlassIcon(fill: .lagerLight, foam: .white, size: size)
        case "wheat-beer":  PintGlassIcon(fill: .wheatBeerGold, foam: .guinnessCream, size: size)

        // MARK: - Shots
        case "shot":        ShotGlassIcon(fill: .shotAmber, size: size)
        case "jager":       JagerBottleIcon(size: size)
        case "tequila":     ShotGlassIcon(fill: .tequilaClear, size: size, hasLime: true)
        case "vodka":       TallBottleIcon(fill: .vodkaClear, labelColor: .vodkaBlue, capColor: .vodkaSilver, size: size)
        case "whiskey":     WhiskeyGlassIcon(size: size)
        case "sambuca":     ShotGlassIcon(fill: .sambucaClear, size: size, hasFlame: true)
        case "rum":         TallBottleIcon(fill: .rumBrown, labelColor: .rumGold, capColor: .rumBrown, size: size)
        case "fireball":    ShotGlassIcon(fill: .fireballRed, size: size, hasFlame: true)
        case "absinthe":    TallBottleIcon(fill: .absintheGreen, labelColor: .absintheDark, capColor: .absintheGreen, size: size)
        case "baileys":     ShotGlassIcon(fill: .baileysCream, size: size)
        case "limoncello":  ShotGlassIcon(fill: .limoncelloYellow, size: size)
        case "disaronno":   ShotGlassIcon(fill: .disaronnoAmber, size: size)
        case "patron":      TallBottleIcon(fill: .patronClear, labelColor: .patronGold, capColor: .patronClear, size: size)
        case "bourbon":     WhiskeyGlassIcon(size: size)
        case "schnapps":    ShotGlassIcon(fill: .schnappsPeach, size: size)

        // MARK: - Wine
        case "red-wine":    WineGlassIcon(fill: .redWine, size: size)
        case "white-wine":  WineGlassIcon(fill: .whiteWine, size: size)
        case "rose":        WineGlassIcon(fill: .roseWine, size: size)
        case "prosecco":    FluteIcon(fill: .proseccoGold, size: size, hasBubbles: true)
        case "champagne":   FluteIcon(fill: .champagneGold, size: size, hasBubbles: true)
        case "pinot-grigio":WineGlassIcon(fill: .pinotGrigio, size: size)
        case "malbec":      WineGlassIcon(fill: .malbecDark, size: size)
        case "sauvignon":   WineGlassIcon(fill: .sauvignonPale, size: size)
        case "port":        PortGlassIcon(size: size)
        case "mulled-wine": MulledWineIcon(size: size)
        case "cava":        FluteIcon(fill: .cavaGold, size: size, hasBubbles: true)

        // MARK: - Cocktails
        case "cocktail":    TropicalGlassIcon(size: size)
        case "margarita":   MargaritaGlassIcon(size: size)
        case "mojito":      MojitoGlassIcon(size: size)
        case "long-island": LongIslandIcon(size: size)
        case "gin-tonic":   BalloonGlassIcon(size: size)
        case "espresso-martini": EspressoMartiniIcon(size: size)
        case "aperol-spritz":    AperolSpritzIcon(size: size)
        case "pina-colada":      PinaColadaIcon(size: size)
        case "cosmopolitan":     CosmoIcon(size: size)
        case "old-fashioned":    OldFashionedIcon(size: size)
        case "negroni":          NegroniIcon(size: size)
        case "daiquiri":         DaiquiriIcon(size: size)
        case "manhattan":        ManhattanIcon(size: size)
        case "whiskey-sour":     WhiskeySourIcon(size: size)
        case "dark-stormy":      DarkStormyIcon(size: size)
        case "moscow-mule":      MoscowMuleIcon(size: size)
        case "sangria":          SangriaIcon(size: size)
        case "tequila-sunrise":  TequilaSunriseIcon(size: size)
        case "sex-on-beach":     SexOnBeachIcon(size: size)
        case "irish-coffee":     IrishCoffeeIcon(size: size)

        default:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .overlay(Text("?").font(.title2).foregroundStyle(.secondary))
        }
    }
}

// MARK: - Color Palette

private extension Color {
    // Beers
    static let pintGold = Color(red: 0.90, green: 0.70, blue: 0.20)
    static let heinekenGreen = Color(red: 0.0, green: 0.45, blue: 0.20)
    static let heinekenStar = Color(red: 0.85, green: 0.15, blue: 0.15)
    static let guinnessDark = Color(red: 0.12, green: 0.08, blue: 0.06)
    static let guinnessCream = Color(red: 0.96, green: 0.93, blue: 0.85)
    static let coronaYellow = Color(red: 0.98, green: 0.88, blue: 0.30)
    static let coronaBlue = Color(red: 0.10, green: 0.20, blue: 0.55)
    static let stellaGold = Color(red: 0.85, green: 0.68, blue: 0.22)
    static let stellaRim = Color(red: 0.75, green: 0.58, blue: 0.12)
    static let ipaAmber = Color(red: 0.82, green: 0.52, blue: 0.12)
    static let ipaFoam = Color(red: 1.0, green: 0.97, blue: 0.88)
    static let ciderGreen = Color(red: 0.30, green: 0.62, blue: 0.18)
    static let ciderRed = Color(red: 0.82, green: 0.18, blue: 0.15)
    static let budRed = Color(red: 0.75, green: 0.12, blue: 0.12)
    static let peroniBlue = Color(red: 0.10, green: 0.22, blue: 0.52)
    static let peroniGold = Color(red: 0.85, green: 0.72, blue: 0.25)
    static let carlsbergGreen = Color(red: 0.08, green: 0.42, blue: 0.22)
    static let becksGreen = Color(red: 0.15, green: 0.48, blue: 0.18)
    static let becksRed = Color(red: 0.80, green: 0.20, blue: 0.15)
    static let morettiGold = Color(red: 0.82, green: 0.62, blue: 0.15)
    static let morettiGreen = Color(red: 0.18, green: 0.40, blue: 0.15)
    static let asahiSilver = Color(red: 0.82, green: 0.84, blue: 0.86)
    static let asahiBlue = Color(red: 0.12, green: 0.18, blue: 0.42)
    static let sapporoGold = Color(red: 0.85, green: 0.72, blue: 0.20)
    static let sapporoDark = Color(red: 0.15, green: 0.12, blue: 0.10)
    static let amstelGreen = Color(red: 0.05, green: 0.38, blue: 0.15)
    static let amstelRed = Color(red: 0.78, green: 0.15, blue: 0.12)
    static let modeloGold = Color(red: 0.88, green: 0.75, blue: 0.25)
    static let modeloBlue = Color(red: 0.12, green: 0.20, blue: 0.48)
    static let blueMoonBlue = Color(red: 0.35, green: 0.52, blue: 0.78)
    static let fostersBlue = Color(red: 0.10, green: 0.25, blue: 0.55)
    static let fostersGold = Color(red: 0.88, green: 0.72, blue: 0.18)
    static let paleAleGold = Color(red: 0.88, green: 0.65, blue: 0.18)
    static let lagerLight = Color(red: 0.95, green: 0.82, blue: 0.30)
    static let wheatBeerGold = Color(red: 0.92, green: 0.75, blue: 0.28)

    // Shots
    static let shotAmber = Color(red: 0.80, green: 0.55, blue: 0.15)
    static let tequilaClear = Color(red: 0.95, green: 0.95, blue: 0.85)
    static let vodkaClear = Color(red: 0.88, green: 0.92, blue: 0.96)
    static let vodkaBlue = Color(red: 0.15, green: 0.30, blue: 0.65)
    static let vodkaSilver = Color(red: 0.75, green: 0.78, blue: 0.82)
    static let sambucaClear = Color(red: 0.92, green: 0.92, blue: 0.95)
    static let rumBrown = Color(red: 0.40, green: 0.22, blue: 0.08)
    static let rumGold = Color(red: 0.85, green: 0.68, blue: 0.20)
    static let fireballRed = Color(red: 0.88, green: 0.28, blue: 0.12)
    static let absintheGreen = Color(red: 0.32, green: 0.65, blue: 0.25)
    static let absintheDark = Color(red: 0.15, green: 0.30, blue: 0.12)
    static let baileysCream = Color(red: 0.85, green: 0.75, blue: 0.60)
    static let limoncelloYellow = Color(red: 0.95, green: 0.90, blue: 0.30)
    static let disaronnoAmber = Color(red: 0.82, green: 0.52, blue: 0.15)
    static let patronClear = Color(red: 0.90, green: 0.92, blue: 0.88)
    static let patronGold = Color(red: 0.82, green: 0.68, blue: 0.22)
    static let schnappsPeach = Color(red: 0.95, green: 0.72, blue: 0.52)

    // Wine
    static let redWine = Color(red: 0.55, green: 0.05, blue: 0.12)
    static let whiteWine = Color(red: 0.95, green: 0.92, blue: 0.65)
    static let roseWine = Color(red: 0.92, green: 0.55, blue: 0.62)
    static let proseccoGold = Color(red: 0.92, green: 0.85, blue: 0.55)
    static let champagneGold = Color(red: 0.95, green: 0.82, blue: 0.35)
    static let pinotGrigio = Color(red: 0.90, green: 0.88, blue: 0.70)
    static let malbecDark = Color(red: 0.40, green: 0.02, blue: 0.10)
    static let sauvignonPale = Color(red: 0.92, green: 0.95, blue: 0.72)
    static let portRuby = Color(red: 0.55, green: 0.08, blue: 0.18)
    static let mulledRed = Color(red: 0.62, green: 0.12, blue: 0.10)
    static let cavaGold = Color(red: 0.90, green: 0.82, blue: 0.48)

    // Cocktails
    static let mojitGreen = Color(red: 0.30, green: 0.72, blue: 0.35)
    static let aperolOrange = Color(red: 0.95, green: 0.45, blue: 0.12)
    static let espressoBrown = Color(red: 0.25, green: 0.15, blue: 0.10)
    static let margaritaLime = Color(red: 0.65, green: 0.82, blue: 0.15)
    static let longIslandAmber = Color(red: 0.75, green: 0.50, blue: 0.15)
    static let ginTonic = Color(red: 0.80, green: 0.92, blue: 0.95)
    static let pinaYellow = Color(red: 0.98, green: 0.92, blue: 0.55)
    static let cosmoPink = Color(red: 0.92, green: 0.30, blue: 0.48)
    static let oldFashionedAmber = Color(red: 0.78, green: 0.48, blue: 0.12)
    static let negroniRed = Color(red: 0.82, green: 0.22, blue: 0.15)
    static let daiquiriPink = Color(red: 0.95, green: 0.55, blue: 0.62)
    static let manhattanCherry = Color(red: 0.68, green: 0.12, blue: 0.15)
    static let whiskeySourGold = Color(red: 0.92, green: 0.78, blue: 0.28)
    static let darkStormyBrown = Color(red: 0.30, green: 0.18, blue: 0.10)
    static let muleCopper = Color(red: 0.82, green: 0.52, blue: 0.25)
    static let sangriaWine = Color(red: 0.65, green: 0.12, blue: 0.18)
    static let sunriseOrange = Color(red: 0.98, green: 0.60, blue: 0.15)
    static let sunriseRed = Color(red: 0.92, green: 0.25, blue: 0.18)
    static let beachPeach = Color(red: 0.95, green: 0.60, blue: 0.35)
    static let irishCreamBrown = Color(red: 0.45, green: 0.28, blue: 0.15)
}

// MARK: - Beer Icons

private struct PintGlassIcon: View {
    let fill: Color
    let foam: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            // Glass body
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 6,
                bottomTrailingRadius: 6, topTrailingRadius: 2
            )
            .fill(fill.gradient)
            .frame(width: size * 0.48, height: size * 0.62)
            .offset(y: size * 0.06)

            // Foam top
            Capsule()
                .fill(foam)
                .frame(width: size * 0.52, height: size * 0.18)
                .offset(y: -size * 0.22)
                .shadow(color: fill.opacity(0.3), radius: 2, y: 2)

            // Glass shine
            RoundedRectangle(cornerRadius: 2)
                .fill(.white.opacity(0.35))
                .frame(width: size * 0.08, height: size * 0.35)
                .offset(x: -size * 0.12, y: size * 0.05)

            // Glass outline
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 6,
                bottomTrailingRadius: 6, topTrailingRadius: 2
            )
            .stroke(fill.opacity(0.5), lineWidth: 1.5)
            .frame(width: size * 0.48, height: size * 0.62)
            .offset(y: size * 0.06)
        }
    }
}

private struct BottleIcon: View {
    let fill: Color
    let labelColor: Color
    let capColor: Color
    let size: CGFloat
    var hasLime: Bool = false
    var hasApple: Bool = false

    var body: some View {
        ZStack {
            // Bottle body
            VStack(spacing: 0) {
                // Neck
                RoundedRectangle(cornerRadius: 2)
                    .fill(fill.gradient)
                    .frame(width: size * 0.14, height: size * 0.22)

                // Shoulder + body
                UnevenRoundedRectangle(
                    topLeadingRadius: 4, bottomLeadingRadius: 4,
                    bottomTrailingRadius: 4, topTrailingRadius: 4
                )
                .fill(fill.gradient)
                .frame(width: size * 0.36, height: size * 0.48)
            }
            .offset(y: size * 0.02)

            // Cap
            RoundedRectangle(cornerRadius: 2)
                .fill(capColor)
                .frame(width: size * 0.16, height: size * 0.06)
                .offset(y: -size * 0.33)

            // Label
            RoundedRectangle(cornerRadius: 3)
                .fill(labelColor.opacity(0.85))
                .frame(width: size * 0.26, height: size * 0.16)
                .offset(y: size * 0.14)

            // Shine
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.25))
                .frame(width: size * 0.05, height: size * 0.30)
                .offset(x: -size * 0.10, y: size * 0.08)

            if hasLime {
                Circle()
                    .fill(Color(red: 0.45, green: 0.75, blue: 0.15))
                    .frame(width: size * 0.18, height: size * 0.18)
                    .offset(x: size * 0.18, y: -size * 0.18)
                    .overlay(
                        Circle()
                            .fill(Color(red: 0.65, green: 0.88, blue: 0.30))
                            .frame(width: size * 0.10)
                            .offset(x: size * 0.18, y: -size * 0.18)
                    )
            }

            if hasApple {
                Circle()
                    .fill(Color.ciderRed)
                    .frame(width: size * 0.18, height: size * 0.18)
                    .offset(x: size * 0.20, y: -size * 0.20)
                    .overlay(
                        // Leaf
                        Ellipse()
                            .fill(Color.ciderGreen)
                            .frame(width: size * 0.08, height: size * 0.05)
                            .offset(x: size * 0.20, y: -size * 0.28)
                    )
            }
        }
    }
}

private struct ChaliceIcon: View {
    let fill: Color
    let rimColor: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            // Bowl
            Ellipse()
                .fill(fill.gradient)
                .frame(width: size * 0.50, height: size * 0.42)
                .offset(y: -size * 0.06)

            // Rim highlight
            Ellipse()
                .stroke(rimColor, lineWidth: 2)
                .frame(width: size * 0.50, height: size * 0.12)
                .offset(y: -size * 0.24)

            // Stem
            RoundedRectangle(cornerRadius: 2)
                .fill(rimColor.gradient)
                .frame(width: size * 0.08, height: size * 0.18)
                .offset(y: size * 0.20)

            // Base
            Capsule()
                .fill(rimColor.gradient)
                .frame(width: size * 0.30, height: size * 0.08)
                .offset(y: size * 0.32)

            // Foam
            Capsule()
                .fill(.white.opacity(0.8))
                .frame(width: size * 0.44, height: size * 0.10)
                .offset(y: -size * 0.22)

            // Shine
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.30))
                .frame(width: size * 0.06, height: size * 0.20)
                .offset(x: -size * 0.14, y: -size * 0.06)
        }
    }
}

// MARK: - Shot Icons

private struct ShotGlassIcon: View {
    let fill: Color
    let size: CGFloat
    var hasLime: Bool = false
    var hasFlame: Bool = false

    var body: some View {
        ZStack {
            // Glass
            UnevenRoundedRectangle(
                topLeadingRadius: 1, bottomLeadingRadius: 4,
                bottomTrailingRadius: 4, topTrailingRadius: 1
            )
            .fill(fill.gradient)
            .frame(width: size * 0.34, height: size * 0.38)
            .offset(y: size * 0.10)

            // Glass outline
            UnevenRoundedRectangle(
                topLeadingRadius: 1, bottomLeadingRadius: 4,
                bottomTrailingRadius: 4, topTrailingRadius: 1
            )
            .stroke(fill.opacity(0.4), lineWidth: 1.5)
            .frame(width: size * 0.38, height: size * 0.42)
            .offset(y: size * 0.08)

            // Rim
            Capsule()
                .fill(.white.opacity(0.5))
                .frame(width: size * 0.38, height: size * 0.04)
                .offset(y: -size * 0.10)

            // Shine
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.30))
                .frame(width: size * 0.05, height: size * 0.22)
                .offset(x: -size * 0.10, y: size * 0.10)

            if hasLime {
                // Lime wedge on rim
                HalfCircle()
                    .fill(Color(red: 0.45, green: 0.78, blue: 0.15))
                    .frame(width: size * 0.22, height: size * 0.12)
                    .offset(x: size * 0.12, y: -size * 0.14)
            }

            if hasFlame {
                // Little flame
                FlameShape()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .yellow, .orange.opacity(0.6)],
                            startPoint: .bottom, endPoint: .top
                        )
                    )
                    .frame(width: size * 0.16, height: size * 0.24)
                    .offset(y: -size * 0.28)
            }
        }
    }
}

private struct JagerBottleIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Body
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.12, green: 0.25, blue: 0.10).gradient)
                    .frame(width: size * 0.12, height: size * 0.18)

                UnevenRoundedRectangle(
                    topLeadingRadius: 6, bottomLeadingRadius: 4,
                    bottomTrailingRadius: 4, topTrailingRadius: 6
                )
                .fill(Color(red: 0.12, green: 0.25, blue: 0.10).gradient)
                .frame(width: size * 0.40, height: size * 0.52)
            }
            .offset(y: size * 0.02)

            // Cap
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.08, green: 0.18, blue: 0.08))
                .frame(width: size * 0.14, height: size * 0.06)
                .offset(y: -size * 0.31)

            // Orange label
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.88, green: 0.48, blue: 0.08).gradient)
                .frame(width: size * 0.30, height: size * 0.22)
                .offset(y: size * 0.12)

            // Cross on label
            Rectangle()
                .fill(Color(red: 0.12, green: 0.25, blue: 0.10))
                .frame(width: size * 0.03, height: size * 0.16)
                .offset(y: size * 0.12)
            Rectangle()
                .fill(Color(red: 0.12, green: 0.25, blue: 0.10))
                .frame(width: size * 0.16, height: size * 0.03)
                .offset(y: size * 0.12)

            // Shine
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.15))
                .frame(width: size * 0.05, height: size * 0.30)
                .offset(x: -size * 0.12, y: size * 0.08)
        }
    }
}

private struct TallBottleIcon: View {
    let fill: Color
    let labelColor: Color
    let capColor: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(fill.gradient)
                    .frame(width: size * 0.12, height: size * 0.24)
                UnevenRoundedRectangle(
                    topLeadingRadius: 2, bottomLeadingRadius: 4,
                    bottomTrailingRadius: 4, topTrailingRadius: 2
                )
                .fill(fill.gradient)
                .frame(width: size * 0.32, height: size * 0.46)
            }
            .offset(y: size * 0.02)

            // Cap
            RoundedRectangle(cornerRadius: 2)
                .fill(capColor)
                .frame(width: size * 0.14, height: size * 0.06)
                .offset(y: -size * 0.33)

            // Label
            RoundedRectangle(cornerRadius: 3)
                .fill(labelColor.opacity(0.8))
                .frame(width: size * 0.24, height: size * 0.14)
                .offset(y: size * 0.14)

            // Shine
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.30))
                .frame(width: size * 0.05, height: size * 0.35)
                .offset(x: -size * 0.08, y: size * 0.05)
        }
    }
}

private struct WhiskeyGlassIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Glass body - wide tumbler
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 6,
                bottomTrailingRadius: 6, topTrailingRadius: 2
            )
            .fill(Color(red: 0.72, green: 0.45, blue: 0.12).gradient)
            .frame(width: size * 0.46, height: size * 0.40)
            .offset(y: size * 0.10)

            // Glass outline
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 6,
                bottomTrailingRadius: 6, topTrailingRadius: 2
            )
            .stroke(Color(red: 0.60, green: 0.38, blue: 0.10).opacity(0.5), lineWidth: 1.5)
            .frame(width: size * 0.50, height: size * 0.44)
            .offset(y: size * 0.08)

            // Ice cubes
            RoundedRectangle(cornerRadius: 3)
                .fill(.white.opacity(0.45))
                .frame(width: size * 0.14, height: size * 0.12)
                .offset(x: -size * 0.08, y: size * 0.02)
                .rotationEffect(.degrees(-8))
            RoundedRectangle(cornerRadius: 3)
                .fill(.white.opacity(0.35))
                .frame(width: size * 0.12, height: size * 0.10)
                .offset(x: size * 0.08, y: size * 0.04)
                .rotationEffect(.degrees(12))

            // Rim
            Capsule()
                .fill(.white.opacity(0.4))
                .frame(width: size * 0.48, height: size * 0.04)
                .offset(y: -size * 0.10)
        }
    }
}

// MARK: - Wine Icons

private struct WineGlassIcon: View {
    let fill: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            // Bowl
            Ellipse()
                .fill(fill.gradient)
                .frame(width: size * 0.44, height: size * 0.38)
                .offset(y: -size * 0.05)

            // Glass rim
            Ellipse()
                .stroke(.white.opacity(0.4), lineWidth: 1.5)
                .frame(width: size * 0.44, height: size * 0.10)
                .offset(y: -size * 0.20)

            // Stem
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.20)
                .offset(y: size * 0.22)

            // Base
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.24, height: size * 0.06)
                .offset(y: size * 0.34)

            // Shine
            Ellipse()
                .fill(.white.opacity(0.25))
                .frame(width: size * 0.10, height: size * 0.18)
                .offset(x: -size * 0.10, y: -size * 0.06)
        }
    }
}

private struct FluteIcon: View {
    let fill: Color
    let size: CGFloat
    var hasBubbles: Bool = false

    var body: some View {
        ZStack {
            // Narrow bowl
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 8,
                bottomTrailingRadius: 8, topTrailingRadius: 2
            )
            .fill(fill.gradient)
            .frame(width: size * 0.24, height: size * 0.42)
            .offset(y: -size * 0.06)

            // Stem
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.04, height: size * 0.16)
                .offset(y: size * 0.24)

            // Base
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.22, height: size * 0.06)
                .offset(y: size * 0.34)

            // Shine
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.30))
                .frame(width: size * 0.04, height: size * 0.24)
                .offset(x: -size * 0.06, y: -size * 0.06)

            if hasBubbles {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(0.55))
                        .frame(width: size * 0.04)
                        .offset(
                            x: CGFloat([-0.04, 0.03, -0.02, 0.05][i]) * size,
                            y: CGFloat([-0.18, -0.08, 0.02, -0.14][i]) * size
                        )
                }
            }
        }
    }
}

// MARK: - Cocktail Icons

private struct TropicalGlassIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Glass - hurricane shape
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 10,
                bottomTrailingRadius: 10, topTrailingRadius: 2
            )
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.35, blue: 0.20), Color(red: 0.95, green: 0.65, blue: 0.15)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: size * 0.38, height: size * 0.44)
            .offset(y: -size * 0.02)

            // Stem
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.14)
                .offset(y: size * 0.26)

            // Base
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.22, height: size * 0.05)
                .offset(y: size * 0.35)

            // Umbrella stick
            Rectangle()
                .fill(Color(red: 0.55, green: 0.35, blue: 0.15))
                .frame(width: size * 0.02, height: size * 0.30)
                .offset(x: size * 0.06, y: -size * 0.18)
                .rotationEffect(.degrees(12))

            // Umbrella
            HalfCircle()
                .fill(Color(red: 0.90, green: 0.25, blue: 0.40))
                .frame(width: size * 0.22, height: size * 0.12)
                .offset(x: size * 0.08, y: -size * 0.32)
        }
    }
}

private struct MargaritaGlassIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // V-shaped glass
            Triangle()
                .fill(Color.margaritaLime.opacity(0.7).gradient)
                .frame(width: size * 0.50, height: size * 0.36)
                .offset(y: -size * 0.04)

            // Salt rim dots
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(0.7))
                    .frame(width: size * 0.04)
                    .offset(
                        x: CGFloat([-0.22, -0.14, -0.04, 0.04, 0.14, 0.22][i]) * size,
                        y: -size * 0.20
                    )
            }

            // Stem
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.16)
                .offset(y: size * 0.22)

            // Base
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.22, height: size * 0.06)
                .offset(y: size * 0.32)

            // Lime wedge
            HalfCircle()
                .fill(Color(red: 0.45, green: 0.78, blue: 0.15))
                .frame(width: size * 0.16, height: size * 0.10)
                .offset(x: size * 0.18, y: -size * 0.18)
        }
    }
}

private struct MojitoGlassIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Tall glass
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 4,
                bottomTrailingRadius: 4, topTrailingRadius: 2
            )
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.85, green: 0.95, blue: 0.80), Color(red: 0.70, green: 0.90, blue: 0.65)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: size * 0.32, height: size * 0.58)
            .offset(y: size * 0.06)

            // Outline
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 4,
                bottomTrailingRadius: 4, topTrailingRadius: 2
            )
            .stroke(Color.mojitGreen.opacity(0.4), lineWidth: 1.5)
            .frame(width: size * 0.34, height: size * 0.60)
            .offset(y: size * 0.05)

            // Mint leaves
            Ellipse()
                .fill(Color.mojitGreen)
                .frame(width: size * 0.14, height: size * 0.08)
                .offset(x: -size * 0.04, y: -size * 0.16)
                .rotationEffect(.degrees(-20))
            Ellipse()
                .fill(Color(red: 0.22, green: 0.60, blue: 0.28))
                .frame(width: size * 0.12, height: size * 0.07)
                .offset(x: size * 0.06, y: -size * 0.20)
                .rotationEffect(.degrees(15))

            // Straw
            Rectangle()
                .fill(Color(red: 0.20, green: 0.55, blue: 0.25))
                .frame(width: size * 0.03, height: size * 0.40)
                .offset(x: size * 0.10, y: -size * 0.08)
                .rotationEffect(.degrees(8))

            // Shine
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.30))
                .frame(width: size * 0.05, height: size * 0.30)
                .offset(x: -size * 0.08, y: size * 0.06)
        }
    }
}

private struct LongIslandIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Tall glass
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 4,
                bottomTrailingRadius: 4, topTrailingRadius: 2
            )
            .fill(Color.longIslandAmber.gradient)
            .frame(width: size * 0.30, height: size * 0.56)
            .offset(y: size * 0.06)

            // Outline
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 4,
                bottomTrailingRadius: 4, topTrailingRadius: 2
            )
            .stroke(Color.longIslandAmber.opacity(0.4), lineWidth: 1.5)
            .frame(width: size * 0.32, height: size * 0.58)
            .offset(y: size * 0.05)

            // Ice cubes
            RoundedRectangle(cornerRadius: 2)
                .fill(.white.opacity(0.35))
                .frame(width: size * 0.10, height: size * 0.08)
                .offset(x: -size * 0.04, y: -size * 0.04)
                .rotationEffect(.degrees(-5))
            RoundedRectangle(cornerRadius: 2)
                .fill(.white.opacity(0.30))
                .frame(width: size * 0.08, height: size * 0.08)
                .offset(x: size * 0.06, y: -size * 0.10)
                .rotationEffect(.degrees(10))

            // Straw
            Rectangle()
                .fill(Color(red: 0.85, green: 0.25, blue: 0.25))
                .frame(width: size * 0.03, height: size * 0.42)
                .offset(x: size * 0.08, y: -size * 0.08)
                .rotationEffect(.degrees(6))

            // Shine
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.25))
                .frame(width: size * 0.05, height: size * 0.28)
                .offset(x: -size * 0.08, y: size * 0.06)
        }
    }
}

private struct BalloonGlassIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Big round bowl
            Ellipse()
                .fill(Color.ginTonic.gradient)
                .frame(width: size * 0.48, height: size * 0.42)
                .offset(y: -size * 0.04)

            // Glass outline
            Ellipse()
                .stroke(Color.ginTonic.opacity(0.5), lineWidth: 1.5)
                .frame(width: size * 0.50, height: size * 0.44)
                .offset(y: -size * 0.04)

            // Stem
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.16)
                .offset(y: size * 0.24)

            // Base
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.22, height: size * 0.06)
                .offset(y: size * 0.34)

            // Lime inside
            Circle()
                .fill(Color(red: 0.45, green: 0.78, blue: 0.15).opacity(0.6))
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: size * 0.06, y: -size * 0.02)

            // Bubbles
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(0.45))
                    .frame(width: size * 0.04)
                    .offset(
                        x: CGFloat([-0.08, 0.02, 0.10][i]) * size,
                        y: CGFloat([-0.12, -0.02, -0.08][i]) * size
                    )
            }

            // Shine
            Ellipse()
                .fill(.white.opacity(0.25))
                .frame(width: size * 0.10, height: size * 0.18)
                .offset(x: -size * 0.12, y: -size * 0.06)
        }
    }
}

private struct EspressoMartiniIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // V-shaped martini glass
            Triangle()
                .fill(Color.espressoBrown.gradient)
                .frame(width: size * 0.48, height: size * 0.34)
                .offset(y: -size * 0.06)

            // Crema layer
            Capsule()
                .fill(Color(red: 0.55, green: 0.38, blue: 0.22))
                .frame(width: size * 0.44, height: size * 0.06)
                .offset(y: -size * 0.20)

            // Coffee beans on top
            Ellipse()
                .fill(Color(red: 0.18, green: 0.10, blue: 0.06))
                .frame(width: size * 0.08, height: size * 0.05)
                .offset(x: -size * 0.06, y: -size * 0.22)
            Ellipse()
                .fill(Color(red: 0.18, green: 0.10, blue: 0.06))
                .frame(width: size * 0.08, height: size * 0.05)
                .offset(x: size * 0.04, y: -size * 0.22)
            Ellipse()
                .fill(Color(red: 0.18, green: 0.10, blue: 0.06))
                .frame(width: size * 0.08, height: size * 0.05)
                .offset(y: -size * 0.24)

            // Stem
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.18)
                .offset(y: size * 0.20)

            // Base
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.22, height: size * 0.06)
                .offset(y: size * 0.32)
        }
    }
}

private struct AperolSpritzIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Big wine glass bowl
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.aperolOrange, Color(red: 0.98, green: 0.60, blue: 0.20)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: size * 0.44, height: size * 0.38)
                .offset(y: -size * 0.04)

            // Glass outline
            Ellipse()
                .stroke(Color.aperolOrange.opacity(0.5), lineWidth: 1.5)
                .frame(width: size * 0.46, height: size * 0.40)
                .offset(y: -size * 0.04)

            // Orange slice
            HalfCircle()
                .fill(Color(red: 0.98, green: 0.65, blue: 0.10))
                .frame(width: size * 0.18, height: size * 0.10)
                .offset(x: size * 0.10, y: -size * 0.16)

            // Stem
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.16)
                .offset(y: size * 0.22)

            // Base
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.22, height: size * 0.06)
                .offset(y: size * 0.32)

            // Bubbles
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(0.50))
                    .frame(width: size * 0.035)
                    .offset(
                        x: CGFloat([-0.06, 0.04, -0.10, 0.08][i]) * size,
                        y: CGFloat([-0.10, 0.00, 0.04, -0.06][i]) * size
                    )
            }

            // Shine
            Ellipse()
                .fill(.white.opacity(0.22))
                .frame(width: size * 0.10, height: size * 0.16)
                .offset(x: -size * 0.12, y: -size * 0.06)
        }
    }
}

// MARK: - Can Icon (for Sapporo, Foster's, etc.)

private struct CanIcon: View {
    let fill: Color
    let labelColor: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            // Can body
            UnevenRoundedRectangle(
                topLeadingRadius: 4, bottomLeadingRadius: 4,
                bottomTrailingRadius: 4, topTrailingRadius: 4
            )
            .fill(fill.gradient)
            .frame(width: size * 0.36, height: size * 0.60)

            // Top rim
            Capsule()
                .fill(fill.opacity(0.6))
                .frame(width: size * 0.30, height: size * 0.05)
                .offset(y: -size * 0.28)

            // Tab
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.5))
                .frame(width: size * 0.12, height: size * 0.06)
                .offset(y: -size * 0.32)

            // Label stripe
            RoundedRectangle(cornerRadius: 2)
                .fill(labelColor.opacity(0.8))
                .frame(width: size * 0.30, height: size * 0.16)
                .offset(y: size * 0.02)

            // Shine
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.25))
                .frame(width: size * 0.05, height: size * 0.35)
                .offset(x: -size * 0.10)
        }
    }
}

// MARK: - New Wine Icons

private struct PortGlassIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Small tulip bowl
            Ellipse()
                .fill(Color.portRuby.gradient)
                .frame(width: size * 0.36, height: size * 0.30)
                .offset(y: -size * 0.04)

            Ellipse()
                .stroke(.white.opacity(0.3), lineWidth: 1.5)
                .frame(width: size * 0.36, height: size * 0.08)
                .offset(y: -size * 0.16)

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.20)
                .offset(y: size * 0.18)

            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.22, height: size * 0.06)
                .offset(y: size * 0.30)

            Ellipse()
                .fill(.white.opacity(0.22))
                .frame(width: size * 0.08, height: size * 0.14)
                .offset(x: -size * 0.08, y: -size * 0.04)
        }
    }
}

private struct MulledWineIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Mug body
            UnevenRoundedRectangle(
                topLeadingRadius: 3, bottomLeadingRadius: 6,
                bottomTrailingRadius: 6, topTrailingRadius: 3
            )
            .fill(Color.mulledRed.gradient)
            .frame(width: size * 0.40, height: size * 0.44)
            .offset(y: size * 0.06)

            // Handle
            Circle()
                .stroke(Color.gray.opacity(0.4), lineWidth: size * 0.04)
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(x: size * 0.26, y: size * 0.06)

            // Steam wisps
            ForEach(0..<2, id: \.self) { i in
                SteamWisp()
                    .stroke(.white.opacity(0.4), lineWidth: 1.5)
                    .frame(width: size * 0.08, height: size * 0.14)
                    .offset(
                        x: CGFloat([-0.06, 0.06][i]) * size,
                        y: -size * 0.24
                    )
            }

            // Cinnamon stick
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(red: 0.55, green: 0.30, blue: 0.10))
                .frame(width: size * 0.04, height: size * 0.30)
                .offset(x: size * 0.10, y: -size * 0.06)
                .rotationEffect(.degrees(15))

            // Orange slice
            HalfCircle()
                .fill(Color(red: 0.95, green: 0.60, blue: 0.12))
                .frame(width: size * 0.14, height: size * 0.08)
                .offset(x: -size * 0.10, y: -size * 0.12)
        }
    }
}

// MARK: - New Cocktail Icons

private struct PinaColadaIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Hurricane glass
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 10,
                bottomTrailingRadius: 10, topTrailingRadius: 2
            )
            .fill(Color.pinaYellow.gradient)
            .frame(width: size * 0.36, height: size * 0.42)
            .offset(y: -size * 0.02)

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.14)
                .offset(y: size * 0.26)

            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.22, height: size * 0.05)
                .offset(y: size * 0.35)

            // Pineapple wedge
            Triangle()
                .fill(Color(red: 0.88, green: 0.72, blue: 0.12))
                .frame(width: size * 0.14, height: size * 0.16)
                .offset(x: size * 0.16, y: -size * 0.18)
                .rotationEffect(.degrees(20))

            // Umbrella
            HalfCircle()
                .fill(Color(red: 0.20, green: 0.65, blue: 0.85))
                .frame(width: size * 0.18, height: size * 0.10)
                .offset(x: -size * 0.06, y: -size * 0.28)
        }
    }
}

private struct CosmoIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Martini V-shape
            Triangle()
                .fill(Color.cosmoPink.gradient)
                .frame(width: size * 0.46, height: size * 0.34)
                .offset(y: -size * 0.06)

            // Rim shine
            Capsule()
                .fill(.white.opacity(0.4))
                .frame(width: size * 0.42, height: size * 0.03)
                .offset(y: -size * 0.20)

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.18)
                .offset(y: size * 0.20)

            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.22, height: size * 0.06)
                .offset(y: size * 0.32)

            // Lime twist on rim
            Ellipse()
                .fill(Color(red: 0.45, green: 0.75, blue: 0.15))
                .frame(width: size * 0.10, height: size * 0.06)
                .offset(x: size * 0.16, y: -size * 0.20)
        }
    }
}

private struct OldFashionedIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Short tumbler
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 6,
                bottomTrailingRadius: 6, topTrailingRadius: 2
            )
            .fill(Color.oldFashionedAmber.gradient)
            .frame(width: size * 0.44, height: size * 0.38)
            .offset(y: size * 0.10)

            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 6,
                bottomTrailingRadius: 6, topTrailingRadius: 2
            )
            .stroke(Color.oldFashionedAmber.opacity(0.4), lineWidth: 1.5)
            .frame(width: size * 0.48, height: size * 0.42)
            .offset(y: size * 0.08)

            // Ice sphere
            Circle()
                .fill(.white.opacity(0.35))
                .frame(width: size * 0.18)
                .offset(y: size * 0.02)

            // Orange peel
            Ellipse()
                .fill(Color(red: 0.95, green: 0.55, blue: 0.10))
                .frame(width: size * 0.16, height: size * 0.06)
                .offset(x: size * 0.08, y: -size * 0.06)
                .rotationEffect(.degrees(-15))

            // Rim
            Capsule()
                .fill(.white.opacity(0.35))
                .frame(width: size * 0.46, height: size * 0.03)
                .offset(y: -size * 0.10)
        }
    }
}

private struct NegroniIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Short rocks glass
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 6,
                bottomTrailingRadius: 6, topTrailingRadius: 2
            )
            .fill(Color.negroniRed.gradient)
            .frame(width: size * 0.44, height: size * 0.38)
            .offset(y: size * 0.10)

            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 6,
                bottomTrailingRadius: 6, topTrailingRadius: 2
            )
            .stroke(Color.negroniRed.opacity(0.4), lineWidth: 1.5)
            .frame(width: size * 0.48, height: size * 0.42)
            .offset(y: size * 0.08)

            // Ice cube
            RoundedRectangle(cornerRadius: 3)
                .fill(.white.opacity(0.35))
                .frame(width: size * 0.14, height: size * 0.12)
                .offset(y: size * 0.02)

            // Orange slice on rim
            HalfCircle()
                .fill(Color(red: 0.95, green: 0.55, blue: 0.10))
                .frame(width: size * 0.16, height: size * 0.10)
                .offset(x: size * 0.14, y: -size * 0.10)

            Capsule()
                .fill(.white.opacity(0.35))
                .frame(width: size * 0.46, height: size * 0.03)
                .offset(y: -size * 0.10)
        }
    }
}

private struct DaiquiriIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Coupe glass
            Ellipse()
                .fill(Color.daiquiriPink.gradient)
                .frame(width: size * 0.44, height: size * 0.28)
                .offset(y: -size * 0.08)

            Ellipse()
                .stroke(.white.opacity(0.3), lineWidth: 1.5)
                .frame(width: size * 0.44, height: size * 0.08)
                .offset(y: -size * 0.18)

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.22)
                .offset(y: size * 0.16)

            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.22, height: size * 0.06)
                .offset(y: size * 0.30)

            // Strawberry on rim
            Circle()
                .fill(Color(red: 0.88, green: 0.18, blue: 0.22))
                .frame(width: size * 0.12)
                .offset(x: size * 0.18, y: -size * 0.16)
        }
    }
}

private struct ManhattanIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Coupe glass
            Ellipse()
                .fill(Color.manhattanCherry.gradient)
                .frame(width: size * 0.42, height: size * 0.26)
                .offset(y: -size * 0.08)

            Ellipse()
                .stroke(.white.opacity(0.3), lineWidth: 1.5)
                .frame(width: size * 0.42, height: size * 0.08)
                .offset(y: -size * 0.18)

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.22)
                .offset(y: size * 0.16)

            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.22, height: size * 0.06)
                .offset(y: size * 0.30)

            // Cherry
            Circle()
                .fill(Color(red: 0.72, green: 0.08, blue: 0.12))
                .frame(width: size * 0.10)
                .offset(y: -size * 0.06)
            // Cherry stem
            Rectangle()
                .fill(Color(red: 0.35, green: 0.20, blue: 0.08))
                .frame(width: size * 0.02, height: size * 0.08)
                .offset(y: -size * 0.14)
        }
    }
}

private struct WhiskeySourIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Coupe
            Ellipse()
                .fill(Color.whiskeySourGold.gradient)
                .frame(width: size * 0.44, height: size * 0.28)
                .offset(y: -size * 0.08)

            // Foam layer
            Capsule()
                .fill(.white.opacity(0.6))
                .frame(width: size * 0.38, height: size * 0.06)
                .offset(y: -size * 0.18)

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.22)
                .offset(y: size * 0.16)

            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.22, height: size * 0.06)
                .offset(y: size * 0.30)

            // Cherry on top
            Circle()
                .fill(Color(red: 0.82, green: 0.12, blue: 0.15))
                .frame(width: size * 0.08)
                .offset(y: -size * 0.20)
        }
    }
}

private struct DarkStormyIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Tall glass with dark liquid
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 4,
                bottomTrailingRadius: 4, topTrailingRadius: 2
            )
            .fill(
                LinearGradient(
                    colors: [Color.darkStormyBrown, Color(red: 0.18, green: 0.10, blue: 0.05)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: size * 0.30, height: size * 0.56)
            .offset(y: size * 0.06)

            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 4,
                bottomTrailingRadius: 4, topTrailingRadius: 2
            )
            .stroke(Color.darkStormyBrown.opacity(0.4), lineWidth: 1.5)
            .frame(width: size * 0.32, height: size * 0.58)
            .offset(y: size * 0.05)

            // Ginger beer foam
            Capsule()
                .fill(Color(red: 0.90, green: 0.82, blue: 0.60).opacity(0.6))
                .frame(width: size * 0.26, height: size * 0.05)
                .offset(y: -size * 0.18)

            // Lime wedge
            HalfCircle()
                .fill(Color(red: 0.45, green: 0.75, blue: 0.15))
                .frame(width: size * 0.14, height: size * 0.08)
                .offset(x: size * 0.12, y: -size * 0.20)

            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.20))
                .frame(width: size * 0.04, height: size * 0.28)
                .offset(x: -size * 0.08, y: size * 0.06)
        }
    }
}

private struct MoscowMuleIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Copper mug body
            UnevenRoundedRectangle(
                topLeadingRadius: 4, bottomLeadingRadius: 6,
                bottomTrailingRadius: 6, topTrailingRadius: 4
            )
            .fill(Color.muleCopper.gradient)
            .frame(width: size * 0.40, height: size * 0.48)
            .offset(y: size * 0.04)

            // Handle
            Circle()
                .stroke(Color.muleCopper.opacity(0.7), lineWidth: size * 0.04)
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(x: size * 0.26, y: size * 0.04)

            // Rim
            Capsule()
                .fill(Color(red: 0.72, green: 0.42, blue: 0.18))
                .frame(width: size * 0.38, height: size * 0.04)
                .offset(y: -size * 0.18)

            // Lime wedge
            HalfCircle()
                .fill(Color(red: 0.45, green: 0.75, blue: 0.15))
                .frame(width: size * 0.16, height: size * 0.10)
                .offset(x: -size * 0.06, y: -size * 0.22)

            // Shine
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.25))
                .frame(width: size * 0.06, height: size * 0.28)
                .offset(x: -size * 0.10, y: size * 0.04)
        }
    }
}

private struct SangriaIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Wine glass bowl
            Ellipse()
                .fill(Color.sangriaWine.gradient)
                .frame(width: size * 0.44, height: size * 0.36)
                .offset(y: -size * 0.04)

            Ellipse()
                .stroke(Color.sangriaWine.opacity(0.4), lineWidth: 1.5)
                .frame(width: size * 0.44, height: size * 0.10)
                .offset(y: -size * 0.18)

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.18)
                .offset(y: size * 0.22)

            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size * 0.22, height: size * 0.06)
                .offset(y: size * 0.34)

            // Fruit pieces floating
            Circle()
                .fill(Color(red: 0.95, green: 0.55, blue: 0.10))
                .frame(width: size * 0.08)
                .offset(x: -size * 0.08, y: -size * 0.06)
            Circle()
                .fill(Color(red: 0.45, green: 0.75, blue: 0.15))
                .frame(width: size * 0.07)
                .offset(x: size * 0.06, y: -size * 0.02)
            Circle()
                .fill(Color(red: 0.88, green: 0.20, blue: 0.22))
                .frame(width: size * 0.06)
                .offset(x: -size * 0.02, y: size * 0.04)
        }
    }
}

private struct TequilaSunriseIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Tall glass with gradient
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 4,
                bottomTrailingRadius: 4, topTrailingRadius: 2
            )
            .fill(
                LinearGradient(
                    colors: [Color.sunriseOrange, Color.sunriseRed, Color(red: 0.85, green: 0.15, blue: 0.12)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: size * 0.30, height: size * 0.56)
            .offset(y: size * 0.06)

            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 4,
                bottomTrailingRadius: 4, topTrailingRadius: 2
            )
            .stroke(Color.sunriseOrange.opacity(0.4), lineWidth: 1.5)
            .frame(width: size * 0.32, height: size * 0.58)
            .offset(y: size * 0.05)

            // Orange slice on rim
            HalfCircle()
                .fill(Color(red: 0.95, green: 0.60, blue: 0.12))
                .frame(width: size * 0.16, height: size * 0.10)
                .offset(x: size * 0.12, y: -size * 0.20)

            // Cherry
            Circle()
                .fill(Color(red: 0.82, green: 0.12, blue: 0.15))
                .frame(width: size * 0.08)
                .offset(x: -size * 0.04, y: -size * 0.14)

            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.22))
                .frame(width: size * 0.04, height: size * 0.28)
                .offset(x: -size * 0.08, y: size * 0.06)
        }
    }
}

private struct SexOnBeachIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Tall glass with gradient
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 4,
                bottomTrailingRadius: 4, topTrailingRadius: 2
            )
            .fill(
                LinearGradient(
                    colors: [Color.beachPeach, Color(red: 0.90, green: 0.35, blue: 0.22)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: size * 0.30, height: size * 0.56)
            .offset(y: size * 0.06)

            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 4,
                bottomTrailingRadius: 4, topTrailingRadius: 2
            )
            .stroke(Color.beachPeach.opacity(0.4), lineWidth: 1.5)
            .frame(width: size * 0.32, height: size * 0.58)
            .offset(y: size * 0.05)

            // Umbrella
            HalfCircle()
                .fill(Color(red: 0.92, green: 0.82, blue: 0.10))
                .frame(width: size * 0.18, height: size * 0.10)
                .offset(x: size * 0.04, y: -size * 0.28)

            // Straw
            Rectangle()
                .fill(Color(red: 0.88, green: 0.20, blue: 0.35))
                .frame(width: size * 0.03, height: size * 0.38)
                .offset(x: size * 0.08, y: -size * 0.06)
                .rotationEffect(.degrees(6))

            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.22))
                .frame(width: size * 0.04, height: size * 0.28)
                .offset(x: -size * 0.08, y: size * 0.06)
        }
    }
}

private struct IrishCoffeeIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Glass mug body
            UnevenRoundedRectangle(
                topLeadingRadius: 3, bottomLeadingRadius: 6,
                bottomTrailingRadius: 6, topTrailingRadius: 3
            )
            .fill(Color.irishCreamBrown.gradient)
            .frame(width: size * 0.38, height: size * 0.44)
            .offset(y: size * 0.06)

            // Handle
            Circle()
                .stroke(Color.gray.opacity(0.35), lineWidth: size * 0.04)
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: size * 0.24, y: size * 0.06)

            // Cream layer
            UnevenRoundedRectangle(
                topLeadingRadius: 3, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 3
            )
            .fill(.white.opacity(0.75))
            .frame(width: size * 0.38, height: size * 0.12)
            .offset(y: -size * 0.10)

            // Steam
            ForEach(0..<2, id: \.self) { i in
                SteamWisp()
                    .stroke(.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: size * 0.07, height: size * 0.12)
                    .offset(
                        x: CGFloat([-0.05, 0.05][i]) * size,
                        y: -size * 0.26
                    )
            }
        }
    }
}

// MARK: - Steam shape for hot drinks

private struct SteamWisp: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.midY),
            control: CGPoint(x: rect.maxX, y: rect.midY + rect.height * 0.25)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.midY - rect.height * 0.25)
        )
        return path
    }
}

// MARK: - Helper Shapes

private struct HalfCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX * 0.75, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.midY * 0.6)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY * 0.65),
            control: CGPoint(x: rect.midX * 1.1, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX * 0.25, y: rect.maxY),
            control: CGPoint(x: rect.midX * 0.9, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.midY * 0.6)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(DrinksCatalog.allVariants) { variant in
                VStack(spacing: 4) {
                    DrinkIconView(variantId: variant.id, size: 56)
                    Text(variant.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}
