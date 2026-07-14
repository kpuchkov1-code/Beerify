//
//  OnboardingView.swift
//  Beerify
//
//  Two-step onboarding: hello screen → about-you form.
//

import SwiftUI

struct OnboardingView: View {
    let onDone: (Profile) -> Void

    @State private var step: Int = 0

    var body: some View {
        Group {
            if step == 0 { welcome } else { form }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BeerifyBackground())
        .foregroundStyle(Theme.ink)
    }

    // MARK: - Step 0

    private var welcome: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("🍺").font(.system(size: 96))
                    Text("Beerify")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                    Text("Your friendly AI drinking buddy. Pick your vibe, tap your drinks, and Beerify keeps you right where you want to be, and no further.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 12) {
                    bullet("🎯", "Choose how merry you want to get")
                    bullet("👆", "Log drinks with one giant tap")
                    bullet("🧠", "Live coaching to hold your sweet spot")
                    bullet("👯", "Rooms to keep an eye on your friends")
                    bullet("☀️", "A morning-after summary of your units")
                }
                .padding(.horizontal, 24)

                Button {
                    withAnimation { step = 1 }
                } label: {
                    Text("Let's set you up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .padding(.horizontal, 20)

                Text("Estimates only, never a legal or medical measure. Never drink and drive.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
        }
    }

    private func bullet(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.title2)
            Text(text).font(.body)
            Spacer()
        }
    }

    // MARK: - Step 1

    @State private var name: String = ""
    @State private var weightText: String = ""
    @State private var sex: Sex? = nil
    @State private var tolerance: Tolerance? = nil

    private var weightKg: Double? { Double(weightText) }
    private var weightValid: Bool {
        if let w = weightKg { return w >= 35 && w <= 250 }
        return false
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        weightValid && sex != nil && tolerance != nil
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("About you")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                Text("Alcohol hits everyone differently. Three quick facts make the estimates actually useful. It all stays on your phone.")
                    .foregroundStyle(Theme.inkSoft)

                VStack(alignment: .leading, spacing: 8) {
                    Text("What should we call you?").font(.subheadline.weight(.semibold))
                    TextField("Your name", text: $name)
                        .textFieldStyle(BeerifyFieldStyle())
                        .textContentType(.givenName)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your weight (kg)").font(.subheadline.weight(.semibold))
                    TextField("e.g. 72", text: $weightText)
                        .textFieldStyle(BeerifyFieldStyle())
                    #if os(iOS) || os(visionOS)
                        .keyboardType(.decimalPad)
                    #endif
                    if !weightText.isEmpty && !weightValid {
                        Text("Enter a weight between 35 and 250 kg")
                            .font(.caption).foregroundStyle(Theme.danger)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Body type for the estimate").font(.subheadline.weight(.semibold))
                    HStack(spacing: 8) {
                        chip("Female", active: sex == .female) { sex = .female }
                        chip("Male", active: sex == .male) { sex = .male }
                        chip("Prefer not to say", active: sex == .other) { sex = .other }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("How often do you drink?").font(.subheadline.weight(.semibold))
                    Text("Regular drinkers process alcohol faster. This tunes your curve.")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        toleranceChip(.rare, "Rarely", "A few times a year")
                        toleranceChip(.monthly, "Sometimes", "Once or twice a month")
                        toleranceChip(.weekly, "Most weeks", "One night a week")
                        toleranceChip(.frequent, "Often", "Several nights a week")
                    }
                }

                Button {
                    guard canSubmit, let sex, let tolerance, let weight = weightKg else { return }
                    onDone(Profile(
                        name: name.trimmingCharacters(in: .whitespaces),
                        weightKg: weight, sex: sex, tolerance: tolerance,
                        createdAt: Date()))
                } label: {
                    Text("Done, take me in 🍻")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!canSubmit)
                .padding(.top, 8)
            }
            .padding(20)
        }
    }

    private func chip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(
                    Capsule().fill(active ? Theme.accent.opacity(0.22) : Theme.surface.opacity(0.85))
                )
                .overlay(
                    Capsule().stroke(active ? Theme.accent : Theme.hairline, lineWidth: 1.5)
                )
                .foregroundStyle(active ? Theme.accentDeep : Theme.ink)
        }
        .buttonStyle(.plain)
    }

    private func toleranceChip(_ id: Tolerance, _ label: String, _ note: String) -> some View {
        let active = tolerance == id
        return Button {
            tolerance = id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                Text(note).font(.caption).foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(active ? Theme.accent.opacity(0.18) : Theme.surface.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(active ? Theme.accent : Theme.hairline, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct BeerifyBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.96, blue: 0.86),
                Color(red: 1.0, green: 0.83, blue: 0.55),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// Text field style that matches Beerify's warm palette (never renders as a
/// dark iOS system field, regardless of appearance).
struct BeerifyFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .foregroundStyle(Theme.ink)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1)
            )
    }
}

#Preview {
    OnboardingView(onDone: { _ in })
}
