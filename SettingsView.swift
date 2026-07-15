//
//  SettingsView.swift
//  Beerify
//
//  Personalisation + safety toggles. Reads and writes AppData.preferences
//  through AppStore.updatePreferences.
//

import SwiftUI
import PhotosUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var showDrinkPicker = false
    @State private var showEmojiPicker = false
    @State private var showProfileEditor = false
    @State private var selectedPhoto: PhotosPickerItem? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("You")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)

                if let profile = store.data.profile {
                    profileSection(profile)
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
                rideHomeCard
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
        .sheet(isPresented: $showEmojiPicker) {
            emojiPickerSheet
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showProfileEditor) {
            if let profile = store.data.profile {
                ProfileEditorSheet(profile: profile) { updated in
                    store.setProfile(updated)
                }
                .presentationDetents([.medium])
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let newItem, let data = try? await newItem.loadTransferable(type: Data.self) {
                    store.updateProfile { $0.profileImageData = data }
                }
                selectedPhoto = nil
            }
        }
    }

    // MARK: - Profile section

    private func profileSection(_ profile: Profile) -> some View {
        VStack(spacing: 12) {
            // Avatar + name row
            HStack(spacing: 14) {
                // Profile picture / emoji
                profileAvatarView(profile)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name).font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)
                    Text("\(Int(profile.weightKg))kg \u{00B7} \(profile.sex.rawValue.capitalized) \u{00B7} \(profile.tolerance.rawValue.capitalized) drinker")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Button {
                    showProfileEditor = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                }
            }

            // Quick-edit buttons
            HStack(spacing: 8) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Photo", systemImage: "camera.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accentDeep)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(Theme.accentDeep.opacity(0.12)))
                }
                .buttonStyle(BeerifyPressStyle())

                Button {
                    showEmojiPicker = true
                } label: {
                    Label("Emoji", systemImage: "face.smiling.inverse")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accentDeep)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(Theme.accentDeep.opacity(0.12)))
                }
                .buttonStyle(BeerifyPressStyle())

                if profile.profileImageData != nil {
                    Button {
                        store.updateProfile { $0.profileImageData = nil }
                    } label: {
                        Label("Remove photo", systemImage: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill(Theme.danger.opacity(0.1)))
                    }
                    .buttonStyle(BeerifyPressStyle())
                }

                Spacer()
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
    }

    @ViewBuilder
    private func profileAvatarView(_ profile: Profile) -> some View {
        if let imageData = profile.profileImageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.accent.opacity(0.4), lineWidth: 2))
        } else {
            Text(profile.emoji ?? "🙂")
                .font(.system(size: 36))
                .frame(width: 56, height: 56)
                .background(Circle().fill(Theme.accent.opacity(0.15)))
                .overlay(Circle().stroke(Theme.accent.opacity(0.3), lineWidth: 1))
        }
    }

    // MARK: - Emoji Picker Sheet

    private static let emojiOptions = [
        "🙂", "😎", "🤠", "🥳", "😈", "🤡", "👻", "🦊", "🐻", "🐼",
        "🦁", "🐨", "🐵", "🦄", "🐙", "🦖", "🐳", "🐹", "🐸", "🍺",
        "🍷", "🍹", "🥂", "🍻", "🎉", "🔥", "⚡", "🌙", "💀", "🫠",
        "🧠", "👑", "🎭", "🌶", "🍄", "🪩", "🫧", "🎯", "🏆", "💎"
    ]

    private var emojiPickerSheet: some View {
        VStack(spacing: 16) {
            Text("Pick your emoji")
                .font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)

            let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(Self.emojiOptions, id: \.self) { emoji in
                    let isSelected = store.data.profile?.emoji == emoji
                    Button {
                        store.updateProfile { $0.emoji = emoji }
                        showEmojiPicker = false
                    } label: {
                        Text(emoji)
                            .font(.system(size: 30))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 10).fill(
                                isSelected ? Theme.accent.opacity(0.3) : Color.clear))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                                isSelected ? Theme.accent : Color.clear, lineWidth: 2))
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .background(BeerifyBackground())
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
            case 1: return ("🍼", "Family-safe", "Nothing risqué - good for game night with parents.")
            case 2: return ("🙂", "Mild party", "Light truths and playful dares. Zero blush.")
            case 3: return ("😏", "Medium", "The default - spicy but never explicit.")
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

    private var rideHomeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("🚕").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ride home link").font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                    Text("Opens when you're past your zone. Change to Lyft, Bolt, or any URL.")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            TextField("https://m.uber.com/", text: Binding(
                get: { store.data.preferences.rideHomeURL },
                set: { newVal in store.updatePreferences { $0.rideHomeURL = newVal } }
            ))
            .textFieldStyle(BeerifyFieldStyle())
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            HStack(spacing: 10) {
                Text("🏠").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Home address").font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                    Text("Pre-fills your dropoff so you just tap 'Go'.")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            TextField("123 Main St, City", text: Binding(
                get: { store.data.preferences.homeAddress },
                set: { newVal in store.updatePreferences { $0.homeAddress = newVal } }
            ))
            .textFieldStyle(BeerifyFieldStyle())
            .textInputAutocapitalization(.words)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
    }
}

// MARK: - Profile Editor Sheet

struct ProfileEditorSheet: View {
    let profile: Profile
    let onSave: (Profile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var weightKg: Double
    @State private var sex: Sex
    @State private var tolerance: Tolerance

    init(profile: Profile, onSave: @escaping (Profile) -> Void) {
        self.profile = profile
        self.onSave = onSave
        _name = State(initialValue: profile.name)
        _weightKg = State(initialValue: profile.weightKg)
        _sex = State(initialValue: profile.sex)
        _tolerance = State(initialValue: profile.tolerance)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Your name", text: $name)
                }

                Section("Weight") {
                    HStack {
                        Text("\(Int(weightKg)) kg")
                            .font(.headline).monospacedDigit()
                        Spacer()
                        Stepper("", value: $weightKg, in: 30...250, step: 1)
                            .labelsHidden()
                    }
                    Slider(value: $weightKg, in: 30...250, step: 1)
                        .tint(Theme.accent)
                }

                Section("Sex") {
                    Picker("Sex", selection: $sex) {
                        ForEach(Sex.allCases, id: \.self) { s in
                            Text(s.rawValue.capitalized).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Drinking frequency") {
                    Picker("How often do you drink?", selection: $tolerance) {
                        ForEach(Tolerance.allCases, id: \.self) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .scrollContentBackground(.hidden)
            .background(BeerifyBackground())
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = profile
                        updated.name = name.trimmingCharacters(in: .whitespaces)
                        updated.weightKg = weightKg
                        updated.sex = sex
                        updated.tolerance = tolerance
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
