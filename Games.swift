//
//  Games.swift
//  Beerify
//
//  All in-app mini-games. Each is a standalone SwiftUI view launched from
//  the Games hub. Games are self-contained: no persistence, no networking
//  (except Roulette, which reads the current squad from RoomService).
//

import SwiftUI

// MARK: - Games hub

struct GamesHub: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoomService.self) private var roomService
    @Environment(AppStore.self) private var store

    private let games: [GameEntry] = [
        // Best games first - actual mechanics, not just card-flipping
        .init(id: "headsup", title: "Heads Up!", emoji: "📱", subtitle: "Phone on forehead - friends describe, you guess. Tilt to play!"),
        .init(id: "psych", title: "Psych!", emoji: "🧠", subtitle: "Write fake answers to real trivia - best bluffer wins"),
        .init(id: "hottakes", title: "Hot Takes 🔥", emoji: "🗳", subtitle: "Vote agree or disagree - minority drinks"),
        .init(id: "bombpass", title: "Bomb Pass", emoji: "💣", subtitle: "Do the dare before the bomb blows - hot potato chaos"),
        .init(id: "medusa", title: "Medusa", emoji: "🐍", subtitle: "Pick who you look at - mutual eye contact = both drink"),
        .init(id: "busdriver", title: "Bus Driver", emoji: "🚌", subtitle: "Red/black, high/low, suit - classic card drinking game"),
        .init(id: "dareladder", title: "Dare Ladder 🔥", emoji: "🪜", subtitle: "5 rungs of escalating dares - chicken out = drink double"),
        .init(id: "flipcup", title: "Flip Cup", emoji: "⚡", subtitle: "Reaction time showdown - slowest drinks"),
        .init(id: "whosaidit", title: "Who Said It?", emoji: "🕵️", subtitle: "Anonymous answers - guess who wrote what"),
        .init(id: "ranked", title: "ID Game 🔥", emoji: "🪪", subtitle: "Rank the squad, others guess your question"),
        .init(id: "hilo", title: "Higher or Lower 🔥", emoji: "📈", subtitle: "Spicy 0–10 ratings - higher or lower?"),
        .init(id: "kings", title: "Kings Cup", emoji: "👑", subtitle: "Draw a card, follow the rule"),
        .init(id: "wyr", title: "Would You Rather 🔥", emoji: "🤔", subtitle: "Impossible dilemmas"),
        .init(id: "mlt", title: "Most Likely To 🔥", emoji: "👉", subtitle: "Everyone votes, one drinks"),
        .init(id: "nhie", title: "Never Have I Ever 🔥", emoji: "🙅", subtitle: "🟢 have · 🔴 haven't"),
        .init(id: "tod", title: "Truth or Dare 🔥", emoji: "🎭", subtitle: "Pick your poison"),
        .init(id: "trivia", title: "Trivia Sprint", emoji: "⏱", subtitle: "60-second rounds"),
        .init(id: "ttl", title: "Two Truths & a Lie", emoji: "🕵", subtitle: "Sell the story, spot the fake"),
        .init(id: "cat", title: "Categories", emoji: "🧠", subtitle: "Name one - fast"),
        .init(id: "emoji", title: "Emoji Charades", emoji: "💬", subtitle: "Guess the phrase"),
        .init(id: "roulette", title: "Roulette", emoji: "🎯", subtitle: "Pick who's next"),
        .init(id: "guessbac", title: "Guess My BAC", emoji: "🎲", subtitle: "How buzzed am I?"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pick your poison")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("Squad-friendly ways to make the night silly.")
                        .foregroundStyle(Theme.inkSoft)
                }

                spicinessChip

                NavigationLink {
                    LeaderboardView()
                        .navigationTitle("Leaderboard")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    HStack(spacing: 12) {
                        Text("🏆").font(.system(size: 36))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Squad leaderboard").font(.headline).foregroundStyle(Theme.ink)
                            Text(leaderboardSubtitle).font(.caption).foregroundStyle(Theme.inkSoft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent.opacity(0.22)))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(BeerifyPressStyle())

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(games) { g in
                        NavigationLink {
                            destination(for: g.id)
                                .navigationTitle(g.title)
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            gameTile(g)
                        }
                        .buttonStyle(BeerifyPressStyle())
                    }
                }
            }
            .padding(20)
        }
        .background(BeerifyBackground())
    }

    private func gameTile(_ g: GameEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(g.emoji).font(.system(size: 44))
            Text(g.title).font(.headline).foregroundStyle(Theme.ink)
            Text(g.subtitle).font(.caption).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline, lineWidth: 1))
        .shadow(color: Theme.ink.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder
    private func destination(for id: String) -> some View {
        switch id {
        case "headsup": HeadsUpGame()
        case "psych": PsychBluffGame()
        case "hottakes": HotTakesGame()
        case "bombpass": BombPassGame()
        case "medusa": MedusaGame()
        case "busdriver": BusDriverGame()
        case "dareladder": DareLadderGame()
        case "whosaidit": WhoSaidItGame()
        case "flipcup": FlipCupGame()
        case "ranked": RankedGame()
        case "wyr": WouldYouRatherGame()
        case "mlt": MostLikelyToGame()
        case "ttl": TwoTruthsAndALieGame()
        case "kings": KingsCupGame()
        case "nhie": NeverHaveIEverGame()
        case "roulette": RouletteGame()
        case "hilo": HigherLowerGame()
        case "guessbac": GuessMyBACGame()
        case "tod": TruthOrDareGame()
        case "cat": CategoriesGame()
        case "emoji": EmojiCharadesGame()
        case "trivia": TriviaGame()
        default: EmptyView()
        }
    }

    private struct GameEntry: Identifiable {
        let id: String; let title: String; let emoji: String; let subtitle: String
    }

    private var leaderboardSubtitle: String {
        let count = roomService.scoreboard.count
        if count == 0 { return "Play a scored game to start the board." }
        return "\(count) score\(count == 1 ? "" : "s") in the squad"
    }

    private var spicinessChip: some View {
        let level = store.data.preferences.spiciness
        let emoji: String = {
            switch level {
            case 1: return "🍼"; case 2: return "🙂"; case 3: return "😏"
            case 4: return "🌶"; default: return "🔥"
            }
        }()
        return HStack(spacing: 8) {
            Text(emoji)
            Text("Spiciness \(level)/5").font(.caption.weight(.semibold)).foregroundStyle(Theme.ink)
            Slider(
                value: Binding(
                    get: { Double(store.data.preferences.spiciness) },
                    set: { newVal in
                        store.updatePreferences { $0.spiciness = max(1, min(5, Int(newVal.rounded()))) }
                    }
                ),
                in: 1...5, step: 1
            )
            .tint(Theme.accent)
            .frame(maxWidth: 120)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
    }
}



// MARK: - Leaderboard

struct LeaderboardView: View {
    @Environment(RoomService.self) private var roomService

    private let scored: [(id: String, name: String, emoji: String, unit: String)] = [
        ("ranked", "ID Game", "🪪", "correct guesses"),
        ("hilo", "Higher or Lower", "📈", "streak"),
        ("trivia", "Trivia Sprint", "⚡", "%"),
        ("guessbac", "Guess My BAC", "🎲", "% accurate"),
        ("nhie", "Never Have I Ever", "🙅", "adventurous"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if roomService.state == nil {
                    empty(text: "Join or create a room to start a squad leaderboard.")
                } else if roomService.scoreboard.isEmpty {
                    empty(text: "No scores yet - play a scored round.")
                } else {
                    ForEach(scored, id: \.id) { g in
                        section(for: g)
                    }
                }
            }
            .padding(20)
        }
        .background(BeerifyBackground())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Squad leaderboard")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            if let code = roomService.state?.code {
                Text("Room · \(code)").font(.caption).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private func empty(text: String) -> some View {
        VStack(spacing: 8) {
            Text("🏆").font(.system(size: 44))
            Text(text)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(24).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
    }

    private func section(for g: (id: String, name: String, emoji: String, unit: String)) -> some View {
        let scores = roomService.scoreboard.values
            .filter { $0.gameId == g.id }
            .sorted { $0.score > $1.score }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(g.emoji).font(.title2)
                Text(g.name).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                Spacer()
            }
            if scores.isEmpty {
                Text("No scores yet - you could be #1.")
                    .font(.caption).foregroundStyle(Theme.inkSoft)
                    .padding(.leading, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(scores.enumerated()), id: \.offset) { i, s in
                        row(rank: i + 1, entry: s, unit: g.unit)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
    }

    private func row(rank: Int, entry: GameScoreEntry, unit: String) -> some View {
        HStack(spacing: 10) {
            Text(rankBadge(rank))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .frame(width: 28)
            Text(Avatars.avatar(for: entry.memberId)).font(.title3)
            Text(entry.memberName).font(.subheadline).foregroundStyle(Theme.ink)
            Spacer()
            Text("\(entry.score) \(unit)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.accentDeep)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(rank == 1 ? Theme.accent.opacity(0.15) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(rank == 1 ? Theme.accent.opacity(0.4) : Color.clear, lineWidth: 1))
    }

    private func rankBadge(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(rank)"
        }
    }
}

// MARK: - Prompt filtering

/// One line in a spicy game deck. `level` is 1 (family-safe) → 5 (unfiltered).
/// Views filter these against `UserPreferences.spiciness`.
struct SpicyPrompt {
    let text: String
    let level: Int
}

extension Array where Element == SpicyPrompt {
    /// Prompts at or below the given spiciness threshold, as plain strings.
    func upTo(_ spiciness: Int) -> [String] {
        self.filter { $0.level <= spiciness }.map(\.text)
    }
}

/// Picks a random element from `pool` while avoiding items in `recent`.
/// Falls back to the full pool when every item is in the recent window.
/// Appends the pick to `recent` and trims to `windowSize`.
func rotatedPick<T: Equatable>(from pool: [T], recent: inout [T], windowSize: Int) -> T? {
    guard !pool.isEmpty else { return nil }
    let candidates = pool.filter { !recent.contains($0) }
    let choice = (candidates.isEmpty ? pool : candidates).randomElement()!
    recent.append(choice)
    let cap = min(windowSize, max(0, pool.count - 1))
    if recent.count > cap { recent.removeFirst(recent.count - cap) }
    return choice
}

// MARK: - Shared

private struct GameChrome<Content: View>: View {
    let content: () -> Content
    var body: some View {
        ScrollView { VStack(spacing: 20) { content() }.padding(20) }
            .background(BeerifyBackground())
    }
}

private struct BigActionButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
    }
}

private func hapticTap() {
    #if canImport(UIKit) && !os(macOS)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    #endif
}

// MARK: - Kings Cup

struct KingsCupGame: View {
    @State private var deck: [Int] = Array(0..<52).shuffled()
    @State private var current: Int? = nil
    @State private var kingsDrunk: Int = 0

    private static let rules: [String: (title: String, body: String)] = [
        "A": ("Waterfall", "Everyone drinks. You can't stop until the person to your right stops."),
        "2": ("You", "Pick someone to drink."),
        "3": ("Me", "You drink."),
        "4": ("Floor", "Last person to touch the floor drinks."),
        "5": ("Guys", "All guys drink."),
        "6": ("Chicks", "All chicks drink."),
        "7": ("Heaven", "Last person to point up drinks."),
        "8": ("Mate", "Pick a mate - they drink when you drink for the rest of the game."),
        "9": ("Rhyme", "Say a word; go around rhyming. First to fail drinks."),
        "10": ("Categories", "Pick a category. Go around naming items. First to fail drinks."),
        "J": ("Never Have I Ever", "Play a quick round."),
        "Q": ("Question Master", "Anyone who answers your question drinks. Until the next Queen."),
        "K": ("King's Cup", "Pour some of your drink into the center cup. 4th king drinks the whole thing."),
    ]

    var body: some View {
        GameChrome {
            VStack(spacing: 16) {
                if let idx = current {
                    let card = Self.cardName(idx)
                    let rank = Self.rank(idx)
                    let rule = Self.rules[rank] ?? ("", "")
                    Text(card).font(.system(size: 72))
                    Text(rule.title).font(.title.weight(.heavy)).foregroundStyle(Theme.ink)
                    Text(rule.body).multilineTextAlignment(.center)
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.horizontal, 12)
                    if rank == "K" {
                        Text("Kings poured: \(kingsDrunk)/4")
                            .font(.caption).foregroundStyle(Theme.inkSoft)
                    }
                } else {
                    Text("🂠").font(.system(size: 90))
                    Text("Ready when you are.").foregroundStyle(Theme.inkSoft)
                }
                BigActionButton(title: deck.isEmpty ? "Reshuffle" : "Draw a card") {
                    hapticTap()
                    if deck.isEmpty {
                        deck = Array(0..<52).shuffled()
                        kingsDrunk = 0
                        current = nil
                    } else {
                        let idx = deck.removeFirst()
                        if Self.rank(idx) == "K" { kingsDrunk += 1 }
                        current = idx
                    }
                }
                Text("\(deck.count) cards left")
                    .font(.caption).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private static func rank(_ idx: Int) -> String {
        let r = idx % 13
        switch r {
        case 0: return "A"; case 10: return "J"; case 11: return "Q"; case 12: return "K"
        default: return "\(r + 1)"
        }
    }

    private static func suit(_ idx: Int) -> String {
        ["♠️", "♥️", "♦️", "♣️"][idx / 13]
    }

    private static func cardName(_ idx: Int) -> String {
        "\(rank(idx))\(suit(idx))"
    }
}

// MARK: - Never Have I Ever

struct NeverHaveIEverGame: View {
    @Environment(RoomService.self) private var roomService
    @Environment(AppStore.self) private var store
    @State private var prompts: [String] = []
    @State private var index: Int = 0
    @State private var haveCount: Int = 0
    @State private var havenotCount: Int = 0

    private static let deck: [SpicyPrompt] = [
        // Level 1 - family-safe
        .init(text: "…gone viral (even briefly).", level: 1),
        .init(text: "…gotten stuck in an elevator.", level: 1),
        .init(text: "…re-gifted a Christmas present.", level: 1),
        .init(text: "…cried at a wedding.", level: 1),
        .init(text: "…faked being sick to skip work.", level: 1),
        .init(text: "…sung karaoke sober.", level: 1),
        .init(text: "…broken a bone doing something dumb.", level: 1),
        .init(text: "…fallen asleep in a public place.", level: 1),
        .init(text: "…lied about reading a book to sound smart.", level: 1),
        .init(text: "…called a teacher 'mum' or 'dad'.", level: 1),
        .init(text: "…met a celebrity in real life.", level: 1),
        .init(text: "…walked into a glass door.", level: 1),
        // Level 2 - mild party
        .init(text: "…been sent home from a bar.", level: 2),
        .init(text: "…gone skinny-dipping.", level: 2),
        .init(text: "…crashed a wedding.", level: 2),
        .init(text: "…lied about my age on a date.", level: 2),
        .init(text: "…been in a food fight.", level: 2),
        .init(text: "…had a crush on a teacher.", level: 2),
        .init(text: "…snuck into a movie theater.", level: 2),
        .init(text: "…thrown up in an Uber.", level: 2),
        .init(text: "…dine-and-dashed by accident.", level: 2),
        .init(text: "…blacked out and had to be told what I did.", level: 2),
        .init(text: "…snuck into a club underage.", level: 2),
        .init(text: "…pretended to be someone else on a night out.", level: 2),
        // Level 3 - medium
        .init(text: "…texted an ex at 2am.", level: 3),
        .init(text: "…kissed someone whose name I forgot.", level: 3),
        .init(text: "…lied to get out of a first date.", level: 3),
        .init(text: "…been ghosted mid-date.", level: 3),
        .init(text: "…stalked an ex on social media in the last month.", level: 3),
        .init(text: "…flirted my way out of a speeding ticket.", level: 3),
        .init(text: "…gotten a tattoo I regret.", level: 3),
        .init(text: "…kissed someone in this room.", level: 3),
        .init(text: "…had a rebound the same night as a breakup.", level: 3),
        .init(text: "…gone through a partner's phone.", level: 3),
        .init(text: "…lied about where I was to a partner.", level: 3),
        .init(text: "…kept a Tinder profile up while dating someone.", level: 3),
        .init(text: "…kissed two different people in one night.", level: 3),
        .init(text: "…been dumped by text.", level: 3),
        // Level 4 - spicy
        .init(text: "…screenshot a nude and shown a friend.", level: 4),
        .init(text: "…been caught lying by a partner.", level: 4),
        .init(text: "…hooked up in a public place.", level: 4),
        .init(text: "…faked how it ended.", level: 4),
        .init(text: "…lied about my number.", level: 4),
        .init(text: "…had a crush on a friend's partner.", level: 4),
        .init(text: "…been in a situationship for over a year.", level: 4),
        .init(text: "…caught feelings for someone I said I wouldn't.", level: 4),
        .init(text: "…hooked up with a coworker.", level: 4),
        .init(text: "…had a friends-with-benefits arrangement.", level: 4),
        .init(text: "…been dumped for someone else.", level: 4),
        .init(text: "…googled a hookup mid-hookup (to check something).", level: 4),
        // Level 5 - unfiltered adult chaos
        .init(text: "…hooked up with someone in this room.", level: 5),
        .init(text: "…had a threesome.", level: 5),
        .init(text: "…joined the mile-high club.", level: 5),
        .init(text: "…faked it more times than I've meant it.", level: 5),
        .init(text: "…hooked up with someone within an hour of meeting them.", level: 5),
        .init(text: "…hooked up with a friend's ex.", level: 5),
        .init(text: "…hooked up with someone whose name I never learned.", level: 5),
        .init(text: "…hooked up with someone twice my age.", level: 5),
        .init(text: "…had sex in my parents' house as an adult.", level: 5),
        .init(text: "…recorded a sex tape.", level: 5),
        .init(text: "…paid for a hookup - or been paid.", level: 5),
        .init(text: "…been the reason someone else got cheated on.", level: 5),
        .init(text: "…lied about being on birth control or wearing protection.", level: 5),
        .init(text: "…had sex on the first date this year.", level: 5),
        .init(text: "…sent a nude to the wrong person.", level: 5),
        .init(text: "…had sex in a car this year.", level: 5),
        .init(text: "…kept a hookup a secret from every friend I have.", level: 5),
        .init(text: "…hooked up with two different people in one day.", level: 5),
        .init(text: "…rated an ex publicly (out of 10).", level: 5),
        .init(text: "…googled 'am I in love with…' this year.", level: 5),
        .init(text: "…bailed on a hookup because they looked different in person.", level: 5),
        .init(text: "…kept a text thread I shouldn't have.", level: 5),
        .init(text: "…had a body count moment I'm not proud of.", level: 5),
        .init(text: "…screenshotted someone's nude to show a friend.", level: 5),
        .init(text: "…cheated and never got caught.", level: 5),
        .init(text: "…been cheated on and stayed.", level: 5),
        .init(text: "…had a hookup that ended with an apology text.", level: 5),
        .init(text: "…hooked up with someone at a wedding I attended.", level: 5),
        .init(text: "…swiped on my ex for revenge or curiosity.", level: 5),
        .init(text: "…considered getting back with an ex this week.", level: 5),
        .init(text: "…had sex somewhere I really shouldn't have.", level: 5),
        .init(text: "…finished in under a minute - and pretended otherwise.", level: 5),
        .init(text: "…hooked up with someone in a friend group without them knowing.", level: 5),
        .init(text: "…said 'I love you' just to seal the deal.", level: 5),
        .init(text: "…been blocked immediately after hooking up.", level: 5),
        .init(text: "…hooked up with a total stranger and never asked their name.", level: 5),
        // Level 5 bonus - unhinged
        .init(text: "…deleted an entire conversation before handing my phone to someone.", level: 5),
        .init(text: "…pretended to be someone else online to get information.", level: 5),
        .init(text: "…snooped through a partner's phone and found something I wish I hadn't.", level: 5),
        .init(text: "…done something I'd genuinely go to prison for if anyone found out.", level: 5),
        .init(text: "…manipulated someone into breaking up with their partner so I could make a move.", level: 5),
        .init(text: "…thrown up during sex and tried to keep going.", level: 5),
        .init(text: "…lied to everyone in this room about something major.", level: 5),
        .init(text: "…had a genuine moment where I questioned my own sanity.", level: 5),
        .init(text: "…stolen something from a hookup's house.", level: 5),
        .init(text: "…used someone purely for their money and felt zero guilt.", level: 5),
        .init(text: "…sabotaged a friend's relationship on purpose.", level: 5),
        .init(text: "…gone through someone's phone, laptop, and drawers while they were asleep.", level: 5),
        .init(text: "…kept hooking up with someone I had zero respect for.", level: 5),
        .init(text: "…let someone take the blame for something I did.", level: 5),
        .init(text: "…faked an entire personality trait to be more attractive to someone.", level: 5),
        .init(text: "…been genuinely afraid of what I might do if I got angry enough.", level: 5),
        // Bonus L1 - family safe
        .init(text: "…ridden a horse.", level: 1),
        .init(text: "…broken a bone before I turned 18.", level: 1),
        .init(text: "…lied about my age to buy something.", level: 1),
        .init(text: "…been on TV.", level: 1),
        .init(text: "…won a trophy or medal.", level: 1),
        .init(text: "…written a fan letter I never sent.", level: 1),
        .init(text: "…cried during a Disney movie as an adult.", level: 1),
        .init(text: "…faked a smile in a photo.", level: 1),
        .init(text: "…been to a foreign country.", level: 1),
        .init(text: "…lost my phone at a concert.", level: 1),
        .init(text: "…had food stuck in my teeth all day and no one told me.", level: 1),
        .init(text: "…finished a Netflix series in one sitting.", level: 1),
        // Bonus L2 - mild
        .init(text: "…had to be carried home.", level: 2),
        .init(text: "…been the drunkest at a family event.", level: 2),
        .init(text: "…snuck food out of a wedding.", level: 2),
        .init(text: "…lied on a resume.", level: 2),
        .init(text: "…faked being sober in front of my parents.", level: 2),
        .init(text: "…been kicked out of a shop.", level: 2),
        .init(text: "…snuck someone into a hotel.", level: 2),
        .init(text: "…done a runner from a restaurant.", level: 2),
        .init(text: "…yelled at a customer service rep.", level: 2),
        .init(text: "…gotten a really bad haircut mid-breakup.", level: 2),
        .init(text: "…lost something important on a night out.", level: 2),
        .init(text: "…climbed something I shouldn't have.", level: 2),
        // Bonus L3 - medium
        .init(text: "…faked being sick to skip a date.", level: 3),
        .init(text: "…pretended not to see someone I knew in public.", level: 3),
        .init(text: "…written a message on my phone I never had the guts to send.", level: 3),
        .init(text: "…felt jealous of my best friend's relationship.", level: 3),
        .init(text: "…lied to a therapist.", level: 3),
        .init(text: "…kept talking to an ex after being told not to.", level: 3),
        .init(text: "…googled 'how to make them jealous'.", level: 3),
        .init(text: "…kept a secret Insta or Snap.", level: 3),
        .init(text: "…faked crying to win an argument.", level: 3),
        .init(text: "…binge-watched something to avoid dealing with my feelings.", level: 3),
        .init(text: "…been on a date and known before dessert it wasn't going anywhere.", level: 3),
        .init(text: "…cried at work.", level: 3),
        .init(text: "…said 'I'm fine' when I definitely wasn't.", level: 3),
        // Bonus L4 - spicy
        .init(text: "…flirted my way out of trouble.", level: 4),
        .init(text: "…rebound-dated someone I didn't actually like.", level: 4),
        .init(text: "…blocked someone dramatically then unblocked them.", level: 4),
        .init(text: "…texted the wrong person something spicy - but salvaged it.", level: 4),
        .init(text: "…been the 'other person' unknowingly.", level: 4),
        .init(text: "…broken up with someone entirely because of how they text.", level: 4),
        .init(text: "…had a full first-date arc in one week and then ghosted.", level: 4),
        .init(text: "…stayed with someone way too long out of pity.", level: 4),
        .init(text: "…had a partner I was ashamed of.", level: 4),
        .init(text: "…been ashamed of a hookup the next morning.", level: 4),
        .init(text: "…made a whole friend group hate my partner.", level: 4),
        .init(text: "…been offered a threesome and said no.", level: 4),
        .init(text: "…been offered a threesome and said yes.", level: 4),
        .init(text: "…been jealous of a friend's love life.", level: 4),
        .init(text: "…lied about a first date being a good one.", level: 4),
        // Bonus L5 - unfiltered adult
        .init(text: "…had sex in the shower.", level: 5),
        .init(text: "…had sex outside.", level: 5),
        .init(text: "…had sex somewhere I could get arrested.", level: 5),
        .init(text: "…had sex in a hot tub or pool.", level: 5),
        .init(text: "…had sex at work.", level: 5),
        .init(text: "…had sex at a wedding I attended.", level: 5),
        .init(text: "…had sex at a family event.", level: 5),
        .init(text: "…finished before my partner even started.", level: 5),
        .init(text: "…been walked in on by a housemate.", level: 5),
        .init(text: "…hooked up with someone I met earlier that day.", level: 5),
        .init(text: "…had morning-after regret that lasted a week.", level: 5),
        .init(text: "…paid for a taxi to leave a hookup.", level: 5),
        .init(text: "…faked an orgasm to speed things up.", level: 5),
        .init(text: "…had a hookup that changed my type entirely.", level: 5),
        .init(text: "…had a partner tell me they'd rated me publicly.", level: 5),
        .init(text: "…had someone in this room shown up in a dream (spicy).", level: 5),
        .init(text: "…thought about a friend of a friend while alone.", level: 5),
        .init(text: "…had a partner cheat on me and told nobody.", level: 5),
        .init(text: "…cheated with someone I know I shouldn't have.", level: 5),
        .init(text: "…blocked all evidence of a hookup after.", level: 5),
        .init(text: "…hooked up with someone who was engaged.", level: 5),
        .init(text: "…been dumped for someone in this room.", level: 5),
        .init(text: "…kissed a friend at 4am and never spoken of it.", level: 5),
        .init(text: "…been paid or offered money for a nude.", level: 5),
        .init(text: "…streamed spicy content in public headphones-off.", level: 5),
        .init(text: "…hooked up in a locker room / gym.", level: 5),
        .init(text: "…had a friend's parent flirt with me.", level: 5),
        .init(text: "…been the reason someone else got dumped.", level: 5),
        .init(text: "…seen a partner's browser history and been shocked.", level: 5),
        .init(text: "…finished during a phone call - with them not knowing.", level: 5),
        // Level 5 bonus - darker / more personal
        .init(text: "…purposely started drama between two friends because I was bored.", level: 5),
        .init(text: "…been so jealous of someone I actively tried to make their life worse.", level: 5),
        .init(text: "…pretended to be happy for a friend's success while dying inside.", level: 5),
        .init(text: "…stayed friends with someone purely to keep tabs on them.", level: 5),
        .init(text: "…ruined something good on purpose because I didn't think I deserved it.", level: 5),
        .init(text: "…told someone's secret to someone else within 24 hours of hearing it.", level: 5),
        .init(text: "…completely fabricated a story to make myself look better in front of this group.", level: 5),
        .init(text: "…been genuinely disgusted by a close friend's life choice but said nothing.", level: 5),
        .init(text: "…kept a friendship alive only because they're useful to me.", level: 5),
        .init(text: "…done something behind a best friend's back that would end the friendship if they knew.", level: 5),
        .init(text: "…looked through someone's phone while they were asleep next to me.", level: 5),
        .init(text: "…had an intrusive thought so dark I've never said it out loud.", level: 5),
    ]

    var body: some View {
        GameChrome {
            VStack(spacing: 20) {
                Text("Never have I ever…").font(.title3.weight(.bold)).foregroundStyle(Theme.inkSoft)
                Text(currentPrompt)
                    .onAppear { if prompts.isEmpty { reshuffle() } }
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 120)
                HStack(spacing: 12) {
                    Button {
                        havenotCount += 1; next()
                    } label: { Text("🔴 I haven't").frame(maxWidth: .infinity).padding(.vertical, 14) }
                        .buttonStyle(.bordered).tint(Theme.danger)
                    Button {
                        haveCount += 1; next()
                    } label: { Text("🟢 I have").frame(maxWidth: .infinity).padding(.vertical, 14) }
                        .buttonStyle(.borderedProminent).tint(Theme.success)
                }
                HStack {
                    Text("Have: \(haveCount)").foregroundStyle(Theme.success)
                    Spacer()
                    Text("Haven't: \(havenotCount)").foregroundStyle(Theme.danger)
                }
                .font(.caption)
                Button("Shuffle deck") {
                    roomService.reportScore(gameId: "nhie", score: haveCount)
                    reshuffle()
                }
                .buttonStyle(.bordered).tint(Theme.accentDeep)
            }
        }
    }

    private var currentPrompt: String {
        prompts.isEmpty ? "Loading…" : prompts[index % max(1, prompts.count)]
    }

    private func next() {
        hapticTap()
        guard !prompts.isEmpty else { return }
        if index + 1 >= prompts.count {
            // Reshuffle at end of cycle so ordering doesn't repeat.
            let last = prompts[index]
            var reshuffled = prompts.shuffled()
            // Avoid putting the same prompt at the top of the fresh cycle.
            if reshuffled.first == last, reshuffled.count > 1 {
                reshuffled.swapAt(0, 1)
            }
            prompts = reshuffled
            index = 0
        } else {
            index += 1
        }
    }

    private func reshuffle() {
        prompts = Self.deck.upTo(store.data.preferences.spiciness).shuffled()
        index = 0; haveCount = 0; havenotCount = 0
    }
}



// MARK: - Roulette

struct RouletteGame: View {
    @Environment(RoomService.self) private var roomService
    @State private var chosen: String? = nil
    @State private var spinning: Bool = false

    var body: some View {
        GameChrome {
            VStack(spacing: 16) {
                let members = roomService.state?.members ?? []
                Text("🎯").font(.system(size: 72))
                    .rotationEffect(.degrees(spinning ? 720 : 0))
                    .animation(.easeInOut(duration: 1.2), value: spinning)
                if let chosen {
                    Text(chosen)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.accentDeep)
                    Text("…drinks next.")
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    Text("Spin to pick who's up.")
                        .foregroundStyle(Theme.inkSoft)
                }

                if members.isEmpty {
                    Text("Join a room to include the squad. Solo spin also works - you against fate.")
                        .font(.caption).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
                }

                BigActionButton(title: "Spin") {
                    hapticTap()
                    let names = members.map(\.name)
                    let pool = names.isEmpty ? ["You"] : names
                    spinning.toggle()
                    Task {
                        try? await Task.sleep(nanoseconds: 900_000_000)
                        await MainActor.run { chosen = pool.randomElement() }
                    }
                }
            }
        }
    }
}

// MARK: - Higher or Lower (person edition)

/// A spicy 0–10 rating game. Each round a random player is put on the spot
/// with a random spicy question and privately enters a number 0–10. From the
/// second round on, everyone else has to guess whether this player's number
/// will be *higher* or *lower* than the previous player's. Keep the streak.
struct HigherLowerGame: View {
    @Environment(RoomService.self) private var roomService
    @Environment(AppStore.self) private var store

    enum Phase {
        case setup       // adding players
        case firstAnswer // very first round - subject rates themselves, no guess yet
        case guess       // waiting for someone to pick higher or lower
        case answer      // subject entering their private number
        case reveal      // showing outcome, streak update
        case over        // game over
    }

    @State private var players: [String] = []
    @State private var newName: String = ""

    @State private var phase: Phase = .setup

    @State private var currentSubject: String = ""
    @State private var currentQuestion: String = ""
    @State private var currentAnswer: Int = 5

    @State private var previousSubject: String = ""
    @State private var previousQuestion: String = ""
    @State private var previousAnswer: Int = 0

    @State private var guessedHigher: Bool? = nil

    @State private var streak: Int = 0
    @State private var bestStreak: Int = 0

    @State private var recentSubjects: [String] = []
    @State private var recentQuestions: [String] = []

    private static let questions: [SpicyPrompt] = [
        // Level 2 - mild party
        .init(text: "how loud they'd be at karaoke", level: 2),
        .init(text: "how likely they are to spill a secret when drunk", level: 2),
        .init(text: "how much they overshare with strangers", level: 2),
        .init(text: "how petty they can be", level: 2),
        .init(text: "how competitive they get at board games", level: 2),
        .init(text: "how likely they are to start a fight with a stranger", level: 2),
        .init(text: "how bad their taste in exes is", level: 2),
        .init(text: "how good they are at keeping secrets", level: 2),
        .init(text: "how likely they'd cry at a Pixar movie", level: 2),
        .init(text: "how likely they are to text 'u up?'", level: 2),
        // Level 3 - medium
        .init(text: "how likely they are to text an ex tonight", level: 3),
        .init(text: "how jealous they get in relationships", level: 3),
        .init(text: "how good they are at flirting", level: 3),
        .init(text: "how much they stalk crushes online", level: 3),
        .init(text: "how likely they are to ghost after 3 dates", level: 3),
        .init(text: "how clingy they are in relationships", level: 3),
        .init(text: "how likely they'd blow their savings on love", level: 3),
        .init(text: "how petty their post-breakup era gets", level: 3),
        .init(text: "how much they lie on dating apps", level: 3),
        .init(text: "how likely they'd date someone rich but boring", level: 3),
        .init(text: "how quickly they catch feelings", level: 3),
        // Level 4 - spicy
        .init(text: "how loyal they'd be in an open relationship", level: 4),
        .init(text: "how likely they'd hook up with a coworker", level: 4),
        .init(text: "how good of a kisser they think they are", level: 4),
        .init(text: "how likely they are to cheat if drunk enough", level: 4),
        .init(text: "how likely they are to keep a hookup a secret", level: 4),
        .init(text: "how emotionally attached they get after sleeping with someone", level: 4),
        .init(text: "how likely they are to pull a stranger tonight", level: 4),
        .init(text: "how many dating apps they have on their phone right now", level: 4),
        .init(text: "how likely they'd get back with their worst ex", level: 4),
        .init(text: "how much they'd give up for the right partner", level: 4),
        // Level 5 - unfiltered adult
        .init(text: "how kinky they really are behind closed doors", level: 5),
        .init(text: "how loud they are in bed", level: 5),
        .init(text: "how selfish they are in bed", level: 5),
        .init(text: "how good they are in bed (their own honest rating)", level: 5),
        .init(text: "how high their body count actually is", level: 5),
        .init(text: "how likely they are to send a nude tonight", level: 5),
        .init(text: "how down they'd be for a threesome right now", level: 5),
        .init(text: "how likely they are to have hooked up with someone in this room", level: 5),
        .init(text: "how likely they are to say the wrong name in bed", level: 5),
        .init(text: "how vanilla they are (10 = very)", level: 5),
        .init(text: "how likely they are to have a secret kink", level: 5),
        .init(text: "how much they still think about their ex during sex", level: 5),
        .init(text: "how likely they are to fake it", level: 5),
        .init(text: "how likely they are to have hooked up somewhere risky in public", level: 5),
        .init(text: "how many hookups this year they've kept secret", level: 5),
        .init(text: "how down they are to try porn IRL", level: 5),
        .init(text: "how likely they are to hook up on a first date", level: 5),
        .init(text: "how likely they'd have paid for sex or been paid", level: 5),
        .init(text: "how much they'd cheat for the right person", level: 5),
        .init(text: "how emotionally attached they get after one hookup", level: 5),
    ]

    private var filteredQuestions: [String] {
        Self.questions.upTo(store.data.preferences.spiciness)
    }

    var body: some View {
        GameChrome {
            VStack(alignment: .leading, spacing: 20) {
                switch phase {
                case .setup: setupView
                default: roundView
                }
            }
        }
        .onAppear(perform: hydrateFromRoom)
    }

    // MARK: Setup

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Higher or Lower")
                .font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            Text("Whoever's up gets a spicy question - they secretly rate themselves 0 to 10. The next player gets a new question. Everyone guesses if their score will be higher or lower than the last person's. Keep the streak.")
                .font(.caption).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)

            HStack {
                TextField("Add a name", text: $newName)
                    .textFieldStyle(BeerifyFieldStyle())
                    .onSubmit(addPlayer)
                Button("Add", action: addPlayer)
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !players.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(players.enumerated()), id: \.offset) { i, name in
                        HStack {
                            Text(Avatars.avatar(for: name)).font(.title3)
                            Text(name).foregroundStyle(Theme.ink)
                            Spacer()
                            Button {
                                players.remove(at: i)
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.9)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                    }
                }
            }

            Button {
                startFirstRound()
            } label: {
                Text("Start game").frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
            .disabled(players.count < 2)
            .opacity(players.count < 2 ? 0.5 : 1)

            if players.count < 2 {
                Text("Need at least 2 players.").font(.caption).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    // MARK: Round

    @ViewBuilder
    private var roundView: some View {
        VStack(alignment: .leading, spacing: 16) {
            streakHeader

            subjectCard

            switch phase {
            case .firstAnswer:
                privateAnswerBlock(intro: "\(currentSubject), hand yourself the phone and secretly pick your number.")

            case .guess:
                guessButtons

            case .answer:
                privateAnswerBlock(intro: "\(currentSubject), take the phone. Pick your number in secret.")

            case .reveal:
                revealBlock

            case .over:
                gameOverBlock

            default: EmptyView()
            }

            Button(role: .destructive) {
                phase = .setup
                streak = 0
                guessedHigher = nil
                previousSubject = ""
            } label: {
                Text("End game").font(.caption).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).tint(Theme.danger).controlSize(.small)
        }
    }

    private var streakHeader: some View {
        HStack {
            Text("🔥 Streak: \(streak)").font(.headline).foregroundStyle(Theme.accentDeep)
            Spacer()
            if bestStreak > 0 {
                Text("Best: \(bestStreak)").font(.caption).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var subjectCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(Avatars.avatar(for: currentSubject)).font(.title2)
                Text(currentSubject).font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)
                Spacer()
            }
            Text("On a scale of 0–10 -")
                .font(.caption).foregroundStyle(Theme.inkSoft)
            Text(currentQuestion)
                .font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent.opacity(0.18)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.45), lineWidth: 1))
    }

    private var guessButtons: some View {
        VStack(spacing: 10) {
            Text("Last round: \(previousSubject) rated themselves **\(previousAnswer)/10** on \"\(previousQuestion)\"")
                .font(.caption).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Text("Will \(currentSubject)'s number be higher or lower?")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            HStack(spacing: 12) {
                Button {
                    guessedHigher = false
                    phase = .answer
                } label: {
                    Text("Lower ⬇").frame(maxWidth: .infinity).padding(.vertical, 14)
                }.buttonStyle(.bordered).tint(Theme.accentDeep)
                Button {
                    guessedHigher = true
                    phase = .answer
                } label: {
                    Text("Higher ⬆").frame(maxWidth: .infinity).padding(.vertical, 14)
                }.buttonStyle(.borderedProminent).tint(Theme.accent)
            }
        }
    }

    private func privateAnswerBlock(intro: String) -> some View {
        VStack(spacing: 12) {
            Text(intro)
                .font(.caption).foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(currentAnswer)")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundStyle(Theme.accentDeep)
                .contentTransition(.numericText())
            Slider(value: Binding(
                get: { Double(currentAnswer) },
                set: { currentAnswer = Int($0.rounded()) }
            ), in: 0...10, step: 1)
            .tint(Theme.accent)
            HStack {
                Text("0").font(.caption).foregroundStyle(Theme.inkSoft)
                Spacer()
                Text("10").font(.caption).foregroundStyle(Theme.inkSoft)
            }
            BigActionButton(title: "Lock it in") { submitAnswer() }
        }
    }

    private var revealBlock: some View {
        let correct = wasGuessCorrect()
        return VStack(spacing: 10) {
            Text(correct ? "🎉 Correct!" : "😅 Nope.")
                .font(.title2.weight(.heavy))
                .foregroundStyle(correct ? Theme.success : Theme.danger)
            Text("\(currentSubject) rated themselves **\(currentAnswer)/10**.")
                .font(.headline).foregroundStyle(Theme.ink)
            if !previousSubject.isEmpty {
                Text("\(previousSubject) had \(previousAnswer)/10.")
                    .font(.caption).foregroundStyle(Theme.inkSoft)
            }
            BigActionButton(title: correct ? "Next round" : "See how you did") {
                if correct { advanceToNext() } else { endGame() }
            }
        }
    }

    private var gameOverBlock: some View {
        VStack(spacing: 10) {
            Text("🏁 Game over").font(.title2.weight(.heavy)).foregroundStyle(Theme.ink)
            Text("Best streak: \(bestStreak)").font(.headline).foregroundStyle(Theme.accentDeep)
            BigActionButton(title: "Play again") { startFirstRound() }
        }
    }

    // MARK: Actions

    private func addPlayer() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !players.contains(trimmed) else { return }
        players.append(trimmed); newName = ""
    }

    private func hydrateFromRoom() {
        guard players.isEmpty else { return }
        if let members = roomService.state?.members, !members.isEmpty {
            players = members.map(\.name)
        }
    }

    private func startFirstRound() {
        streak = 0
        previousSubject = ""
        previousQuestion = ""
        previousAnswer = 0
        guessedHigher = nil
        recentSubjects.removeAll()
        recentQuestions.removeAll()
        drawNext(isFirst: true)
    }

    private func drawNext(isFirst: Bool) {
        currentSubject = rotatedPick(from: players, recent: &recentSubjects, windowSize: max(1, players.count - 1)) ?? players.first ?? ""
        let pool = filteredQuestions
        currentQuestion = rotatedPick(from: pool, recent: &recentQuestions, windowSize: max(5, pool.count / 3)) ?? "how bold they can be"
        currentAnswer = 5
        guessedHigher = nil
        phase = isFirst ? .firstAnswer : .guess
    }

    private func submitAnswer() {
        hapticTap()
        if phase == .firstAnswer {
            // First round bootstraps the "previous" state without scoring.
            previousSubject = currentSubject
            previousQuestion = currentQuestion
            previousAnswer = currentAnswer
            drawNext(isFirst: false)
        } else {
            phase = .reveal
        }
    }

    private func wasGuessCorrect() -> Bool {
        guard let higher = guessedHigher else { return false }
        // Ties count as correct either way (kind to players).
        if currentAnswer == previousAnswer { return true }
        return higher ? currentAnswer > previousAnswer : currentAnswer < previousAnswer
    }

    private func advanceToNext() {
        streak += 1
        if streak > bestStreak { bestStreak = streak }
        previousSubject = currentSubject
        previousQuestion = currentQuestion
        previousAnswer = currentAnswer
        drawNext(isFirst: false)
    }

    private func endGame() {
        if streak > bestStreak { bestStreak = streak }
        roomService.reportScore(gameId: "hilo", score: bestStreak)
        phase = .over
    }
}

// MARK: - Guess My BAC

struct GuessMyBACGame: View {
    @Environment(AppStore.self) private var store
    @Environment(RoomService.self) private var roomService
    @State private var guess: Double = 0.05
    @State private var revealed: Bool = false

    var body: some View {
        GameChrome {
            VStack(spacing: 18) {
                Text("Hand this to a friend").font(.headline).foregroundStyle(Theme.inkSoft)
                Text("Their guess:")
                    .font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                Text(BAC.format(guess) + "%")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accentDeep)
                Slider(value: $guess, in: 0...0.20, step: 0.005)
                    .tint(Theme.accent)

                if revealed {
                    let actual = liveBAC()
                    let delta = abs(actual - guess)
                    Text("Actual: \(BAC.format(actual))%")
                        .font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                    Text("Off by \(BAC.format(delta))%")
                        .font(.subheadline).foregroundStyle(Theme.inkSoft)
                    let verdict = delta < 0.005 ? "🧠 Uncanny!" :
                                  delta < 0.01 ? "🎯 Very close." :
                                  delta < 0.02 ? "🙂 Not bad." : "😅 Way off."
                    Text(verdict).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                    BigActionButton(title: "New round") { revealed = false; guess = 0.05 }
                } else {
                    BigActionButton(title: "Reveal 🎉") {
                        hapticTap()
                        revealed = true
                        // Accuracy score 0-100: 0% delta = 100 points, 0.05+ delta = 0 points.
                        let actual = liveBAC()
                        let delta = abs(actual - guess)
                        let accuracy = max(0, Int(100 - min(100, delta * 2000)))
                        roomService.reportScore(gameId: "guessbac", score: accuracy)
                    }
                }
            }
        }
    }

    private func liveBAC() -> Double {
        guard let profile = store.data.profile else { return 0 }
        if let session = store.data.session {
            return BAC.estimate(drinks: session.drinks, profile: profile, at: Date())
        }
        return 0
    }
}

// MARK: - Truth or Dare

struct TruthOrDareGame: View {
    @Environment(AppStore.self) private var store
    @State private var showing: (String, Bool)? = nil  // (text, isDare)
    @State private var recentTruths: [String] = []
    @State private var recentDares: [String] = []

    private static let truths: [SpicyPrompt] = [
        // Level 1 - family-safe
        .init(text: "What's the most embarrassing song on your playlist?", level: 1),
        .init(text: "Weirdest place you've fallen asleep?", level: 1),
        .init(text: "What's a secret talent no one here knows about?", level: 1),
        .init(text: "What's the worst haircut you've ever had?", level: 1),
        .init(text: "What's the last thing you googled?", level: 1),
        .init(text: "What's a childhood dream you've secretly kept?", level: 1),
        .init(text: "What's the most embarrassing thing your parents caught you doing?", level: 1),
        .init(text: "What's your go-to lie when you're running late?", level: 1),
        // Level 2 - mild
        .init(text: "Biggest lie you've told to get out of plans?", level: 2),
        .init(text: "Last text you regret sending?", level: 2),
        .init(text: "Who in this room would you swap lives with for a day?", level: 2),
        .init(text: "What's the pettiest reason you've unfollowed someone?", level: 2),
        .init(text: "What's a compliment you've never told anyone in this room?", level: 2),
        .init(text: "What's the most you've spent on something dumb this year?", level: 2),
        .init(text: "What's a hill you'd die on that would upset everyone here?", level: 2),
        .init(text: "Who in this room do you find most annoying - and why?", level: 2),
        .init(text: "What's the last thing you cried about?", level: 2),
        // Level 3 - medium
        .init(text: "Who was the last person you stalked online?", level: 3),
        .init(text: "Who in this room have you had a crush on?", level: 3),
        .init(text: "What's the most you've spent trying to impress a date?", level: 3),
        .init(text: "What's your most cringe-worthy voice memo?", level: 3),
        .init(text: "Rate everyone at this table on a scale of 1–10 for chaos.", level: 3),
        .init(text: "What's the worst first-date red flag you've ignored?", level: 3),
        .init(text: "Have you ever lied on a resume?", level: 3),
        .init(text: "What's the pettiest revenge you've taken?", level: 3),
        .init(text: "What's the biggest lie you've told your parents?", level: 3),
        .init(text: "Who was the last person to make you cry - and why?", level: 3),
        // Level 4 - spicy
        .init(text: "Which of your exes would you unblock right now for $500?", level: 4),
        .init(text: "What's the worst thing you've done to get out of a relationship?", level: 4),
        .init(text: "Have you ever lied about how it ended? Say more.", level: 4),
        .init(text: "Who here would you kiss if you had to pick one?", level: 4),
        .init(text: "What's the wildest place you've kissed someone?", level: 4),
        .init(text: "Have you ever had a crush on someone in a relationship?", level: 4),
        .init(text: "What's the most embarrassing photo in your camera roll right now?", level: 4),
        .init(text: "Who was your worst kiss - and what made it so bad?", level: 4),
        .init(text: "Have you ever pretended to be more experienced than you are?", level: 4),
        .init(text: "What's the longest you've stayed with someone you knew wasn't right?", level: 4),
        // Level 5 - unfiltered adult chaos
        .init(text: "What's your actual body count? Say the number.", level: 5),
        .init(text: "Who in this room would you sleep with if you had one free pass?", level: 5),
        .init(text: "What's the wildest thing you've done in bed?", level: 5),
        .init(text: "Have you ever hooked up with someone in this room?", level: 5),
        .init(text: "How many times have you faked it - total?", level: 5),
        .init(text: "What's the shortest time between meeting someone and sleeping with them?", level: 5),
        .init(text: "Who's the last person you sent a nude to?", level: 5),
        .init(text: "What's a kink or fantasy you've never admitted out loud?", level: 5),
        .init(text: "Have you ever thought about someone else while with your partner? Who?", level: 5),
        .init(text: "Who was your worst hookup and why?", level: 5),
        .init(text: "Rate everyone here for sexual chemistry.", level: 5),
        .init(text: "What's the sluttiest thing you've done to get someone's attention?", level: 5),
        .init(text: "Have you ever hooked up with a friend's ex or partner?", level: 5),
        .init(text: "What's the longest you've gone without sex - and why?", level: 5),
        .init(text: "Have you ever cheated? Details.", level: 5),
        .init(text: "What's the wildest place you've had sex?", level: 5),
        .init(text: "What's your number of one-night stands in the last year?", level: 5),
        .init(text: "Have you ever paid for it or been paid for it? Be honest.", level: 5),
        .init(text: "Who's the person in this room you've thought about sexually?", level: 5),
        .init(text: "Have you ever ghosted immediately after finishing?", level: 5),
        .init(text: "What's the most reckless thing you've done because you fancied someone?", level: 5),
        .init(text: "Have you ever hooked up with someone twice your age?", level: 5),
        .init(text: "Have you ever recorded yourself during sex?", level: 5),
        .init(text: "What's the worst thing about your last sexual partner - that they don't know?", level: 5),
        .init(text: "Have you ever hooked up in a public bathroom?", level: 5),
        // Level 5 bonus - beyond hookups
        .init(text: "What's the worst thing you've done that nobody in this room knows about?", level: 5),
        .init(text: "Who in this room do you think is genuinely a bad person deep down? Why?", level: 5),
        .init(text: "What's a friendship in this group you think is fake? Explain.", level: 5),
        .init(text: "If you had to rank everyone here by who you'd cut from your life first, go.", level: 5),
        .init(text: "What's the most manipulative thing you've ever done - and did it work?", level: 5),
        .init(text: "What's a secret you know about someone in this room that they don't know you know?", level: 5),
        .init(text: "If this group had a group chat without you, what do you think they'd say?", level: 5),
        .init(text: "What's the cruelest thing you've ever said to someone's face?", level: 5),
        .init(text: "Have you ever genuinely wished harm on a friend? Who and why?", level: 5),
        .init(text: "What's the biggest lie you're currently living?", level: 5),
        .init(text: "If you could erase one person from your life with no consequences, who and why?", level: 5),
        .init(text: "What have you done drunk that you'd never admit sober? Say it now.", level: 5),
        .init(text: "Who here are you most jealous of and what specifically makes you jealous?", level: 5),
        .init(text: "What's the worst thing you've said about someone in this room behind their back?", level: 5),
        .init(text: "Confess something right now that could genuinely change how this group sees you.", level: 5),
        // Bonus L1 - family-safe
        .init(text: "What was your favorite childhood snack?", level: 1),
        .init(text: "What's your comfort movie?", level: 1),
        .init(text: "What's your most irrational fear?", level: 1),
        .init(text: "What was your favorite subject in school?", level: 1),
        .init(text: "What would your last meal be?", level: 1),
        .init(text: "What talent do you wish you had?", level: 1),
        .init(text: "What's a hobby you've picked up recently?", level: 1),
        .init(text: "If you could live anywhere, where?", level: 1),
        .init(text: "What was your favorite pet?", level: 1),
        // Bonus L2 - mild
        .init(text: "What's the pettiest text you've sent?", level: 2),
        .init(text: "What's a lie you tell yourself often?", level: 2),
        .init(text: "What's your worst habit you refuse to fix?", level: 2),
        .init(text: "Who in this room would you swap phones with for a day?", level: 2),
        .init(text: "What's the most childish thing you still do?", level: 2),
        .init(text: "What's the last thing you ate in bed?", level: 2),
        .init(text: "Who was your worst boss and what did they do?", level: 2),
        .init(text: "What's a purchase you regret this month?", level: 2),
        // Bonus L3 - medium
        .init(text: "What's the worst gift you've received and pretended to love?", level: 3),
        .init(text: "What's a rumor you've spread that turned out false?", level: 3),
        .init(text: "What's your worst date story?", level: 3),
        .init(text: "Who was the last person you unfollowed and why?", level: 3),
        .init(text: "What's the meanest thing you've said behind a friend's back?", level: 3),
        .init(text: "What's an argument you're still holding onto?", level: 3),
        .init(text: "What's the worst first impression you made?", level: 3),
        .init(text: "Who's the pettiest person in this room, honestly?", level: 3),
        .init(text: "What's a compliment you've never been able to accept?", level: 3),
        // Bonus L4 - spicy
        .init(text: "What's a red flag you've ignored and stayed anyway?", level: 4),
        .init(text: "Have you ever ended a friendship over a partner?", level: 4),
        .init(text: "What's the shortest relationship you had that meant the most?", level: 4),
        .init(text: "Have you ever caught feelings for a friend's partner?", level: 4),
        .init(text: "What's your dating deal-breaker that nobody knows about?", level: 4),
        .init(text: "What's the last thing you did that would embarrass your mum?", level: 4),
        .init(text: "Have you ever seen someone else's phone screen and immediately felt weird?", level: 4),
        .init(text: "What's a story you've told a partner you slightly exaggerated?", level: 4),
        // Bonus L5 - unfiltered
        .init(text: "What's the shortest hookup you've had, in minutes?", level: 5),
        .init(text: "What's a hookup you're glad nobody knows about?", level: 5),
        .init(text: "Have you ever been paid for a sexual favor?", level: 5),
        .init(text: "Have you ever pretended to be attracted to someone for their money?", level: 5),
        .init(text: "Who is the last person you thought about sexually?", level: 5),
        .init(text: "What's the wildest thing someone asked for in bed?", level: 5),
        .init(text: "Have you ever finished during a very inappropriate moment?", level: 5),
        .init(text: "What's the most awkward sex situation you've been in?", level: 5),
        .init(text: "Have you ever been secretly recorded?", level: 5),
        .init(text: "What's the worst pickup line that actually worked on you?", level: 5),
        .init(text: "Have you ever slept with a coworker on the boss's desk?", level: 5),
        .init(text: "What's the highest number of partners you've had in one week?", level: 5),
        .init(text: "Have you ever slept with someone twice in one day (different people)?", level: 5),
        .init(text: "What's a fetish you'd never confess sober?", level: 5),
        .init(text: "Rate everyone here by how well they'd flirt with your parents.", level: 5),
        .init(text: "What's the meanest thing an ex ever said in bed?", level: 5),
        .init(text: "Have you ever had a hookup you paid to end early?", level: 5),
        .init(text: "Have you ever kept a hookup's underwear?", level: 5),
        .init(text: "Have you ever propositioned a stranger?", level: 5),
        .init(text: "What's the wildest place you've had a hookup end?", level: 5),
        // Bonus L5 - friendship destroyers
        .init(text: "What do you genuinely dislike about the person on your left? No sugarcoating.", level: 5),
        .init(text: "Who here do you think peaked in school and hasn't grown since?", level: 5),
        .init(text: "What's something you pretend to find funny in this group but actually cringe at?", level: 5),
        .init(text: "If you could swap lives with someone here, who - and what's the first thing you'd fix?", level: 5),
        .init(text: "Who in this room gives off 'I peaked at 17' energy?", level: 5),
        .init(text: "What's the most pathetic thing you've done for validation this year?", level: 5),
        .init(text: "If everyone here was honest about who they actually like least, who'd get the most votes?", level: 5),
        .init(text: "Tell the room the thing you're most ashamed of - not a hookup story, something real.", level: 5),
        .init(text: "What's a time you were genuinely the villain and knew it?", level: 5),
        .init(text: "Who here do you think will look back on their 20s with the most regret?", level: 5),
    ]
    private static let dares: [SpicyPrompt] = [
        // Level 1 - family-safe
        .init(text: "Do your best impression of someone in the room.", level: 1),
        .init(text: "Talk in an accent for the next 5 minutes.", level: 1),
        .init(text: "Compliment everyone in the room. Genuinely.", level: 1),
        .init(text: "Sing the chorus of the last song you listened to.", level: 1),
        .init(text: "Do the worm across the room.", level: 1),
        .init(text: "Draw a self-portrait in 15 seconds. Show it.", level: 1),
        // Level 2 - mild
        .init(text: "Do 10 squats without breaking eye contact.", level: 2),
        .init(text: "Swap one item of clothing with someone here.", level: 2),
        .init(text: "Speak only in questions until your next turn.", level: 2),
        .init(text: "Post a random emoji story on Instagram, no context.", level: 2),
        .init(text: "Text your mum in the moodiest possible language.", level: 2),
        .init(text: "Do your best flirty compliment to the person on your right.", level: 2),
        .init(text: "Speak in a British accent until the next round.", level: 2),
        // Level 3 - medium
        .init(text: "Let someone here rewrite your bio.", level: 3),
        .init(text: "Read out your last three sent messages, in order.", level: 3),
        .init(text: "Show the last five photos in your camera roll.", level: 3),
        .init(text: "Do your best flirty pickup line to the person on your left.", level: 3),
        .init(text: "Post the ugliest selfie you can take on your story for 30 seconds.", level: 3),
        .init(text: "Let the group vote on which of your exes to unfollow.", level: 3),
        .init(text: "Show the last DM you sent to anyone.", level: 3),
        .init(text: "Give a heartfelt confession to the person on your left. Made up or real.", level: 3),
        // Level 4 - spicy
        .init(text: "Call the last number you dialed and sing 'Happy Birthday'.", level: 4),
        .init(text: "Text your crush 'you awake?' - right now, no context.", level: 4),
        .init(text: "Let the group send one message from your phone.", level: 4),
        .init(text: "Do your best sultry runway walk to the door and back.", level: 4),
        .init(text: "Delete the last person you texted from your contacts (you can re-add later).", level: 4),
        .init(text: "Kiss the person on your left - cheek or better.", level: 4),
        .init(text: "Send a flirty voice memo to the last person you slept with.", level: 4),
        .init(text: "Whisper something flirty in the ear of the person on your right.", level: 4),
        .init(text: "Take a shot off someone's collarbone.", level: 4),
        .init(text: "Let the group swipe on Tinder/Hinge for you for 60 seconds.", level: 4),
        // Level 5 - unfiltered adult chaos
        .init(text: "Read out the most recent DM from your crush.", level: 5),
        .init(text: "Let the group post any story they want to your profile.", level: 5),
        .init(text: "Show the group the last three texts you sent to your last hookup.", level: 5),
        .init(text: "Send 'I've been thinking about the other night 😏' to your most recent hookup - no context.", level: 5),
        .init(text: "Let the group scroll your dating app for 30 seconds - no vetoes.", level: 5),
        .init(text: "Give a 30-second lap dance to the person on your right.", level: 5),
        .init(text: "Send a voice memo saying 'I miss you' to your ex, right now.", level: 5),
        .init(text: "Take a body shot off the person to your left.", level: 5),
        .init(text: "Kiss the person here you find most attractive - anywhere but the mouth.", level: 5),
        .init(text: "Reveal the most explicit photo in your camera roll.", level: 5),
        .init(text: "Let the group compose a horny text and send it from your phone to anyone.", level: 5),
        .init(text: "Sit on the lap of the person to your right until your next turn.", level: 5),
        .init(text: "Show the last person you slept with in your phone - name and photo.", level: 5),
        .init(text: "Text your crush 'come over' and screenshot the reply.", level: 5),
        .init(text: "Let the group pick your dating app profile picture for a week.", level: 5),
        .init(text: "Whisper the dirtiest thought you've had this week into the ear of the person on your left.", level: 5),
        .init(text: "Take off one piece of clothing of the group's choice.", level: 5),
        .init(text: "Rate the last person you slept with - out of 10, out loud.", level: 5),
        .init(text: "Send a nude-style thirst trap (fully clothed) to your last hookup.", level: 5),
        .init(text: "Confess something intimate to the room - nothing off limits.", level: 5),
        .init(text: "Kiss the person of your choice in this room. On the mouth. For 5 seconds.", level: 5),
        .init(text: "Show the group your steamiest message ever sent.", level: 5),
        .init(text: "DM your last hookup and ask them what their favourite thing was that night.", level: 5),
        .init(text: "Reenact your last hookup using someone here as a stand-in - clothed only.", level: 5),
        // Bonus L1 - family-safe
        .init(text: "Attempt to juggle three random objects.", level: 1),
        .init(text: "Say a tongue twister three times fast.", level: 1),
        .init(text: "Try to lick your elbow. Everyone watches.", level: 1),
        .init(text: "Text a random emoji to your best friend.", level: 1),
        .init(text: "Do your best impression of a public figure.", level: 1),
        .init(text: "Rap the alphabet in under 15 seconds.", level: 1),
        .init(text: "Sing your last text in an opera voice.", level: 1),
        .init(text: "Do a handstand attempt against a wall.", level: 1),
        // Bonus L2 - mild
        .init(text: "Put on the ugliest snap filter and take a selfie for the group.", level: 2),
        .init(text: "Do 15 push-ups. Now.", level: 2),
        .init(text: "Text your last five contacts 'you free tonight?' in one round.", level: 2),
        .init(text: "Send a story of you doing a random dance to your close friends.", level: 2),
        .init(text: "Call a friend and confess a fake but wholesome secret.", level: 2),
        .init(text: "Speak only in whispers for the next two rounds.", level: 2),
        .init(text: "Change your profile picture to whatever the group picks (5 min).", level: 2),
        // Bonus L3 - medium
        .init(text: "Show the last person you searched for on Instagram.", level: 3),
        .init(text: "Read out your last five Google searches.", level: 3),
        .init(text: "Show the group your Camera Roll from exactly one year ago today.", level: 3),
        .init(text: "Let the group send a wild message to your last WhatsApp chat.", level: 3),
        .init(text: "Video-call the last person you added on socials and say 'thinking of you'.", level: 3),
        .init(text: "Post an unflattering selfie for at least 30 seconds.", level: 3),
        .init(text: "Read out the last three notes in your Notes app.", level: 3),
        .init(text: "Show the group the last three DMs you sent that were more than 30 words.", level: 3),
        // Bonus L4 - spicy
        .init(text: "Send a heart emoji to your last three exes in a row.", level: 4),
        .init(text: "Let the group vote on which of your exes to text 'I still think about you' to.", level: 4),
        .init(text: "Take a body shot off someone in the room's forearm.", level: 4),
        .init(text: "Whisper something inappropriate in the ear of the person on your right.", level: 4),
        .init(text: "Give someone in this room a hickey (of your choice).", level: 4),
        .init(text: "Rate the attractiveness of your last three dates out loud.", level: 4),
        .init(text: "Do a striptease down to whatever you're comfortable with, 15 seconds.", level: 4),
        .init(text: "Kiss someone here for 3 seconds - anywhere but the mouth.", level: 4),
        // Bonus L5 - unfiltered
        .init(text: "Text your last hookup 'be honest - how was it, out of 10?'", level: 5),
        .init(text: "Show the group the spiciest photo of yourself you're willing to share.", level: 5),
        .init(text: "Let the group post a thirsty comment on your latest photo.", level: 5),
        .init(text: "Read the last DM your ex sent you out loud.", level: 5),
        .init(text: "Give the person on your left a lap dance - 20 seconds, fully clothed.", level: 5),
        .init(text: "Let the group choose any question to ask your last hookup - and send it live.", level: 5),
        .init(text: "Call your ex and hang up as soon as they answer.", level: 5),
        .init(text: "Send a voice memo to your crush saying only 'come over'.", level: 5),
        .init(text: "Screenshot your dating apps' recent chats and show the group first names only.", level: 5),
        .init(text: "Take off one accessory - glasses, jewelry, belt - chosen by the person on your right.", level: 5),
        .init(text: "Let the group compose a horny paragraph and send it to any name in your phone.", level: 5),
        .init(text: "Show the last screenshot on your phone - no explaining.", level: 5),
        .init(text: "Whisper a very specific detail from your last hookup into the ear of the person on your left.", level: 5),
        .init(text: "Text 'wanna go halfsies on a hotel' to the last person you slept with.", level: 5),
        .init(text: "Do your dirtiest dance move for 10 seconds. Solo.", level: 5),
        .init(text: "Let the group pick a hookup they think will reply to a 'u up?' from you tonight.", level: 5),
        .init(text: "Sit backwards on a chair like they do in bad movies - for the next 3 rounds.", level: 5),
        .init(text: "Text your ex 'I had a dream about you' - full stop.", level: 5),
        .init(text: "Show the group your saved reels/TikToks.", level: 5),
        .init(text: "Reenact your first kiss with the person on your right - mimed, cheek-to-cheek.", level: 5),
        // Level 5 bonus - chaotic energy
        .init(text: "Unlock your phone and hand it to the person you trust least in this room for 60 seconds.", level: 5),
        .init(text: "Let the group go through your 'Recently Deleted' photos for 30 seconds.", level: 5),
        .init(text: "Screen share your Notes app. All of it. 20 seconds.", level: 5),
        .init(text: "Open your calculator history. Explain each one.", level: 5),
        .init(text: "Show the group the contact name you have saved for your ex.", level: 5),
        .init(text: "Let someone in the room text literally anything from your phone to your mum.", level: 5),
        .init(text: "Read your screen time report out loud - every app, every hour.", level: 5),
        .init(text: "Let the group pick someone in your contacts. Call them and say 'I need to tell you something'. Then hang up.", level: 5),
        .init(text: "Show the group your Spotify Wrapped top artists. No skipping.", level: 5),
        .init(text: "Go live on Instagram for 30 seconds doing whatever the group decides.", level: 5),
        .init(text: "Text your mum 'I need to talk to you about something important' - then don't reply for 10 minutes.", level: 5),
        .init(text: "Open your Maps timeline and show the group everywhere you've been this week.", level: 5),
    ]

    var body: some View {
        GameChrome {
            VStack(spacing: 20) {
                if let showing {
                    Text(showing.1 ? "😈 Dare" : "🫣 Truth")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(showing.1 ? Theme.danger : Theme.info)
                    Text(showing.0)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                } else {
                    Text("🎭").font(.system(size: 72))
                    Text("Pick one.").foregroundStyle(Theme.inkSoft)
                }
                HStack(spacing: 12) {
                    Button {
                        hapticTap()
                        let pool = Self.truths.upTo(store.data.preferences.spiciness)
                        if let t = rotatedPick(from: pool, recent: &recentTruths, windowSize: max(5, pool.count / 3)) {
                            showing = (t, false)
                        }
                    } label: { Text("Truth").frame(maxWidth: .infinity).padding(.vertical, 14) }
                        .buttonStyle(.bordered).tint(Theme.info)
                    Button {
                        hapticTap()
                        let pool = Self.dares.upTo(store.data.preferences.spiciness)
                        if let d = rotatedPick(from: pool, recent: &recentDares, windowSize: max(5, pool.count / 3)) {
                            showing = (d, true)
                        }
                    } label: { Text("Dare").frame(maxWidth: .infinity).padding(.vertical, 14) }
                        .buttonStyle(.borderedProminent).tint(Theme.danger)
                }
            }
        }
    }
}

// MARK: - Categories

struct CategoriesGame: View {
    @Environment(AppStore.self) private var store

    private static let categories: [SpicyPrompt] = [
        // Level 1-3 - general
        .init(text: "Cocktails", level: 1),
        .init(text: "80s bands", level: 1),
        .init(text: "Beers", level: 1),
        .init(text: "Capital cities", level: 1),
        .init(text: "Pixar movies", level: 1),
        .init(text: "Types of pasta", level: 1),
        .init(text: "NBA teams", level: 1),
        .init(text: "Fruits", level: 1),
        .init(text: "Board games", level: 1),
        .init(text: "Types of cheese", level: 1),
        .init(text: "Video games", level: 1),
        .init(text: "Chocolate bars", level: 1),
        .init(text: "TV show villains", level: 1),
        .init(text: "Types of dogs", level: 1),
        .init(text: "Fast food chains", level: 1),
        .init(text: "Superhero movies", level: 1),
        .init(text: "Halloween costumes", level: 1),
        .init(text: "Christmas songs", level: 1),
        .init(text: "Types of coffee drinks", level: 1),
        .init(text: "Kitchen appliances", level: 1),
        .init(text: "Countries in Europe", level: 1),
        .init(text: "Countries in Asia", level: 1),
        .init(text: "US states", level: 1),
        .init(text: "Marvel characters", level: 1),
        .init(text: "Disney princesses", level: 1),
        .init(text: "Types of shoes", level: 1),
        .init(text: "Types of dance", level: 1),
        .init(text: "Card games", level: 1),
        .init(text: "Types of bread", level: 1),
        .init(text: "Sitcom characters", level: 1),
        .init(text: "Rappers", level: 1),
        .init(text: "Ice cream flavors", level: 1),
        .init(text: "F1 drivers", level: 1),
        .init(text: "Musical instruments", level: 1),
        .init(text: "Marvel movies", level: 1),
        .init(text: "Famous painters", level: 1),
        .init(text: "Airline names", level: 1),
        .init(text: "Types of tea", level: 1),
        .init(text: "Whisky brands", level: 1),
        .init(text: "Places you've thrown up", level: 2),
        .init(text: "Reasons to leave a party early", level: 2),
        .init(text: "Things in your bag right now", level: 2),
        .init(text: "Excuses to skip work", level: 2),
        .init(text: "Things you regret buying", level: 2),
        .init(text: "Reasons you'd cry in public", level: 2),
        .init(text: "Bad tattoo ideas", level: 2),
        .init(text: "Deal-breakers on a first date", level: 3),
        .init(text: "Red flags in a text", level: 3),
        .init(text: "Green flags in a partner", level: 3),
        .init(text: "Things you'd lie about on a dating app", level: 3),
        .init(text: "Reasons to ghost someone", level: 3),
        // Level 4-5 - adult
        .init(text: "Types of kisses", level: 4),
        .init(text: "Pickup lines", level: 4),
        .init(text: "Places you shouldn't hook up", level: 4),
        .init(text: "Excuses to leave after a hookup", level: 4),
        .init(text: "Things not to say during sex", level: 5),
        .init(text: "Sex positions", level: 5),
        .init(text: "Kinks", level: 5),
        .init(text: "Body parts", level: 5),
        .init(text: "Words for hookup", level: 5),
        .init(text: "Places you've had sex", level: 5),
        .init(text: "Sex toys", level: 5),
        .init(text: "Nicknames for genitals", level: 5),
        .init(text: "Reasons your last hookup didn't call back", level: 5),
        // Bonus general (L1)
        .init(text: "Sports played with a ball", level: 1),
        .init(text: "Types of fish", level: 1),
        .init(text: "Types of cake", level: 1),
        .init(text: "Types of soup", level: 1),
        .init(text: "Herbs and spices", level: 1),
        .init(text: "Vegetables you'd put in a salad", level: 1),
        .init(text: "Types of berries", level: 1),
        .init(text: "Insects", level: 1),
        .init(text: "Reptiles", level: 1),
        .init(text: "Sea creatures", level: 1),
        .init(text: "Dinosaurs", level: 1),
        .init(text: "Musical genres", level: 1),
        .init(text: "Words for 'happy'", level: 1),
        .init(text: "Words for 'sad'", level: 1),
        .init(text: "Words for 'walk'", level: 1),
        .init(text: "Countries in Africa", level: 1),
        .init(text: "Countries in South America", level: 1),
        .init(text: "Countries starting with 'S'", level: 1),
        .init(text: "Rivers", level: 1),
        .init(text: "Mountains", level: 1),
        .init(text: "US presidents", level: 1),
        .init(text: "British Prime Ministers", level: 1),
        .init(text: "Types of hats", level: 1),
        .init(text: "Types of jewelry", level: 1),
        .init(text: "Colors", level: 1),
        .init(text: "Words that rhyme with 'moon'", level: 1),
        .init(text: "Board games", level: 1),
        .init(text: "Pixar characters", level: 1),
        .init(text: "Marvel villains", level: 1),
        .init(text: "James Bond actors", level: 1),
        .init(text: "Types of tea", level: 1),
        .init(text: "Types of noodles", level: 1),
        .init(text: "Alcoholic drinks", level: 1),
        .init(text: "Non-alcoholic mocktails", level: 1),
        .init(text: "Famous scientists", level: 1),
        .init(text: "Famous inventors", level: 1),
        .init(text: "Types of vehicles", level: 1),
        .init(text: "Furniture", level: 1),
        .init(text: "Words you shout at TV sports", level: 1),
        .init(text: "Yellow things", level: 1),
        .init(text: "Things that are round", level: 1),
        .init(text: "Reasons to be late to work", level: 1),
        .init(text: "Toys from your childhood", level: 1),
        .init(text: "Cartoons from the 90s", level: 1),
        .init(text: "Bands you've cried to", level: 1),
        .init(text: "Reality TV shows", level: 1),
        .init(text: "Types of pizza toppings", level: 1),
        .init(text: "Sandwich fillings", level: 1),
        .init(text: "Ways to cook eggs", level: 1),
        // Bonus L2 - mild
        .init(text: "Things you'd rescue in a house fire", level: 2),
        .init(text: "Foods you can eat with your hands", level: 2),
        .init(text: "Songs at every wedding", level: 2),
        .init(text: "Ways to break bad news", level: 2),
        .init(text: "Excuses to not answer your phone", level: 2),
        .init(text: "Reasons you can't come out tonight", level: 2),
        .init(text: "Songs you can't help but sing along to", level: 2),
        .init(text: "Things in a hangover survival kit", level: 2),
        .init(text: "Types of tears you've cried this year", level: 2),
        .init(text: "Reasons to text your ex", level: 2),
        .init(text: "Guilty pleasure TV shows", level: 2),
        .init(text: "Things you Google at 3am", level: 2),
        .init(text: "Signs you're getting old", level: 2),
        .init(text: "Ways to embarrass yourself in public", level: 2),
        // Bonus L3 - medium
        .init(text: "Reasons to leave a date early", level: 3),
        .init(text: "Bad first date locations", level: 3),
        .init(text: "Things you don't say to your mother-in-law", level: 3),
        .init(text: "Reasons you've cried on a night out", level: 3),
        .init(text: "Signs your relationship is doomed", level: 3),
        .init(text: "Bad decisions made after 1am", level: 3),
        .init(text: "Songs that describe your love life", level: 3),
        .init(text: "Excuses for missing a friend's birthday", level: 3),
        .init(text: "Reasons you were dumped", level: 3),
        // Bonus L4 - spicy
        .init(text: "Places you've made out you shouldn't have", level: 4),
        .init(text: "Reasons you slept over 'accidentally'", level: 4),
        .init(text: "Things your parents don't know about you", level: 4),
        .init(text: "Turn-offs on a first date", level: 4),
        .init(text: "Signs someone's a bad kisser", level: 4),
        .init(text: "Reasons you'd cancel a hookup last minute", level: 4),
        .init(text: "Body language that's a green flag", level: 4),
        // Bonus L5 - unfiltered
        .init(text: "Things you've said in bed you regret", level: 5),
        .init(text: "Kinks that shouldn't exist but do", level: 5),
        .init(text: "Sex noises that need to be banned", level: 5),
        .init(text: "Places you've had sex you shouldn't have", level: 5),
        .init(text: "Words for turned on", level: 5),
        .init(text: "Ways to end a bad hookup", level: 5),
        .init(text: "Weird things partners have asked for", level: 5),
        .init(text: "Excuses to leave right after sex", level: 5),
        .init(text: "Reasons you'd fake an orgasm", level: 5),
        .init(text: "Things you'd say to spice things up", level: 5),
        .init(text: "Words nobody should say during sex", level: 5),
        .init(text: "Reasons someone's a bad lay", level: 5),
        .init(text: "Fetishes you didn't know had names", level: 5),
    ]

    @State private var category: String = ""
    @State private var recent: [String] = []
    @State private var timeLeft: Int = 8
    @State private var running: Bool = false
    @State private var timerTask: Task<Void, Never>? = nil

    private var filtered: [String] {
        Self.categories.upTo(store.data.preferences.spiciness)
    }

    var body: some View {
        GameChrome {
            VStack(spacing: 18) {
                Text("Category").font(.headline).foregroundStyle(Theme.inkSoft)
                Text(category)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("\(timeLeft)")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundStyle(running ? (timeLeft <= 2 ? Theme.danger : Theme.accentDeep) : Theme.inkSoft)
                    .contentTransition(.numericText())
                Text("Name one → tap to pass. Last one standing loses.")
                    .font(.caption).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("New category") {
                        stopTimer()
                        pickNextCategory()
                        timeLeft = 8
                    }.buttonStyle(.bordered).tint(Theme.accentDeep)

                    Button(running ? "Pass ▶︎" : "Start") {
                        hapticTap()
                        if !running { startTimer() }
                        else { timeLeft = 8 }  // pass = reset clock
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                }
            }
            .onAppear { if category.isEmpty { pickNextCategory() } }
        }
        .onDisappear { stopTimer() }
    }

    private func pickNextCategory() {
        let pool = filtered
        if let picked = rotatedPick(from: pool, recent: &recent, windowSize: max(6, pool.count / 3)) {
            category = picked
        }
    }

    private func startTimer() {
        running = true
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled && timeLeft > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { if timeLeft > 0 { timeLeft -= 1 } }
            }
            await MainActor.run { running = false }
        }
    }

    private func stopTimer() {
        timerTask?.cancel(); timerTask = nil; running = false
    }
}

// MARK: - Emoji Charades

struct EmojiCharadesGame: View {
    private static let phrases: [(emoji: String, answer: String)] = [
        ("🦁👑", "The Lion King"),
        ("👻🚫", "Ghostbusters"),
        ("🍫🏭", "Charlie and the Chocolate Factory"),
        ("🕷🕸👦", "Spider-Man"),
        ("🦈🌪", "Sharknado"),
        ("👑🎤", "Bohemian Rhapsody"),
        ("🌊🐟🔎", "Finding Nemo"),
        ("🚢🧊❤️", "Titanic"),
        ("🏝🐷", "Lord of the Flies"),
        ("🧙⚡", "Harry Potter"),
        ("👽📞🏠", "E.T. phone home"),
        ("🦖🏞", "Jurassic Park"),
        ("👴🎈🏠", "Up"),
        ("🐘🐒🦁🐺", "The Jungle Book"),
        ("🕶🕴️", "The Matrix"),
        ("❄️👑👗", "Frozen"),
        ("🐀👨‍🍳", "Ratatouille"),
        ("🎯🏹🔥", "The Hunger Games"),
        ("🦇🌆", "Batman"),
        ("🦸‍♀️⚔️", "Wonder Woman"),
        ("🧛🌹", "Twilight"),
        ("🐢🥷🍕", "Teenage Mutant Ninja Turtles"),
        ("🚗🏁💨", "Fast and Furious"),
        ("🎩🐰🕳️", "Alice in Wonderland"),
        ("🐷🎬", "Babe"),
        ("🎈👴🐕", "Up"),
        ("🚿🔪🎬", "Psycho"),
        ("🎃👻🔪", "Halloween"),
        ("🐺👶🌲", "The Jungle Book"),
        ("🌸🥋", "Kung Fu Panda"),
        ("🐟💦🌊", "Aquaman"),
        ("🐭🎩✨", "Cinderella"),
        ("🕰️🐰⏳", "Alice Through the Looking Glass"),
        ("💊🔴🔵", "The Matrix"),
        ("🎬🚀🌕", "Interstellar"),
        ("🔨⚡👨", "Thor"),
        ("🇺🇸🛡️", "Captain America"),
        ("🍫🎫👦", "Willy Wonka"),
        ("🐝🎬", "Bee Movie"),
        ("🐟🐟", "Big Fish"),
        ("🎶🏔️👩", "The Sound of Music"),
        ("💃🕺🌆", "La La Land"),
        ("🎪🎩🐘", "The Greatest Showman"),
        ("🚀🌙🐒", "Space Jam"),
        ("👨‍🔬💥", "Breaking Bad"),
        ("👑👗🇬🇧", "The Crown"),
        ("🔨🕹️👦", "Fortnite"),
        ("🕺🕰️🎉", "Back to the Future"),
        ("🤠🚀", "Toy Story"),
        ("🦸🕷️🕸️🏙️", "Spider-Man: Into the Spider-Verse"),
        ("🏝️🐒🍌", "King Kong"),
        ("🎣🐋", "Moby Dick"),
        ("🎂🕯️🌸", "Sixteen Candles"),
        ("👩‍🚀🌋🚀", "The Martian"),
        ("🐭🚀", "Ratatouille"),
        ("🍎🐍👩", "Snow White"),
        ("🐊🎩", "Peter Pan"),
        ("💃💔🐟", "The Shape of Water"),
        ("🐷🦆", "Peppa Pig"),
        ("🚂🎁🎅", "The Polar Express"),
        ("🧸🎂👦", "Toy Story"),
        ("🌻👩🎨", "Van Gogh"),
        ("🐠🐟🌊", "Finding Dory"),
        ("🎧💃💔", "Baby Driver"),
        ("🚔🐷🍩", "Zootopia"),
        ("🦖🎢", "Jurassic World"),
        ("🎬🃏😈", "Joker"),
        ("💍🌋👣", "The Lord of the Rings"),
        // Bonus batch
        ("🎬🎩🍫", "Wonka"),
        ("🏰🐸💋", "The Princess and the Frog"),
        ("🕊️👦", "Peter Pan"),
        ("🐟👀🌊", "Finding Dory"),
        ("🥷🐢🍕", "TMNT"),
        ("🔴🔵💊", "The Matrix"),
        ("🚗⚡🔥", "Cars"),
        ("👽🚲🌕", "E.T."),
        ("🦕🌳🏞️", "Jurassic Park"),
        ("🦸‍♂️🕷️", "Spider-Man"),
        ("🧙‍♂️💍👣", "The Hobbit"),
        ("🎓🐍⚡", "Harry Potter and the Chamber of Secrets"),
        ("👑💍👰", "The Princess Diaries"),
        ("👑❄️☃️", "Frozen"),
        ("🌊🧜‍♀️🎣", "The Little Mermaid"),
        ("🐻👦🍯", "Winnie the Pooh"),
        ("🐘👂🎪", "Dumbo"),
        ("🦁👶👑", "The Lion King"),
        ("🐕🐕🚗", "101 Dalmatians"),
        ("🎃👦🧙", "Coraline"),
        ("👺🎭📺", "Squid Game"),
        ("💰📺👨‍👩‍👧", "Succession"),
        ("👑🇬🇧📺", "The Crown"),
        ("🦑🎮🔴🟢", "Squid Game"),
        ("🕵️‍♂️🚬📺", "Peaky Blinders"),
        ("🍩👮📺", "Brooklyn Nine-Nine"),
        ("🏫🧪💊", "Breaking Bad"),
        ("🐎🎬", "Seabiscuit"),
        ("🦍🏙️", "King Kong"),
        ("🥊🇺🇸🎬", "Rocky"),
        ("🎬🕵️‍♂️🎩", "Sherlock Holmes"),
        ("🎩🌂🕰️", "Doctor Who"),
        ("🚀🌌🌠", "Star Wars"),
        ("👽🛸🔫", "Men in Black"),
        ("🐭🎩✨", "Cinderella"),
        ("🍏🐍👩", "Snow White"),
        ("🐰🕶️🕳️", "Alice in Wonderland"),
        ("🌸💃🎬", "La La Land"),
        ("🎬💃🕺", "Grease"),
        ("🎬💃🚗", "Baby Driver"),
        ("🎬🎼🏫", "School of Rock"),
        ("🦁🌪️🌈", "The Wizard of Oz"),
        ("🐍🎬✈️", "Snakes on a Plane"),
        ("🎪🐘🎩", "The Greatest Showman"),
        ("👨‍🍳🐀🇫🇷", "Ratatouille"),
        ("🐟💙🐟", "Finding Nemo"),
        ("👶🎬📈", "Boss Baby"),
        ("🐧🎬🇦🇶", "Happy Feet"),
        ("👑🌊🐟", "Aquaman"),
        ("🦇🃏🌆", "The Dark Knight"),
        ("🕶️🕰️🚗", "Back to the Future"),
        ("🎮👨‍🚀🌌", "Guardians of the Galaxy"),
        ("👊💥🦾", "Iron Man"),
        ("⚡🔨🦸", "Thor"),
        ("🎯🏹💚", "The Avengers"),
        ("🕷️🕸️🌆", "Spider-Man Homecoming"),
        ("🐆👗🎬", "Cruella"),
        ("👨‍👩‍👧‍👦🎬🎭", "Encanto"),
        ("💃🎭🎬", "The Phantom of the Opera"),
        ("🎼🎬🇺🇸", "Hamilton"),
        ("👦👩‍🎤🎤", "A Star Is Born"),
        ("🎬🚀🌒", "First Man"),
        ("🐺💵📈", "The Wolf of Wall Street"),
        ("🎬💵🏦", "Ocean's Eleven"),
        ("🎬🔐💵", "The Italian Job"),
        ("🎬💊🇲🇽", "Narcos"),
        ("🎬🔫🇺🇸", "The Godfather"),
        ("🚔🇺🇸💰", "Bad Boys"),
        ("🏊‍♂️🎬💰", "The Big Short"),
        ("👀🏠", "Get Out"),
        ("👶👦🎬", "Home Alone"),
        ("🎅🎄🚁", "Die Hard"),
        ("🎬🚗💨", "Gone in 60 Seconds"),
        ("🎬🚘⏱️", "Speed"),
        ("🎬🏖️🦈", "Jaws"),
        ("🕰️🐢", "The Curious Case of Benjamin Button"),
        ("🎬🎂🎩", "Alice in Wonderland (2010)"),
        ("🎬🐘🚂", "Dumbo (2019)"),
        ("🎬🐝🎥", "Bee Movie"),
        ("🎬📕😍", "The Notebook"),
        ("🎬💌💒", "27 Dresses"),
        ("🎬🍰💔", "Marriage Story"),
        ("🎬💇‍♀️👗", "Legally Blonde"),
        ("🎬🍿📺", "Scream"),
        ("🎬🎃🪓", "Halloween"),
        ("🎬🚿🔪", "Psycho"),
        ("🎬👻🏠", "The Conjuring"),
        ("🎬👻⛏️", "The Grudge"),
        ("🎬👽🌌🌎", "Independence Day"),
        ("🚀🌒👨‍🚀", "Apollo 13"),
        ("🎬🌌🎼", "Interstellar"),
        ("🎬🌌🕰️", "Tenet"),
        ("🎬🌀💤", "Inception"),
        ("👴🎈🐕🏠", "Up"),
        ("🎬🐷👨‍🌾", "Babe"),
        ("🎬🐴🎠", "War Horse"),
        ("🐺🐺🎬", "The Grey"),
        ("🎬🦁🐟", "Life of Pi"),
        ("🎬🎯🌌", "Guardians of the Galaxy Vol. 2"),
    ]

    @State private var idx: Int = 0
    @State private var revealed: Bool = false
    @State private var queue: [Int] = []

    var body: some View {
        GameChrome {
            VStack(spacing: 20) {
                let p = Self.phrases[idx]
                Text(p.emoji)
                    .font(.system(size: 76))
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface.opacity(0.95)))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.hairline, lineWidth: 1))

                if revealed {
                    Text(p.answer)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Theme.accentDeep)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Guess the phrase.").foregroundStyle(Theme.inkSoft)
                }

                HStack(spacing: 12) {
                    Button(revealed ? "Next ▶︎" : "Reveal") {
                        hapticTap()
                        if revealed {
                            advance()
                        } else {
                            revealed = true
                        }
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                    .frame(maxWidth: .infinity)
                    Button("Shuffle") {
                        advance()
                    }
                    .buttonStyle(.bordered).tint(Theme.accentDeep)
                    .frame(maxWidth: .infinity)
                }
            }
            .onAppear {
                if queue.isEmpty {
                    queue = Array(0..<Self.phrases.count).shuffled()
                    idx = queue.popLast() ?? 0
                }
            }
        }
    }

    private func advance() {
        revealed = false
        if queue.isEmpty {
            var reshuffled = Array(0..<Self.phrases.count).shuffled()
            if reshuffled.last == idx, reshuffled.count > 1 {
                reshuffled.swapAt(reshuffled.count - 1, 0)
            }
            queue = reshuffled
        }
        idx = queue.popLast() ?? idx
    }
}

// MARK: - Trivia

struct TriviaGame: View {
    @Environment(RoomService.self) private var roomService
    private struct Question { let q: String; let options: [String]; let answer: Int }
    private static let bank: [Question] = [
        // Geography
        .init(q: "What is the capital of Australia?", options: ["Sydney", "Canberra", "Melbourne", "Perth"], answer: 1),
        .init(q: "How many continents are there?", options: ["5", "6", "7", "8"], answer: 2),
        .init(q: "Which is the largest ocean?", options: ["Atlantic", "Pacific", "Indian", "Arctic"], answer: 1),
        .init(q: "What is the longest river in the world?", options: ["Amazon", "Nile", "Yangtze", "Mississippi"], answer: 1),
        .init(q: "What is the tallest mountain in the world?", options: ["K2", "Everest", "Kilimanjaro", "Denali"], answer: 1),
        .init(q: "Which is the smallest country in the world?", options: ["Monaco", "Vatican City", "San Marino", "Malta"], answer: 1),
        .init(q: "What is the capital of Canada?", options: ["Toronto", "Montreal", "Ottawa", "Vancouver"], answer: 2),
        .init(q: "What is the capital of Brazil?", options: ["Rio de Janeiro", "São Paulo", "Brasília", "Salvador"], answer: 2),
        .init(q: "Which is the largest country by area?", options: ["USA", "Canada", "Russia", "China"], answer: 2),
        .init(q: "Capital of Norway?", options: ["Stockholm", "Oslo", "Helsinki", "Copenhagen"], answer: 1),
        .init(q: "Capital of Spain?", options: ["Barcelona", "Madrid", "Seville", "Valencia"], answer: 1),
        .init(q: "Capital of Japan?", options: ["Kyoto", "Osaka", "Tokyo", "Nagoya"], answer: 2),
        .init(q: "Capital of Egypt?", options: ["Alexandria", "Cairo", "Giza", "Luxor"], answer: 1),
        .init(q: "Capital of South Korea?", options: ["Busan", "Incheon", "Seoul", "Daegu"], answer: 2),
        .init(q: "Which country has the most time zones?", options: ["Russia", "USA", "France", "China"], answer: 2),
        .init(q: "Which desert is the largest in the world?", options: ["Sahara", "Gobi", "Antarctic", "Kalahari"], answer: 2),
        .init(q: "Which country is home to Machu Picchu?", options: ["Chile", "Peru", "Bolivia", "Colombia"], answer: 1),
        .init(q: "How many US states are there?", options: ["48", "49", "50", "52"], answer: 2),
        .init(q: "Great Barrier Reef is off the coast of…", options: ["Australia", "New Zealand", "Fiji", "Indonesia"], answer: 0),
        .init(q: "Currency of Japan?", options: ["Yen", "Yuan", "Won", "Rupee"], answer: 0),
        .init(q: "Currency of Switzerland?", options: ["Euro", "Franc", "Krona", "Krone"], answer: 1),
        .init(q: "Currency of Sweden?", options: ["Krona", "Krone", "Franc", "Euro"], answer: 0),
        // History
        .init(q: "In what year did WWII end?", options: ["1943", "1944", "1945", "1946"], answer: 2),
        .init(q: "In what year did WWI start?", options: ["1912", "1914", "1916", "1918"], answer: 1),
        .init(q: "Year the Titanic sank?", options: ["1910", "1912", "1914", "1916"], answer: 1),
        .init(q: "First president of the USA?", options: ["Adams", "Washington", "Jefferson", "Madison"], answer: 1),
        .init(q: "Who was the first man on the moon?", options: ["Buzz Aldrin", "Neil Armstrong", "Yuri Gagarin", "Michael Collins"], answer: 1),
        .init(q: "In what year did the Berlin Wall fall?", options: ["1987", "1989", "1990", "1991"], answer: 1),
        .init(q: "The Cold War ended around…", options: ["1985", "1989", "1991", "1993"], answer: 2),
        .init(q: "The Chernobyl disaster occurred in…", options: ["1984", "1986", "1988", "1990"], answer: 1),
        .init(q: "In what year did the US declare independence?", options: ["1774", "1776", "1783", "1791"], answer: 1),
        .init(q: "First person to circumnavigate the globe was…", options: ["Columbus", "Magellan", "Cook", "Drake"], answer: 1),
        .init(q: "Which ancient wonder was in Egypt?", options: ["Hanging Gardens", "Colossus of Rhodes", "Great Pyramid of Giza", "Lighthouse of Alexandria"], answer: 2),
        .init(q: "Napoleon was defeated at the Battle of…", options: ["Trafalgar", "Waterloo", "Austerlitz", "Borodino"], answer: 1),
        .init(q: "Julius Caesar was assassinated in…", options: ["44 BC", "27 BC", "14 AD", "100 BC"], answer: 0),
        .init(q: "The French Revolution began in…", options: ["1776", "1789", "1799", "1815"], answer: 1),
        // Science / nature
        .init(q: "Chemical formula for water?", options: ["H2O", "CO2", "O2", "HO"], answer: 0),
        .init(q: "Chemical symbol for gold?", options: ["Ag", "Au", "Gd", "Go"], answer: 1),
        .init(q: "Chemical symbol for iron?", options: ["Fl", "Ir", "Fe", "In"], answer: 2),
        .init(q: "Chemical symbol for potassium?", options: ["P", "K", "Po", "Pt"], answer: 1),
        .init(q: "Chemical symbol for mercury?", options: ["He", "Hy", "Hg", "Mc"], answer: 2),
        .init(q: "How many bones are in the adult human body?", options: ["186", "206", "226", "256"], answer: 1),
        .init(q: "How many teeth in a typical adult mouth?", options: ["28", "30", "32", "34"], answer: 2),
        .init(q: "How many hearts does an octopus have?", options: ["1", "2", "3", "4"], answer: 2),
        .init(q: "Which is the largest planet?", options: ["Earth", "Saturn", "Jupiter", "Neptune"], answer: 2),
        .init(q: "Which planet is closest to the Sun?", options: ["Venus", "Mercury", "Earth", "Mars"], answer: 1),
        .init(q: "Which planet is known as the Red Planet?", options: ["Venus", "Mars", "Jupiter", "Mercury"], answer: 1),
        .init(q: "The coldest planet in our solar system is…", options: ["Uranus", "Neptune", "Pluto", "Saturn"], answer: 1),
        .init(q: "Which planet has the most well-known rings?", options: ["Jupiter", "Uranus", "Saturn", "Neptune"], answer: 2),
        .init(q: "How fast is the speed of light (approx)?", options: ["300,000 km/s", "3,000 km/s", "30,000 km/s", "3,000,000 km/s"], answer: 0),
        .init(q: "Which vitamin does the sun help your body produce?", options: ["A", "C", "D", "E"], answer: 2),
        .init(q: "Which vitamin helps blood clotting?", options: ["A", "D", "E", "K"], answer: 3),
        .init(q: "Universal blood donor type?", options: ["A+", "O-", "AB+", "B-"], answer: 1),
        .init(q: "Fastest land animal?", options: ["Cheetah", "Lion", "Horse", "Pronghorn"], answer: 0),
        .init(q: "Fastest bird?", options: ["Peregrine falcon", "Eagle", "Hawk", "Swift"], answer: 0),
        .init(q: "Which is a mammal?", options: ["Shark", "Octopus", "Dolphin", "Snake"], answer: 2),
        .init(q: "Which is NOT a primary color of light?", options: ["Red", "Yellow", "Green", "Blue"], answer: 1),
        .init(q: "What does DNA stand for?", options: ["Deoxyribonucleic acid", "Diribonucleic acid", "Dinitro amine", "Direct nuclear acid"], answer: 0),
        .init(q: "Longest bone in the human body?", options: ["Femur", "Tibia", "Humerus", "Spine"], answer: 0),
        .init(q: "Study of earthquakes is called…", options: ["Meteorology", "Seismology", "Geology", "Volcanology"], answer: 1),
        .init(q: "What percentage of Earth's surface is water?", options: ["51%", "61%", "71%", "81%"], answer: 2),
        .init(q: "Which is a noble gas?", options: ["Nitrogen", "Oxygen", "Argon", "Chlorine"], answer: 2),
        // Literature / arts
        .init(q: "Who wrote Romeo and Juliet?", options: ["Dickens", "Shakespeare", "Austen", "Twain"], answer: 1),
        .init(q: "Who wrote Hamlet?", options: ["Marlowe", "Shakespeare", "Milton", "Chaucer"], answer: 1),
        .init(q: "Who wrote Pride and Prejudice?", options: ["Charlotte Brontë", "Jane Austen", "Virginia Woolf", "Emily Dickinson"], answer: 1),
        .init(q: "Who wrote 1984?", options: ["Huxley", "Orwell", "Bradbury", "Vonnegut"], answer: 1),
        .init(q: "Who wrote The Great Gatsby?", options: ["Hemingway", "Fitzgerald", "Faulkner", "Steinbeck"], answer: 1),
        .init(q: "Who wrote War and Peace?", options: ["Dostoevsky", "Tolstoy", "Chekhov", "Pushkin"], answer: 1),
        .init(q: "Who wrote Alice in Wonderland?", options: ["Barrie", "Carroll", "Milne", "Kipling"], answer: 1),
        .init(q: "Who wrote Frankenstein?", options: ["Mary Shelley", "Bram Stoker", "Edgar Allan Poe", "Arthur Conan Doyle"], answer: 0),
        .init(q: "Who wrote The Odyssey?", options: ["Virgil", "Homer", "Ovid", "Aristotle"], answer: 1),
        .init(q: "Who wrote the Harry Potter series?", options: ["J.K. Rowling", "C.S. Lewis", "R.R. Martin", "R.L. Stine"], answer: 0),
        .init(q: "Who wrote The Divine Comedy?", options: ["Dante", "Petrarch", "Boccaccio", "Machiavelli"], answer: 0),
        .init(q: "Who painted the Mona Lisa?", options: ["Michelangelo", "Da Vinci", "Van Gogh", "Picasso"], answer: 1),
        .init(q: "Who painted the Sistine Chapel ceiling?", options: ["Da Vinci", "Raphael", "Michelangelo", "Donatello"], answer: 2),
        .init(q: "Who painted The Starry Night?", options: ["Van Gogh", "Monet", "Cézanne", "Renoir"], answer: 0),
        .init(q: "Who painted The Persistence of Memory?", options: ["Dalí", "Miró", "Picasso", "Braque"], answer: 0),
        .init(q: "Who composed Für Elise?", options: ["Bach", "Beethoven", "Mozart", "Chopin"], answer: 1),
        .init(q: "Who composed Moonlight Sonata?", options: ["Mozart", "Beethoven", "Chopin", "Bach"], answer: 1),
        // Pop culture / movies
        .init(q: "Who directed Titanic?", options: ["James Cameron", "Spielberg", "Nolan", "Scorsese"], answer: 0),
        .init(q: "Which is NOT a Star Wars planet?", options: ["Tatooine", "Naboo", "Endor", "Krypton"], answer: 3),
        .init(q: "In which city are the Central Perk sets from Friends set?", options: ["New York", "Chicago", "Boston", "LA"], answer: 0),
        .init(q: "Which country hosted the 2022 FIFA World Cup?", options: ["Russia", "Qatar", "France", "Brazil"], answer: 1),
        .init(q: "Where were the 2016 Summer Olympics held?", options: ["London", "Beijing", "Rio", "Tokyo"], answer: 2),
        .init(q: "How many players on a football (soccer) team on the field?", options: ["9", "10", "11", "12"], answer: 2),
        .init(q: "Which instrument does Yo-Yo Ma play?", options: ["Violin", "Cello", "Piano", "Guitar"], answer: 1),
        .init(q: "Which is the best-selling album of all time?", options: ["Thriller", "Back in Black", "Dark Side of the Moon", "The Bodyguard"], answer: 0),
        .init(q: "Which company founded by Bill Gates?", options: ["Apple", "Microsoft", "IBM", "Oracle"], answer: 1),
        .init(q: "Which is the tallest building in the world (2020s)?", options: ["Burj Khalifa", "Shanghai Tower", "One WTC", "Merdeka 118"], answer: 0),
        .init(q: "Where does the football club Barcelona come from?", options: ["Portugal", "Spain", "Italy", "Argentina"], answer: 1),
        .init(q: "What color is a giraffe's tongue?", options: ["Pink", "Red", "Blue", "Purple"], answer: 3),
        // Language / general
        .init(q: "Which language has the most native speakers?", options: ["English", "Spanish", "Mandarin", "Hindi"], answer: 2),
        .init(q: "Language most commonly spoken in Brazil?", options: ["Spanish", "Portuguese", "French", "Italian"], answer: 1),
        .init(q: "What does HTTP stand for?", options: ["Hyper Text Transfer Protocol", "Home Terminal Transfer Path", "Hyper Terminal Transfer Program", "Hosted Text Type Protocol"], answer: 0),
        .init(q: "Roman numeral for 50?", options: ["X", "L", "C", "D"], answer: 1),
        .init(q: "Roman numeral for 1000?", options: ["V", "M", "D", "C"], answer: 1),
        .init(q: "Pi to two decimal places?", options: ["3.12", "3.14", "3.16", "3.18"], answer: 1),
        .init(q: "Common name for sodium chloride?", options: ["Sugar", "Salt", "Baking soda", "Chalk"], answer: 1),
        .init(q: "Chess piece that only moves diagonally?", options: ["Rook", "Bishop", "Knight", "Queen"], answer: 1),
        .init(q: "Which is the smallest ocean?", options: ["Atlantic", "Southern", "Arctic", "Indian"], answer: 2),
        .init(q: "Which is not one of the seven wonders of the ancient world?", options: ["Great Pyramid", "Hanging Gardens", "Colosseum", "Colossus of Rhodes"], answer: 2),
        .init(q: "How many strings does a standard violin have?", options: ["3", "4", "5", "6"], answer: 1),
        .init(q: "What is the currency of the UK?", options: ["Euro", "Dollar", "Pound", "Krone"], answer: 2),
        .init(q: "Which country invented paper?", options: ["Egypt", "China", "Greece", "India"], answer: 1),
        .init(q: "Which is the hottest chili on the Scoville scale (of these)?", options: ["Jalapeño", "Habanero", "Ghost pepper", "Carolina Reaper"], answer: 3),
        .init(q: "Which meat traditionally is used in a Wellington?", options: ["Chicken", "Lamb", "Beef", "Pork"], answer: 2),
        .init(q: "What year was Facebook founded?", options: ["2001", "2004", "2006", "2008"], answer: 1),
        .init(q: "Which app was originally called 'Bark'?", options: ["Twitter", "Snapchat", "Instagram", "TikTok"], answer: 1),
        .init(q: "How many colors are in a rainbow?", options: ["5", "6", "7", "8"], answer: 2),
        .init(q: "How many minutes are in a full day?", options: ["1200", "1440", "1600", "2400"], answer: 1),
        .init(q: "What is the square root of 144?", options: ["10", "12", "14", "16"], answer: 1),
        .init(q: "Which animal is Australia's national symbol along with the kangaroo?", options: ["Koala", "Emu", "Wombat", "Platypus"], answer: 1),
    ]

    @State private var order: [Int] = Array(0..<TriviaGame.bank.count).shuffled()
    @State private var idx: Int = 0
    @State private var score: Int = 0
    @State private var selected: Int? = nil
    @State private var timeLeft: Int = 15
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var done: Bool = false

    var body: some View {
        GameChrome {
            VStack(spacing: 20) {
                if done {
                    Text("🏁").font(.system(size: 72))
                    Text("Score: \(score)/\(order.count)")
                        .font(.title.weight(.heavy)).foregroundStyle(Theme.ink)
                    BigActionButton(title: "Play again") { reset() }
                } else {
                    let q = Self.bank[order[idx]]
                    HStack {
                        Text("Q\(idx + 1)/\(order.count)").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                        Spacer()
                        Text("⏱ \(timeLeft)s")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(timeLeft <= 3 ? Theme.danger : Theme.inkSoft)
                    }
                    Text(q.q)
                        .font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 10) {
                        ForEach(0..<q.options.count, id: \.self) { i in
                            Button {
                                choose(i, correct: q.answer)
                            } label: {
                                HStack {
                                    Text(q.options[i]).foregroundStyle(Theme.ink)
                                    Spacer()
                                    if let sel = selected {
                                        if i == q.answer {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                                        } else if sel == i {
                                            Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.danger)
                                        }
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 12).fill(tone(for: i, answer: q.answer)))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
                            }
                            .buttonStyle(BeerifyPressStyle())
                            .disabled(selected != nil)
                        }
                    }
                    if selected != nil {
                        BigActionButton(title: idx + 1 >= order.count ? "See score" : "Next question") { advance() }
                    }
                }
            }
        }
        .onAppear { startTimer() }
        .onDisappear { timerTask?.cancel() }
    }

    private func tone(for i: Int, answer: Int) -> Color {
        guard let sel = selected else { return Theme.surface.opacity(0.9) }
        if i == answer { return Theme.success.opacity(0.20) }
        if i == sel { return Theme.danger.opacity(0.18) }
        return Theme.surface.opacity(0.9)
    }

    private func choose(_ i: Int, correct: Int) {
        hapticTap()
        selected = i
        if i == correct { score += 1 }
        timerTask?.cancel()
    }

    private func advance() {
        if idx + 1 >= order.count {
            done = true
            let pct = Int(round(Double(score) / Double(order.count) * 100))
            roomService.reportScore(gameId: "trivia", score: pct)
        } else {
            idx += 1
            selected = nil
            timeLeft = 15
            startTimer()
        }
    }

    private func startTimer() {
        timeLeft = 15
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled && timeLeft > 0 && selected == nil {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { if timeLeft > 0 { timeLeft -= 1 } }
            }
            if selected == nil {
                await MainActor.run { selected = -1 }  // out of time - nothing selected
            }
        }
    }

    private func reset() {
        order = Array(0..<Self.bank.count).shuffled()
        idx = 0; score = 0; selected = nil; done = false; startTimer()
    }
}
