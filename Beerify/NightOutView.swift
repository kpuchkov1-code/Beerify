//
//  NightOutView.swift
//  Beerify
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct NightOutView: View {
    let session: NightSession
    let profile: Profile
    let membership: RoomMembership?
    let onLogDrink: (DrinkTypeId) -> Void
    let onLogDrinkVariant: ((DrinkTypeId, String?) -> Void)?
    let onLogWater: () -> Void
    let onUndo: () -> Void
    let onEndNight: () -> Void

    @Environment(RoomService.self) private var roomService
    @Environment(AppStore.self) private var store

    @State private var now: Date = Date()
    @State private var confirmEnd: Bool = false
    @State private var burst: (id: String, key: Int)? = nil
    @State private var burstToken: Int = 0
    @State private var cheersFlash: Cheer? = nil
    @State private var showDrinkPicker: Bool = false

    private var prefs: UserPreferences { store.data.preferences }
    private var activeVariants: [DrinkVariant] {
        let ids = prefs.selectedDrinkVariants.isEmpty
            ? Array(DrinksCatalog.defaultVariantIds)
            : prefs.selectedDrinkVariants
        return ids.compactMap { DrinksCatalog.variantMap[$0] }
    }
    private var target: Target { TargetsCatalog.target(session.targetId) }
    private var bac: Double { BAC.estimate(drinks: session.drinks, profile: profile, at: now) }
    private var incoming: Double { BAC.peakAhead(drinks: session.drinks, profile: profile, from: now, horizonMin: 60) }
    private var status: ZoneStatus { Coach.zoneStatus(bac: bac, session: session) }
    private var coach: CoachMessage {
        Coach.message(session: session, profile: profile, now: now, personality: prefs.coachPersonality)
    }
    private var totalUnits: Double { session.drinks.reduce(0) { $0 + $1.units } }
    private var blocked: Bool { status == .wayOver || prefs.ddMode || prefs.soberMode }
    private var minsUntilSober: Int {
        BAC.minutesUntilBac(drinks: session.drinks, profile: profile, from: now, targetBac: 0.005)
    }
    private var minsUntilDrive: Int {
        BAC.minutesUntilBac(drinks: session.drinks, profile: profile, from: now, targetBac: 0.02)
    }
    private var shouldEatNudge: Bool {
        session.drinks.count >= 3 && session.waters.isEmpty && status != .sober
    }
    private var showRideButton: Bool { status == .over || status == .wayOver }

    struct Cheer: Equatable { let id: Int; let name: String }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                BeerMeterView(bac: bac, incoming: incoming, target: target, status: status)
                    .padding(.vertical, 8)

                coachBanner

                if blocked {
                    Text(blockedBannerText)
                        .font(.callout.weight(.semibold))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.danger.opacity(0.15)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.danger.opacity(0.4), lineWidth: 1))
                        .foregroundStyle(Theme.danger)
                }

                extrasBar

                HStack {
                    Text("Tap what you're having").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Button {
                        showDrinkPicker = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accentDeep)
                    .controlSize(.small)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(activeVariants) { variant in
                        variantButton(variant: variant)
                    }
                }

                waterButton

                metaBar

                if let membership,
                   let room = roomService.state,
                   room.members.count > 1 {
                    Text("Your room · \(membership.code)").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                    VStack(spacing: 4) {
                        ForEach(room.members) { m in
                            SquadMemberRow(member: m, isSelf: m.id == membership.memberId)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.85)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
                }

                if !session.drinks.isEmpty {
                    Text("Latest").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                    VStack(spacing: 4) {
                        ForEach(session.drinks
                            .sorted(by: { $0.at > $1.at })
                            .prefix(6), id: \.id) { d in
                            let variant = d.variantId.flatMap { DrinksCatalog.variantMap[$0] }
                            let def = DrinksCatalog.types[d.type]
                            HStack {
                                if let vid = d.variantId {
                                    DrinkIconView(variantId: vid, size: 28)
                                } else {
                                    Text(def?.emoji ?? "").font(.title3)
                                }
                                Text(variant?.label ?? def?.label ?? "").font(.subheadline).foregroundStyle(Theme.ink)
                                Spacer()
                                Text(Fmt.time(d.at))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.85)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(backgroundGradient)
        .onAppear(perform: startTickers)
        .onChange(of: session.drinks.count) { _, _ in pushSnapshot() }
        .onChange(of: session.targetId) { _, _ in pushSnapshot() }
        .onChange(of: roomService.lastCheers?.id) { _, _ in
            if let c = roomService.lastCheers {
                cheersFlash = Cheer(id: c.id, name: c.name)
                Task { try? await Task.sleep(nanoseconds: 2_000_000_000); await MainActor.run { cheersFlash = nil } }
                hapticHeavy()
            }
        }
        .overlay(alignment: .center) { cheersOverlay }
        .sheet(isPresented: $confirmEnd) {
            endNightSheet
                .presentationDetents([.height(300), .medium])
        }
        .sheet(isPresented: $showDrinkPicker) {
            DrinkPickerView()
                .presentationDetents([.large])
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Night out")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("\(target.emoji) \(target.label)")
                    .font(.subheadline).foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Button("End night") { confirmEnd = true }
                .buttonStyle(.bordered)
                .tint(Theme.accentDeep)
        }
    }

    // MARK: - Coach banner

    private var coachBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("🤖").font(.system(size: 34))
                .padding(10)
                .background(Circle().fill(coachTone.opacity(0.15)))
                .overlay(Circle().stroke(coachTone.opacity(0.4), lineWidth: 1))
            VStack(alignment: .leading, spacing: 4) {
                Text(coach.text).font(.callout.weight(.medium)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let tip = coach.tip {
                    Text(tip).font(.caption).foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface.opacity(0.92)))
        .overlay(
            RoundedRectangle(cornerRadius: 16).stroke(coachTone.opacity(0.55), lineWidth: 1.5)
        )
        .shadow(color: coachTone.opacity(0.18), radius: 12, x: 0, y: 6)
        .id(coach.text)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: coach.text)
    }

    private var coachTone: Color {
        switch coach.tone {
        case .cheer: return Theme.success
        case .chill: return Theme.info
        case .nudge: return Theme.accent
        case .warn: return Theme.danger
        }
    }

    // MARK: - Extras bar (safe-to-drive, food nudge, ride, cheers)

    private var extrasBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                extrasTile(icon: "⏳",
                           label: "Safe to drive",
                           value: minsUntilDrive <= 0 ? "—" : Fmt.duration(minutes: minsUntilDrive),
                           tint: Theme.info)
                extrasTile(icon: "🌅",
                           label: "Fully sober",
                           value: minsUntilSober <= 0 ? "—" : Fmt.duration(minutes: minsUntilSober),
                           tint: Theme.accentDeep)
            }

            if let membership = membership,
               (roomService.state?.members.count ?? 0) >= 1 {
                Button {
                    hapticHeavy()
                    roomService.sendCheers(fromName: profile.name)
                } label: {
                    HStack {
                        Text("🍻").font(.title2)
                        Text("Group cheers").font(.headline).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("· \(membership.code)").font(.caption).foregroundStyle(Theme.inkSoft)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent.opacity(0.22)))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.55), lineWidth: 1))
                }
                .buttonStyle(BeerifyPressStyle())
            }

            if shouldEatNudge {
                nudgeCard(icon: "🍟",
                          text: "You've had \(session.drinks.count) with no water yet. Grab food + a big water.")
            }

            if showRideButton {
                Button {
                    openRide()
                } label: {
                    HStack {
                        Text("🚕").font(.title2)
                        VStack(alignment: .leading) {
                            Text("Call a ride home").font(.headline).foregroundStyle(Theme.ink)
                            Text("You're past your zone — future-you will thank you.")
                                .font(.caption).foregroundStyle(Theme.inkSoft)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right").foregroundStyle(Theme.accentDeep)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.danger.opacity(0.15)))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.danger.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(BeerifyPressStyle())
            }
        }
    }

    private func extrasTile(icon: String, label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) { Text(icon); Text(label).font(.caption).foregroundStyle(Theme.inkSoft) }
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.4), lineWidth: 1))
    }

    private func nudgeCard(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(icon).font(.title2)
            Text(text).font(.callout).foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.warning.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.warning.opacity(0.4), lineWidth: 1))
    }

    private var blockedBannerText: String {
        if prefs.ddMode { return "🚗 Designated driver mode is on. Water only tonight." }
        if prefs.soberMode { return "🌱 Sober mode is on. Water only — you're crushing it." }
        return "Drink logging is paused. You are well past your zone, so it is water only for now. 💧"
    }

    // MARK: - Cheers overlay

    @ViewBuilder
    private var cheersOverlay: some View {
        if let c = cheersFlash {
            VStack(spacing: 10) {
                Text("🍻").font(.system(size: 100))
                Text("\(c.name) says cheers!")
                    .font(.title2.weight(.heavy)).foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.35).ignoresSafeArea())
            .transition(.scale.combined(with: .opacity))
            .id(c.id)
        }
    }

    private func openRide() {
        #if canImport(UIKit)
        if let url = URL(string: prefs.rideHomeURL) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    // MARK: - Buttons

    private func drinkButton(id: DrinkTypeId) -> some View {
        let def = DrinksCatalog.types[id]!
        let bursting = burst?.id == id.rawValue
        return Button {
            tapDrink(id)
        } label: {
            VStack(spacing: 6) {
                Text(def.emoji).font(.system(size: 48))
                    .scaleEffect(bursting ? 1.22 : 1.0)
                    .rotationEffect(.degrees(bursting ? -6 : 0))
                    .animation(.spring(response: 0.30, dampingFraction: 0.45), value: burst?.key)
                Text(def.label).font(.headline).foregroundStyle(Theme.ink)
                Text(def.detail).font(.caption).foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.surface.opacity(blocked ? 0.45 : 0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.accent.opacity(blocked ? 0.15 : 0.55), lineWidth: 1.2)
            )
            .shadow(color: Theme.ink.opacity(blocked ? 0.0 : 0.10), radius: 10, x: 0, y: 5)
            .opacity(blocked ? 0.55 : 1)
        }
        .buttonStyle(BeerifyPressStyle(pressedScale: 0.94))
        .disabled(blocked)
        .accessibilityLabel(Text("Log one \(def.label)"))
    }

    private func variantButton(variant: DrinkVariant) -> some View {
        let effective = DrinksCatalog.effectiveType(for: variant)
        let bursting = burst?.id == variant.id
        return Button {
            tapVariant(variant)
        } label: {
            VStack(spacing: 8) {
                DrinkIconView(variantId: variant.id, size: 52)
                    .scaleEffect(bursting ? 1.18 : 1.0)
                    .rotationEffect(.degrees(bursting ? -6 : 0))
                    .animation(.spring(response: 0.30, dampingFraction: 0.45), value: burst?.key)
                Text(variant.label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.75)
                Text(effective.detail)
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.surface.opacity(blocked ? 0.45 : 0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.accent.opacity(blocked ? 0.15 : 0.55), lineWidth: 1.2)
            )
            .shadow(color: Theme.ink.opacity(blocked ? 0.0 : 0.10), radius: 10, x: 0, y: 5)
            .opacity(blocked ? 0.55 : 1)
        }
        .buttonStyle(BeerifyPressStyle(pressedScale: 0.94))
        .disabled(blocked)
        .accessibilityLabel(Text("Log one \(variant.label)"))
    }

    private var waterButton: some View {
        let bursting = burst?.id == "water"
        return Button {
            tapWater()
        } label: {
            HStack(spacing: 14) {
                Text("💧").font(.system(size: 42))
                    .scaleEffect(bursting ? 1.22 : 1.0)
                    .rotationEffect(.degrees(bursting ? 8 : 0))
                    .animation(.spring(response: 0.30, dampingFraction: 0.45), value: burst?.key)
                VStack(alignment: .leading) {
                    Text("Water break").font(.headline).foregroundStyle(Theme.ink)
                    Text("Your liver's best friend").font(.caption).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.info.opacity(0.16)))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.info.opacity(0.55), lineWidth: 1.2))
            .shadow(color: Theme.info.opacity(0.20), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(BeerifyPressStyle(pressedScale: 0.96))
    }

    private var metaBar: some View {
        HStack {
            Text("\(session.drinks.count) drink\(session.drinks.count == 1 ? "" : "s") · \(Fmt.units(totalUnits)) units\(session.waters.isEmpty ? "" : " · \(session.waters.count) 💧")")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            if !session.drinks.isEmpty {
                Button("Undo last") { onUndo() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(Theme.accentDeep)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - End sheet

    private var endNightSheet: some View {
        VStack(spacing: 16) {
            Text("Calling it a night?").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            Text("We'll save tonight and have your summary of units, peak and all, waiting for you in the morning. ☀️")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.inkSoft)
            Button {
                confirmEnd = false
                onEndNight()
            } label: {
                Text("End night, sleep tight 😴")
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(Theme.accent)
            Button("Keep going") { confirmEnd = false }
                .buttonStyle(.bordered)
                .tint(Theme.accentDeep)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BeerifyBackground())
    }

    // MARK: - Actions

    private func tapDrink(_ id: DrinkTypeId) {
        onLogDrink(id)
        now = Date()
        showBurst(id: id.rawValue)
        hapticLight()
    }

    private func tapVariant(_ variant: DrinkVariant) {
        if let logVariant = onLogDrinkVariant {
            logVariant(variant.baseType, variant.id)
        } else {
            onLogDrink(variant.baseType)
        }
        now = Date()
        showBurst(id: variant.id)
        hapticLight()
    }

    private func tapWater() {
        onLogWater()
        now = Date()
        showBurst(id: "water")
        hapticSoft()
    }

    private func showBurst(id: String) {
        burstToken += 1
        burst = (id, burstToken)
    }

    private func hapticLight() {
        #if canImport(UIKit) && !os(macOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func hapticSoft() {
        #if canImport(UIKit) && !os(macOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    private func hapticHeavy() {
        #if canImport(UIKit) && !os(macOS)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }

    // MARK: - Background gradient reflects status

    private var backgroundGradient: some View {
        let colors: [Color]
        switch status {
        case .sober:
            colors = [Color(red: 1.0, green: 0.96, blue: 0.86), Color(red: 0.98, green: 0.88, blue: 0.65)]
        case .warming:
            colors = [Color(red: 1.0, green: 0.94, blue: 0.78), Color(red: 1.0, green: 0.83, blue: 0.55)]
        case .inZone:
            colors = [Color(red: 0.85, green: 0.98, blue: 0.85), Color(red: 0.55, green: 0.92, blue: 0.75)]
        case .over:
            colors = [Color(red: 1.0, green: 0.94, blue: 0.78), Color(red: 1.0, green: 0.72, blue: 0.4)]
        case .wayOver:
            colors = [Color(red: 1.0, green: 0.85, blue: 0.83), Color(red: 0.95, green: 0.55, blue: 0.55)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    // MARK: - Tickers

    private func startTickers() {
        Task { @MainActor in
            while !Task.isCancelled {
                now = Date()
                pushSnapshot()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
        // Make sure the mesh is up with an in-session snapshot even after a
        // cold launch that jumped straight back into a night.
        pushSnapshot(forceActivate: true)
    }

    private func pushSnapshot(forceActivate: Bool = false) {
        guard let membership else { return }
        let snapshot = SquadMember(
            id: membership.memberId,
            name: profile.name,
            bac: bac,
            units: totalUnits,
            drinks: session.drinks.count,
            targetId: session.targetId,
            status: status.rawValue,
            inSession: true,
            updatedAt: Date()
        )
        if forceActivate && (!roomService.isActive || roomService.state?.code != membership.code) {
            roomService.activate(code: membership.code, memberId: membership.memberId, snapshot: snapshot)
        } else {
            roomService.update(snapshot: snapshot)
        }
    }
}
