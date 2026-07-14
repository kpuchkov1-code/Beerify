//
//  SpicyGames.swift
//  Beerify
//
//  Spicier party games: Ranked (the "pick a question, rank the squad, others
//  guess" format), Would You Rather, Most Likely To, and Two Truths and a Lie.
//
//  All are pass-the-phone friendly — no multi-device sync required. Where
//  it makes sense they read squad members from the current room.
//

import SwiftUI

// MARK: - Ranked

struct RankedGame: View {
    @Environment(RoomService.self) private var roomService
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if let room = roomService.state, room.members.count >= 2 {
                RankedMultiDevice()
            } else {
                RankedPassAround()
            }
        }
        .navigationTitle("ID Game")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Ranked · Multi-device

private struct RankedMultiDevice: View {
    @Environment(RoomService.self) private var roomService
    @Environment(AppStore.self) private var store

    /// Only the picker device knows the chosen index.
    @State private var pickerChoice: Int? = nil
    /// The picker's in-progress ranking before submission.
    @State private var workingRanking: [String] = []
    /// Set once the local guesser taps a question but hasn't hit "lock in".
    @State private var pendingGuess: Int? = nil

    private var members: [SquadMember] { roomService.state?.members ?? [] }
    private var myId: String? { roomService.currentMemberId }
    private var round: RankedRoundState? { roomService.rankedRound }
    private var isPicker: Bool { myId != nil && round?.pickerId == myId }
    private var deck: [String] {
        guard let round else { return [] }
        return RankedPassAround.deck.upTo(round.spiciness)
    }

    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) { content }.padding(20) }
            .background(BeerifyBackground())
    }

    @ViewBuilder private var content: some View {
        if let round {
            if round.revealedQuestionIdx != nil {
                revealBody(round)
            } else if isPicker {
                pickerBody(round)
            } else {
                guesserBody(round)
            }
        } else {
            startBody
        }
    }

    // MARK: Start

    private var startBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ID Game").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
            Text("You'll draw a random question in secret and rank the squad by it. The others see only a shortlist of 10 questions and have to guess which one you had.")
                .foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text("🌶").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spiciness: \(store.data.preferences.spiciness)/5").font(.headline).foregroundStyle(Theme.ink)
                    Text("The round uses your spiciness — everyone will see the same filtered deck.")
                        .font(.caption).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface.opacity(0.9)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))

            Button {
                _ = roomService.rankedStart(spiciness: store.data.preferences.spiciness)
                pickerChoice = nil
                workingRanking = []
                pendingGuess = nil
            } label: {
                Text("Start round — I'm the picker").frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)

            Text("You're in a room with \(members.count) player\(members.count == 1 ? "" : "s"). They'll see everything live.")
                .font(.caption).foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: Picker

    @ViewBuilder
    private func pickerBody(_ round: RankedRoundState) -> some View {
        if pickerChoice == nil {
            pickerDrawQuestion(round)
        } else if round.ranking.isEmpty {
            pickerRankView(round)
        } else {
            pickerAwaitReveal(round)
        }
    }

    private func pickerDrawQuestion(_ round: RankedRoundState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header("You're the picker")
            Text("Tap to draw a random question. Only you will see it. The squad will see a shortlist of 10 to guess from.")
                .font(.callout).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)

            Button {
                drawQuestion(round: round)
            } label: {
                HStack {
                    Image(systemName: "die.face.5.fill")
                    Text("Draw a random question").frame(maxWidth: .infinity)
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)

            cancelRow
        }
    }

    /// Draws a random question for the picker and generates a shortlist of 10
    /// (including the drawn one). Broadcasts the shortlist to the squad.
    private func drawQuestion(round: RankedRoundState) {
        let count = deck.count
        guard count > 0 else { return }
        let answer = Int.random(in: 0..<count)
        pickerChoice = answer
        let listSize = min(10, count)
        var picks: Set<Int> = [answer]
        while picks.count < listSize {
            picks.insert(Int.random(in: 0..<count))
        }
        let shortlist = Array(picks).shuffled()
        roomService.rankedSubmitShortlist(shortlist)
    }

    private func pickerShowsAnswer(_ round: RankedRoundState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your secret question").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
            Text(deck.indices.contains(pickerChoice ?? -1) ? deck[pickerChoice!] : "—")
                .font(.title3.weight(.heavy)).foregroundStyle(Theme.accentDeep)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.2)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
        }
    }

    private func pickerRankView(_ round: RankedRoundState) -> some View {
        let others = members.map(\.id)
        let remaining = others.filter { !workingRanking.contains($0) }
        return VStack(alignment: .leading, spacing: 12) {
            pickerShowsAnswer(round)
            header("Rank the squad. Tap in order (🥇, 🥈, 🥉, then #4+).")
            if !workingRanking.isEmpty {
                rankedList(memberIds: workingRanking)
            }
            if !remaining.isEmpty {
                Text("Still to place").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(remaining, id: \.self) { id in
                        Button {
                            workingRanking.append(id)
                        } label: { memberPill(id: id) }
                            .buttonStyle(BeerifyPressStyle())
                    }
                }
            } else {
                Button {
                    roomService.rankedSubmitRanking(workingRanking)
                } label: {
                    Text("Send ranking to the squad").frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
            }
            if !workingRanking.isEmpty {
                Button("Undo last") {
                    workingRanking.removeLast()
                }.buttonStyle(.bordered).tint(Theme.accentDeep).font(.caption)
            }
            cancelRow
        }
    }

    private func pickerAwaitReveal(_ round: RankedRoundState) -> some View {
        let guesserCount = members.filter { $0.id != round.pickerId }.count
        let submitted = round.guesses.count
        return VStack(alignment: .leading, spacing: 12) {
            pickerShowsAnswer(round)
            header("Ranking sent. Waiting for guesses…")
            rankedList(memberIds: round.ranking)
            ProgressView(value: Double(min(submitted, guesserCount)), total: Double(max(1, guesserCount))) {
                Text("\(submitted) of \(guesserCount) squad members guessed")
                    .font(.caption).foregroundStyle(Theme.inkSoft)
            }
            .tint(Theme.accent)
            if let choice = pickerChoice {
                Button {
                    roomService.rankedReveal(choice)
                } label: {
                    Text("Reveal the answer").frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
            }
            cancelRow
        }
    }

    // MARK: Guesser

    @ViewBuilder
    private func guesserBody(_ round: RankedRoundState) -> some View {
        if round.shortlist == nil || round.ranking.isEmpty {
            waitingCard(text: "\(round.pickerName) is drawing a question and ranking the squad…")
        } else if let myId, round.guesses[myId] != nil {
            guesserLocked(round)
        } else {
            guesserGuessing(round)
        }
    }

    private func guesserGuessing(_ round: RankedRoundState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header("\(round.pickerName) ranked the squad. What question did they use?")
            rankedList(memberIds: round.ranking)
            questionList(round: round, selectedIdx: pendingGuess, onTap: { i in
                pendingGuess = i
            })
            if let pending = pendingGuess {
                Button {
                    roomService.rankedSubmitGuess(pending)
                } label: {
                    Text("Lock in guess").frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
            }
            cancelRow
        }
    }

    private func guesserLocked(_ round: RankedRoundState) -> some View {
        let guesserCount = members.filter { $0.id != round.pickerId }.count
        return VStack(alignment: .leading, spacing: 12) {
            header("Guess locked in ✅")
            Text("Waiting for the reveal from \(round.pickerName)…")
                .foregroundStyle(Theme.inkSoft)
            ProgressView(value: Double(round.guesses.count), total: Double(max(1, guesserCount)))
                .tint(Theme.accent)
            rankedList(memberIds: round.ranking)
            cancelRow
        }
    }

    // MARK: Reveal (all devices)

    private func revealBody(_ round: RankedRoundState) -> some View {
        let questionIdx = round.revealedQuestionIdx ?? 0
        let questions = deck
        let winners = round.guesses.filter { $0.value == questionIdx }.keys.compactMap { id in members.first(where: { $0.id == id })?.name }
        return VStack(alignment: .leading, spacing: 12) {
            Text("The question was").font(.subheadline).foregroundStyle(Theme.inkSoft)
            Text(questions.indices.contains(questionIdx) ? questions[questionIdx] : "—")
                .font(.title2.weight(.heavy)).foregroundStyle(Theme.accentDeep)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.2)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.5), lineWidth: 1))

            Text("Ranking").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
            rankedList(memberIds: round.ranking)

            if !winners.isEmpty {
                Text("🏆 Guessed it right: \(winners.joined(separator: ", "))")
                    .font(.headline).foregroundStyle(Theme.success)
            } else if !round.guesses.isEmpty {
                Text("Nobody nailed it this round. Better luck next 🙂")
                    .font(.callout).foregroundStyle(Theme.inkSoft)
            }

            Button {
                roomService.rankedCancel()
                pickerChoice = nil
                workingRanking = []
                pendingGuess = nil
            } label: {
                Text("Start next round").frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
        }
    }

    // MARK: Shared bits

    private func header(_ text: String) -> some View {
        Text(text).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
    }

    /// Shows the picker's shortlist of ten questions for guessers to choose from.
    /// If the shortlist hasn't been synced yet we hide the list rather than
    /// spoiling the reveal by showing the full deck.
    private func questionList(round: RankedRoundState, selectedIdx: Int?, onTap: @escaping (Int) -> Void) -> some View {
        let shortlist = round.shortlist ?? []
        return VStack(spacing: 6) {
            ForEach(Array(shortlist.enumerated()), id: \.offset) { pos, deckIdx in
                let q = deck.indices.contains(deckIdx) ? deck[deckIdx] : "—"
                let selected = selectedIdx == deckIdx
                Button {
                    onTap(deckIdx)
                } label: {
                    HStack(alignment: .top) {
                        Text("\(pos + 1).")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(width: 22, alignment: .leading)
                        Text(q).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                        Spacer()
                        if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accentDeep) }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Theme.accent.opacity(0.25) : Theme.surface.opacity(0.9)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Theme.accent : Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(BeerifyPressStyle())
            }
        }
    }

    private func rankedList(memberIds: [String]) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(memberIds.enumerated()), id: \.offset) { i, id in
                let name = members.first(where: { $0.id == id })?.name ?? id
                HStack {
                    Text(RankedGameFormat.badge(i + 1))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .frame(width: 32)
                    Text(Avatars.avatar(for: id)).font(.title3)
                    Text(name).foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
            }
        }
    }

    private func memberPill(id: String) -> some View {
        let name = members.first(where: { $0.id == id })?.name ?? id
        return HStack(spacing: 6) {
            Text(Avatars.avatar(for: id)).font(.title3)
            Text(name).foregroundStyle(Theme.ink)
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
    }

    private func waitingCard(text: String) -> some View {
        VStack(spacing: 10) {
            ProgressView().tint(Theme.accentDeep)
            Text(text).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
        }
        .padding(24).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
    }

    private var cancelRow: some View {
        Button(role: .destructive) {
            roomService.rankedCancel()
        } label: {
            Text("Cancel round").font(.caption).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered).tint(Theme.danger).controlSize(.small)
    }
}

enum RankedGameFormat {
    static func badge(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(rank)"
        }
    }
}

// MARK: - Ranked · Pass-around (solo device)

private struct RankedPassAround: View {
    @Environment(RoomService.self) private var roomService
    @Environment(AppStore.self) private var store

    enum Phase { case setup, secret, pick, rank, reveal }

    @State private var phase: Phase = .setup
    @State private var players: [String] = []
    @State private var newName: String = ""
    @State private var questionIdx: Int? = nil
    @State private var shortlist: [Int] = []
    @State private var ranking: [String] = []
    @State private var guessIdx: Int? = nil
    @State private var revealed: Bool = false

    /// Same master deck as the multi-device flow. `static` so the multi-device
    /// version can reference it too.
    ///
    /// Curated list of ~200 "ID game" style ranking prompts. The picker draws
    /// one at random and ranks the squad by it; the other players see only
    /// a shortlist of 10 to guess from.
    static let deck: [SpicyPrompt] = [
        // Level 2 — silly / general
        .init(text: "Most to least likely to live the longest", level: 2),
        .init(text: "Most to least likely to give themselves food poisoning", level: 2),
        .init(text: "Most to least likely to crash a car", level: 2),
        .init(text: "Most to least likely to lecture everyone about conspiracy theories", level: 2),
        .init(text: "If you could be in someone's body for 24 hours, who would you choose?", level: 2),
        .init(text: "Person you would most want to get stuck on a desert island with", level: 2),
        .init(text: "Most to least likely to get a face tattoo", level: 2),
        .init(text: "Most to least likely to become famous", level: 2),
        .init(text: "Most to least likely to have their own TV show", level: 2),
        .init(text: "Most to least likely to become a Karen", level: 2),
        .init(text: "Most to least likely to marry/date a celebrity", level: 2),
        .init(text: "Most to least likely to die first in the Hunger Games", level: 2),
        .init(text: "Best to worst music taste (subjective)", level: 2),
        .init(text: "Who gives the best to worst advice", level: 2),
        .init(text: "Most ballsy to least ballsy", level: 2),
        .init(text: "Most to least likely to leave uni", level: 2),
        .init(text: "Most to least likely to turn to YouTube/TikTok/being an influencer for money", level: 2),
        .init(text: "Most to least likely to die alone surrounded by their 10 dogs/cats/whatever", level: 2),
        .init(text: "You get to choose one of us to be your sibling — what order are you picking us in?", level: 2),
        .init(text: "Best to worst chef", level: 2),
        .init(text: "Best to worst at parenting (if they had a kid)", level: 2),
        .init(text: "Poshest to least posh voice", level: 2),
        .init(text: "If we all had YouTube accounts, who would you be most to least likely to watch?", level: 2),
        .init(text: "Most to least likely to be a house wife/husband", level: 2),
        .init(text: "Most to least bossiest", level: 2),
        .init(text: "Most to least likely to drop out of uni", level: 2),
        .init(text: "Most to least likely to be living with their parents when they're 30", level: 2),
        .init(text: "Most likely to get offended by this game", level: 2),
        .init(text: "If you got in a fight, who would you want most to least to back you the most?", level: 2),
        .init(text: "Most to least feisty", level: 2),
        .init(text: "Person you would want most to least as a housemate for a year", level: 2),
        .init(text: "Most likely to be involved in any kind of successful business startup", level: 2),
        .init(text: "Most to least likely to throw up in class/work", level: 2),
        .init(text: "Most to least likely to commit plagiarism", level: 2),
        .init(text: "Most to least likely to fail 1st year", level: 2),
        .init(text: "Most to least likely to release music unironically", level: 2),
        .init(text: "Most to least likely to become prime minister", level: 2),
        .init(text: "Most to least likely to be in a history book", level: 2),
        .init(text: "Most to least likely to be nice to someone they hate", level: 2),
        .init(text: "Most to least likely to like a piece of ugly clothing", level: 2),
        .init(text: "Most to least likely to cry on a night out", level: 2),
        .init(text: "Most to least likely to get paralytic on a night out", level: 2),
        .init(text: "Most to least likely to get a bad piercing or tattoo", level: 2),
        .init(text: "Most to least likely to get a shocking haircut", level: 2),
        .init(text: "Most to least likely to get hit by a car", level: 2),
        .init(text: "Most to least likely to live abroad", level: 2),
        .init(text: "Most to least likely to fail quitting nicotine", level: 2),
        .init(text: "Most to least likely to become emo", level: 2),
        .init(text: "Most to least likely to fail to make it to the night out", level: 2),
        .init(text: "Most to least likely to spend the most on a night out", level: 2),
        .init(text: "Most to least likely to win 'Traitors' as a traitor (BBC show)", level: 2),
        .init(text: "Most to least likely to collect crystals and cast spells", level: 2),
        .init(text: "Most to least likely to go into space", level: 2),
        .init(text: "Most to least likely to join the army", level: 2),
        .init(text: "Most to least likely to be first on karaoke", level: 2),
        .init(text: "Most to least likely to get too drunk at the pre game", level: 2),
        .init(text: "Most likely to embarrass themselves at a work function", level: 2),
        .init(text: "Most to least likely to survive a zombie apocalypse", level: 2),
        .init(text: "Most to least likely to be first on the dance floor", level: 2),
        .init(text: "Most to least likely to go out more than 3 nights in a row", level: 2),
        .init(text: "Most to least likely to write a love song/poem", level: 2),
        .init(text: "Most to least likely to start a fire", level: 2),
        .init(text: "Most to least likely to go missing on a night out", level: 2),
        .init(text: "Most to least likely to overshare on social media", level: 2),
        .init(text: "Most to least likely to ask stupid questions", level: 2),
        .init(text: "Most to least likely to do something cringey/embarrassing tonight", level: 2),
        .init(text: "Most to least likely to call it an early night", level: 2),
        // Level 3 — medium
        .init(text: "Most to least likely to get in a fight", level: 3),
        .init(text: "Most to least likely to get stood up", level: 3),
        .init(text: "Most to least likely to remain single forever", level: 3),
        .init(text: "Most to least likely to have plastic surgery", level: 3),
        .init(text: "Most to least likely to join a cult", level: 3),
        .init(text: "Most to least likely to give money to a homeless person, and then take it back", level: 3),
        .init(text: "Most to least likely to become emotionally dependent on a significant other", level: 3),
        .init(text: "Best to worst person you'd want to introduce to your parents", level: 3),
        .init(text: "Most to least likely to have a mental breakdown and fuck off out of the country and start a new life", level: 3),
        .init(text: "Biggest pussy", level: 3),
        .init(text: "Most to least likely to join the mafia", level: 3),
        .init(text: "Most to least likely to have a psychotic/mental breakdown", level: 3),
        .init(text: "Most to least likely to still be single at 30+", level: 3),
        .init(text: "Most to least likely to get pushed around in a relationship", level: 3),
        .init(text: "Most to least likely to end up in prison", level: 3),
        .init(text: "Best to worst taste in boys/girls", level: 3),
        .init(text: "Most to least likely to bark at a cat caller/fight back", level: 3),
        .init(text: "Who would you most likely want to be your partner in an actual crime?", level: 3),
        .init(text: "Most likely to accidentally shit themselves", level: 3),
        .init(text: "Most to least likely to get kicked out of uni", level: 3),
        .init(text: "Most to least likely to get kicked out of a club", level: 3),
        .init(text: "Most to least likely to have kids first", level: 3),
        .init(text: "Most to least likely to marry rich", level: 3),
        .init(text: "Most to least likely to divorce more than once", level: 3),
        .init(text: "Biggest to least biggest simp", level: 3),
        .init(text: "Most to least likely to start a cult", level: 3),
        .init(text: "Most to least likely to not get over their ex", level: 3),
        .init(text: "Most to least likely to become a monk or nun", level: 3),
        .init(text: "Most to least likely to have a relationship of less than 3 months", level: 3),
        .init(text: "Most to least likely to break up with someone over text", level: 3),
        .init(text: "Most to least likely to date someone who doesn't speak English", level: 3),
        .init(text: "Most to least likely to become a stalker", level: 3),
        .init(text: "Most to least likely to flirt for a free drink", level: 3),
        .init(text: "Most to least likely to be stalked", level: 3),
        .init(text: "Most to least likely to fake being drunk/high", level: 3),
        .init(text: "Most to least likely to be on Love Island", level: 3),
        .init(text: "Most to least likely to ask someone to be their significant other within 4 days", level: 3),
        .init(text: "Most to least likely to use a shit pick-up line", level: 3),
        .init(text: "Most to least likely to convert to religious extremism", level: 3),
        .init(text: "Most to least likely to agree with Andrew Tate", level: 3),
        .init(text: "Most to least likely to go skinny dipping", level: 3),
        .init(text: "Most to least likely to lose all their money by gambling", level: 3),
        .init(text: "Most to least likely to ghost someone", level: 3),
        .init(text: "Most to least likely to end up in rehab", level: 3),
        .init(text: "Most to least likely to say something offensive", level: 3),
        .init(text: "Most to least likely to stand someone up/ditch mid date", level: 3),
        // Level 4 — spicy
        .init(text: "Most to least likely to cheat", level: 4),
        .init(text: "Most to least likely to get with someone of the same sex", level: 4),
        .init(text: "Most to least likely to date 2 people at once", level: 4),
        .init(text: "Most to least likely to forget the name of someone they hooked up with", level: 4),
        .init(text: "Most to least likely to get over someone by getting under someone else", level: 4),
        .init(text: "Most to least likely to get with a teacher/professor", level: 4),
        .init(text: "Most to least likely to run over a kid (and maybe drive off)", level: 4),
        .init(text: "Most to least likely to become a sugar daddy/mummy when you're old and rich", level: 4),
        .init(text: "Who you think is gonna get pregnant/get a girl pregnant first — and they keep it", level: 4),
        .init(text: "Most to least likely to send a sext to the wrong person", level: 4),
        .init(text: "Most to least likely to become a drug lord", level: 4),
        .init(text: "Most to least likely to be a MILF/DILF", level: 4),
        .init(text: "Most to least likely to message someone just to get nudes", level: 4),
        .init(text: "Most to least likely to scam an old person", level: 4),
        .init(text: "Most to least likely to cheat on their partner", level: 4),
        .init(text: "Most to least likely to have a one night stand", level: 4),
        .init(text: "Most to least likely to be a home wrecker", level: 4),
        .init(text: "Most to least likely to lie to sleep with someone", level: 4),
        .init(text: "Biggest daddy issues", level: 4),
        .init(text: "Biggest mummy issues", level: 4),
        .init(text: "Most to least likely to be walked in on", level: 4),
        .init(text: "Most to least likely to send a 'Showering without me?' Snap", level: 4),
        .init(text: "Most to least likely to go celibate", level: 4),
        .init(text: "Most to least likely to become an incel", level: 4),
        .init(text: "Most to least likely to hook up with someone at a house party", level: 4),
        .init(text: "Most to least likely to snort an unknown powder", level: 4),
        .init(text: "Most to least likely to be on Epstein's list", level: 4),
        .init(text: "Most to least likely to brag about their get-with/one night stand", level: 4),
        .init(text: "Most to least likely to go to a strip club", level: 4),
        .init(text: "Most to least likely to have a secret family", level: 4),
        .init(text: "Most to least likely to sleep with their ex", level: 4),
        .init(text: "Most to least likely to be caught cheating on a club's Instagram photos", level: 4),
        .init(text: "Most to least likely to ditch their friends for a hookup", level: 4),
        .init(text: "Most to least likely to pull a stranger", level: 4),
        .init(text: "Most to least likely to be in a forever-long situationship", level: 4),
        .init(text: "Most to least likely to end up in a toxic relationship", level: 4),
        .init(text: "Most to least likely to say 'I love you' and not mean it", level: 4),
        // Level 5 — unfiltered adult chaos
        .init(text: "Most to least likely to be the loudest during sex", level: 5),
        .init(text: "Most to least vanilla", level: 5),
        .init(text: "Most to least likely to enjoy anal", level: 5),
        .init(text: "Most to least likely to get pegged / peg", level: 5),
        .init(text: "Most to least likely to have a sex change", level: 5),
        .init(text: "Most to least likely to overdose", level: 5),
        .init(text: "Most to least likely to have a threesome", level: 5),
        .init(text: "Most to least likely to masturbate in public", level: 5),
        .init(text: "Most to least likely to get with someone over the age of 60", level: 5),
        .init(text: "Most to least likely to make a sex tape", level: 5),
        .init(text: "Most to least likely to commit murder", level: 5),
        .init(text: "Most to least likely to become a terrorist", level: 5),
        .init(text: "Most to least likely to have an orgy", level: 5),
        .init(text: "Most to least likely to murder their significant other", level: 5),
        .init(text: "Most to least likely to get a sugar daddy/mummy", level: 5),
        .init(text: "Most to least likely to have a gay one night stand", level: 5),
        .init(text: "Most to least likely to fuck their boss/teacher for a raise/perks", level: 5),
        .init(text: "Most to least likely to get penis enlargement / breast enlargement / booty implants when they're older", level: 5),
        .init(text: "Most to least likely to kill themselves after a breakup", level: 5),
        .init(text: "Most to least likely to have sex with a prostitute", level: 5),
        .init(text: "Most to least likely to have a red room (a sex room) in their house when they're older/married/whatever", level: 5),
        .init(text: "Most likely to cry after/during sex", level: 5),
        .init(text: "Highest to lowest sex drive", level: 5),
        .init(text: "Most to least likely to hook up in a public place", level: 5),
        .init(text: "Most to least likely to have a foot fetish", level: 5),
        .init(text: "Most to least submissive", level: 5),
        .init(text: "Most to least likely to join a swingers club", level: 5),
        .init(text: "Most to least likely to join a thruple", level: 5),
        .init(text: "Most to least likely to play awful music during sex", level: 5),
        .init(text: "Most to least likely to keep socks on during sex", level: 5),
        .init(text: "Most to least likely to hook up in public toilets", level: 5),
        .init(text: "Most to least likely to sleep with their friend's mum or dad", level: 5),
        .init(text: "Most to least likely to get an STD", level: 5),
        .init(text: "Most to least likely to reenact the bathtub scene in Saltburn", level: 5),
        .init(text: "Most to least likely to watch midget porn", level: 5),
        .init(text: "Most to least likely to buy an OnlyFans / PornHub subscription", level: 5),
        .init(text: "Most to least likely to try to reenact porn in the bedroom", level: 5),
        .init(text: "Most to least likely to fall asleep during sex", level: 5),
        .init(text: "Most to least likely to join the mile high club", level: 5),
        .init(text: "Most to least likely to sleep with their partner's parent", level: 5),
        .init(text: "Most to least likely to Wiki-how giving head", level: 5),
        .init(text: "Most to least likely to go on Naked Attraction", level: 5),
        .init(text: "Most to least likely to say the wrong name in bed", level: 5),
        .init(text: "Most to least likely to have a pet name for their private parts", level: 5),
        .init(text: "Most to least likely to have a strange kink/fetish", level: 5),
        .init(text: "Most to least likely to get caught masturbating", level: 5),
        .init(text: "Most to least likely to get their nudes leaked", level: 5),
        .init(text: "Most to least likely to become a pornstar", level: 5),
    ]

    private var deckFiltered: [String] { Self.deck.upTo(store.data.preferences.spiciness) }

    var body: some View {
        ScrollView { VStack(spacing: 20) { content }.padding(20) }
            .background(BeerifyBackground())
            .onAppear(perform: hydrateFromRoom)
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .setup: setupView
        case .secret: secretView
        case .pick: pickView
        case .rank: rankView
        case .reveal: revealView
        }
    }

    // MARK: Setup

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who's playing?")
                .font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            Text("Pass the phone around. Add everyone in your circle.")
                .font(.caption).foregroundStyle(Theme.inkSoft)

            HStack {
                TextField("Add a name", text: $newName)
                    .textFieldStyle(BeerifyFieldStyle())
                    .onSubmit(addName)
                Button("Add", action: addName)
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
                phase = .secret
            } label: {
                Text("Start — pass to the picker").frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
            .disabled(players.count < 3)
            .opacity(players.count < 3 ? 0.5 : 1)

            if players.count < 3 {
                Text("Need at least 3 players.").font(.caption).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    // MARK: Secret handoff

    private var secretView: some View {
        VStack(spacing: 16) {
            Text("🤫").font(.system(size: 72))
            Text("Only the picker looks now.")
                .font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            Text("Everyone else — look away. The picker draws one random question that only they'll see.")
                .foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
            Button {
                phase = .pick
                questionIdx = nil
                shortlist = []
                ranking.removeAll()
            } label: {
                Text("I'm the picker, show me").frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
        }
    }

    // MARK: Pick (draw)

    private var pickView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Draw a question").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            Text("Only you see the question. The squad will only see a shortlist of 10 to guess from later.")
                .font(.caption).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)

            if let qi = questionIdx, deckFiltered.indices.contains(qi) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your secret question").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                    Text(deckFiltered[qi])
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Theme.accentDeep)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.2)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
                }

                HStack(spacing: 10) {
                    Button {
                        drawQuestion()
                    } label: {
                        HStack {
                            Image(systemName: "die.face.5.fill")
                            Text("Redraw").frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered).tint(Theme.accentDeep)

                    Button {
                        phase = .rank
                        ranking.removeAll()
                    } label: {
                        Text("Rank the squad").frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                }
            } else {
                Button {
                    drawQuestion()
                } label: {
                    HStack {
                        Image(systemName: "die.face.5.fill")
                        Text("Draw a random question").frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
            }
        }
    }

    /// Picks a random question from the filtered deck and builds a shortlist
    /// of 10 (including the answer) that the squad will see at reveal.
    private func drawQuestion() {
        let count = deckFiltered.count
        guard count > 0 else { return }
        let answer = Int.random(in: 0..<count)
        questionIdx = answer
        let listSize = min(10, count)
        var picks: Set<Int> = [answer]
        while picks.count < listSize {
            picks.insert(Int.random(in: 0..<count))
        }
        shortlist = Array(picks).shuffled()
        guessIdx = nil
        revealed = false
    }

    // MARK: Rank

    private var rankView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let qi = questionIdx, deckFiltered.indices.contains(qi) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your secret question").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                    Text(deckFiltered[qi])
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(Theme.accentDeep)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent.opacity(0.2)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
                }
            }
            Text("Rank the squad")
                .font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            Text("Tap first for #1 (fits the question most), then #2, and so on. Nobody but you sees the question.")
                .font(.caption).foregroundStyle(Theme.inkSoft)

            if !ranking.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(ranking.enumerated()), id: \.offset) { i, name in
                        HStack {
                            Text(rankBadge(i + 1))
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .frame(width: 28)
                            Text(Avatars.avatar(for: name)).font(.title3)
                            Text(name).foregroundStyle(Theme.ink)
                            Spacer()
                            Button {
                                ranking.remove(at: i)
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle.fill").foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent.opacity(0.18)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent.opacity(0.45), lineWidth: 1))
                    }
                }
            }

            let remaining = players.filter { !ranking.contains($0) }
            if !remaining.isEmpty {
                Text("Still to place").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(remaining, id: \.self) { name in
                        Button {
                            ranking.append(name)
                        } label: {
                            HStack(spacing: 6) {
                                Text(Avatars.avatar(for: name)).font(.title3)
                                Text(name).foregroundStyle(Theme.ink)
                                Spacer()
                            }
                            .padding(.horizontal, 10).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.9)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                        }
                        .buttonStyle(BeerifyPressStyle())
                    }
                }
            } else {
                Button {
                    phase = .reveal
                    revealed = false
                    guessIdx = nil
                } label: {
                    Text("Done — pass to the squad").frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
            }
        }
    }

    // MARK: Reveal & guess

    private var revealView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The ranking").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            VStack(spacing: 6) {
                ForEach(Array(ranking.enumerated()), id: \.offset) { i, name in
                    HStack {
                        Text(rankBadge(i + 1))
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .frame(width: 28)
                        Text(Avatars.avatar(for: name)).font(.title3)
                        Text(name).foregroundStyle(Theme.ink)
                        Spacer()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.95)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                }
            }

            if !revealed {
                Text("What question was it? Discuss with the squad, then tap your best guess from the shortlist.")
                    .font(.caption).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 6) {
                ForEach(Array(shortlist.enumerated()), id: \.offset) { pos, deckIdx in
                    let q = deckFiltered.indices.contains(deckIdx) ? deckFiltered[deckIdx] : "—"
                    let isTruth = revealed && deckIdx == questionIdx
                    let isGuess = guessIdx == deckIdx
                    let tint: Color = {
                        if !revealed {
                            return isGuess ? Theme.accent.opacity(0.25) : Theme.surface.opacity(0.9)
                        }
                        if isTruth { return Theme.success.opacity(0.25) }
                        if isGuess { return Theme.danger.opacity(0.20) }
                        return Theme.surface.opacity(0.9)
                    }()
                    Button {
                        if !revealed { guessIdx = deckIdx }
                    } label: {
                        HStack(alignment: .top) {
                            Text("\(pos + 1).")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.inkSoft)
                                .frame(width: 22, alignment: .leading)
                            if revealed && isTruth { Text("✅") }
                            else if revealed && isGuess { Text("❌") }
                            Text(q).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(tint))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(BeerifyPressStyle())
                    .disabled(revealed)
                }
            }

            if !revealed {
                Button {
                    revealed = true
                    if let q = questionIdx, guessIdx == q {
                        roomService.reportScore(gameId: "ranked", score: 1)
                    }
                } label: {
                    Text(guessIdx == nil ? "Reveal the question" : "Lock in guess & reveal")
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
            } else {
                Button {
                    phase = .secret
                    questionIdx = nil
                    shortlist = []
                    guessIdx = nil
                    revealed = false
                    ranking.removeAll()
                } label: {
                    Text("Next round").frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
            }
        }
    }

    // MARK: Helpers

    private func addName() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !players.contains(trimmed) else { return }
        players.append(trimmed)
        newName = ""
    }

    private func hydrateFromRoom() {
        guard players.isEmpty else { return }
        if let members = roomService.state?.members, !members.isEmpty {
            players = members.map(\.name)
        }
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

// MARK: - Would You Rather

struct WYRPair {
    let a: String
    let b: String
    let level: Int
}

struct WouldYouRatherGame: View {
    @Environment(AppStore.self) private var store

    private static let deck: [WYRPair] = [
        // Level 1 — family-safe
        .init(a: "Never drink coffee again", b: "Never drink alcohol again", level: 1),
        .init(a: "Live without music", b: "Live without any streaming shows", level: 1),
        .init(a: "Have someone else pick your outfits for life", b: "Have someone else pick your car for life", level: 1),
        .init(a: "Always be 10 minutes early", b: "Always be 20 minutes late", level: 1),
        .init(a: "Be able to fly (slowly)", b: "Be invisible (but only at 3am)", level: 1),
        .init(a: "Live without pizza forever", b: "Live without dessert forever", level: 1),
        .init(a: "Have unlimited money for travel", b: "Have unlimited free time", level: 1),
        .init(a: "Live in a beach town", b: "Live in a big city", level: 1),
        // Level 2 — mild
        .init(a: "Have your search history public", b: "Have your camera roll public", level: 2),
        .init(a: "Sing karaoke sober in front of your parents", b: "Give a wedding speech drunk", level: 2),
        .init(a: "Marry for money", b: "Marry for love and be broke forever", level: 2),
        .init(a: "Have a really smart partner", b: "Have a really attractive one", level: 2),
        .init(a: "Be a bad friend to good people", b: "A good friend to bad people", level: 2),
        .init(a: "Never travel again", b: "Never see your family again", level: 2),
        .init(a: "Have someone else pick your outfits for life", b: "Have someone else pick your partner", level: 2),
        .init(a: "Say what you really think of each friend once", b: "Hear what they really think of you once", level: 2),
        .init(a: "Only wear formalwear forever", b: "Only wear pajamas forever", level: 2),
        .init(a: "Have your Spotify Wrapped be brutally honest", b: "Have your Instagram DMs read aloud", level: 2),
        // Level 3 — medium
        .init(a: "Read your ex's diary", b: "Have your ex read yours", level: 3),
        .init(a: "Have your worst secret revealed", b: "Reveal someone else's worst secret", level: 3),
        .init(a: "Be honest with everyone forever", b: "Only ever lie for the rest of your life", level: 3),
        .init(a: "Have everyone at this party read your DMs", b: "Read everyone else's DMs", level: 3),
        .init(a: "Never date anyone new", b: "Only date your exes on rotation", level: 3),
        .init(a: "Only text in voice notes", b: "Only text in memes", level: 3),
        .init(a: "Have your first date be brutally honest", b: "Only ever lie on first dates", level: 3),
        .init(a: "Get back with your worst ex for a week", b: "Never speak to your best friend for a year", level: 3),
        .init(a: "Have your parents unlock your phone once", b: "Have your ex unlock it once", level: 3),
        // Level 4 — spicy
        .init(a: "Kiss the last person you texted", b: "Kiss your boss", level: 4),
        .init(a: "Be great in bed and terrible in conversation", b: "Be great in conversation and terrible in bed", level: 4),
        .init(a: "Be caught cheating", b: "Catch a partner cheating", level: 4),
        .init(a: "Only ever hook up sober", b: "Only ever hook up drunk", level: 4),
        .init(a: "Give up sex for a year", b: "Give up your phone for a month", level: 4),
        .init(a: "Have every ex show up at your wedding", b: "Have your partner's exes at yours", level: 4),
        .init(a: "Date someone in this room for a month", b: "Never date again", level: 4),
        .init(a: "Have your parents watch your first hookup", b: "Watch your parents' first hookup", level: 4),
        .init(a: "Know exactly when your partner cheated", b: "Never know if they did", level: 4),
        .init(a: "Be your ex's best friend forever", b: "Never see your best friend again", level: 4),
        // Level 5 — unfiltered adult chaos
        .init(a: "Have a threesome with two strangers", b: "Have a threesome with two friends", level: 5),
        .init(a: "Amazing sex with someone you'll never love", b: "Terrible sex with your soulmate — forever", level: 5),
        .init(a: "Sleep with someone in this room tonight", b: "Never have sex again", level: 5),
        .init(a: "Only ever be a top", b: "Only ever be a bottom", level: 5),
        .init(a: "Have your search history projected at your funeral", b: "Have your camera roll shown at your wedding", level: 5),
        .init(a: "Sext the wrong number", b: "Accidentally send a nude in the family group chat", level: 5),
        .init(a: "Have every hookup rated publicly", b: "Rate every hookup you've had publicly", level: 5),
        .init(a: "Never finish again", b: "Only finish when someone's watching", level: 5),
        .init(a: "Have your body count doubled and made public", b: "Halved and told to your mum", level: 5),
        .init(a: "Sleep with your best friend once — no aftermath", b: "Sleep with their partner once — you know", level: 5),
        .init(a: "Have your ex live next door", b: "Have your ex be your new boss", level: 5),
        .init(a: "Only have loud sex — always", b: "Only have silent sex — always", level: 5),
        .init(a: "Have your last text to your crush read aloud here", b: "Have your Google search history from tonight projected", level: 5),
        .init(a: "Get with someone in this room", b: "Lose one friendship of the group's choosing", level: 5),
        .init(a: "Have your dating app profile edited by your enemies", b: "By your ex", level: 5),
        .init(a: "Only hook up with people your parents know", b: "Only hook up with strangers you'll see again", level: 5),
        .init(a: "Have every fantasy of yours read aloud", b: "Every fantasy of your partner's read aloud", level: 5),
        .init(a: "Send a booty call to the wrong number", b: "Send a serious 'we need to talk' to your crush right now", level: 5),
        .init(a: "Confess your worst hookup to the room", b: "Have the room guess it", level: 5),
        .init(a: "Kiss the person on your left", b: "Kiss the person on your right", level: 5),
        // Bonus L1 — silly
        .init(a: "Have hands the size of dinner plates", b: "Have feet the size of skis", level: 1),
        .init(a: "Fight one horse-sized duck", b: "Fight 100 duck-sized horses", level: 1),
        .init(a: "Never sneeze again", b: "Never yawn again", level: 1),
        .init(a: "Have permanent bed head", b: "Have permanent morning breath", level: 1),
        .init(a: "Live on a boat", b: "Live in a treehouse", level: 1),
        .init(a: "Only drink hot drinks", b: "Only drink cold drinks", level: 1),
        .init(a: "Have unlimited pizza forever", b: "Have unlimited sushi forever", level: 1),
        .init(a: "Speak every language poorly", b: "Speak only one language perfectly", level: 1),
        .init(a: "Be a great singer", b: "Be a great dancer", level: 1),
        .init(a: "Be super strong but slow", b: "Be super fast but weak", level: 1),
        .init(a: "Only eat with a spoon", b: "Only eat with chopsticks", level: 1),
        .init(a: "Live 300 years but be poor", b: "Live 70 years but be a billionaire", level: 1),
        .init(a: "Have Wi-Fi anywhere for free forever", b: "Have free flights anywhere forever", level: 1),
        .init(a: "Have a pet dragon", b: "Have a pet unicorn", level: 1),
        .init(a: "Only ever wear crocs", b: "Only ever wear stilettos", level: 1),
        .init(a: "Always be too hot", b: "Always be too cold", level: 1),
        .init(a: "Sleep 3 hours a night forever", b: "Sleep 14 hours a night forever", level: 1),
        .init(a: "Have a photographic memory", b: "Be able to read minds for one minute a day", level: 1),
        // Bonus L2 — light
        .init(a: "Never watch TV again", b: "Never listen to music again", level: 2),
        .init(a: "Never scroll socials again", b: "Never watch a new movie again", level: 2),
        .init(a: "Only wear neon", b: "Only wear beige", level: 2),
        .init(a: "Be famous for something embarrassing", b: "Be forgotten entirely after death", level: 2),
        .init(a: "Have every stranger recognize you", b: "Have every friend forget you exist once a year", level: 2),
        .init(a: "Have your best friend read your diary", b: "Have your mum read it", level: 2),
        .init(a: "Never have takeaway again", b: "Never cook at home again", level: 2),
        .init(a: "Live in a mansion in the middle of nowhere", b: "Live in a studio flat in the coolest city", level: 2),
        .init(a: "Only listen to the songs you loved at 14", b: "Only listen to Christmas music", level: 2),
        .init(a: "Wear a helmet in public forever", b: "Wear sunglasses inside forever", level: 2),
        .init(a: "Have your worst photo become your passport photo", b: "Have your worst text become a headline", level: 2),
        .init(a: "Never be able to lie", b: "Never be able to tell the truth", level: 2),
        .init(a: "Have a really annoying laugh", b: "Have a really annoying voice", level: 2),
        .init(a: "Have to sing everything you say", b: "Have to dance every 10 minutes", level: 2),
        .init(a: "Wear the same outfit every day", b: "Wear a costume every day", level: 2),
        // Bonus L3 — medium
        .init(a: "Have your teenage diaries read live on radio", b: "Have your Notes app read to your parents", level: 3),
        .init(a: "See every text your ex sent you again", b: "Delete your camera roll forever", level: 3),
        .init(a: "Give a wedding speech that goes viral for the wrong reasons", b: "Post a story you can't delete for a week", level: 3),
        .init(a: "Have your therapist post your notes", b: "Have your ex post your notes", level: 3),
        .init(a: "Text 'I love you' to your boss by accident", b: "Text your crush 'we need to talk' by accident", level: 3),
        .init(a: "Have every crush from the last five years find out you liked them", b: "Have every crush block you", level: 3),
        .init(a: "Get roasted by all your exes for an hour", b: "Get complimented by them for an hour", level: 3),
        .init(a: "Have to redo every awkward first date", b: "Redo every dumb breakup", level: 3),
        .init(a: "Only ever date long distance", b: "Only ever date someone who lives with you", level: 3),
        .init(a: "Be caught crying at work", b: "Be caught singing in your car by your boss", level: 3),
        .init(a: "Fake it forever", b: "Actually feel it forever (with anyone)", level: 3),
        .init(a: "Date your best friend for a month", b: "Never see them again", level: 3),
        .init(a: "Marry someone rich but boring", b: "Marry someone poor and hilarious", level: 3),
        .init(a: "Live with your parents at 40", b: "Live with your ex at 40", level: 3),
        .init(a: "Have every ex meet each other", b: "Have every ex meet your parents", level: 3),
        // Bonus L4 — spicy
        .init(a: "Have your camera roll shown at a job interview", b: "Have your search history shown to your family", level: 4),
        .init(a: "Send a booty call to your boss", b: "Send a formal work email to your last hookup", level: 4),
        .init(a: "Get caught mid-hookup by a housemate", b: "Get caught mid-hookup by their parents", level: 4),
        .init(a: "Have a nude leak to your best friend", b: "To your worst enemy", level: 4),
        .init(a: "Kiss someone you can't stand for a week", b: "Never kiss anyone again for a year", level: 4),
        .init(a: "Have your last DM read out loud here", b: "Read someone else's last DM out loud", level: 4),
        .init(a: "Only date people your parents pick", b: "Only date people your ex picks", level: 4),
        .init(a: "Get caught cheating once", b: "Be cheated on once and never told", level: 4),
        .init(a: "Never orgasm again with a partner", b: "Never orgasm again alone", level: 4),
        .init(a: "Marry the second person you dated", b: "Marry the last person you kissed", level: 4),
        .init(a: "Get a hickey somewhere visible for a month", b: "Have a tattoo of an ex's name for a year", level: 4),
        .init(a: "Have every partner rate you at the end", b: "Rate every partner at the end", level: 4),
        .init(a: "Only date people 10 years older", b: "Only date people 10 years younger", level: 4),
        .init(a: "Have your ex be the officiant at your wedding", b: "Have your worst boss be the officiant", level: 4),
        .init(a: "Text your last crush 'thinking of you'", b: "Text your last hookup the same", level: 4),
        // Bonus L5 — unfiltered
        .init(a: "Have all your fantasies shown as a slideshow to the group", b: "Have your entire hookup history shown", level: 5),
        .init(a: "Only have sex sober forever", b: "Only have sex drunk forever", level: 5),
        .init(a: "Never receive again", b: "Never give again", level: 5),
        .init(a: "Have every hookup rate you 6/10", b: "Have every hookup ghost you the next day", level: 5),
        .init(a: "Sleep with your best friend once", b: "Sleep with their sibling once", level: 5),
        .init(a: "Sleep with the same person for the rest of your life", b: "Never sleep with the same person twice", level: 5),
        .init(a: "Have a threesome with two exes", b: "Have a threesome with two strangers", level: 5),
        .init(a: "Have to send a nude every Monday", b: "Have to send a poem every Monday", level: 5),
        .init(a: "Have your parents scroll your Snapchat memories", b: "Have your parents scroll your dating apps", level: 5),
        .init(a: "Never be told 'I love you' back again", b: "Say 'I love you' every hookup", level: 5),
        .init(a: "Discover your partner has a secret family", b: "Be the secret family", level: 5),
        .init(a: "Have your last hookup show up to your funeral", b: "Show up to your last hookup's funeral", level: 5),
        .init(a: "Get with your enemy tonight", b: "Get with a family friend tonight", level: 5),
        .init(a: "Have every kink you have go public", b: "Have every fantasy of yours acted out — live", level: 5),
        .init(a: "Only ever do it with the lights on", b: "Only ever do it in total silence", level: 5),
        .init(a: "Be the loudest person in bed", b: "Be the quietest", level: 5),
        .init(a: "Have your longest situationship come to your wedding", b: "Skip your wedding to hook up with them", level: 5),
        .init(a: "Do the walk of shame every weekend", b: "Never leave the house on a weekend again", level: 5),
        .init(a: "Have your worst hookup ever DM you tonight", b: "DM them first", level: 5),
        .init(a: "Have your porn history projected at a family dinner", b: "Have your therapist notes read at a work meeting", level: 5),
        .init(a: "Hook up in public", b: "Hook up in front of your parents' friends' house", level: 5),
        .init(a: "Have to break up over voice memo", b: "Have to break up in a public restaurant", level: 5),
        .init(a: "Kiss your friend's ex", b: "Kiss your ex's friend", level: 5),
        .init(a: "Send a spicy text to the wrong sibling", b: "Get one from the wrong sibling", level: 5),
        .init(a: "Try every kink once", b: "Never try anything new again", level: 5),
    ]

    @State private var queue: [WYRPair] = []
    @State private var current: WYRPair? = nil
    @State private var picked: Int? = nil

    private var filtered: [WYRPair] {
        Self.deck.filter { $0.level <= store.data.preferences.spiciness }
    }

    var body: some View {
        ScrollView { VStack(spacing: 20) {
            Text("Would you rather…")
                .font(.title3.weight(.bold)).foregroundStyle(Theme.inkSoft)
            if let pair = current {
                optionCard(text: pair.a, tone: Theme.accent, selected: picked == 0) { picked = 0 }
                Text("or").font(.headline).foregroundStyle(Theme.inkSoft)
                optionCard(text: pair.b, tone: Theme.accentDeep, selected: picked == 1) { picked = 1 }
            }

            Button {
                advance()
            } label: {
                Text("New dilemma").frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(Theme.accent)

            if picked != nil {
                Text("Debate. Loser drinks. Or both drink because it was too close.")
                    .font(.caption).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
            }
        }.padding(20) }
        .background(BeerifyBackground())
        .onAppear { if current == nil { advance() } }
    }

    private func advance() {
        picked = nil
        if queue.isEmpty { queue = filtered.shuffled() }
        current = queue.popLast() ?? filtered.randomElement()
    }

    private func optionCard(text: String, tone: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16).padding(.vertical, 24)
                .background(RoundedRectangle(cornerRadius: 18).fill(selected ? tone.opacity(0.28) : Theme.surface.opacity(0.95)))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? tone : Theme.hairline, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(BeerifyPressStyle())
    }
}

// MARK: - Most Likely To

struct MostLikelyToGame: View {
    @Environment(RoomService.self) private var roomService
    @Environment(AppStore.self) private var store

    @State private var players: [String] = []
    @State private var newName: String = ""
    @State private var currentPrompt: String = ""
    @State private var recent: [String] = []
    @State private var votes: [String: Int] = [:]
    @State private var revealed: Bool = false

    static let deck: [SpicyPrompt] = [
        // Level 1 — family-safe
        .init(text: "…win the lottery and spend it all in a month.", level: 1),
        .init(text: "…be first to have a kid.", level: 1),
        .init(text: "…start a podcast nobody listens to.", level: 1),
        .init(text: "…marry someone from another country.", level: 1),
        .init(text: "…run away and join a commune.", level: 1),
        .init(text: "…host the worst dinner party ever.", level: 1),
        .init(text: "…name a dog after an ex.", level: 1),
        .init(text: "…adopt seven cats and one goat.", level: 1),
        .init(text: "…become a viral TikTok chef.", level: 1),
        .init(text: "…quit their job to become a beekeeper.", level: 1),
        // Level 2 — mild party
        .init(text: "…get a face tattoo on a dare.", level: 2),
        .init(text: "…crash a wedding.", level: 2),
        .init(text: "…sing at a stranger's wedding.", level: 2),
        .init(text: "…get scammed by a fake DM.", level: 2),
        .init(text: "…faint at the sight of blood.", level: 2),
        .init(text: "…spend too much on skincare.", level: 2),
        .init(text: "…get a Christmas card from a bartender.", level: 2),
        .init(text: "…get in a fight over parking.", level: 2),
        .init(text: "…lie about their star sign for compatibility.", level: 2),
        .init(text: "…be the last one still partying.", level: 2),
        .init(text: "…lose their phone before midnight.", level: 2),
        .init(text: "…fall asleep at the pregame.", level: 2),
        // Level 3 — medium
        .init(text: "…get arrested this year.", level: 3),
        .init(text: "…date a coworker.", level: 3),
        .init(text: "…be canceled and deserve it.", level: 3),
        .init(text: "…text an ex tonight.", level: 3),
        .init(text: "…start a fight with a bouncer.", level: 3),
        .init(text: "…cry in an Uber this year.", level: 3),
        .init(text: "…stalk their crush's tagged photos to 2019.", level: 3),
        .init(text: "…drunk-book a flight.", level: 3),
        .init(text: "…get back with their worst ex.", level: 3),
        .init(text: "…post something they'll delete in the morning.", level: 3),
        .init(text: "…lie about their job on a first date.", level: 3),
        // Level 4 — spicy
        .init(text: "…hook up in an Uber.", level: 4),
        .init(text: "…get with a coworker at the Christmas party.", level: 4),
        .init(text: "…lie about their number to a new partner.", level: 4),
        .init(text: "…get caught cheating.", level: 4),
        .init(text: "…kiss two people in one night.", level: 4),
        .init(text: "…keep a hookup a secret from the group.", level: 4),
        .init(text: "…have already hooked up with someone in this room.", level: 4),
        .init(text: "…get engaged before 30.", level: 4),
        .init(text: "…break up with someone by text.", level: 4),
        .init(text: "…have a crush on someone in this room.", level: 4),
        .init(text: "…have a folder in their phone they'd delete before dying.", level: 4),
        // Level 5 — unfiltered adult chaos
        .init(text: "…hook up with someone in this room tonight.", level: 5),
        .init(text: "…be down for a threesome if we offered right now.", level: 5),
        .init(text: "…have a body count in triple digits.", level: 5),
        .init(text: "…send a nude before the night ends.", level: 5),
        .init(text: "…have already sent a nude tonight.", level: 5),
        .init(text: "…have hooked up in a public bathroom.", level: 5),
        .init(text: "…be terrible in bed.", level: 5),
        .init(text: "…fake it and never say a word.", level: 5),
        .init(text: "…hook up with a stranger before sunrise.", level: 5),
        .init(text: "…have hooked up with someone whose name they don't remember.", level: 5),
        .init(text: "…still sleep with their ex if invited.", level: 5),
        .init(text: "…have a secret kink nobody in the group would guess.", level: 5),
        .init(text: "…have hooked up with a friend of someone here.", level: 5),
        .init(text: "…leave without saying goodbye after sex.", level: 5),
        .init(text: "…have cheated and never told anyone.", level: 5),
        .init(text: "…have hooked up with someone twice their age.", level: 5),
        .init(text: "…finish in under 60 seconds.", level: 5),
        .init(text: "…have joined the mile high club.", level: 5),
        .init(text: "…have made a sex tape.", level: 5),
        .init(text: "…hook up with someone on a first date this month.", level: 5),
        .init(text: "…have used their body to get their way at work.", level: 5),
        .init(text: "…have a hookup they'd take to their grave.", level: 5),
        .init(text: "…have gotten with someone in this room's friend group without them knowing.", level: 5),
        .init(text: "…be secretly in love with someone in this room.", level: 5),
        .init(text: "…lie about being on birth control or wearing protection.", level: 5),
        // Bonus L1 — silly
        .init(text: "…save the world with a spreadsheet.", level: 1),
        .init(text: "…become a cottagecore homesteader.", level: 1),
        .init(text: "…marry their yoga instructor.", level: 1),
        .init(text: "…become a park ranger.", level: 1),
        .init(text: "…start a successful bakery.", level: 1),
        .init(text: "…be a champion at Monopoly.", level: 1),
        .init(text: "…become a librarian.", level: 1),
        .init(text: "…adopt a rescue donkey.", level: 1),
        .init(text: "…win a pie-eating contest.", level: 1),
        .init(text: "…host a wholesome family podcast.", level: 1),
        // Bonus L2 — mild
        .init(text: "…get catfished.", level: 2),
        .init(text: "…get scammed by a Nigerian prince email.", level: 2),
        .init(text: "…start crying in the middle of Ikea.", level: 2),
        .init(text: "…get lost in their own hometown.", level: 2),
        .init(text: "…take a photo of every meal they eat.", level: 2),
        .init(text: "…get too invested in reality TV.", level: 2),
        .init(text: "…have the messiest handbag/wallet in the room.", level: 2),
        .init(text: "…forget where they parked, every time.", level: 2),
        .init(text: "…be the last one still texting the group chat.", level: 2),
        .init(text: "…lose an argument to a child.", level: 2),
        .init(text: "…own the most half-drunk water bottles in their car.", level: 2),
        .init(text: "…name their firstborn something no one can spell.", level: 2),
        .init(text: "…forget the person they just met's name in 4 seconds.", level: 2),
        .init(text: "…leave a party without saying goodbye.", level: 2),
        .init(text: "…set an alarm they'll ignore anyway.", level: 2),
        .init(text: "…binge a series in one weekend.", level: 2),
        // Bonus L3 — medium
        .init(text: "…get in a passive-aggressive email war.", level: 3),
        .init(text: "…delete their socials in a fit of drama.", level: 3),
        .init(text: "…get roasted by a taxi driver.", level: 3),
        .init(text: "…pretend to have read a book they haven't.", level: 3),
        .init(text: "…block someone then unblock them within an hour.", level: 3),
        .init(text: "…rebrand themselves after a breakup.", level: 3),
        .init(text: "…get therapy specifically to complain about their partner.", level: 3),
        .init(text: "…mistake a stranger for someone they know and commit hard.", level: 3),
        .init(text: "…cry at their own birthday party.", level: 3),
        .init(text: "…post a heartfelt caption then delete it in an hour.", level: 3),
        .init(text: "…get stopped at security.", level: 3),
        .init(text: "…lie in a Hinge prompt in a way that will haunt them.", level: 3),
        .init(text: "…develop feelings for a coworker they don't even like.", level: 3),
        .init(text: "…be the reason a group chat exists to talk about them.", level: 3),
        .init(text: "…flirt with someone entirely out of habit.", level: 3),
        // Bonus L4 — spicy
        .init(text: "…kiss a stranger for a free drink.", level: 4),
        .init(text: "…date someone specifically to make an ex jealous.", level: 4),
        .init(text: "…keep an ex's hoodie for over a year.", level: 4),
        .init(text: "…have a Notes app confession they'll never send.", level: 4),
        .init(text: "…get caught reading their partner's messages.", level: 4),
        .init(text: "…date someone for their friend group.", level: 4),
        .init(text: "…leave a party to meet a hookup.", level: 4),
        .init(text: "…pretend to be busy to avoid a date they said yes to.", level: 4),
        .init(text: "…get with someone in a taxi.", level: 4),
        .init(text: "…have a favorite hookup they'd never admit to.", level: 4),
        .init(text: "…still have a burner Instagram to stalk exes.", level: 4),
        .init(text: "…have a secret 'situationship' the group doesn't know about.", level: 4),
        .init(text: "…start something with the friend of the person they're dating.", level: 4),
        .init(text: "…flirt with an ex at a wedding.", level: 4),
        .init(text: "…swap partners with a sibling's ex for chaos.", level: 4),
        .init(text: "…have a favorite person's number saved under a fake name.", level: 4),
        .init(text: "…miss a whole day of work because of a hookup.", level: 4),
        // Bonus L5 — unfiltered adult
        .init(text: "…film a hookup 'by accident'.", level: 5),
        .init(text: "…sleep with a boss for a promotion.", level: 5),
        .init(text: "…join a sex club just to see what it's like.", level: 5),
        .init(text: "…lie about their orgasm history.", level: 5),
        .init(text: "…lose their virginity story down for a story to tell.", level: 5),
        .init(text: "…sleep with a stranger's roommate first.", level: 5),
        .init(text: "…rate their partners in a private group chat.", level: 5),
        .init(text: "…hook up during a video call at work.", level: 5),
        .init(text: "…hook up with someone twice in one night by accident.", level: 5),
        .init(text: "…have a folder on their phone titled 'don't open'.", level: 5),
        .init(text: "…admit to a partner they'd want a threesome.", level: 5),
        .init(text: "…propose after a very short time to force the situation.", level: 5),
        .init(text: "…block someone mid-thrust and never explain.", level: 5),
        .init(text: "…finish an ex's marriage by 'accidentally' meeting up.", level: 5),
        .init(text: "…be the reason a friend gets dumped.", level: 5),
        .init(text: "…confess a crush to a partner just to feel free.", level: 5),
        .init(text: "…try every position from a viral list in one night.", level: 5),
        .init(text: "…get a call from a hookup at 4am and answer.", level: 5),
        .init(text: "…have kissed way more people than they've told anyone.", level: 5),
        .init(text: "…swap partners with a friend for a night.", level: 5),
        .init(text: "…know the taste of someone else's fantasy.", level: 5),
        .init(text: "…date two people at once and forget who's who.", level: 5),
        .init(text: "…have a fetish for authority figures.", level: 5),
        .init(text: "…hook up with a stranger they met in an airport.", level: 5),
        .init(text: "…break up with someone because they're bad in bed.", level: 5),
        .init(text: "…keep an OnlyFans in secret.", level: 5),
        .init(text: "…be paid by a partner to stay quiet about them.", level: 5),
        .init(text: "…have a spicy playlist named after an ex.", level: 5),
        .init(text: "…confess feelings for a friend at 3am.", level: 5),
    ]

    private var filteredDeck: [String] {
        Self.deck.upTo(store.data.preferences.spiciness)
    }

    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            if players.count < 3 { setup } else { round }
        }.padding(20) }
        .background(BeerifyBackground())
        .onAppear {
            if players.isEmpty, let members = roomService.state?.members {
                players = members.map(\.name)
            }
            if currentPrompt.isEmpty { nextPrompt() }
        }
    }

    private func nextPrompt() {
        let pool = filteredDeck
        if let picked = rotatedPick(from: pool, recent: &recent, windowSize: max(5, pool.count / 3)) {
            currentPrompt = picked
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add players").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            Text("At least 3.").font(.caption).foregroundStyle(Theme.inkSoft)
            HStack {
                TextField("Name", text: $newName).textFieldStyle(BeerifyFieldStyle())
                    .onSubmit(add)
                Button("Add", action: add).buttonStyle(.borderedProminent).tint(Theme.accent)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ForEach(players, id: \.self) { p in
                HStack {
                    Text(Avatars.avatar(for: p)); Text(p).foregroundStyle(Theme.ink); Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.9)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
            }
        }
    }

    private var round: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who is most likely to…").font(.subheadline).foregroundStyle(Theme.inkSoft)
            Text(currentPrompt)
                .font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)

            VStack(spacing: 6) {
                ForEach(players, id: \.self) { p in
                    Button {
                        votes[p, default: 0] += 1
                    } label: {
                        HStack {
                            Text(Avatars.avatar(for: p)).font(.title3)
                            Text(p).foregroundStyle(Theme.ink)
                            Spacer()
                            if revealed || (votes[p] ?? 0) > 0 {
                                Text("\(votes[p] ?? 0)").font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.accentDeep)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.95)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(BeerifyPressStyle())
                    .disabled(revealed)
                }
            }

            if revealed, let top = votes.max(by: { $0.value < $1.value }) {
                Text("🏆 \(top.key) — take a drink!")
                    .font(.headline).foregroundStyle(Theme.accentDeep)
            }

            HStack(spacing: 10) {
                Button(revealed ? "Next prompt" : "Reveal winner") {
                    if revealed {
                        nextPrompt()
                        votes = [:]
                        revealed = false
                    } else {
                        revealed = true
                    }
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent)
                .frame(maxWidth: .infinity)

                Button("Skip") {
                    nextPrompt()
                    votes = [:]; revealed = false
                }
                .buttonStyle(.bordered).tint(Theme.accentDeep)
            }
        }
    }

    private func add() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !players.contains(trimmed) else { return }
        players.append(trimmed); newName = ""
    }
}

// MARK: - Two Truths and a Lie

struct TwoTruthsAndALieGame: View {
    enum Phase { case enter, guess, reveal }

    @State private var phase: Phase = .enter
    @State private var truth1: String = ""
    @State private var truth2: String = ""
    @State private var lie: String = ""
    @State private var order: [Int] = [0, 1, 2].shuffled()  // display order
    @State private var lieIdx: Int? = nil  // index within `order` of the lie
    @State private var revealedIdx: Int? = nil

    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            switch phase {
            case .enter: enterView
            case .guess: guessView
            case .reveal: revealView
            }
        }.padding(20) }
        .background(BeerifyBackground())
    }

    private var enterView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Two Truths and a Lie")
                .font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            Text("Write two true things and one lie about yourself. Others guess the lie.")
                .font(.caption).foregroundStyle(Theme.inkSoft)

            field(placeholder: "First truth", text: $truth1)
            field(placeholder: "Second truth", text: $truth2)
            field(placeholder: "One convincing lie", text: $lie, tone: Theme.danger)

            Button {
                let items = [truth1, truth2, lie]
                order = [0, 1, 2].shuffled()
                lieIdx = order.firstIndex(of: 2)
                _ = items
                phase = .guess
            } label: {
                Text("Ready — pass it").frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
            .disabled(truth1.isEmpty || truth2.isEmpty || lie.isEmpty)
            .opacity((truth1.isEmpty || truth2.isEmpty || lie.isEmpty) ? 0.5 : 1)
        }
    }

    private func field(placeholder: String, text: Binding<String>, tone: Color = Theme.accent) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .textFieldStyle(BeerifyFieldStyle())
            .lineLimit(2, reservesSpace: true)
    }

    private var guessView: some View {
        let items = [truth1, truth2, lie]
        return VStack(alignment: .leading, spacing: 10) {
            Text("Which one's the lie?").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            ForEach(Array(order.enumerated()), id: \.offset) { pos, srcIdx in
                Button {
                    revealedIdx = pos
                    phase = .reveal
                } label: {
                    HStack {
                        Text("\(pos + 1).").font(.headline).foregroundStyle(Theme.inkSoft)
                        Text(items[srcIdx]).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface.opacity(0.95)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(BeerifyPressStyle())
            }
        }
    }

    private var revealView: some View {
        VStack(alignment: .leading, spacing: 10) {
            let correct = revealedIdx == lieIdx
            Text(correct ? "🎉 Nailed it!" : "😅 Nope.")
                .font(.title2.weight(.heavy)).foregroundStyle(correct ? Theme.success : Theme.danger)
            Text("The lie was:").font(.caption).foregroundStyle(Theme.inkSoft)
            Text(lie).font(.headline).foregroundStyle(Theme.accentDeep)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.18)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.5), lineWidth: 1))

            Text("Truths were:").font(.caption).foregroundStyle(Theme.inkSoft).padding(.top, 4)
            Text("• \(truth1)").foregroundStyle(Theme.ink)
            Text("• \(truth2)").foregroundStyle(Theme.ink)

            Button {
                truth1 = ""; truth2 = ""; lie = ""
                revealedIdx = nil; lieIdx = nil
                phase = .enter
            } label: {
                Text("New round").frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(Theme.accent)
        }
    }
}
