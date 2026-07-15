//
//  SummaryView.swift
//  Beerify
//

import SwiftUI

private let WEEKLY_GUIDELINE_UNITS: Double = 14

struct SummaryView: View {
    let session: NightSession
    let profile: Profile
    let onClose: () -> Void

    private var target: Target { TargetsCatalog.target(session.targetId) }
    private var end: Date { session.endedAt ?? Date() }

    private var stats: Stats {
        var totalUnits = 0.0
        for d in session.drinks { totalUnits += d.units }

        var peak: Double = 0
        var peakAt = session.startedAt
        var t = session.startedAt
        while t <= end {
            let b = BAC.estimate(drinks: session.drinks, profile: profile, at: t)
            if b > peak { peak = b; peakAt = t }
            t = t.addingTimeInterval(5 * 60)
        }
        let soberInMin = BAC.minutesUntilBac(drinks: session.drinks, profile: profile, from: end, targetBac: 0.005)
        let soberAt = end.addingTimeInterval(Double(soberInMin) * 60)

        var byType: [DrinkTypeId: (count: Int, units: Double)] = [:]
        for d in session.drinks {
            var entry = byType[d.type] ?? (0, 0)
            entry.count += 1
            entry.units += d.units
            byType[d.type] = entry
        }

        return Stats(
            totalUnits: totalUnits, peak: peak, peakAt: peakAt,
            soberAt: soberAt, soberInMin: soberInMin, byType: byType
        )
    }

    var body: some View {
        let verdict = Coach.morningVerdict(session: session, profile: profile)
        let s = stats
        let hangoverScore = Coach.hangoverScore(session: session, profile: profile)
        let hangover = Coach.hangoverBanner(score: hangoverScore)
        let earnedBadges = Badges.evaluate(session: session, profile: profile, history: [])

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("☀️").font(.system(size: 56))
                    Text(verdict.headline)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(verdict.body)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(Fmt.nightDate(session.startedAt))
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                }

                // Hangover forecast
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(hangover.emoji).font(.system(size: 36))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hangover forecast - \(hangover.label)")
                                .font(.headline).foregroundStyle(Theme.ink)
                            Text(hangover.body).font(.caption).foregroundStyle(Theme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    ProgressView(value: Double(hangoverScore), total: 100)
                        .tint(hangoverScore > 70 ? Theme.danger :
                              hangoverScore > 45 ? Theme.warning : Theme.success)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.9)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))

                if !earnedBadges.isEmpty {
                    Text("Badges earned").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(earnedBadges) { b in
                            HStack(spacing: 10) {
                                Text(b.emoji).font(.system(size: 28))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(b.title).font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                                    Text(b.subtitle).font(.caption2).foregroundStyle(Theme.inkSoft)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.18)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statTile(value: Fmt.units(s.totalUnits), label: "units of alcohol")
                    statTile(value: "\(session.drinks.count)", label: "drinks logged")
                    statTile(value: BAC.format(s.peak), label: "peak BAC% · \(Fmt.time(s.peakAt))")
                    statTile(value: "\(session.waters.count) 💧", label: "water breaks")
                }

                if !session.drinks.isEmpty {
                    Text("What you had").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                    VStack(spacing: 6) {
                        ForEach(Array(s.byType.keys.sorted { $0.rawValue < $1.rawValue }), id: \.self) { key in
                            if let entry = s.byType[key], let def = DrinksCatalog.types[key] {
                                HStack {
                                    Text(def.emoji).font(.title3)
                                    Text("\(entry.count)× \(def.label)").font(.subheadline).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Text("\(Fmt.units(entry.units)) units")
                                        .font(.subheadline.weight(.semibold))
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

                VStack(alignment: .leading, spacing: 10) {
                    if s.soberInMin > 5 && !session.drinks.isEmpty {
                        Text("⏳ Your body may still be processing alcohol. Estimated clear time: around **\(Fmt.time(s.soberAt))**. This is a rough estimate, not medical advice.")
                    }
                    Text("📊 That's **\(Fmt.units(s.totalUnits))** of the \(Int(WEEKLY_GUIDELINE_UNITS)) units many health guidelines suggest as a weekly maximum\(s.totalUnits > WEEKLY_GUIDELINE_UNITS ? ". A lighter week ahead would be smart" : "").")
                    Text("🎯 Target was “\(target.label)” \(target.emoji). \(session.drinks.isEmpty ? "Nothing logged, nothing to judge!" : "Check the verdict above for how it went.")")
                    Text("💧 Water + a proper breakfast = the official Beerify recovery plan.")
                }
                .font(.callout)
                .foregroundStyle(Theme.ink)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.75)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))

                Button {
                    onClose()
                } label: {
                    Text("Got it, back home")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .controlSize(.large)
                .shadow(color: Theme.accent.opacity(0.30), radius: 12, x: 0, y: 6)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(BeerifyBackground())
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label).font(.caption).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
        .shadow(color: Theme.ink.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private struct Stats {
        let totalUnits: Double
        let peak: Double
        let peakAt: Date
        let soberAt: Date
        let soberInMin: Int
        let byType: [DrinkTypeId: (count: Int, units: Double)]
    }
}
