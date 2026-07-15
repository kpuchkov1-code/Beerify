//
//  Badges.swift
//  Beerify
//
//  Achievements you can earn across nights. Evaluated locally at the end of
//  each night. Badge state is a set of IDs in AppData.unlockedBadges.
//

import Foundation

struct Badge: Identifiable, Hashable {
    let id: String
    let emoji: String
    let title: String
    let subtitle: String
}

enum Badges {
    static let catalog: [Badge] = [
        Badge(id: "first_night", emoji: "🌙", title: "First Night", subtitle: "You logged your first session"),
        Badge(id: "first_shot", emoji: "🥃", title: "First Shot", subtitle: "One shot down"),
        Badge(id: "hydration_hero", emoji: "💧", title: "Hydration Hero", subtitle: "3+ waters in one night"),
        Badge(id: "home_before_midnight", emoji: "🕛", title: "Home by Midnight", subtitle: "Wrapped before 12am"),
        Badge(id: "marathoner", emoji: "🏃", title: "Marathoner", subtitle: "10+ drinks in a night"),
        Badge(id: "in_the_zone", emoji: "🎯", title: "In the Zone", subtitle: "Nailed your target with no overshoot"),
        Badge(id: "designated_driver", emoji: "🚗", title: "Designated Driver", subtitle: "Zero drinks, still out with the squad"),
        Badge(id: "streak_5", emoji: "🔥", title: "5-Night Streak", subtitle: "Five nights logged in a row"),
        Badge(id: "sommelier", emoji: "🍷", title: "Sommelier", subtitle: "Wine-only night"),
        Badge(id: "brewmaster", emoji: "🍺", title: "Brewmaster", subtitle: "Beer-only night"),
        Badge(id: "mixologist", emoji: "🍹", title: "Mixologist", subtitle: "Cocktail-only night"),
        Badge(id: "explorer", emoji: "🌍", title: "Explorer", subtitle: "All 4 drink types in one night"),
    ]

    private static let byId: [String: Badge] =
        Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })

    static func lookup(_ id: String) -> Badge? { byId[id] }

    /// Evaluate all badges against the just-ended session (`session`) and the
    /// full history including it. Returns badges newly earned.
    static func evaluate(session: NightSession, profile: Profile, history: [NightSession]) -> [Badge] {
        var earned: [Badge] = []

        // First night: always awarded when history has at least one entry.
        if history.count >= 1 { earned.append(byId["first_night"]!) }

        // First shot ever.
        let anyShot = history.contains { s in s.drinks.contains { $0.type == .shot } }
        if anyShot { earned.append(byId["first_shot"]!) }

        // Session-specific badges.
        if session.waters.count >= 3 { earned.append(byId["hydration_hero"]!) }

        if let end = session.endedAt, !session.drinks.isEmpty {
            let cal = Calendar.current
            let startDay = cal.startOfDay(for: session.startedAt)
            let midnight = cal.date(byAdding: .day, value: 1, to: startDay) ?? end
            if end < midnight {
                earned.append(byId["home_before_midnight"]!)
            }
        }

        if session.drinks.count >= 10 { earned.append(byId["marathoner"]!) }

        // Target hit cleanly.
        let target = TargetsCatalog.target(session.targetId)
        let end = session.endedAt ?? Date()
        var peak = 0.0
        var everInZone = false
        var everOver = false
        var t = session.startedAt
        while t <= end {
            let b = BAC.estimate(drinks: session.drinks, profile: profile, at: t)
            peak = max(peak, b)
            if b >= target.minBac && b <= target.maxBac { everInZone = true }
            if b > target.maxBac { everOver = true }
            t = t.addingTimeInterval(5 * 60)
        }
        if everInZone && !everOver && !session.drinks.isEmpty {
            earned.append(byId["in_the_zone"]!)
        }

        if session.drinks.isEmpty && (session.endedAt?.timeIntervalSince(session.startedAt) ?? 0) > 45 * 60 {
            earned.append(byId["designated_driver"]!)
        }

        // 5-night streak - trailing 5 sessions each on different days.
        let recentDays = history.suffix(5).map { Calendar.current.startOfDay(for: $0.startedAt) }
        if recentDays.count == 5, Set(recentDays).count == 5 {
            earned.append(byId["streak_5"]!)
        }

        let uniqueTypes = Set(session.drinks.map(\.type))
        if uniqueTypes == [.wine] { earned.append(byId["sommelier"]!) }
        if uniqueTypes == [.beer] { earned.append(byId["brewmaster"]!) }
        if uniqueTypes == [.cocktail] { earned.append(byId["mixologist"]!) }
        if uniqueTypes.count == 4 { earned.append(byId["explorer"]!) }

        return earned
    }
}
