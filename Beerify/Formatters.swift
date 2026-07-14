//
//  Formatters.swift
//  Beerify
//

import Foundation

enum Fmt {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func nightDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func units(_ units: Double) -> String {
        let rounded = (units * 10).rounded() / 10
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%.1f", rounded)
    }

    static func timeAgo(from date: Date) -> String {
        let mins = Int(((Date().timeIntervalSince(date)) / 60).rounded())
        if mins < 2 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(Int((Double(mins) / 60).rounded()))h ago"
    }

    static func duration(minutes: Int) -> String {
        if minutes <= 0 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
