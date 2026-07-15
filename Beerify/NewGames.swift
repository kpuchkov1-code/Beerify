//
//  NewGames.swift
//  Beerify
//
//  Interactive party games with real mechanics - voting, reaction time,
//  word recall, anonymous confessions, and escalating stakes.
//

import SwiftUI
#if canImport(CoreMotion)
import CoreMotion
#endif

// MARK: - Hot Takes Showdown

/// A spicy statement appears. Everyone secretly votes agree or disagree.
/// Reveal the split - the minority side drinks. Creates real debate.
struct HotTakesGame: View {
    @Environment(AppStore.self) private var store
    @Environment(RoomService.self) private var roomService

    enum Phase { case setup, voting, reveal }

    @State private var players: [String] = []
    @State private var newName: String = ""
    @State private var phase: Phase = .setup
    @State private var currentTake: String = ""
    @State private var votes: [String: Bool] = [:]  // player -> true=agree
    @State private var currentVoterIndex: Int = 0
    @State private var roundNumber: Int = 0
    @State private var recentTakes: [String] = []

    private static let takes: [SpicyPrompt] = [
        // Level 1
        .init(text: "Pineapple belongs on pizza.", level: 1),
        .init(text: "Breakfast for dinner is better than dinner for dinner.", level: 1),
        .init(text: "Dogs are better than cats.", level: 1),
        .init(text: "The toilet paper should go over, not under.", level: 1),
        .init(text: "Cereal is soup.", level: 1),
        .init(text: "A hot dog is a sandwich.", level: 1),
        .init(text: "Summer is overrated.", level: 1),
        .init(text: "Monday is the worst day of the week.", level: 1),
        .init(text: "Naps are better than coffee.", level: 1),
        .init(text: "The book is always better than the movie.", level: 1),
        .init(text: "It's okay to wear socks with sandals.", level: 1),
        .init(text: "Pop music peaked in the 2000s.", level: 1),
        .init(text: "Being early is worse than being late.", level: 1),
        .init(text: "Texting is better than calling.", level: 1),
        .init(text: "Water is the best drink.", level: 1),
        .init(text: "People who recline their airplane seats are monsters.", level: 1),
        .init(text: "Cold pizza is better than reheated pizza.", level: 1),
        .init(text: "You should shower in the morning, not at night.", level: 1),
        // Level 2
        .init(text: "It's fine to ghost someone after one date.", level: 2),
        .init(text: "Drunk texts are always honest.", level: 2),
        .init(text: "Going out alone is more fun than with friends.", level: 2),
        .init(text: "It's okay to cry in public.", level: 2),
        .init(text: "Couples who share social media passwords are insecure.", level: 2),
        .init(text: "Your mid-20s are harder than your teens.", level: 2),
        .init(text: "Being single is better than being in a bad relationship.", level: 2),
        .init(text: "Flirting is harmless even if you're in a relationship.", level: 2),
        .init(text: "You should always split the bill on a first date.", level: 2),
        .init(text: "Social media has ruined dating.", level: 2),
        .init(text: "People who say 'I don't do drama' are always the most dramatic.", level: 2),
        .init(text: "Being a night owl is a personality trait, not a lifestyle choice.", level: 2),
        .init(text: "Hangovers get worse every year after 25.", level: 2),
        // Level 3
        .init(text: "Everyone has a 'the one that got away'.", level: 3),
        .init(text: "You should tell your friend if their partner is cheating.", level: 3),
        .init(text: "Staying friends with an ex is a red flag.", level: 3),
        .init(text: "Love at first sight is just lust.", level: 3),
        .init(text: "Once a cheater, always a cheater.", level: 3),
        .init(text: "The person who cares less in a relationship has all the power.", level: 3),
        .init(text: "It's normal to still think about your ex sometimes.", level: 3),
        .init(text: "Everyone settles to some degree.", level: 3),
        .init(text: "Jealousy is a sign you care.", level: 3),
        .init(text: "Going through your partner's phone is justified if you suspect something.", level: 3),
        .init(text: "Rebounds actually help you get over someone.", level: 3),
        .init(text: "Most people in relationships are bored.", level: 3),
        .init(text: "Couples therapy should be normalized before things go wrong.", level: 3),
        // Level 4
        .init(text: "Your body count shouldn't matter to your partner.", level: 4),
        .init(text: "Everyone has someone they'd cheat with given zero consequences.", level: 4),
        .init(text: "Emotional cheating is worse than physical cheating.", level: 4),
        .init(text: "Open relationships can work long-term.", level: 4),
        .init(text: "If you have to ask 'are we exclusive?' - you already know the answer.", level: 4),
        .init(text: "Most men can't handle a woman who's slept with more people than them.", level: 4),
        .init(text: "Friends with benefits always ends with someone catching feelings.", level: 4),
        .init(text: "You can love someone and still cheat on them.", level: 4),
        .init(text: "Looks matter more than personality in the first year.", level: 4),
        .init(text: "Some secrets should go to the grave.", level: 4),
        // Level 5
        .init(text: "Everyone in this room has lied about something major tonight.", level: 5),
        .init(text: "Most people would sleep with their best friend's partner if nobody found out.", level: 5),
        .init(text: "The hottest person in this room knows they're the hottest.", level: 5),
        .init(text: "At least one person here has faked an orgasm with a current or recent partner.", level: 5),
        .init(text: "Most relationships survive infidelity - people just don't talk about it.", level: 5),
        .init(text: "Everyone has a price for which they'd sell out a friendship.", level: 5),
        .init(text: "Someone in this room has hooked up with someone else in this room and nobody knows.", level: 5),
        .init(text: "Your parents' relationship is probably messier than you think.", level: 5),
        .init(text: "Most people here would date up for money over love.", level: 5),
        .init(text: "The least attractive person in the room is probably the best in bed.", level: 5),
    ]

    private var filteredTakes: [String] {
        Self.takes.upTo(store.data.preferences.spiciness)
    }

    var body: some View {
        GameChrome {
            VStack(alignment: .leading, spacing: 20) {
                switch phase {
                case .setup: setupView
                case .voting: votingView
                case .reveal: revealView
                }
            }
        }
        .onAppear(perform: hydrateFromRoom)
    }

    // MARK: Setup

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hot Takes")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("A spicy statement appears. Everyone secretly votes AGREE or DISAGREE - pass the phone around. The minority side drinks.")
                .font(.callout).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

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
                            Button { players.remove(at: i) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.9)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                    }
                }
            }

            BigActionButton(title: "Start game") { startRound() }
                .disabled(players.count < 3)
                .opacity(players.count < 3 ? 0.5 : 1)

            if players.count < 3 {
                Text("Need at least 3 players for a good split.").font(.caption).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    // MARK: Voting

    private var votingView: some View {
        let voter = players[currentVoterIndex]
        return VStack(spacing: 20) {
            Text("Round \(roundNumber)")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)

            VStack(spacing: 8) {
                Text("THE TAKE").font(.caption.weight(.bold)).foregroundStyle(Theme.inkSoft)
                Text(currentTake)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent.opacity(0.18)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.45), lineWidth: 1))

            Text("Pass the phone to:")
                .font(.caption).foregroundStyle(Theme.inkSoft)
            HStack(spacing: 8) {
                Text(Avatars.avatar(for: voter)).font(.system(size: 40))
                Text(voter)
                    .font(.title2.weight(.heavy)).foregroundStyle(Theme.accentDeep)
            }
            Text("Vote secretly - don't show the others!")
                .font(.caption).foregroundStyle(Theme.inkSoft)

            HStack(spacing: 12) {
                Button {
                    hapticTap()
                    castVote(agree: false)
                } label: {
                    VStack(spacing: 4) {
                        Text("👎").font(.system(size: 36))
                        Text("Disagree").font(.headline)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                }
                .buttonStyle(.bordered).tint(Theme.danger)

                Button {
                    hapticTap()
                    castVote(agree: true)
                } label: {
                    VStack(spacing: 4) {
                        Text("👍").font(.system(size: 36))
                        Text("Agree").font(.headline)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent).tint(Theme.success)
            }

            Text("\(currentVoterIndex + 1) of \(players.count) voted")
                .font(.caption).foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: Reveal

    private var revealView: some View {
        let agrees = votes.filter { $0.value == true }.map(\.key)
        let disagrees = votes.filter { $0.value == false }.map(\.key)
        let minorityIsAgree = agrees.count < disagrees.count
        let minority = minorityIsAgree ? agrees : disagrees
        let isTie = agrees.count == disagrees.count

        return VStack(spacing: 16) {
            Text(currentTake)
                .font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("👍").font(.system(size: 32))
                    Text("\(agrees.count)").font(.title.weight(.black)).foregroundStyle(Theme.success)
                    Text("Agree").font(.caption).foregroundStyle(Theme.inkSoft)
                    ForEach(agrees, id: \.self) { name in
                        Text(name).font(.caption2.weight(.semibold)).foregroundStyle(Theme.ink)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("👎").font(.system(size: 32))
                    Text("\(disagrees.count)").font(.title.weight(.black)).foregroundStyle(Theme.danger)
                    Text("Disagree").font(.caption).foregroundStyle(Theme.inkSoft)
                    ForEach(disagrees, id: \.self) { name in
                        Text(name).font(.caption2.weight(.semibold)).foregroundStyle(Theme.ink)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface.opacity(0.95)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))

            if isTie {
                Text("It's a tie - EVERYONE drinks!")
                    .font(.headline).foregroundStyle(Theme.accentDeep)
            } else {
                VStack(spacing: 4) {
                    Text("Minority loses - drink up!")
                        .font(.headline).foregroundStyle(Theme.danger)
                    Text(minority.joined(separator: ", "))
                        .font(.title3.weight(.heavy)).foregroundStyle(Theme.accentDeep)
                }
            }

            BigActionButton(title: "Next take") { startRound() }

            Button(role: .destructive) { phase = .setup; roundNumber = 0 } label: {
                Text("End game").font(.caption).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).tint(Theme.danger).controlSize(.small)
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

    private func startRound() {
        roundNumber += 1
        votes.removeAll()
        currentVoterIndex = 0
        let pool = filteredTakes
        currentTake = rotatedPick(from: pool, recent: &recentTakes, windowSize: max(5, pool.count / 3)) ?? "Pineapple on pizza is fine."
        phase = .voting
    }

    private func castVote(agree: Bool) {
        votes[players[currentVoterIndex]] = agree
        if currentVoterIndex + 1 >= players.count {
            phase = .reveal
        } else {
            currentVoterIndex += 1
        }
    }
}

// MARK: - Heads Up

/// Phone-on-forehead guessing game. Friends describe the word, you guess.
/// Tilt phone down = got it, tilt up = skip. Uses the accelerometer.
struct HeadsUpGame: View {
    @Environment(AppStore.self) private var store

    enum Phase { case menu, ready, playing, done }
    enum HeadsUpCategory: String, CaseIterable {
        case celebrities = "Celebrities"
        case movies = "Movies"
        case animals = "Animals"
        case actions = "Act It Out"
        case party = "Party Life"
        case spicy = "Spicy 🔥"

        var emoji: String {
            switch self {
            case .celebrities: return "⭐"
            case .movies: return "🎬"
            case .animals: return "🐾"
            case .actions: return "🎭"
            case .party: return "🍻"
            case .spicy: return "🌶"
            }
        }

        var minSpiciness: Int {
            switch self {
            case .spicy: return 3
            default: return 1
            }
        }

        var words: [String] {
            switch self {
            case .celebrities: return [
                "Beyoncé", "Elon Musk", "Taylor Swift", "Dwayne Johnson", "Oprah",
                "Drake", "Kim Kardashian", "Leonardo DiCaprio", "Rihanna", "Kanye West",
                "Ariana Grande", "Gordon Ramsay", "Billie Eilish", "Post Malone", "Snoop Dogg",
                "Will Smith", "Adele", "Justin Bieber", "Lady Gaga", "Bad Bunny",
                "Zendaya", "Harry Styles", "Tom Holland", "Chris Hemsworth", "Margot Robbie",
                "Dua Lipa", "Ice Spice", "Travis Scott", "Shakira", "Morgan Freeman",
                "Jack Black", "Timothée Chalamet", "Selena Gomez", "The Weeknd", "Lizzo",
                "Ryan Reynolds", "Kevin Hart", "Cardi B", "Ed Sheeran", "Miley Cyrus",
            ]
            case .movies: return [
                "Titanic", "The Avengers", "Frozen", "Jaws", "The Matrix",
                "Harry Potter", "Star Wars", "Toy Story", "The Godfather", "Jurassic Park",
                "The Lion King", "Shrek", "Finding Nemo", "Forrest Gump", "The Dark Knight",
                "Inception", "Mean Girls", "Twilight", "Rocky", "Avatar",
                "Spider-Man", "Barbie", "Top Gun", "The Notebook", "Gladiator",
                "The Hangover", "John Wick", "Interstellar", "Black Panther", "Superbad",
                "Pulp Fiction", "Fight Club", "Home Alone", "The Exorcist", "Grease",
                "La La Land", "Joker", "Oppenheimer", "Deadpool", "Mamma Mia",
            ]
            case .animals: return [
                "Elephant", "Penguin", "Giraffe", "Dolphin", "Kangaroo",
                "Octopus", "Flamingo", "Gorilla", "Chameleon", "Sloth",
                "Peacock", "Porcupine", "Platypus", "Hamster", "Crocodile",
                "Jellyfish", "Koala", "Parrot", "Lobster", "Toucan",
                "Seahorse", "Armadillo", "Meerkat", "Narwhal", "Hedgehog",
                "Cheetah", "Polar Bear", "Bat", "Rattlesnake", "Tarantula",
            ]
            case .actions: return [
                "Surfing", "Doing laundry", "Playing drums", "Changing a diaper", "Riding a horse",
                "Eating spaghetti", "Parallel parking", "Taking a selfie", "Rock climbing", "Salsa dancing",
                "Brushing teeth", "Mowing the lawn", "Doing yoga", "Bowling", "Opening a jar",
                "Skydiving", "Arm wrestling", "Hula hooping", "Juggling", "Swimming",
                "Boxing", "Karate chopping", "Fishing", "Skiing", "Moonwalking",
                "Tightrope walking", "Sneezing", "Limbo", "Bench pressing", "Blowing bubbles",
            ]
            case .party: return [
                "Beer pong", "Pregaming", "Bouncer", "Hangover", "Karaoke",
                "Last call", "Designated driver", "Pub crawl", "Happy hour", "Keg stand",
                "Cocktail", "Dance floor", "Jukebox", "Blackout", "Shotgunning",
                "Bar tab", "House party", "Uber home", "Afterparty", "Bottle service",
                "Walk of shame", "Flip cup", "Quarters", "Tipsy", "Open bar",
                "Toga party", "Tequila sunrise", "Jägerbomb", "Line at the bar", "VIP section",
            ]
            case .spicy: return [
                "Ghosting", "Situationship", "Friends with benefits", "Netflix and chill", "Booty call",
                "Thirst trap", "The ick", "Catfish", "Love bombing", "Breadcrumbing",
                "Rebound", "One night stand", "Walk of fame", "Skinny dipping", "Body count",
                "Hall pass", "Sugar daddy", "Slide into DMs", "Left on read", "Slow fade",
                "Cuffing season", "Hot girl summer", "Red flag", "Green flag", "Benching",
                "Orbiting", "Soft launch", "Hard launch", "DTR talk", "Roster",
            ]
            }
        }
    }

    @State private var phase: Phase = .menu
    @State private var category: HeadsUpCategory = .celebrities
    @State private var shuffledWords: [String] = []
    @State private var wordIndex: Int = 0
    @State private var score: Int = 0
    @State private var skipped: Int = 0
    @State private var timeLeft: Int = 60
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var results: [(word: String, gotIt: Bool)] = []

    // Tilt detection via motion
    @State private var lastTiltAction: Date = .distantPast
    @State private var motionTask: Task<Void, Never>? = nil

    var body: some View {
        Group {
            switch phase {
            case .menu: menuView
            case .ready: readyView
            case .playing: playingView
            case .done: doneView
            }
        }
        .onDisappear {
            timerTask?.cancel()
            motionTask?.cancel()
        }
    }

    // MARK: Menu

    private var menuView: some View {
        GameChrome {
            VStack(spacing: 16) {
                Text("Heads Up!")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("Hold the phone on your forehead. Your friends describe the word - guess it! Tilt down = got it. Tilt up = skip. Or use the buttons.")
                    .font(.callout).foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Pick a category").font(.headline).foregroundStyle(Theme.ink)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(HeadsUpCategory.allCases.filter { $0.minSpiciness <= store.data.preferences.spiciness }, id: \.self) { cat in
                        Button {
                            category = cat
                            startGame()
                        } label: {
                            VStack(spacing: 6) {
                                Text(cat.emoji).font(.system(size: 36))
                                Text(cat.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.95)))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
                        }
                        .buttonStyle(BeerifyPressStyle())
                    }
                }
            }
        }
    }

    // MARK: Ready

    private var readyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("📱⬆️").font(.system(size: 72))
            Text("Hold the phone on your forehead!")
                .font(.title2.weight(.heavy)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("Tilt DOWN = got it\nTilt UP = skip\n(or use the buttons)")
                .font(.callout).foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            BigActionButton(title: "I'm ready - start!") {
                phase = .playing
                startTimer()
                startMotionDetection()
            }
            Spacer()
        }
        .padding(20)
        .background(BeerifyBackground())
    }

    // MARK: Playing

    private var playingView: some View {
        let word = shuffledWords.indices.contains(wordIndex) ? shuffledWords[wordIndex] : "???"
        return VStack(spacing: 0) {
            // Skip zone (tilt up) - tap to skip
            Button {
                hapticTap(); skipWord()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "chevron.up").font(.title2.weight(.bold))
                    Text("SKIP").font(.caption.weight(.heavy))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.danger)
            }
            .buttonStyle(.plain)

            // Word display
            VStack(spacing: 8) {
                Text("⏱ \(timeLeft)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(timeLeft <= 10 ? Theme.danger : Theme.inkSoft)
                    .contentTransition(.numericText())
                Text(word)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 16)
                HStack {
                    Text("✓ \(score)").foregroundStyle(Theme.success)
                    Text("·")
                    Text("✗ \(skipped)").foregroundStyle(Theme.danger)
                }
                .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.surface)

            // Got it zone (tilt down) - tap to score
            Button {
                hapticTap(); gotWord()
            } label: {
                VStack(spacing: 4) {
                    Text("GOT IT!").font(.caption.weight(.heavy))
                    Image(systemName: "chevron.down").font(.title2.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.success)
            }
            .buttonStyle(.plain)
        }
        .ignoresSafeArea()
    }

    // MARK: Done

    private var doneView: some View {
        GameChrome {
            VStack(spacing: 16) {
                Text("Time's up!").font(.title.weight(.heavy)).foregroundStyle(Theme.ink)
                Text("\(score)").font(.system(size: 72, weight: .black, design: .rounded)).foregroundStyle(Theme.accentDeep)
                Text("out of \(score + skipped)").font(.headline).foregroundStyle(Theme.inkSoft)

                if !results.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, r in
                            HStack {
                                Text(r.gotIt ? "✓" : "✗")
                                    .foregroundStyle(r.gotIt ? Theme.success : Theme.danger)
                                    .font(.subheadline.weight(.bold))
                                Text(r.word).font(.subheadline).foregroundStyle(Theme.ink)
                                Spacer()
                            }
                            .padding(.horizontal, 10).padding(.vertical, 4)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.9)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
                }

                BigActionButton(title: "Play again") { phase = .menu }
            }
        }
    }

    // MARK: Actions

    private func startGame() {
        shuffledWords = category.words.shuffled()
        wordIndex = 0
        score = 0
        skipped = 0
        timeLeft = 60
        results = []
        phase = .ready
    }

    private func gotWord() {
        guard phase == .playing else { return }
        let word = shuffledWords.indices.contains(wordIndex) ? shuffledWords[wordIndex] : "???"
        results.append((word: word, gotIt: true))
        score += 1
        advanceWord()
    }

    private func skipWord() {
        guard phase == .playing else { return }
        let word = shuffledWords.indices.contains(wordIndex) ? shuffledWords[wordIndex] : "???"
        results.append((word: word, gotIt: false))
        skipped += 1
        advanceWord()
    }

    private func advanceWord() {
        wordIndex += 1
        if wordIndex >= shuffledWords.count {
            shuffledWords.shuffle()
            wordIndex = 0
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled && timeLeft > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    if timeLeft > 0 { timeLeft -= 1 }
                    if timeLeft == 0 {
                        phase = .done
                        motionTask?.cancel()
                    }
                }
            }
        }
    }

    private func startMotionDetection() {
        #if canImport(CoreMotion)
        motionTask?.cancel()
        motionTask = Task {
            let manager = CMMotionManager()
            guard manager.isDeviceMotionAvailable else { return }
            manager.deviceMotionUpdateInterval = 0.1
            manager.startDeviceMotionUpdates()
            // Wait a moment for the user to get the phone on their forehead
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard phase == .playing else { continue }
                if let motion = manager.deviceMotion {
                    let pitch = motion.attitude.pitch  // radians
                    let now = Date()
                    // Debounce: only act once per 1.5s to prevent rapid-fire
                    guard now.timeIntervalSince(lastTiltAction) > 1.5 else { continue }
                    // Thresholds: ~69 degrees tilt required for deliberate action
                    if pitch > 1.2 {
                        // Tilted forward (nod down) = got it
                        await MainActor.run { lastTiltAction = now; gotWord() }
                    } else if pitch < -0.3 {
                        // Tilted back (lean back) = skip
                        // Lower threshold since phone-on-forehead baseline is ~0,
                        // so tilting back only needs to cross -0.3 (~17°)
                        await MainActor.run { lastTiltAction = now; skipWord() }
                    }
                }
            }
            manager.stopDeviceMotionUpdates()
        }
        #endif
    }
}

// MARK: - Bomb Pass

/// Hot potato with a hidden timer. Each person gets a dare/challenge.
/// Complete it and pass before the bomb goes off. Explodes on you = drink.
struct BombPassGame: View {
    @Environment(AppStore.self) private var store
    @Environment(RoomService.self) private var roomService

    @State private var players: [String] = []
    @State private var newName: String = ""
    @State private var phase: BombPhase = .setup
    @State private var currentPlayerIndex: Int = 0
    @State private var currentChallenge: String = ""
    @State private var exploded: Bool = false
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var bombTicks: Int = 0
    @State private var tickSpeed: Double = 1.0
    @State private var recentChallenges: [String] = []
    @State private var roundNumber: Int = 0

    enum BombPhase { case setup, ticking, exploded }

    private static let challenges: [SpicyPrompt] = [
        // Level 1
        .init(text: "Name 3 types of cheese - GO!", level: 1),
        .init(text: "Do 5 star jumps - GO!", level: 1),
        .init(text: "Name a country for each letter: A, B, C - GO!", level: 1),
        .init(text: "Sing the first line of any song - GO!", level: 1),
        .init(text: "Name 3 dog breeds - GO!", level: 1),
        .init(text: "Do your best animal impression - GO!", level: 1),
        .init(text: "Name 3 things in your fridge right now - GO!", level: 1),
        .init(text: "Spell your name backwards - GO!", level: 1),
        .init(text: "Name 3 Marvel characters - GO!", level: 1),
        .init(text: "Clap a rhythm, the next person copies it - GO!", level: 1),
        .init(text: "Name 3 Taylor Swift songs - GO!", level: 1),
        .init(text: "Say a tongue twister without messing up - GO!", level: 1),
        .init(text: "Name 3 pizza toppings - GO!", level: 1),
        .init(text: "Count to 10 in any other language - GO!", level: 1),
        .init(text: "Name 3 things that are yellow - GO!", level: 1),
        // Level 2
        .init(text: "Name someone you've ghosted - GO!", level: 2),
        .init(text: "Show the last photo in your camera roll - GO!", level: 2),
        .init(text: "Name 3 things you regret buying - GO!", level: 2),
        .init(text: "Do your best impression of someone here - GO!", level: 2),
        .init(text: "Name a song everyone here would know the lyrics to, then sing it - GO!", level: 2),
        .init(text: "Say something nice about the person on your left - GO!", level: 2),
        .init(text: "Name 3 excuses you've used to skip plans - GO!", level: 2),
        .init(text: "Do a dramatic re-enactment of your last text - GO!", level: 2),
        .init(text: "Name 3 celebrity crushes - GO!", level: 2),
        .init(text: "Do a silly walk across the room - GO!", level: 2),
        // Level 3
        .init(text: "Name someone you'd swipe right on in this room - GO!", level: 3),
        .init(text: "Describe your type in 5 words - GO!", level: 3),
        .init(text: "Name 3 dating red flags - GO!", level: 3),
        .init(text: "Say the corniest pickup line you know - GO!", level: 3),
        .init(text: "Tell us your most embarrassing drunk story in 10 seconds - GO!", level: 3),
        .init(text: "Name 3 reasons your ex would say they dumped you - GO!", level: 3),
        .init(text: "Rate the last person you kissed out of 10 - GO!", level: 3),
        .init(text: "Name 3 things on your ideal first date - GO!", level: 3),
        // Level 4
        .init(text: "Name your biggest turn-off - GO!", level: 4),
        .init(text: "Name someone in this room most likely to slide into DMs - GO!", level: 4),
        .init(text: "Confess one thing you've never told anyone here - GO!", level: 4),
        .init(text: "Name the last person you stalked on Instagram - GO!", level: 4),
        .init(text: "Rate your own kissing from 1-10 - GO!", level: 4),
        .init(text: "Say the worst thing an ex ever said to you - GO!", level: 4),
        // Level 5
        .init(text: "Name the wildest place you've hooked up - GO!", level: 5),
        .init(text: "Say your actual body count out loud - GO!", level: 5),
        .init(text: "Name someone in this room you've thought about - GO!", level: 5),
        .init(text: "Describe your last hookup in one word - GO!", level: 5),
        .init(text: "Name your most embarrassing kink - GO!", level: 5),
        .init(text: "Rate everyone here out of 10 - speed round - GO!", level: 5),
    ]

    private var filteredChallenges: [String] {
        Self.challenges.upTo(store.data.preferences.spiciness)
    }

    var body: some View {
        GameChrome {
            VStack(alignment: .leading, spacing: 20) {
                switch phase {
                case .setup: setupView
                case .ticking: tickingView
                case .exploded: explodedView
                }
            }
        }
        .onAppear(perform: hydrateFromRoom)
        .onDisappear { timerTask?.cancel() }
    }

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bomb Pass")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("A bomb is ticking! You get a challenge - do it and pass the phone FAST. If the bomb explodes on you, you drink. Timer is random so you never know when it blows.")
                .font(.callout).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

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
                            Button { players.remove(at: i) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.9)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                    }
                }
            }

            BigActionButton(title: "Start bomb") { startBomb() }
                .disabled(players.count < 2)
                .opacity(players.count < 2 ? 0.5 : 1)

            if players.count < 2 {
                Text("Need at least 2 players.").font(.caption).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var tickingView: some View {
        let player = players[currentPlayerIndex % players.count]
        return VStack(spacing: 16) {
            // Bomb animation
            Text(bombTicks % 2 == 0 ? "💣" : "🔥")
                .font(.system(size: 72))
                .scaleEffect(1.0 + Double(bombTicks % 2) * 0.15)
                .animation(.easeInOut(duration: 0.2), value: bombTicks)

            Text("PASS TO: \(player)")
                .font(.title2.weight(.black)).foregroundStyle(Theme.accentDeep)

            Text(currentChallenge)
                .font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.danger.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.danger.opacity(0.4), lineWidth: 1))

            Text("Do it and pass - before it BLOWS!")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.danger)

            BigActionButton(title: "Done - pass the bomb! 💣") {
                hapticTap()
                currentPlayerIndex = (currentPlayerIndex + 1) % players.count
                drawChallenge()
            }
        }
    }

    private var explodedView: some View {
        let victim = players[currentPlayerIndex % players.count]
        return VStack(spacing: 16) {
            Text("💥").font(.system(size: 100))
            Text("BOOM!").font(.system(size: 36, weight: .black, design: .rounded)).foregroundStyle(Theme.danger)
            Text("\(victim) got blown up!").font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)
            Text("DRINK UP!").font(.headline).foregroundStyle(Theme.danger)

            BigActionButton(title: "Next round") { startBomb() }
            Button(role: .destructive) { phase = .setup } label: {
                Text("End game").font(.caption).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).tint(Theme.danger).controlSize(.small)
        }
    }

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

    private func drawChallenge() {
        let pool = filteredChallenges
        currentChallenge = rotatedPick(from: pool, recent: &recentChallenges, windowSize: max(5, pool.count / 3)) ?? "Name 3 things - GO!"
    }

    private func startBomb() {
        roundNumber += 1
        exploded = false
        bombTicks = 0
        currentPlayerIndex = Int.random(in: 0..<players.count)
        drawChallenge()
        phase = .ticking

        // Random fuse: 8 to 25 seconds
        let fuse = Double.random(in: 8...25)
        timerTask?.cancel()
        timerTask = Task {
            let startTime = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                // Ticking gets faster as fuse burns
                let interval = max(0.15, 1.0 - (elapsed / fuse) * 0.85)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                await MainActor.run { bombTicks += 1 }
                if elapsed >= fuse {
                    await MainActor.run {
                        exploded = true
                        phase = .exploded
                        #if canImport(UIKit) && !os(macOS)
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        #endif
                    }
                    return
                }
            }
        }
    }
}

// MARK: - Psych / Bluff

/// A real trivia fact appears. Everyone writes a fake but plausible answer.
/// All answers get shuffled with the real one. Pick the real answer -
/// wrong guesses = drink. Best bluffer (most people fooled) wins.
struct PsychBluffGame: View {
    @Environment(RoomService.self) private var roomService

    @State private var players: [String] = []
    @State private var newName: String = ""
    @State private var phase: PsychPhase = .setup
    @State private var currentQuestion: (q: String, a: String) = ("", "")
    @State private var fakeAnswers: [(player: String, answer: String)] = []
    @State private var currentWriterIndex: Int = 0
    @State private var currentText: String = ""
    @State private var allOptions: [(text: String, isReal: Bool, author: String)] = []
    @State private var currentVoterIndex: Int = 0
    @State private var votes: [String: String] = [:]  // voter -> chosen answer text
    @State private var bluffScores: [String: Int] = [:]
    @State private var roundNumber: Int = 0
    @State private var questionOrder: [Int] = []
    @State private var questionIdx: Int = 0

    enum PsychPhase { case setup, showQuestion, writing, voting, results }

    private static let questions: [(q: String, a: String)] = [
        ("What is the national animal of Scotland?", "Unicorn"),
        ("What color is a hippo's sweat?", "Pink"),
        ("How many hearts does an octopus have?", "Three"),
        ("What is the fear of long words called?", "Hippopotomonstrosesquippedaliophobia"),
        ("In what country can you find a high-speed train called a Shinkansen?", "Japan"),
        ("What fruit is used to flavor the liqueur Chambord?", "Raspberry"),
        ("What is the smallest bone in the human body?", "The stapes (in the ear)"),
        ("How many time zones does Russia have?", "11"),
        ("What element does the chemical symbol 'Au' stand for?", "Gold"),
        ("In which year was the first iPhone released?", "2007"),
        ("What is the only food that never expires?", "Honey"),
        ("What country has the most islands?", "Sweden"),
        ("What is the longest-running animated TV show?", "The Simpsons"),
        ("How many languages are written from right to left?", "12"),
        ("What percentage of the Earth's water is drinkable?", "About 1%"),
        ("What do butterflies taste with?", "Their feet"),
        ("How long is the shortest war in history?", "38 minutes"),
        ("What is the most stolen food in the world?", "Cheese"),
        ("What is the real name of the hashtag symbol?", "Octothorpe"),
        ("How many muscles does a cat have in each ear?", "32"),
        ("What animal can't jump?", "Elephant"),
        ("In what country were French fries invented?", "Belgium"),
        ("What is the dot over the letters 'i' and 'j' called?", "Tittle"),
        ("How many noses does a slug have?", "Four"),
        ("What is the collective noun for a group of flamingos?", "Flamboyance"),
        ("What is McDonald's most profitable item?", "Coca-Cola / fountain drinks"),
        ("Which planet rains diamonds?", "Neptune"),
        ("What is the most common password in the world?", "123456"),
        ("How fast does a sneeze travel?", "About 100 mph"),
        ("What animal has the longest pregnancy?", "Elephant (22 months)"),
        ("What percentage of people have never sent an email?", "About 50%"),
        ("How many dimples does the average golf ball have?", "336"),
        ("What is the only letter not in any US state name?", "Q"),
        ("What is the world record for most T-shirts worn at once?", "260"),
        ("What flavor is the white Haribo gummy bear?", "Pineapple"),
    ]

    var body: some View {
        GameChrome {
            VStack(alignment: .leading, spacing: 20) {
                switch phase {
                case .setup: setupView
                case .showQuestion: questionView
                case .writing: writingView
                case .voting: votingView
                case .results: resultsView
                }
            }
        }
        .onAppear(perform: hydrateFromRoom)
    }

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Psych!")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("A real trivia question appears. Everyone writes a FAKE but believable answer. All the fakes get mixed with the real answer. Pick the real one - wrong = drink. Whoever fools the most people wins.")
                .font(.callout).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

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
                            Button { players.remove(at: i) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.9)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                    }
                }
            }

            BigActionButton(title: "Start game") { startRound() }
                .disabled(players.count < 3)
                .opacity(players.count < 3 ? 0.5 : 1)

            if players.count < 3 {
                Text("Need at least 3 players for a good bluff.").font(.caption).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var questionView: some View {
        VStack(spacing: 16) {
            Text("Round \(roundNumber)").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
            Text("THE QUESTION").font(.caption.weight(.bold)).foregroundStyle(Theme.accentDeep)
            Text(currentQuestion.q)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent.opacity(0.18)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.45), lineWidth: 1))

            Text("Everyone will now write a FAKE answer. Make it believable!")
                .font(.callout).foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            BigActionButton(title: "Start writing fakes") {
                currentWriterIndex = 0
                phase = .writing
            }
        }
    }

    private var writingView: some View {
        let writer = players[currentWriterIndex]
        return VStack(spacing: 16) {
            Text("Pass to: \(writer)").font(.caption).foregroundStyle(Theme.inkSoft)
            HStack(spacing: 8) {
                Text(Avatars.avatar(for: writer)).font(.system(size: 36))
                Text(writer).font(.title2.weight(.heavy)).foregroundStyle(Theme.accentDeep)
            }

            Text(currentQuestion.q).font(.headline).foregroundStyle(Theme.ink).multilineTextAlignment(.center)

            Text("Write a FAKE but believable answer:").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)

            TextField("Your fake answer...", text: $currentText)
                .textFieldStyle(BeerifyFieldStyle())

            BigActionButton(title: "Submit") {
                hapticTap()
                let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                fakeAnswers.append((player: writer, answer: trimmed))
                currentText = ""
                if currentWriterIndex + 1 >= players.count {
                    buildVotingOptions()
                    currentVoterIndex = 0
                    phase = .voting
                } else {
                    currentWriterIndex += 1
                }
            }
            .disabled(currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

            Text("\(currentWriterIndex + 1) of \(players.count)").font(.caption).foregroundStyle(Theme.inkSoft)
            Text("Don't peek at others' answers!").font(.caption2).foregroundStyle(Theme.danger)
        }
    }

    private var votingView: some View {
        let voter = players[currentVoterIndex]
        return VStack(spacing: 16) {
            Text("Pass to: \(voter)").font(.caption).foregroundStyle(Theme.inkSoft)
            HStack(spacing: 8) {
                Text(Avatars.avatar(for: voter)).font(.system(size: 36))
                Text("\(voter), pick the REAL answer").font(.headline).foregroundStyle(Theme.accentDeep)
            }

            Text(currentQuestion.q).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)

            // Show all options except the voter's own fake
            let options = allOptions.filter { $0.author != voter }
            VStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                    Button {
                        hapticTap()
                        votes[voter] = opt.text
                        if currentVoterIndex + 1 >= players.count {
                            tallyBluffScores()
                            phase = .results
                        } else {
                            currentVoterIndex += 1
                        }
                    } label: {
                        Text(opt.text)
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface.opacity(0.95)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(BeerifyPressStyle())
                }
            }

            Text("\(currentVoterIndex + 1) of \(players.count)").font(.caption).foregroundStyle(Theme.inkSoft)
        }
    }

    private var resultsView: some View {
        // Who got fooled?
        let correctAnswer = currentQuestion.a
        let fooled = votes.filter { $0.value != correctAnswer }
        let gotIt = votes.filter { $0.value == correctAnswer }

        // Who fooled whom? Count how many picked each fake
        var fooledBy: [String: Int] = [:]  // fake author -> count
        for (_, chosenText) in fooled {
            if let fake = fakeAnswers.first(where: { $0.answer == chosenText }) {
                fooledBy[fake.player, default: 0] += 1
            }
        }

        return VStack(spacing: 14) {
            Text("The real answer was:").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
            Text(correctAnswer)
                .font(.title3.weight(.black)).foregroundStyle(Theme.success)
                .padding(12).frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.success.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.success.opacity(0.4), lineWidth: 1))

            if !gotIt.isEmpty {
                Text("Got it right: \(gotIt.keys.joined(separator: ", "))")
                    .font(.subheadline).foregroundStyle(Theme.success)
            }

            if !fooled.isEmpty {
                VStack(spacing: 4) {
                    Text("FOOLED - drink up!").font(.headline).foregroundStyle(Theme.danger)
                    ForEach(Array(fooled), id: \.key) { voter, chose in
                        let author = fakeAnswers.first(where: { $0.answer == chose })?.player ?? "?"
                        Text("\(voter) picked \"\(chose)\" (written by \(author))")
                            .font(.caption).foregroundStyle(Theme.inkSoft)
                    }
                }
            }

            if !fooledBy.isEmpty {
                VStack(spacing: 4) {
                    Text("Best bluffers this round:").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    ForEach(fooledBy.sorted { $0.value > $1.value }, id: \.key) { player, count in
                        Text("\(player) fooled \(count) player\(count == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(Theme.accentDeep)
                    }
                }
            }

            BigActionButton(title: "Next round") { startRound() }

            Button(role: .destructive) {
                phase = .setup; roundNumber = 0; bluffScores.removeAll()
            } label: {
                Text("End game").font(.caption).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).tint(Theme.danger).controlSize(.small)
        }
    }

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

    private func startRound() {
        roundNumber += 1
        fakeAnswers.removeAll()
        votes.removeAll()
        allOptions.removeAll()
        currentText = ""

        if questionOrder.isEmpty || questionIdx >= questionOrder.count {
            questionOrder = Array(0..<Self.questions.count).shuffled()
            questionIdx = 0
        }
        let q = Self.questions[questionOrder[questionIdx]]
        currentQuestion = q
        questionIdx += 1
        phase = .showQuestion
    }

    private func buildVotingOptions() {
        var opts: [(text: String, isReal: Bool, author: String)] = []
        opts.append((text: currentQuestion.a, isReal: true, author: "__REAL__"))
        for fake in fakeAnswers {
            opts.append((text: fake.answer, isReal: false, author: fake.player))
        }
        allOptions = opts.shuffled()
    }

    private func tallyBluffScores() {
        let correctAnswer = currentQuestion.a
        for (_, chosenText) in votes where chosenText != correctAnswer {
            if let fake = fakeAnswers.first(where: { $0.answer == chosenText }) {
                bluffScores[fake.player, default: 0] += 1
            }
        }
    }
}

// MARK: - Bus Driver

/// Classic pre-game card guessing game. 4 rounds of escalating guesses:
/// Red or Black? Higher or Lower? Inside or Outside? Guess the suit.
/// Wrong = drink. The stakes increase each round.
struct BusDriverGame: View {
    @State private var phase: BusPhase = .intro
    @State private var round: Int = 0
    @State private var currentCard: Int? = nil
    @State private var previousCard: Int? = nil
    @State private var cardHistory: [Int] = []
    @State private var drinkCount: Int = 0
    @State private var correctCount: Int = 0
    @State private var deck: [Int] = Array(0..<52).shuffled()
    @State private var showResult: Bool = false
    @State private var lastCorrect: Bool = false

    enum BusPhase { case intro, redBlack, highLow, insideOutside, suit, done }

    private static let roundNames = ["Red or Black?", "Higher or Lower?", "Inside or Outside?", "Guess the Suit"]
    private static let roundDrinks = [1, 2, 3, 4]  // escalating stakes

    var body: some View {
        GameChrome {
            VStack(spacing: 20) {
                switch phase {
                case .intro: introView
                case .redBlack: redBlackView
                case .highLow: highLowView
                case .insideOutside: insideOutsideView
                case .suit: suitView
                case .done: doneView
                }
            }
        }
    }

    // MARK: Views

    private var introView: some View {
        VStack(spacing: 14) {
            Text("Bus Driver")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("4 rounds of escalating card guesses. Get it wrong? Drink more each round.\n\n1. Red or Black? (1 sip)\n2. Higher or Lower? (2 sips)\n3. Inside or Outside? (3 sips)\n4. Guess the suit (4 sips)")
                .font(.callout).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            BigActionButton(title: "Deal me in") {
                deck = Array(0..<52).shuffled()
                drinkCount = 0; correctCount = 0; cardHistory = []
                drawCard()
                phase = .redBlack
            }
        }
    }

    private var redBlackView: some View {
        cardGuessView(
            title: "Red or Black?",
            subtitle: "Wrong = 1 sip",
            options: [
                ("♥️ Red", { isRed(currentCard!) }),
                ("♠️ Black", { !isRed(currentCard!) })
            ]
        )
    }

    private var highLowView: some View {
        let prev = previousCard ?? 0
        return cardGuessView(
            title: "Higher or Lower?",
            subtitle: "Previous card: \(cardDisplay(prev)). Wrong = 2 sips",
            options: [
                ("⬇ Lower", { rankValue(currentCard!) < rankValue(prev) }),
                ("⬆ Higher", { rankValue(currentCard!) > rankValue(prev) })
            ]
        )
    }

    private var insideOutsideView: some View {
        // Use the last two cards from history for inside/outside
        let card1 = cardHistory.count >= 2 ? cardHistory[cardHistory.count - 2] : 0
        let card2 = cardHistory.count >= 1 ? cardHistory[cardHistory.count - 1] : 0
        let lo = min(rankValue(card1), rankValue(card2))
        let hi = max(rankValue(card1), rankValue(card2))
        return cardGuessView(
            title: "Inside or Outside?",
            subtitle: "Between \(cardDisplay(card1)) and \(cardDisplay(card2))? Wrong = 3 sips",
            options: [
                ("Inside", {
                    let val = rankValue(currentCard!)
                    return val > lo && val < hi
                }),
                ("Outside", {
                    let val = rankValue(currentCard!)
                    return val <= lo || val >= hi
                })
            ]
        )
    }

    private var suitView: some View {
        cardGuessView(
            title: "Guess the Suit",
            subtitle: "Wrong = 4 sips. This is the big one.",
            options: [
                ("♠️ Spades", { suitIndex(currentCard!) == 0 }),
                ("♥️ Hearts", { suitIndex(currentCard!) == 1 }),
                ("♦️ Diamonds", { suitIndex(currentCard!) == 2 }),
                ("♣️ Clubs", { suitIndex(currentCard!) == 3 })
            ]
        )
    }

    private func cardGuessView(title: String, subtitle: String, options: [(String, () -> Bool)]) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Round \(round + 1)/4").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                Spacer()
                Text("Sips: \(drinkCount)").font(.caption.weight(.semibold)).foregroundStyle(Theme.danger)
            }

            if showResult, let card = currentCard {
                Text(cardDisplay(card)).font(.system(size: 72))
                Text(lastCorrect ? "Correct!" : "Wrong - drink \(Self.roundDrinks[min(round, 3)])!")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(lastCorrect ? Theme.success : Theme.danger)

                BigActionButton(title: round >= 3 ? "See results" : "Next round") {
                    showResult = false
                    if let card = currentCard { cardHistory.append(card) }
                    round += 1
                    previousCard = currentCard
                    if round >= 4 {
                        phase = .done
                    } else {
                        drawCard()
                        switch round {
                        case 1: phase = .highLow
                        case 2: phase = .insideOutside
                        case 3: phase = .suit
                        default: phase = .done
                        }
                    }
                }
            } else {
                Text("🂠").font(.system(size: 72))
                Text(title).font(.title2.weight(.heavy)).foregroundStyle(Theme.ink)
                Text(subtitle).font(.caption).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                        Button {
                            hapticTap()
                            let correct = opt.1()
                            lastCorrect = correct
                            if !correct { drinkCount += Self.roundDrinks[min(round, 3)] }
                            else { correctCount += 1 }
                            showResult = true
                        } label: {
                            Text(opt.0).frame(maxWidth: .infinity).padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent).tint(Theme.accent)
                    }
                }
            }
        }
    }

    private var doneView: some View {
        let verdict = drinkCount == 0 ? "Perfect run - you're a legend!" :
                      drinkCount <= 3 ? "Not bad - light damage." :
                      drinkCount <= 6 ? "Ouch - moderate damage." :
                      "Brutal. You got destroyed."
        return VStack(spacing: 14) {
            Text(drinkCount == 0 ? "🏆" : "🚌").font(.system(size: 72))
            Text("Bus Driver Complete").font(.title.weight(.heavy)).foregroundStyle(Theme.ink)
            Text("\(correctCount)/4 correct").font(.headline).foregroundStyle(Theme.accentDeep)
            Text("Total sips: \(drinkCount)").font(.title3.weight(.heavy)).foregroundStyle(Theme.danger)
            Text(verdict).font(.callout).foregroundStyle(Theme.inkSoft)
            BigActionButton(title: "Ride again") {
                phase = .intro; round = 0
            }
        }
    }

    // MARK: Helpers

    private func drawCard() {
        if deck.isEmpty { deck = Array(0..<52).shuffled() }
        let card = deck.removeFirst()
        currentCard = card
    }

    private func isRed(_ idx: Int) -> Bool {
        let s = suitIndex(idx)
        return s == 1 || s == 2  // hearts or diamonds
    }

    private func suitIndex(_ idx: Int) -> Int { idx / 13 }

    private func rankValue(_ idx: Int) -> Int { idx % 13 }

    private func cardDisplay(_ idx: Int) -> String {
        let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
        let suits = ["♠️", "♥️", "♦️", "♣️"]
        return "\(ranks[idx % 13])\(suits[idx / 13])"
    }
}

// MARK: - Medusa

/// Everyone secretly picks who they're "looking at." Reveal simultaneously.
/// If two people picked each other = they both drink. Creates insane tension.
struct MedusaGame: View {
    @Environment(RoomService.self) private var roomService

    @State private var players: [String] = []
    @State private var newName: String = ""
    @State private var phase: MedusaPhase = .setup
    @State private var choices: [String: String] = [:]  // player -> who they looked at
    @State private var currentChooserIndex: Int = 0
    @State private var roundNumber: Int = 0

    enum MedusaPhase { case setup, choosing, reveal }

    var body: some View {
        GameChrome {
            VStack(alignment: .leading, spacing: 20) {
                switch phase {
                case .setup: setupView
                case .choosing: choosingView
                case .reveal: revealView
                }
            }
        }
        .onAppear(perform: hydrateFromRoom)
    }

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Medusa")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("Everyone looks down. Each person secretly picks someone to \"look at.\" When all choices are locked in, we reveal. If two people picked EACH OTHER - they both drink. Eye contact = chaos.")
                .font(.callout).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

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
                            Button { players.remove(at: i) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.9)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                    }
                }
            }

            BigActionButton(title: "Start round") { startRound() }
                .disabled(players.count < 3)
                .opacity(players.count < 3 ? 0.5 : 1)

            if players.count < 3 {
                Text("Need at least 3 players.").font(.caption).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var choosingView: some View {
        let chooser = players[currentChooserIndex]
        let others = players.filter { $0 != chooser }
        return VStack(spacing: 16) {
            Text("Round \(roundNumber)").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)

            Text("Pass to: \(chooser)")
                .font(.caption).foregroundStyle(Theme.inkSoft)
            HStack(spacing: 8) {
                Text(Avatars.avatar(for: chooser)).font(.system(size: 40))
                Text(chooser).font(.title2.weight(.heavy)).foregroundStyle(Theme.accentDeep)
            }

            Text("Who are you looking at?")
                .font(.headline).foregroundStyle(Theme.ink)
            Text("Pick secretly - don't show anyone!")
                .font(.caption).foregroundStyle(Theme.inkSoft)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(others, id: \.self) { target in
                    Button {
                        hapticTap()
                        choices[chooser] = target
                        if currentChooserIndex + 1 >= players.count {
                            phase = .reveal
                        } else {
                            currentChooserIndex += 1
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(Avatars.avatar(for: target))
                            Text(target).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface.opacity(0.9)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(BeerifyPressStyle())
                }
            }

            Text("\(currentChooserIndex + 1) of \(players.count)").font(.caption).foregroundStyle(Theme.inkSoft)
        }
    }

    private var revealView: some View {
        // Find mutual matches
        var matches: [(String, String)] = []
        var matched: Set<String> = []
        for (a, target) in choices {
            if let bTarget = choices[target], bTarget == a, !matched.contains(a), !matched.contains(target) {
                matches.append((a, target))
                matched.insert(a)
                matched.insert(target)
            }
        }

        return VStack(spacing: 16) {
            Text("REVEAL!").font(.title.weight(.black)).foregroundStyle(Theme.accentDeep)

            // Show all choices
            VStack(spacing: 6) {
                ForEach(players, id: \.self) { player in
                    let target = choices[player] ?? "?"
                    let isMutual = matched.contains(player)
                    HStack {
                        Text(Avatars.avatar(for: player)).font(.title3)
                        Text(player).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        Image(systemName: "arrow.right").font(.caption).foregroundStyle(Theme.inkSoft)
                        Text(Avatars.avatar(for: target)).font(.title3)
                        Text(target).font(.subheadline).foregroundStyle(Theme.ink)
                        Spacer()
                        if isMutual {
                            Text("MATCH!").font(.caption.weight(.black)).foregroundStyle(Theme.danger)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(isMutual ? Theme.danger.opacity(0.15) : Theme.surface.opacity(0.9)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(isMutual ? Theme.danger.opacity(0.4) : Theme.hairline, lineWidth: 1))
                }
            }

            if matches.isEmpty {
                Text("No matches - everyone's safe this round!")
                    .font(.headline).foregroundStyle(Theme.success)
            } else {
                VStack(spacing: 4) {
                    Text("EYE CONTACT! Both drink:")
                        .font(.headline).foregroundStyle(Theme.danger)
                    ForEach(matches, id: \.0) { a, b in
                        Text("\(a) & \(b)")
                            .font(.title3.weight(.heavy)).foregroundStyle(Theme.accentDeep)
                    }
                }
            }

            BigActionButton(title: "Next round") { startRound() }

            Button(role: .destructive) { phase = .setup; roundNumber = 0 } label: {
                Text("End game").font(.caption).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).tint(Theme.danger).controlSize(.small)
        }
    }

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

    private func startRound() {
        roundNumber += 1
        choices.removeAll()
        currentChooserIndex = 0
        phase = .choosing
    }
}

// MARK: - Who Said It?

/// Players anonymously type confessions/answers. Then everyone guesses who
/// wrote each one. The best guesser wins; wrong guessers drink.
struct WhoSaidItGame: View {
    @Environment(AppStore.self) private var store
    @Environment(RoomService.self) private var roomService

    enum Phase { case setup, prompting, writing, reading, guessing, scores }

    @State private var players: [String] = []
    @State private var newName: String = ""
    @State private var phase: Phase = .setup
    @State private var currentPrompt: String = ""
    @State private var submissions: [(player: String, answer: String)] = []
    @State private var currentWriterIndex: Int = 0
    @State private var currentText: String = ""
    @State private var currentReadIndex: Int = 0
    @State private var guesses: [String: String] = [:]  // reader -> guessed player
    @State private var currentGuesserIndex: Int = 0
    @State private var scoreBoard: [String: Int] = [:]
    @State private var roundNumber: Int = 0
    @State private var recentPrompts: [String] = []
    @State private var shuffledSubmissions: [(player: String, answer: String)] = []

    private static let prompts: [SpicyPrompt] = [
        .init(text: "What's your most embarrassing childhood memory?", level: 1),
        .init(text: "What's a lie you tell yourself every day?", level: 1),
        .init(text: "What's your most unpopular opinion?", level: 1),
        .init(text: "What's a secret skill you have?", level: 1),
        .init(text: "What's the weirdest thing you've eaten?", level: 1),
        .init(text: "What would you do with a million dollars?", level: 1),
        .init(text: "What's the pettiest hill you'd die on?", level: 2),
        .init(text: "Describe your worst date in one sentence.", level: 2),
        .init(text: "What's a habit you're ashamed of?", level: 2),
        .init(text: "What's the drunkest text you've ever sent?", level: 2),
        .init(text: "What's the dumbest thing you've done for money?", level: 2),
        .init(text: "What was the last lie you told?", level: 3),
        .init(text: "What's a secret you've been keeping from someone in this room?", level: 3),
        .init(text: "What's the most toxic trait you bring to relationships?", level: 3),
        .init(text: "Describe your type in three words.", level: 3),
        .init(text: "What's something you've done that you'd never admit sober?", level: 3),
        .init(text: "What's a confession you need to get off your chest?", level: 4),
        .init(text: "Describe your worst hookup in one sentence.", level: 4),
        .init(text: "What's a red flag you know you are but won't fix?", level: 4),
        .init(text: "What's the most embarrassing thing in your search history?", level: 4),
        .init(text: "Who in this room would you hook up with? Be honest.", level: 5),
        .init(text: "What's something you've never told anyone?", level: 5),
        .init(text: "What's the wildest thing on your bucket list?", level: 5),
        .init(text: "Describe your kinkiest fantasy in one sentence.", level: 5),
    ]

    private var filteredPrompts: [String] {
        Self.prompts.upTo(store.data.preferences.spiciness)
    }

    var body: some View {
        GameChrome {
            VStack(alignment: .leading, spacing: 20) {
                switch phase {
                case .setup: setupView
                case .prompting: promptRevealView
                case .writing: writingView
                case .reading: readingView
                case .guessing: guessingView
                case .scores: scoresView
                }
            }
        }
        .onAppear(perform: hydrateFromRoom)
    }

    // MARK: Setup

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who Said It?")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("Everyone anonymously answers a prompt. Then you all try to guess who wrote what. Wrong guesses = drink.")
                .font(.callout).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

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
                            Button { players.remove(at: i) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.9)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                    }
                }
            }

            BigActionButton(title: "Start game") { startNewRound() }
                .disabled(players.count < 3)
                .opacity(players.count < 3 ? 0.5 : 1)

            if players.count < 3 {
                Text("Need at least 3 players.").font(.caption).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    // MARK: Prompt reveal

    private var promptRevealView: some View {
        VStack(spacing: 16) {
            Text("Round \(roundNumber)").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
            Text("THE PROMPT").font(.caption.weight(.bold)).foregroundStyle(Theme.accentDeep)
            Text(currentPrompt)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Text("Everyone will answer this anonymously. Pass the phone around - no peeking!")
                .font(.callout).foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            BigActionButton(title: "Start writing") {
                currentWriterIndex = 0
                phase = .writing
            }
        }
    }

    // MARK: Writing

    private var writingView: some View {
        let writer = players[currentWriterIndex]
        return VStack(spacing: 16) {
            Text("Pass the phone to:").font(.caption).foregroundStyle(Theme.inkSoft)
            HStack(spacing: 8) {
                Text(Avatars.avatar(for: writer)).font(.system(size: 36))
                Text(writer).font(.title2.weight(.heavy)).foregroundStyle(Theme.accentDeep)
            }

            Text(currentPrompt)
                .font(.headline).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            TextField("Type your answer...", text: $currentText, axis: .vertical)
                .textFieldStyle(BeerifyFieldStyle())
                .lineLimit(3...6)

            BigActionButton(title: "Submit (secretly)") {
                hapticTap()
                let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                submissions.append((player: writer, answer: trimmed))
                currentText = ""
                if currentWriterIndex + 1 >= players.count {
                    shuffledSubmissions = submissions.shuffled()
                    currentReadIndex = 0
                    currentGuesserIndex = 0
                    phase = .reading
                } else {
                    currentWriterIndex += 1
                }
            }
            .disabled(currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

            Text("\(currentWriterIndex + 1) of \(players.count)").font(.caption).foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: Reading

    private var readingView: some View {
        let sub = shuffledSubmissions[currentReadIndex]
        return VStack(spacing: 16) {
            Text("Someone wrote:").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
            Text("\"\(sub.answer)\"")
                .font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.4), lineWidth: 1))

            Text("Who do you think said this? Discuss, then tap to guess.")
                .font(.callout).foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            BigActionButton(title: "We're ready to guess") {
                currentGuesserIndex = 0
                guesses.removeAll()
                phase = .guessing
            }
        }
    }

    // MARK: Guessing

    private var guessingView: some View {
        let sub = shuffledSubmissions[currentReadIndex]
        // Filter out the actual author from guessers (you don't guess your own)
        let eligibleGuessers = players.filter { $0 != sub.player }
        let guesser: String? = currentGuesserIndex < eligibleGuessers.count ? eligibleGuessers[currentGuesserIndex] : nil

        return VStack(spacing: 16) {
            Text("\"\(sub.answer)\"")
                .font(.headline).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            if let guesser {
                Text("\(guesser), who said this?")
                    .font(.title3.weight(.heavy)).foregroundStyle(Theme.accentDeep)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(players.filter { $0 != guesser }, id: \.self) { candidate in
                        Button {
                            hapticTap()
                            guesses[guesser] = candidate
                            let correct = candidate == sub.player
                            if correct {
                                scoreBoard[guesser, default: 0] += 1
                            }
                            if currentGuesserIndex + 1 >= eligibleGuessers.count {
                                // Reveal who wrote it, then move to next
                                revealAndAdvance()
                            } else {
                                currentGuesserIndex += 1
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(Avatars.avatar(for: candidate))
                                Text(candidate).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface.opacity(0.9)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
                        }
                        .buttonStyle(BeerifyPressStyle())
                    }
                }

                Text("\(currentGuesserIndex + 1) of \(eligibleGuessers.count) guessing")
                    .font(.caption).foregroundStyle(Theme.inkSoft)
            } else {
                revealCard(for: sub)
            }
        }
    }

    private func revealCard(for sub: (player: String, answer: String)) -> some View {
        VStack(spacing: 12) {
            Text("It was...").font(.headline).foregroundStyle(Theme.inkSoft)
            HStack(spacing: 8) {
                Text(Avatars.avatar(for: sub.player)).font(.system(size: 40))
                Text(sub.player).font(.title.weight(.black)).foregroundStyle(Theme.accentDeep)
            }

            let wrongGuessers = guesses.filter { $0.value != sub.player }.map(\.key)
            if !wrongGuessers.isEmpty {
                Text("Wrong guessers drink: \(wrongGuessers.joined(separator: ", "))")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.danger)
                    .multilineTextAlignment(.center)
            } else {
                Text("Everyone got it right!").font(.subheadline).foregroundStyle(Theme.success)
            }

            BigActionButton(title: currentReadIndex + 1 >= shuffledSubmissions.count ? "See scores" : "Next answer") {
                if currentReadIndex + 1 >= shuffledSubmissions.count {
                    phase = .scores
                } else {
                    currentReadIndex += 1
                    guesses.removeAll()
                    phase = .reading
                }
            }
        }
    }

    private func revealAndAdvance() {
        // Push index past the end so guessingView shows the reveal card
        let sub = shuffledSubmissions[currentReadIndex]
        let eligibleCount = players.filter { $0 != sub.player }.count
        currentGuesserIndex = eligibleCount
    }

    // MARK: Scores

    private var scoresView: some View {
        let sorted = scoreBoard.sorted { $0.value > $1.value }
        return VStack(spacing: 14) {
            Text("Scoreboard").font(.title.weight(.heavy)).foregroundStyle(Theme.ink)
            if sorted.isEmpty {
                Text("Nobody guessed correctly!").foregroundStyle(Theme.inkSoft)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(sorted.enumerated()), id: \.offset) { i, entry in
                        HStack(spacing: 10) {
                            Text(i == 0 ? "🥇" : i == 1 ? "🥈" : i == 2 ? "🥉" : "#\(i+1)")
                                .font(.subheadline.weight(.bold)).frame(width: 28)
                            Text(Avatars.avatar(for: entry.key)).font(.title3)
                            Text(entry.key).font(.subheadline).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(entry.value) correct").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accentDeep)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(i == 0 ? Theme.accent.opacity(0.15) : Color.clear))
                    }
                }
            }

            BigActionButton(title: "Next round") { startNewRound() }

            Button(role: .destructive) {
                phase = .setup; roundNumber = 0; scoreBoard.removeAll()
            } label: {
                Text("End game").font(.caption).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).tint(Theme.danger).controlSize(.small)
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

    private func startNewRound() {
        roundNumber += 1
        submissions.removeAll()
        shuffledSubmissions.removeAll()
        guesses.removeAll()
        currentText = ""
        let pool = filteredPrompts
        currentPrompt = rotatedPick(from: pool, recent: &recentPrompts, windowSize: max(3, pool.count / 3)) ?? "What's a secret you've been keeping?"
        phase = .prompting
    }
}

// MARK: - Flip Cup Challenge

/// A reaction time game. A countdown runs, then "FLIP!" appears - tap as fast
/// as you can. Each player takes a turn; slowest reaction time drinks.
struct FlipCupGame: View {
    @Environment(RoomService.self) private var roomService

    enum Phase { case setup, countdown, waiting, tapped, results }

    @State private var players: [String] = []
    @State private var newName: String = ""
    @State private var phase: Phase = .setup
    @State private var currentPlayerIndex: Int = 0
    @State private var reactionTimes: [String: Double] = [:]
    @State private var countdownNumber: Int = 3
    @State private var flipTime: Date? = nil
    @State private var tappedTime: Double? = nil
    @State private var tooEarly: Bool = false
    @State private var timerTask: Task<Void, Never>? = nil

    var body: some View {
        GameChrome {
            VStack(spacing: 20) {
                switch phase {
                case .setup: setupView
                case .countdown: countdownView
                case .waiting: waitingView
                case .tapped: tappedView
                case .results: resultsView
                }
            }
        }
        .onAppear(perform: hydrateFromRoom)
        .onDisappear { timerTask?.cancel() }
    }

    // MARK: Setup

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flip Cup")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("Test your reflexes! Wait for \"FLIP!\" to appear, then tap as fast as you can. Slowest player drinks. Tap too early? Automatic last place.")
                .font(.callout).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

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
                            if let time = reactionTimes[name] {
                                Text(time < 0 ? "TOO EARLY" : String(format: "%.3fs", time))
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(time < 0 ? Theme.danger : Theme.success)
                            }
                            Button { players.remove(at: i) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.9)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                    }
                }
            }

            BigActionButton(title: reactionTimes.isEmpty ? "Start game" : "Next player") {
                startCountdown()
            }
            .disabled(players.count < 2 || (reactionTimes.count > 0 && currentPlayerIndex >= players.count))
            .opacity(players.count < 2 ? 0.5 : 1)

            if players.count < 2 {
                Text("Need at least 2 players.").font(.caption).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    // MARK: Countdown

    private var countdownView: some View {
        VStack(spacing: 16) {
            Text("Pass phone to \(players[currentPlayerIndex])")
                .font(.headline).foregroundStyle(Theme.inkSoft)
            Text("\(countdownNumber)")
                .font(.system(size: 120, weight: .black, design: .rounded))
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText())
            Text("Get ready...")
                .font(.title3).foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: Waiting for tap

    private var waitingView: some View {
        Button {
            hapticTap()
            if let ft = flipTime {
                let reaction = Date().timeIntervalSince(ft)
                tappedTime = reaction
                reactionTimes[players[currentPlayerIndex]] = reaction
                phase = .tapped
            } else {
                // Tapped too early!
                tooEarly = true
                reactionTimes[players[currentPlayerIndex]] = -1
                timerTask?.cancel()
                phase = .tapped
            }
        } label: {
            VStack(spacing: 16) {
                if flipTime != nil {
                    Text("FLIP!")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("TAP NOW!")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Text("Wait for it...")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Don't tap yet!")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 300)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(flipTime != nil ? Theme.success : Theme.accentDeep)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Tapped

    private var tappedView: some View {
        VStack(spacing: 16) {
            if tooEarly {
                Text("TOO EARLY!").font(.title.weight(.black)).foregroundStyle(Theme.danger)
                Text("\(players[currentPlayerIndex]) jumped the gun - automatic last place.")
                    .font(.callout).foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            } else if let time = tappedTime {
                Text(String(format: "%.3f", time))
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accentDeep)
                Text("seconds")
                    .font(.title3).foregroundStyle(Theme.inkSoft)
                let verdict = time < 0.25 ? "Lightning fast!" :
                              time < 0.4 ? "Quick reflexes!" :
                              time < 0.6 ? "Not bad." : "A bit slow..."
                Text(verdict).font(.headline).foregroundStyle(Theme.ink)
            }

            if currentPlayerIndex + 1 < players.count {
                BigActionButton(title: "Next player: \(players[currentPlayerIndex + 1])") {
                    currentPlayerIndex += 1
                    startCountdown()
                }
            } else {
                BigActionButton(title: "See results") {
                    phase = .results
                }
            }
        }
    }

    // MARK: Results

    private var resultsView: some View {
        let sorted = reactionTimes.sorted { a, b in
            // -1 means too early = last place
            if a.value < 0 { return false }
            if b.value < 0 { return true }
            return a.value < b.value
        }
        let loser = sorted.last

        return VStack(spacing: 14) {
            Text("Results").font(.title.weight(.heavy)).foregroundStyle(Theme.ink)

            VStack(spacing: 6) {
                ForEach(Array(sorted.enumerated()), id: \.offset) { i, entry in
                    let isLoser = entry.key == loser?.key
                    HStack(spacing: 10) {
                        Text(i == 0 ? "🥇" : i == 1 ? "🥈" : i == 2 ? "🥉" : "#\(i+1)")
                            .font(.subheadline.weight(.bold)).frame(width: 28)
                        Text(Avatars.avatar(for: entry.key)).font(.title3)
                        Text(entry.key).font(.subheadline).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(entry.value < 0 ? "TOO EARLY" : String(format: "%.3fs", entry.value))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(entry.value < 0 ? Theme.danger : Theme.accentDeep)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(isLoser ? Theme.danger.opacity(0.15) : (i == 0 ? Theme.accent.opacity(0.15) : Color.clear)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(isLoser ? Theme.danger.opacity(0.4) : Color.clear, lineWidth: 1))
                }
            }

            if let loser {
                VStack(spacing: 4) {
                    Text("\(loser.key) drinks!")
                        .font(.title2.weight(.black)).foregroundStyle(Theme.danger)
                    Text(loser.value < 0 ? "Don't jump the gun next time." : "Slowest reflexes in the squad.")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                }
            }

            BigActionButton(title: "Play again") {
                reactionTimes.removeAll()
                currentPlayerIndex = 0
                phase = .setup
            }
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

    private func startCountdown() {
        tooEarly = false
        tappedTime = nil
        flipTime = nil
        countdownNumber = 3
        phase = .countdown

        timerTask?.cancel()
        timerTask = Task {
            for i in stride(from: 3, through: 1, by: -1) {
                await MainActor.run { countdownNumber = i }
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
            // Random delay between 0.5 and 3 seconds
            await MainActor.run { phase = .waiting }
            let delay = UInt64.random(in: 500_000_000...3_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            if !Task.isCancelled {
                await MainActor.run { flipTime = Date() }
            }
        }
    }
}

// MARK: - Dare Ladder

/// Escalating dares round by round. Each round the stakes go up.
/// Chicken out at any point = drink double. Survive = glory.
struct DareLadderGame: View {
    @Environment(AppStore.self) private var store
    @Environment(RoomService.self) private var roomService

    @State private var players: [String] = []
    @State private var newName: String = ""
    @State private var phase: DareLadderPhase = .setup
    @State private var currentPlayerIndex: Int = 0
    @State private var currentRung: Int = 0
    @State private var currentDare: String = ""
    @State private var eliminated: Set<String> = []
    @State private var recentDares: [[String]] = [[], [], [], [], []]

    enum DareLadderPhase { case setup, dare, result }

    // 5 rungs of escalating intensity
    private static let ladder: [[SpicyPrompt]] = [
        // Rung 1 - Easy warm-up
        [
            .init(text: "Do your best celebrity impression for 15 seconds.", level: 1),
            .init(text: "Speak in a foreign accent until the next round.", level: 1),
            .init(text: "Do 10 jumping jacks right now.", level: 1),
            .init(text: "Sing the chorus of the last song you listened to.", level: 1),
            .init(text: "Let someone draw something on your hand with a pen.", level: 1),
            .init(text: "Talk like a robot for the next 2 minutes.", level: 1),
            .init(text: "Dance with no music for 10 seconds.", level: 1),
            .init(text: "Make up a rap about the person on your left. 4 bars.", level: 1),
            .init(text: "Do your best model walk across the room.", level: 2),
            .init(text: "Let the group pick a silly nickname for you for the rest of the game.", level: 2),
        ],
        // Rung 2 - Getting warmer
        [
            .init(text: "Text 'I need to tell you something important' to the 3rd person in your contacts.", level: 2),
            .init(text: "Post an ugly selfie on your story for 1 minute.", level: 2),
            .init(text: "Let the group pick an emoji and send it to your mum with no context.", level: 2),
            .init(text: "Do a trust fall right now. Someone catch them.", level: 2),
            .init(text: "Eat a spoonful of the hottest sauce available.", level: 2),
            .init(text: "Let someone go through your most recent 10 photos.", level: 3),
            .init(text: "Read your last 3 sent texts out loud.", level: 3),
            .init(text: "Call the last person who called you and sing Happy Birthday.", level: 3),
            .init(text: "Do your best seductive voice reading a Wikipedia article.", level: 3),
            .init(text: "Show the group the last person you stalked on Instagram.", level: 3),
        ],
        // Rung 3 - Stakes rising
        [
            .init(text: "Show the group your screen time report.", level: 3),
            .init(text: "Let the group send one text from your phone to anyone.", level: 3),
            .init(text: "Read your last DM conversation out loud for 30 seconds.", level: 3),
            .init(text: "Let the group rewrite your dating app bio.", level: 3),
            .init(text: "Show your most embarrassing saved photo.", level: 3),
            .init(text: "Confess a real secret - something nobody here knows.", level: 4),
            .init(text: "Let someone scroll your camera roll for 15 seconds.", level: 4),
            .init(text: "Text your ex 'thinking of you' - right now.", level: 4),
            .init(text: "Call a friend and tell them you're in love with someone in this room.", level: 4),
            .init(text: "Let the group swipe on your dating app for 60 seconds.", level: 4),
        ],
        // Rung 4 - Nerve test
        [
            .init(text: "Give the person on your left a genuine, specific compliment that makes everyone go 'ohhh'.", level: 4),
            .init(text: "Show the group your recently deleted photos.", level: 4),
            .init(text: "Send 'you up?' to the last person you hooked up with.", level: 4),
            .init(text: "Let the group compose a message and send it from your phone to anyone they choose.", level: 4),
            .init(text: "Show the group the contact name you have for your ex.", level: 4),
            .init(text: "Kiss the person on your right on the cheek.", level: 4),
            .init(text: "Do a lap dance for 10 seconds - fully clothed, pick your victim.", level: 5),
            .init(text: "Reveal your actual body count to the group.", level: 5),
            .init(text: "Rate everyone here out of 10 - out loud.", level: 5),
            .init(text: "Share the screen of your most-used app for 30 seconds.", level: 5),
        ],
        // Rung 5 - Final boss
        [
            .init(text: "Unlock your phone and hand it to the person you trust least here. 60 seconds.", level: 5),
            .init(text: "Let the group post literally anything to your Instagram story.", level: 5),
            .init(text: "Text your crush exactly what the group dictates.", level: 5),
            .init(text: "Read aloud the most explicit message in your phone.", level: 5),
            .init(text: "Confess something that could genuinely change how this group sees you.", level: 5),
            .init(text: "Call your mum and tell her something embarrassing about tonight.", level: 5),
            .init(text: "Give the group your phone password and close your eyes for 30 seconds.", level: 5),
            .init(text: "Show the group your full search history from today.", level: 5),
            .init(text: "Send a voice memo to your last hookup saying 'I miss the way you...' - group finishes the sentence.", level: 5),
            .init(text: "Reveal every lie you've told tonight.", level: 5),
        ],
    ]

    private func daresForRung(_ rung: Int) -> [String] {
        guard rung < Self.ladder.count else { return [] }
        return Self.ladder[rung].upTo(store.data.preferences.spiciness)
    }

    private var activePlayers: [String] {
        players.filter { !eliminated.contains($0) }
    }

    var body: some View {
        GameChrome {
            VStack(alignment: .leading, spacing: 20) {
                switch phase {
                case .setup: setupView
                case .dare: dareView
                case .result: resultView
                }
            }
        }
        .onAppear(perform: hydrateFromRoom)
    }

    // MARK: Setup

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dare Ladder")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("5 rungs of escalating dares. Each round, everyone faces a dare. Chicken out? Drink double and you're eliminated. Last one standing wins.")
                .font(.callout).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            // Show the 5 rungs
            HStack(spacing: 4) {
                ForEach(0..<5) { i in
                    VStack(spacing: 2) {
                        Text(["😊", "😬", "😰", "🥵", "💀"][i])
                        Text("Rung \(i+1)").font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(Double(i+1) * 0.15)))
                }
            }

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
                            Button { players.remove(at: i) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.9)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                    }
                }
            }

            BigActionButton(title: "Start the ladder") {
                currentRung = 0
                currentPlayerIndex = 0
                eliminated.removeAll()
                drawDare()
                phase = .dare
            }
            .disabled(players.count < 2)
            .opacity(players.count < 2 ? 0.5 : 1)
        }
    }

    // MARK: Dare

    private var dareView: some View {
        let player = activePlayers.isEmpty ? "???" : activePlayers[currentPlayerIndex % activePlayers.count]
        let rungEmoji = ["😊", "😬", "😰", "🥵", "💀"]
        let rungName = ["Easy", "Warm", "Spicy", "Intense", "Final Boss"]

        return VStack(spacing: 16) {
            // Rung indicator
            HStack(spacing: 4) {
                ForEach(0..<5) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i <= currentRung ? Theme.accent : Theme.hairline)
                        .frame(height: 6)
                }
            }

            HStack {
                Text("\(rungEmoji[min(currentRung, 4)]) Rung \(currentRung + 1): \(rungName[min(currentRung, 4)])")
                    .font(.headline).foregroundStyle(Theme.accentDeep)
                Spacer()
                Text("\(activePlayers.count) left").font(.caption).foregroundStyle(Theme.inkSoft)
            }

            HStack(spacing: 8) {
                Text(Avatars.avatar(for: player)).font(.system(size: 40))
                Text(player).font(.title2.weight(.heavy)).foregroundStyle(Theme.ink)
            }

            Text(currentDare)
                .font(.title3.weight(.heavy)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent.opacity(0.18)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.45), lineWidth: 1))

            HStack(spacing: 12) {
                Button {
                    hapticTap()
                    // Chicken out = eliminated
                    eliminated.insert(player)
                    advancePlayer()
                } label: {
                    VStack(spacing: 2) {
                        Text("Chicken out 🐔")
                        Text("Drink double").font(.caption2)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.bordered).tint(Theme.danger)

                Button {
                    hapticTap()
                    advancePlayer()
                } label: {
                    VStack(spacing: 2) {
                        Text("Did it! ✓")
                        Text("Move on").font(.caption2)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent).tint(Theme.success)
            }

            if !eliminated.isEmpty {
                Text("Eliminated: \(eliminated.sorted().joined(separator: ", "))")
                    .font(.caption).foregroundStyle(Theme.danger)
            }
        }
    }

    // MARK: Result

    private var resultView: some View {
        VStack(spacing: 14) {
            if activePlayers.count == 1 {
                Text("👑").font(.system(size: 72))
                Text("\(activePlayers[0]) WINS!")
                    .font(.title.weight(.black)).foregroundStyle(Theme.accentDeep)
                Text("Survived all \(currentRung + 1) rungs of the ladder.")
                    .font(.callout).foregroundStyle(Theme.inkSoft)
            } else if activePlayers.isEmpty {
                Text("💀").font(.system(size: 72))
                Text("Everyone chickened out!")
                    .font(.title.weight(.heavy)).foregroundStyle(Theme.ink)
                Text("No survivors. Everyone drinks.")
                    .font(.callout).foregroundStyle(Theme.danger)
            } else {
                Text("🏆").font(.system(size: 72))
                Text("Ladder complete!")
                    .font(.title.weight(.heavy)).foregroundStyle(Theme.ink)
                Text("Survivors: \(activePlayers.joined(separator: ", "))")
                    .font(.headline).foregroundStyle(Theme.accentDeep)
            }

            BigActionButton(title: "Play again") {
                phase = .setup
                eliminated.removeAll()
            }
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

    private func drawDare() {
        let rung = min(currentRung, 4)
        let pool = daresForRung(rung)
        var recent = rung < recentDares.count ? recentDares[rung] : []
        currentDare = rotatedPick(from: pool, recent: &recent, windowSize: max(3, pool.count / 3)) ?? "Do something the group decides."
        if rung < recentDares.count { recentDares[rung] = recent }
    }

    private func advancePlayer() {
        // Check end conditions
        if activePlayers.count <= 1 {
            phase = .result
            return
        }

        // Move to next active player
        let nextIndex = (currentPlayerIndex + 1) % activePlayers.count
        if nextIndex <= currentPlayerIndex || nextIndex == 0 {
            // Completed a full round of all active players - advance rung
            if currentRung + 1 >= 5 {
                phase = .result
                return
            }
            currentRung += 1
        }
        currentPlayerIndex = nextIndex % max(1, activePlayers.count)
        drawDare()
    }
}

// MARK: - Shared helpers (private to this file)

/// Wraps content in the standard game chrome (scrollable, themed background).
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
