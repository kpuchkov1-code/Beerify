//
//  BeerifyApp.swift
//  Beerify
//

import SwiftUI

@main
struct BeerifyApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    @State private var store = AppStore()
    @State private var roomService = RoomService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(roomService)
                .preferredColorScheme(.light)
                .tint(Theme.accent)
        }
    }
}
