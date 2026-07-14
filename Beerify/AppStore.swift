//
//  AppStore.swift
//  Beerify
//
//  Single source of truth for the app. Mirrors the web app's AppData shape
//  (profile / active session / history / room). Persists via UserDefaults
//  as JSON — same pattern as localStorage on web.
//

import Foundation
import SwiftUI

@Observable
final class AppStore {
    private let storageKey = "beerify.v1"

    private(set) var data: AppData

    init() {
        self.data = Self.load(key: storageKey)
    }

    // MARK: - Persistence

    private static func load(key: String) -> AppData {
        guard let raw = UserDefaults.standard.data(forKey: key) else { return .empty }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        do {
            return try decoder.decode(AppData.self, from: raw)
        } catch {
            return .empty
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        if let encoded = try? encoder.encode(data) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    // MARK: - Mutations (mirroring App.tsx handlers)

    func setProfile(_ profile: Profile) {
        data.profile = profile
        save()
    }

    func startNight(target: TargetId) {
        data.session = NightSession(
            id: IDGen.new(),
            startedAt: Date(),
            targetId: target,
            drinks: [],
            waters: [],
            endedAt: nil,
            reviewedAt: nil
        )
        save()
    }

    func logDrink(_ typeId: DrinkTypeId) {
        logDrinkVariant(typeId: typeId, variantId: nil)
    }

    func logDrinkVariant(typeId: DrinkTypeId, variantId: String?) {
        guard var session = data.session else { return }
        let def: DrinkType
        if let vid = variantId, let variant = DrinksCatalog.variantMap[vid] {
            def = DrinksCatalog.effectiveType(for: variant)
        } else if let base = DrinksCatalog.types[typeId] {
            def = base
        } else {
            return
        }
        let entry = LoggedDrink(
            id: IDGen.new(),
            type: typeId,
            at: Date(),
            units: DrinksCatalog.unitsOfAlcohol(def),
            grams: DrinksCatalog.gramsOfAlcohol(def),
            variantId: variantId
        )
        session.drinks.append(entry)
        data.session = session
        save()
    }

    func logWater() {
        guard var session = data.session else { return }
        session.waters.append(Date())
        data.session = session
        save()
    }

    func undoDrink() {
        guard var session = data.session, !session.drinks.isEmpty else { return }
        session.drinks.removeLast()
        data.session = session
        save()
    }

    func endNight() {
        guard var session = data.session else { return }
        session.endedAt = Date()
        data.history.append(session)
        data.session = nil
        // Unlock any newly-earned badges from this session.
        if let profile = data.profile {
            let unlocked = Badges.evaluate(session: session, profile: profile, history: data.history)
            data.unlockedBadges.formUnion(unlocked.map(\.id))
        }
        save()
    }

    // MARK: - Preferences

    func updatePreferences(_ mutate: (inout UserPreferences) -> Void) {
        var prefs = data.preferences
        mutate(&prefs)
        data.preferences = prefs
        save()
    }

    func joinRoom(_ membership: RoomMembership) {
        data.room = membership
        save()
    }

    func leaveRoom() {
        data.room = nil
        save()
    }

    /// Marks a summary as read (analogous to the web app's reviewedAt bump).
    func markReviewed(sessionId: String) {
        if let idx = data.history.firstIndex(where: { $0.id == sessionId }),
           data.history[idx].reviewedAt == nil {
            data.history[idx].reviewedAt = Date()
            save()
        }
    }

    /// Reset for the "Sign out and start over" button on the profile.
    func resetAll() {
        data = .empty
        save()
    }

    // MARK: - Derived helpers

    var unreviewedSummary: NightSession? {
        data.history
            .sorted(by: { $0.startedAt > $1.startedAt })
            .first(where: { $0.reviewedAt == nil })
    }
}
