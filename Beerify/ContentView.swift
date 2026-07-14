//
//  ContentView.swift
//  Beerify
//
//  Routes between Onboarding / Home / Night Out / Summary based on app state.
//  Mirrors the top-level switch in beerify/src/App.tsx.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @State private var viewingSummary: NightSession? = nil
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            if store.data.profile == nil {
                OnboardingView { profile in
                    store.setProfile(profile)
                }
                .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 1.04))))
            } else if let session = viewingSummary {
                SummaryView(session: session, profile: store.data.profile!) {
                    viewingSummary = nil
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                tabRoot
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: store.data.profile == nil)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewingSummary?.id)
    }

    @ViewBuilder
    private var tonightTab: some View {
        if let session = store.data.session {
            NightOutView(
                session: session,
                profile: store.data.profile!,
                membership: store.data.room,
                onLogDrink: store.logDrink,
                onLogDrinkVariant: store.logDrinkVariant,
                onLogWater: store.logWater,
                onUndo: store.undoDrink,
                onEndNight: store.endNight
            )
        } else {
            HomeView(
                profile: store.data.profile!,
                history: store.data.history,
                unreviewed: store.unreviewedSummary,
                membership: store.data.room,
                onStartNight: store.startNight,
                onOpenSummary: { session in
                    store.markReviewed(sessionId: session.id)
                    viewingSummary = session
                },
                onJoinRoom: store.joinRoom,
                onLeaveRoom: store.leaveRoom
            )
        }
    }

    private var tabRoot: some View {
        TabView(selection: $selectedTab) {
            tonightTab
                .tabItem { Label("Tonight", systemImage: "moon.stars.fill") }
                .tag(0)

            NavigationStack { GamesHub() }
                .tabItem { Label("Games", systemImage: "gamecontroller.fill") }
                .tag(1)

            NavigationStack { StatsView() }
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(2)

            NavigationStack { PubMapView() }
                .tabItem { Label("Pubs", systemImage: "map.fill") }
                .tag(3)

            NavigationStack { SettingsView() }
                .tabItem { Label("You", systemImage: "person.crop.circle.fill") }
                .tag(4)
        }
        .tint(Theme.accentDeep)
    }
}

#Preview {
    ContentView()
        .environment(AppStore())
}
