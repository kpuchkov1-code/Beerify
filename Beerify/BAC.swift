//
//  BAC.swift
//  Beerify
//
//  Widmark-based BAC estimation with gradual per-drink absorption.
//  Ported from beerify/src/lib/bac.ts — the two implementations should
//  produce numerically identical curves.
//

import Foundation

private let BETA_BY_TOLERANCE: [Tolerance: Double] = [
    .rare: 0.012,
    .monthly: 0.015,
    .weekly: 0.017,
    .frequent: 0.020,
]

private func betaPerHour(_ profile: Profile) -> Double {
    BETA_BY_TOLERANCE[profile.tolerance] ?? 0.015
}

private func widmarkR(_ sex: Sex) -> Double {
    switch sex {
    case .male: return 0.68
    case .female: return 0.55
    case .other: return 0.615
    }
}

private func bacFromGrams(_ grams: Double, _ profile: Profile) -> Double {
    (grams / (profile.weightKg * 1000 * widmarkR(profile.sex))) * 100
}

private func absorbedFraction(elapsedMin: Double, absorptionMin: Double) -> Double {
    if elapsedMin <= 0 { return 0 }
    if elapsedMin >= absorptionMin { return 1 }
    let x = elapsedMin / absorptionMin
    return 1 - (1 - x) * (1 - x)
}

enum BAC {

    /// Estimate BAC (%) at `at` given drinks so far.
    static func estimate(drinks: [LoggedDrink], profile: Profile, at: Date) -> Double {
        guard !drinks.isEmpty else { return 0 }
        let sorted = drinks.sorted { $0.at < $1.at }
        let start = sorted[0].at
        if at <= start { return 0 }

        let stepSec: TimeInterval = 60
        var bac = 0.0
        var prevAbsorbed = 0.0
        var prev = start
        var t = start

        while t < at {
            t = min(t.addingTimeInterval(stepSec), at)
            let dtHours = t.timeIntervalSince(prev) / 3600

            var absorbed = 0.0
            for d in sorted {
                if d.at > t { continue }
                guard let type = DrinksCatalog.types[d.type] else { continue }
                let elapsedMin = t.timeIntervalSince(d.at) / 60
                let frac = absorbedFraction(elapsedMin: elapsedMin, absorptionMin: type.absorptionMin)
                absorbed += bacFromGrams(d.grams * frac, profile)
            }

            bac = max(0, bac + (absorbed - prevAbsorbed) - betaPerHour(profile) * dtHours)
            prevAbsorbed = absorbed
            prev = t
        }
        return bac
    }

    static func project(drinks: [LoggedDrink], profile: Profile, from: Date, minutes: Double) -> Double {
        estimate(drinks: drinks, profile: profile, at: from.addingTimeInterval(minutes * 60))
    }

    static func peakAhead(drinks: [LoggedDrink], profile: Profile, from: Date, horizonMin: Int) -> Double {
        var peak = 0.0
        var m = 0
        while m <= horizonMin {
            peak = max(peak, estimate(drinks: drinks, profile: profile,
                                      at: from.addingTimeInterval(Double(m) * 60)))
            m += 5
        }
        return peak
    }

    static func minutesUntilBac(drinks: [LoggedDrink], profile: Profile, from: Date, targetBac: Double) -> Int {
        let step = 10
        var m = 0
        while m <= 720 {
            if estimate(drinks: drinks, profile: profile,
                        at: from.addingTimeInterval(Double(m) * 60)) <= targetBac {
                return m
            }
            m += step
        }
        return 720
    }

    /// Format like ".052" (matches the web app: `bac.toFixed(3).replace(/^0/, '')`).
    static func format(_ bac: Double) -> String {
        var s = String(format: "%.3f", bac)
        if s.hasPrefix("0") { s.removeFirst() }
        return s
    }
}
