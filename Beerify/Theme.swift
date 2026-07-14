//
//  Theme.swift
//  Beerify
//
//  Central palette for the app. The app is intentionally light-only: it lives
//  on a warm amber gradient, so all text/surfaces are tuned against that,
//  not against the system's adaptive light/dark colors.
//

import SwiftUI

enum Theme {
    // Text
    static let ink = Color(red: 0.20, green: 0.11, blue: 0.04)          // deep espresso
    static let inkSoft = Color(red: 0.42, green: 0.28, blue: 0.14)      // cocoa
    static let inkMuted = Color(red: 0.55, green: 0.42, blue: 0.28)     // caramel-gray

    // Brand
    static let accent = Color(red: 0.98, green: 0.55, blue: 0.10)       // Beerify amber
    static let accentDeep = Color(red: 0.85, green: 0.40, blue: 0.02)   // roasted amber

    // Surfaces (cards on the amber background)
    static let surface = Color(red: 1.00, green: 0.99, blue: 0.94)      // warm ivory
    static let surfaceStrong = Color(red: 1.00, green: 0.97, blue: 0.88) // creamer
    static let hairline = Color(red: 0.85, green: 0.72, blue: 0.50).opacity(0.5)

    // Semantic
    static let success = Color(red: 0.14, green: 0.52, blue: 0.25)
    static let info = Color(red: 0.10, green: 0.42, blue: 0.75)
    static let warning = Color(red: 0.80, green: 0.45, blue: 0.05)
    static let danger = Color(red: 0.78, green: 0.15, blue: 0.15)
}

/// Springy press feedback for custom-styled buttons. Replaces `.plain` where
/// we want the button to feel like it has physical weight.
struct BeerifyPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.55),
                       value: configuration.isPressed)
    }
}
