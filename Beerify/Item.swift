//
//  Models.swift  (was Item.swift)
//  Beerify
//
//  Domain model types. Codable so the whole app state can be persisted to
//  UserDefaults in one blob, mirroring the web app's localStorage approach.
//

import Foundation

enum Sex: String, Codable, CaseIterable, Sendable {
    case female, male, other
}

enum Tolerance: String, Codable, CaseIterable, Sendable {
    case rare, monthly, weekly, frequent
}

struct Profile: Codable, Equatable, Sendable {
    var name: String
    var weightKg: Double
    var sex: Sex
    var tolerance: Tolerance
    var createdAt: Date
    var emoji: String?
    var profileImageData: Data?

    enum CodingKeys: String, CodingKey {
        case name, weightKg, sex, tolerance, createdAt, emoji, profileImageData
    }

    init(name: String, weightKg: Double, sex: Sex, tolerance: Tolerance, createdAt: Date, emoji: String? = nil, profileImageData: Data? = nil) {
        self.name = name
        self.weightKg = weightKg
        self.sex = sex
        self.tolerance = tolerance
        self.createdAt = createdAt
        self.emoji = emoji
        self.profileImageData = profileImageData
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        weightKg = try c.decode(Double.self, forKey: .weightKg)
        sex = try c.decode(Sex.self, forKey: .sex)
        tolerance = try c.decode(Tolerance.self, forKey: .tolerance)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        emoji = try? c.decode(String.self, forKey: .emoji)
        profileImageData = try? c.decode(Data.self, forKey: .profileImageData)
    }
}

enum DrinkTypeId: String, Codable, CaseIterable, Sendable {
    case beer, shot, wine, cocktail
}

struct DrinkType: Identifiable, Sendable {
    let id: DrinkTypeId
    let label: String
    let emoji: String
    let volumeMl: Double
    let abv: Double
    let absorptionMin: Double
    let detail: String
}

struct LoggedDrink: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let type: DrinkTypeId
    let at: Date
    let units: Double
    let grams: Double
    /// Optional variant id for display purposes; nil for legacy entries.
    var variantId: String?
}

struct DrinkVariant: Identifiable, Sendable {
    let id: String
    let label: String
    let emoji: String
    let baseType: DrinkTypeId
    var customVolumeMl: Double? = nil
    var customAbv: Double? = nil
    var customDetail: String? = nil
}

enum TargetId: String, Codable, CaseIterable, Sendable {
    case glow, buzz, tipsy, merry, bignight
}

struct Target: Identifiable, Sendable {
    let id: TargetId
    let label: String
    let emoji: String
    let tagline: String
    let minBac: Double
    let maxBac: Double
    let warning: String?
}

struct NightSession: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let startedAt: Date
    var targetId: TargetId
    var drinks: [LoggedDrink]
    var waters: [Date]
    var endedAt: Date?
    var reviewedAt: Date?
}

struct RoomMembership: Codable, Equatable, Sendable {
    let code: String
    let memberId: String
}

struct SquadMember: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let bac: Double
    let units: Double
    let drinks: Int
    let targetId: TargetId
    let status: String
    let inSession: Bool
    let updatedAt: Date
}

struct RoomState: Codable, Equatable, Sendable {
    let code: String
    let createdAt: Date
    let members: [SquadMember]
}

/// A single entry on the squad leaderboard for a given game. Broadcast over
/// the room mesh so everyone sees each other's high scores in real time.
struct GameScoreEntry: Codable, Equatable, Sendable, Identifiable {
    let gameId: String
    let memberId: String
    let memberName: String
    let score: Int
    let updatedAt: Date

    var id: String { "\(gameId)-\(memberId)" }
}

struct AppData: Codable, Equatable, Sendable {
    var profile: Profile?
    var session: NightSession?
    var history: [NightSession]
    var room: RoomMembership?
    var preferences: UserPreferences
    var unlockedBadges: Set<String>

    static let empty = AppData(
        profile: nil, session: nil, history: [], room: nil,
        preferences: .init(), unlockedBadges: []
    )

    // Custom decode so old on-disk payloads (before preferences/badges existed)
    // still hydrate cleanly.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.profile = try c.decodeIfPresent(Profile.self, forKey: .profile)
        self.session = try c.decodeIfPresent(NightSession.self, forKey: .session)
        self.history = (try? c.decode([NightSession].self, forKey: .history)) ?? []
        self.room = try c.decodeIfPresent(RoomMembership.self, forKey: .room)
        self.preferences = (try? c.decode(UserPreferences.self, forKey: .preferences)) ?? .init()
        self.unlockedBadges = (try? c.decode(Set<String>.self, forKey: .unlockedBadges)) ?? []
    }

    init(profile: Profile?, session: NightSession?, history: [NightSession],
         room: RoomMembership?, preferences: UserPreferences, unlockedBadges: Set<String>) {
        self.profile = profile
        self.session = session
        self.history = history
        self.room = room
        self.preferences = preferences
        self.unlockedBadges = unlockedBadges
    }
}

enum CoachPersonality: String, Codable, CaseIterable, Sendable {
    case friend, elder, gremlin
    var label: String {
        switch self {
        case .friend: return "Cool friend"
        case .elder: return "Wise elder"
        case .gremlin: return "Party gremlin"
        }
    }
    var emoji: String {
        switch self {
        case .friend: return "🤗"
        case .elder: return "🧙"
        case .gremlin: return "👺"
        }
    }
}

enum ThemedNight: String, Codable, CaseIterable, Sendable {
    case standard, halloween, nye, birthday, stpatrick
    var label: String {
        switch self {
        case .standard: return "Classic"
        case .halloween: return "Halloween"
        case .nye: return "New Year's Eve"
        case .birthday: return "Birthday"
        case .stpatrick: return "St. Patrick's"
        }
    }
    var emoji: String {
        switch self {
        case .standard: return "🍺"
        case .halloween: return "🎃"
        case .nye: return "🎆"
        case .birthday: return "🎂"
        case .stpatrick: return "🍀"
        }
    }
}

struct UserPreferences: Codable, Equatable, Sendable {
    var coachPersonality: CoachPersonality = .friend
    var themedNight: ThemedNight = .standard
    var bigThumbMode: Bool = false
    var soberMode: Bool = false
    var ddMode: Bool = false
    var rideHomeURL: String = "https://m.uber.com/"
    /// Home address for pre-filling ride app destination.
    var homeAddress: String = ""
    /// 1 (family-safe) → 5 (unfiltered). Games filter their prompt decks by
    /// this so users pick the vibe.
    var spiciness: Int = 3
    /// Variant IDs the user wants on their night-out tap grid. Empty means use defaults.
    var selectedDrinkVariants: [String] = []

    init() {}

    private enum CodingKeys: String, CodingKey {
        case coachPersonality, themedNight, bigThumbMode, soberMode, ddMode, rideHomeURL, homeAddress, spiciness, selectedDrinkVariants
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.coachPersonality = (try? c.decode(CoachPersonality.self, forKey: .coachPersonality)) ?? .friend
        self.themedNight = (try? c.decode(ThemedNight.self, forKey: .themedNight)) ?? .standard
        self.bigThumbMode = (try? c.decode(Bool.self, forKey: .bigThumbMode)) ?? false
        self.soberMode = (try? c.decode(Bool.self, forKey: .soberMode)) ?? false
        self.ddMode = (try? c.decode(Bool.self, forKey: .ddMode)) ?? false
        self.rideHomeURL = (try? c.decode(String.self, forKey: .rideHomeURL)) ?? "https://m.uber.com/"
        self.homeAddress = (try? c.decode(String.self, forKey: .homeAddress)) ?? ""
        self.spiciness = (try? c.decode(Int.self, forKey: .spiciness)) ?? 3
        self.selectedDrinkVariants = (try? c.decode([String].self, forKey: .selectedDrinkVariants)) ?? []
    }
}

/// Ranked round state, mirrored across every device in the room. Codable so
/// it can flow through the peer mesh.
struct RankedRoundState: Codable, Equatable, Sendable {
    let roundId: String
    let pickerId: String
    let pickerName: String
    /// Spiciness filter applied to the question deck for this round. Fixed
    /// at round start so every device sees the same filtered list.
    let spiciness: Int
    /// Ranked memberIds, top → bottom. Empty until the picker submits.
    var ranking: [String]
    /// guesserMemberId → their chosen question index inside the filtered deck.
    var guesses: [String: Int]
    /// Set once the picker reveals; index into the filtered deck.
    var revealedQuestionIdx: Int?
    /// Ten question indices (in the filtered deck) shown to guessers. Contains
    /// the picker's actual question - but nobody knows which until the reveal.
    var shortlist: [Int]?

    init(roundId: String, pickerId: String, pickerName: String, spiciness: Int,
         ranking: [String] = [], guesses: [String: Int] = [:],
         revealedQuestionIdx: Int? = nil, shortlist: [Int]? = nil) {
        self.roundId = roundId
        self.pickerId = pickerId
        self.pickerName = pickerName
        self.spiciness = spiciness
        self.ranking = ranking
        self.guesses = guesses
        self.revealedQuestionIdx = revealedQuestionIdx
        self.shortlist = shortlist
    }
}

enum CoachTone: String, Sendable {
    case cheer, chill, nudge, warn
}

struct CoachMessage: Sendable {
    let tone: CoachTone
    let text: String
    let tip: String?
}

enum ZoneStatus: String, Sendable {
    case sober
    case warming
    case inZone = "in-zone"
    case over
    case wayOver = "way-over"
}

// MARK: - Pub Golf (shared over room mesh)

/// A single hole on the pub golf course, Codable for mesh sharing.
struct SharedPubGolfHole: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let pubName: String
    let latitude: Double
    let longitude: Double
    let drink: String
    let par: Int
}

/// One member's progress through the pub golf course.
struct PubGolfMemberProgress: Codable, Equatable, Sendable {
    let memberId: String
    let memberName: String
    /// holeId -> number of sips (strokes)
    var scores: [String: Int]
    /// Index of the hole the member is currently on.
    var currentHoleIndex: Int
}

/// Full pub golf game state, synced across all devices in the room.
struct PubGolfGameState: Codable, Equatable, Sendable {
    let gameId: String
    let holes: [SharedPubGolfHole]
    /// memberId -> their progress
    var progress: [String: PubGolfMemberProgress]
}

/// Random id in the same shape the web app produces, so historical data
/// exports could theoretically round-trip.
enum IDGen {
    static func new() -> String {
        let random = String(Int.random(in: 0..<Int(pow(36.0, 8.0))), radix: 36)
        let ts = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
        return random + ts
    }
}
