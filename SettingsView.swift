//
//  SettingsView.swift
//  Beerify
//
//  Personalisation + safety toggles. Reads and writes AppData.preferences
//  through AppStore.updatePreferences.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var showDrinkPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("You")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)

                if let profile = store.data.profile {
                    profileCard(profile)
                }

                sectionHeader("My drinks")
                myDrinksCard

                sectionHeader("Coach personality")
                personalityPicker

                sectionHeader("Themed night")
                themePicker

                sectionHeader("Spiciness")
                spicinessCard

                sectionHeader("Modes")
                toggle(
                    icon: "🚗", title: "Designated driver",
                    subtitle: "Locks logging, shows water challenges only",
                    isOn: Binding(
                        get: { store.data.preferences.ddMode },
                        set: { newVal in store.updatePreferences { $0.ddMode = newVal } }
                    )
                )
                toggle(
                    icon: "🌱", title: "Sober mode",
                    subtitle: "Track waters + earn XP for saying no",
                    isOn: Binding(
                        get: { store.data.preferences.soberMode },
                        set: { newVal in store.updatePreferences { $0.soberMode = newVal } }
                    )
                )
                toggle(
                    icon: "👍", title: "Big-thumb mode",
                    subtitle: "Bigger buttons, fewer confirmations after \"in the zone\"",
                    isOn: Binding(
                        get: { store.data.preferences.bigThumbMode },
                        set: { newVal in store.updatePreferences { $0.bigThumbMode = newVal } }
                    )
                )

                sectionHeader("Safety")
                Text("Beerify estimates are a friendly guide, not a breathalyser. Never drink and drive.")
                    .font(.caption).foregroundStyle(Theme.inkSoft)

                Button(role: .destructive) {
                    store.resetAll()
                } label: {
                    Text("Sign out and start over").frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.bordered).tint(Theme.danger)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(BeerifyBackground())
        .sheet(isPresented: $showDrinkPicker) {
            DrinkPickerView()
                .presentationDetents([.large])
        }
    }

    // MARK: - Sub views

    private var myDrinksCard: some View {
        let ids = store.data.preferences.selectedDrinkVariants.isEmpty
            ? Array(DrinksCatalog.defaultVariantIds)
            : store.data.preferences.selectedDrinkVariants
        let variants = ids.compactMap { DrinksCatalog.variantMap[$0] }
        return Button {
            showDrinkPicker = true
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: 2) {
                    ForEach(variants.prefix(5)) { v in
                        DrinkIconView(variantId: v.id, size: 28)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(variants.count) drink\(variants.count == 1 ? "" : "s") on your grid")
                        .font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                    Text("Tap to add or remove drinks")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.95)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(BeerifyPressStyle())
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            .padding(.top, 4)
    }

    private func profileCard(_ profile: Profile) -> some View {
        HStack(spacing: 12) {
            Text("🙂").font(.system(size: 40))
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).font(.headline).foregroundStyle(Theme.ink)
                Text("\(Int(profile.weightKg))kg · \(profile.sex.rawValue.capitalized) · \(profile.tolerance.rawValue.capitalized) drinker")
                    .font(.caption).foregroundStyle(Theme.inkSoft)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
    }

    private var personalityPicker: some View {
        let current = store.data.preferences.coachPersonality
        return HStack(spacing: 10) {
            ForEach(CoachPersonality.allCases, id: \.self) { p in
                let active = current == p
                Button {
                    store.updatePreferences { $0.coachPersonality = p }
                } label: {
                    VStack(spacing: 4) {
                        Text(p.emoji).font(.system(size: 30))
                        Text(p.label).font(.caption.weight(.semibold)).foregroundStyle(Theme.ink)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(active ? Theme.accent.opacity(0.25) : Theme.surface.opacity(0.9)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(active ? Theme.accent : Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(BeerifyPressStyle())
            }
        }
    }

    private var themePicker: some View {
        let current = store.data.preferences.themedNight
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ThemedNight.allCases, id: \.self) { t in
                    let active = current == t
                    Button {
                        store.updatePreferences { $0.themedNight = t }
                    } label: {
                        HStack(spacing: 6) {
                            Text(t.emoji)
                            Text(t.label).font(.subheadline.weight(active ? .bold : .medium))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 16).fill(active ? Theme.accent.opacity(0.25) : Theme.surface.opacity(0.9)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(active ? Theme.accent : Theme.hairline, lineWidth: 1))
                        .foregroundStyle(Theme.ink)
                    }
                }
            }
        }
    }

    private var spicinessCard: some View {
        let level = store.data.preferences.spiciness
        let (emoji, label, blurb): (String, String, String) = {
            switch level {
            case 1: return ("🍼", "Family-safe", "Nothing risqué — good for game night with parents.")
            case 2: return ("🙂", "Mild party", "Light truths and playful dares. Zero blush.")
            case 3: return ("😏", "Medium", "The default — spicy but never explicit.")
            case 4: return ("🌶", "Spicy", "Grown-up questions and daring dares.")
            default: return ("🔥", "Unfiltered", "Adults only. Explicit, borderline unhinged. No filters.")
            }
        }()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(emoji).font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(label) · \(level)/5").font(.headline).foregroundStyle(Theme.ink)
                    Text(blurb).font(.caption).foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            Slider(
                value: Binding(
                    get: { Double(store.data.preferences.spiciness) },
                    set: { newVal in
                        store.updatePreferences { $0.spiciness = max(1, min(5, Int(newVal.rounded()))) }
                    }
                ),
                in: 1...5, step: 1
            )
            .tint(Theme.accent)
            HStack {
                Text("🍼").font(.caption)
                Spacer()
                Text("🔥").font(.caption)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
    }

    private func toggle(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(icon).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                Text(subtitle).font(.caption).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Theme.accent)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
    }
}
