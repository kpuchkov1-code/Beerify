//
//  DrinkPickerView.swift
//  Beerify
//
//  Lets the user choose which drink variants appear on their night-out tap grid.
//

import SwiftUI

struct DrinkPickerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<String> = []

    private var resolvedSelection: [String] {
        selected.isEmpty
            ? Array(DrinksCatalog.defaultVariantIds)
            : Array(selected)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your drinks")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)

                Text("Pick the drinks you want on your tap grid. Tap to toggle.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)

                ForEach(DrinksCatalog.variantsByCategory, id: \.label) { category in
                    Text(category.label)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 4)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(category.variants) { variant in
                            let active = selected.contains(variant.id)
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if active {
                                        selected.remove(variant.id)
                                    } else {
                                        selected.insert(variant.id)
                                    }
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    DrinkIconView(variantId: variant.id, size: 40)
                                        .scaleEffect(active ? 1.08 : 1.0)
                                    Text(variant.label)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(active ? Theme.accent.opacity(0.25) : Theme.surface.opacity(0.9))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(active ? Theme.accent : Theme.hairline, lineWidth: active ? 1.8 : 1)
                                )
                                .shadow(color: active ? Theme.accent.opacity(0.2) : .clear, radius: 8, y: 4)
                            }
                            .buttonStyle(BeerifyPressStyle())
                        }
                    }
                }

                if !selected.isEmpty {
                    Text("\(selected.count) drink\(selected.count == 1 ? "" : "s") selected")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                }

                Button {
                    store.updatePreferences { $0.selectedDrinkVariants = Array(selected) }
                    dismiss()
                } label: {
                    Text("Save my drinks")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(selected.isEmpty)
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(BeerifyBackground())
        .onAppear {
            let saved = store.data.preferences.selectedDrinkVariants
            selected = saved.isEmpty ? DrinksCatalog.defaultVariantIds : Set(saved)
        }
    }
}
