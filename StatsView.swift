//
//  StatsView.swift
//  Beerify
//
//  Personal analytics across all logged nights: units per week, personal
//  records, drink-type breakdown, badge collection.
//

import SwiftUI

struct StatsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your stats")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)

                if store.data.history.isEmpty {
                    empty
                } else {
                    tiles
                    weekChart
                    typeBreakdown
                    records
                }

                Text("Achievements")
                    .font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                badgeGrid
            }
            .padding(20)
        }
        .background(BeerifyBackground())
    }

    // MARK: - Sections

    private var empty: some View {
        VStack(spacing: 8) {
            Text("📓").font(.system(size: 44))
            Text("No nights logged yet.").font(.headline).foregroundStyle(Theme.ink)
            Text("Finish a night to unlock stats and badges.")
                .foregroundStyle(Theme.inkSoft).font(.caption)
        }
        .frame(maxWidth: .infinity).padding(24)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
    }

    private var tiles: some View {
        let history = store.data.history
        let totalNights = history.count
        let totalUnits = history.flatMap(\.drinks).reduce(0.0) { $0 + $1.units }
        let totalDrinks = history.flatMap(\.drinks).count
        let waterCount = history.flatMap(\.waters).count
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statTile(value: "\(totalNights)", label: "nights")
            statTile(value: Fmt.units(totalUnits), label: "total units")
            statTile(value: "\(totalDrinks)", label: "drinks logged")
            statTile(value: "\(waterCount) 💧", label: "waters")
        }
    }

    private var weekChart: some View {
        let unitsByDay = last7DaysUnits(store.data.history)
        let peak = max(0.1, unitsByDay.map(\.units).max() ?? 0)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Last 7 days").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(unitsByDay) { d in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [Theme.accent, Theme.accentDeep],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(height: max(4, CGFloat(d.units / peak) * 120))
                        Text(d.label).font(.caption2).foregroundStyle(Theme.inkSoft)
                    }.frame(maxWidth: .infinity)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.9)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
        }
    }

    private var typeBreakdown: some View {
        var totals: [DrinkTypeId: Int] = [:]
        for d in store.data.history.flatMap(\.drinks) {
            totals[d.type, default: 0] += 1
        }
        let ordered = totals.sorted { $0.value > $1.value }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Favorites").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            VStack(spacing: 6) {
                ForEach(ordered, id: \.key) { key, count in
                    if let def = DrinksCatalog.types[key] {
                        HStack {
                            Text(def.emoji).font(.title3)
                            Text(def.label).font(.subheadline).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(count)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.9)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                    }
                }
            }
        }
    }

    private var records: some View {
        let history = store.data.history
        let biggest = history.map { $0.drinks.count }.max() ?? 0
        let mostWater = history.map { $0.waters.count }.max() ?? 0
        let longestDry: Int = longestSoberStreak(history)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Personal records").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            VStack(spacing: 6) {
                recordRow(icon: "🏆", label: "Most drinks in a night", value: "\(biggest)")
                recordRow(icon: "💧", label: "Most waters in a night", value: "\(mostWater)")
                recordRow(icon: "🌱", label: "Longest dry streak", value: "\(longestDry) days")
            }
        }
    }

    private var badgeGrid: some View {
        let unlocked = store.data.unlockedBadges
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(Badges.catalog) { badge in
                let earned = unlocked.contains(badge.id)
                VStack(alignment: .leading, spacing: 4) {
                    Text(badge.emoji).font(.system(size: 32)).opacity(earned ? 1 : 0.25)
                    Text(badge.title).font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(badge.subtitle).font(.caption).foregroundStyle(Theme.inkSoft)
                        .lineLimit(2, reservesSpace: true)
                    if !earned {
                        Text("Locked").font(.caption2).foregroundStyle(Theme.inkSoft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(earned ? Theme.surface.opacity(0.95) : Theme.surface.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(earned ? Theme.accent.opacity(0.5) : Theme.hairline, lineWidth: 1))
                .opacity(earned ? 1 : 0.75)
            }
        }
    }

    // MARK: - Helpers

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text(label).font(.caption).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
    }

    private func recordRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Text(icon).font(.title3)
            Text(label).font(.subheadline).foregroundStyle(Theme.ink)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
    }

    private struct DayBucket: Identifiable {
        let id: Int
        let label: String
        let units: Double
    }

    private func last7DaysUnits(_ history: [NightSession]) -> [DayBucket] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let nextDay = cal.date(byAdding: .day, value: 1, to: day)!
            let units = history
                .filter { $0.startedAt >= day && $0.startedAt < nextDay }
                .flatMap(\.drinks).reduce(0.0) { $0 + $1.units }
            let f = DateFormatter(); f.dateFormat = "E"
            return DayBucket(id: offset, label: f.string(from: day), units: units)
        }
    }

    private func longestSoberStreak(_ history: [NightSession]) -> Int {
        let sorted = history.map { Calendar.current.startOfDay(for: $0.startedAt) }.sorted()
        guard sorted.count >= 2 else { return 0 }
        var best = 0
        for i in 1..<sorted.count {
            let days = Calendar.current.dateComponents([.day], from: sorted[i-1], to: sorted[i]).day ?? 0
            best = max(best, max(0, days - 1))
        }
        return best
    }
}
