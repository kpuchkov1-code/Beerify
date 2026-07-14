//
//  HomeView.swift
//  Beerify
//

import SwiftUI

struct HomeView: View {
    let profile: Profile
    let history: [NightSession]
    let unreviewed: NightSession?
    let membership: RoomMembership?
    let onStartNight: (TargetId) -> Void
    let onOpenSummary: (NightSession) -> Void
    let onJoinRoom: (RoomMembership) -> Void
    let onLeaveRoom: () -> Void

    @State private var target: TargetId = .tipsy

    private var firstName: String {
        profile.name.split(separator: " ").first.map(String.init) ?? profile.name
    }
    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Morning" }
        if h < 18 { return "Afternoon" }
        return "Evening"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(greeting), \(firstName) 👋")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("How merry are we getting tonight?")
                        .foregroundStyle(Theme.inkSoft)
                }

                if let unreviewed {
                    Button {
                        onOpenSummary(unreviewed)
                    } label: {
                        HStack(spacing: 12) {
                            Text("☀️").font(.system(size: 32))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Your night recap is ready")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.ink)
                                Text("\(Fmt.nightDate(unreviewed.startedAt)) · Tap to see your units")
                                    .font(.caption).foregroundStyle(Theme.inkSoft)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent.opacity(0.22)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.45), lineWidth: 1))
                        .shadow(color: Theme.accent.opacity(0.22), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(BeerifyPressStyle())
                }

                Text("Tonight's vibe")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)

                VStack(spacing: 10) {
                    ForEach(TargetsCatalog.order, id: \.self) { id in
                        let t = TargetsCatalog.target(id)
                        let active = target == id
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                target = id
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(t.emoji).font(.system(size: 32))
                                    .scaleEffect(active ? 1.1 : 1.0)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.label).font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                                    Text(t.tagline)
                                        .font(.caption).foregroundStyle(Theme.inkSoft)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                if active {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Theme.accent)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(active ? Theme.accent.opacity(0.20) : Theme.surface.opacity(0.90))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(active ? Theme.accent : Theme.hairline,
                                            lineWidth: active ? 1.8 : 1.0)
                            )
                            .shadow(color: active ? Theme.accent.opacity(0.22) : Theme.ink.opacity(0.05),
                                    radius: active ? 12 : 6, x: 0, y: active ? 6 : 3)
                        }
                        .buttonStyle(BeerifyPressStyle())
                    }
                }

                if let warning = TargetsCatalog.target(target).warning {
                    Text("⚠️ \(warning)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.warning.opacity(0.14)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.warning.opacity(0.35), lineWidth: 1))
                }

                Button {
                    onStartNight(target)
                } label: {
                    Text("Start night out 🌙")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .controlSize(.large)
                .shadow(color: Theme.accent.opacity(0.35), radius: 14, x: 0, y: 8)

                RoomPanelView(
                    profile: profile,
                    membership: membership,
                    onJoin: onJoinRoom,
                    onLeave: onLeaveRoom
                )

                if !history.isEmpty {
                    Text("Past nights").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                    VStack(spacing: 6) {
                        ForEach(history
                            .sorted(by: { $0.startedAt > $1.startedAt })
                            .prefix(10), id: \.id) { s in
                            Button {
                                onOpenSummary(s)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(TargetsCatalog.target(s.targetId).emoji).font(.system(size: 24))
                                    Text(Fmt.nightDate(s.startedAt))
                                        .font(.subheadline).foregroundStyle(Theme.ink)
                                    Spacer()
                                    let units = s.drinks.reduce(0.0) { $0 + $1.units }
                                    Text("\(Fmt.units(units)) units")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.inkSoft)
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(Theme.inkSoft)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface.opacity(0.90)))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
                                .shadow(color: Theme.ink.opacity(0.05), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(BeerifyPressStyle())
                        }
                    }
                }

                Text("Beerify estimates are a friendly guide, not a breathalyser. Never drink and drive.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
            .padding(20)
        }
        .background(BeerifyBackground())
    }
}
