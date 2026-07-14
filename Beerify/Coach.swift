//
//  Coach.swift
//  Beerify
//
//  Rule-based coach. Reads BAC, target zone and pacing, then talks like a
//  friend who wants you to have a great night AND a great morning.
//  Ported from beerify/src/lib/coach.ts.
//

import Foundation

enum Coach {

    static func zoneStatus(bac: Double, session: NightSession) -> ZoneStatus {
        let target = TargetsCatalog.target(session.targetId)
        if bac < 0.005 { return .sober }
        if bac < target.minBac { return .warming }
        if bac <= target.maxBac { return .inZone }
        if bac <= target.maxBac + 0.03 { return .over }
        return .wayOver
    }

    private static func pick<T>(_ arr: [T], seed: Int) -> T {
        arr[abs(seed) % arr.count]
    }

    private static func minutesSinceLastDrink(_ session: NightSession, now: Date) -> Double? {
        guard let last = session.drinks.map({ $0.at }).max() else { return nil }
        return now.timeIntervalSince(last) / 60
    }

    private static func recentWater(_ session: NightSession, now: Date) -> Bool {
        session.waters.contains { now.timeIntervalSince($0) < 45 * 60 }
    }

    static func message(session: NightSession, profile: Profile, now: Date,
                        personality: CoachPersonality = .friend) -> CoachMessage {
        let base = baseMessage(session: session, profile: profile, now: now)
        return recolor(base, personality: personality)
    }

    /// Convenience for callers that don't yet pass personality.
    static func message(session: NightSession, profile: Profile, now: Date) -> CoachMessage {
        message(session: session, profile: profile, now: now, personality: .friend)
    }

    private static func recolor(_ msg: CoachMessage, personality: CoachPersonality) -> CoachMessage {
        switch personality {
        case .friend: return msg
        case .elder:
            let prefix: String = {
                switch msg.tone {
                case .cheer: return "🧙‍♂️ "
                case .chill: return "🧘 "
                case .nudge: return "🕯 "
                case .warn: return "⚠️ "
                }
            }()
            return CoachMessage(tone: msg.tone, text: prefix + msg.text, tip: msg.tip)
        case .gremlin:
            let text: String
            switch msg.tone {
            case .cheer: text = msg.text + " Do another? 😈"
            case .chill: text = msg.text + " Boring! One more!"
            case .nudge: text = msg.text.replacingOccurrences(of: "water", with: "shot", options: .caseInsensitive)
            case .warn: text = msg.text  // gremlin still respects real warnings
            }
            return CoachMessage(tone: msg.tone, text: text, tip: msg.tip)
        }
    }

    /// Deep hangover forecast — 0-100 severity based on total units,
    /// water:drink ratio, and session length.
    static func hangoverScore(session: NightSession, profile: Profile) -> Int {
        let units = session.drinks.reduce(0.0) { $0 + $1.units }
        let waters = Double(session.waters.count)
        let hours = ((session.endedAt ?? Date()).timeIntervalSince(session.startedAt)) / 3600.0
        let hydration = max(0, waters - units / 4)  // roughly 1 water per 4 units offsets
        let base = min(100, units * 12)             // 8 units ≈ 96/100
        let bonus = min(20, hours * 2)              // longer nights hurt more
        let relief = min(35, hydration * 8)         // waters help
        return max(0, Int(base + bonus - relief))
    }

    static func hangoverBanner(score: Int) -> (emoji: String, label: String, body: String) {
        switch score {
        case 0..<20: return ("😌", "Mild", "Should feel fresh with a glass of water and breakfast.")
        case 20..<45: return ("🥴", "Mild-medium", "Coffee, water, and a proper meal will sort you out.")
        case 45..<70: return ("😵", "Medium", "Plan a slow morning: eggs, water, walk.")
        case 70..<90: return ("💀", "Rough", "Cancel morning plans. Rehydrate aggressively.")
        default: return ("☠️", "Brutal", "This is the 'never again' zone. Water, electrolytes, blackout blinds.")
        }
    }

    private static func baseMessage(session: NightSession, profile: Profile, now: Date) -> CoachMessage {
        let bac = BAC.estimate(drinks: session.drinks, profile: profile, at: now)
        let inThirty = BAC.project(drinks: session.drinks, profile: profile, from: now, minutes: 30)
        let rising = inThirty > bac + 0.002
        let status = zoneStatus(bac: bac, session: session)
        let target = TargetsCatalog.target(session.targetId)
        let seed = session.drinks.count * 7
            + session.waters.count * 3
            + Int(now.timeIntervalSince1970 / 600)
        let sinceLast = minutesSinceLastDrink(session, now: now)
        let hadWater = recentWater(session, now: now)
        let firstName = profile.name.split(separator: " ").first.map(String.init) ?? "friend"

        switch status {
        case .sober:
            if session.drinks.isEmpty {
                return CoachMessage(tone: .cheer,
                    text: pick([
                        "Fresh night, \(firstName)! Tap a drink below when you start.",
                        "All set. Your target is “\(target.label)” \(target.emoji). Tap as you sip.",
                        "Ready when you are. First one's on you. 😉",
                    ], seed: seed),
                    tip: "Eating before you drink slows absorption and smooths the ride.")
            }
            if let s = sinceLast, s < 25 {
                return CoachMessage(tone: .cheer,
                    text: pick([
                        "That one is on its way in. Give it a few minutes to land. 🚀",
                        "Nice. Your body is unpacking that drink right now.",
                        "Incoming! Watch the mug fill up as it hits.",
                    ], seed: seed),
                    tip: "A drink takes 20 to 40 minutes to fully show up. No need to chase it.")
            }
            return CoachMessage(tone: .chill,
                text: pick([
                    "Pretty much sober again. Round two, or call it a night?",
                    "You've landed back at zero. Nicely done.",
                ], seed: seed), tip: nil)

        case .warming:
            if rising {
                let tip: String? = (sinceLast.map { $0 < 10 } == true)
                    ? "Give each drink ~30 min to land before judging it." : nil
                return CoachMessage(tone: .cheer,
                    text: pick([
                        "Warming up nicely. You're on track for “\(target.label)” \(target.emoji).",
                        "That last one is still kicking in. Cruise for a bit.",
                        "On the way up. No rush, the zone will come to you.",
                    ], seed: seed), tip: tip)
            }
            return CoachMessage(tone: .chill,
                text: pick([
                    "You're drifting below the zone. One more would top you back up.",
                    "Buzz is fading. Your call: another round, or ride it out?",
                ], seed: seed), tip: nil)

        case .inZone:
            if rising {
                let overshoot = BAC.project(drinks: session.drinks, profile: profile, from: now, minutes: 45) > target.maxBac
                if overshoot {
                    return CoachMessage(tone: .nudge,
                        text: pick([
                            "You're in the zone, but what's in your system will push you past it. Skip the next round.",
                            "Perfect spot right now, and still climbing. Hold off a while to stay here.",
                        ], seed: seed),
                        tip: hadWater ? nil : "Grab a water. It buys you time in the zone.")
                }
                return CoachMessage(tone: .cheer,
                    text: pick([
                        "You're IN the zone \(target.emoji). This is the good stuff. Keep this pace.",
                        "Chef's kiss. Exactly where you wanted to be.",
                    ], seed: seed),
                    tip: hadWater ? nil : "A water between rounds keeps you here longer.")
            }
            let minsLeft = BAC.minutesUntilBac(drinks: session.drinks, profile: profile, from: now, targetBac: target.minBac)
            let rounded = Int((Double(minsLeft) / 10.0).rounded()) * 10
            return CoachMessage(tone: .cheer,
                text: pick([
                    "In the zone and gliding. You've got ~\(rounded) min before it fades.",
                    "Holding steady in “\(target.label)”. You've mastered this.",
                ], seed: seed), tip: nil)

        case .over:
            let minsBack = BAC.minutesUntilBac(drinks: session.drinks, profile: profile, from: now, targetBac: target.maxBac)
            return CoachMessage(tone: .nudge,
                text: pick([
                    "You've floated past your zone. No more for now. You'll drift back in about \(minsBack) min.",
                    "A touch over target. Water, snack, dance break. Anything but another drink.",
                    "Past the sweet spot. Pause here and let your liver catch up (~\(minsBack) min).",
                ], seed: seed),
                tip: hadWater ? "Good hydration! Keep it up." : "Order a big water. Future-you says thanks.")

        case .wayOver:
            return CoachMessage(tone: .warn,
                text: pick([
                    "Well past your target, \(firstName). Stop drinking, get water and food, and stay with friends.",
                    "This is over the fun line. No more alcohol tonight. Water and a mate nearby, please.",
                ], seed: seed),
                tip: "If anyone feels unwell or unresponsive, get help immediately.")
        }
    }

    struct Verdict { let headline: String; let body: String }

    static func morningVerdict(session: NightSession, profile: Profile) -> Verdict {
        let target = TargetsCatalog.target(session.targetId)
        let end = session.endedAt ?? Date()
        let start = session.startedAt

        var peak = 0.0
        var inZoneSec: TimeInterval = 0
        var overSec: TimeInterval = 0
        let step: TimeInterval = 5 * 60
        var t = start
        while t <= end {
            let b = BAC.estimate(drinks: session.drinks, profile: profile, at: t)
            peak = max(peak, b)
            if b >= target.minBac && b <= target.maxBac { inZoneSec += step }
            if b > target.maxBac { overSec += step }
            t = t.addingTimeInterval(step)
        }
        let inZoneMin = Int((inZoneSec / 60).rounded())
        let overMin = Int((overSec / 60).rounded())

        if session.drinks.isEmpty {
            return Verdict(headline: "A perfectly sober night 🌙",
                           body: "Zero drinks logged. Your liver sends a thank-you card.")
        }
        if overMin == 0 && inZoneMin > 0 {
            return Verdict(headline: "Nailed it 🎯",
                           body: "You spent about \(inZoneMin) minutes in your “\(target.label)” zone and never overshot. Textbook night.")
        }
        if overMin > 0 && overMin <= 45 {
            return Verdict(headline: "Pretty solid 👏",
                           body: "Mostly on target, with roughly \(overMin) minutes over the line. A water between rounds would've kept it perfect.")
        }
        if overMin > 45 {
            return Verdict(headline: "A big one 😅",
                           body: "You were over your target for about \(overMin) minutes. Hydrate today, eat something real, and go easier next time.")
        }
        return Verdict(headline: "Easy does it 😌",
                       body: "You kept things light and never quite reached the “\(target.label)” zone. Zero regrets guaranteed.")
    }
}
