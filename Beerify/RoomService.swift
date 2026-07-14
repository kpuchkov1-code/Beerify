//
//  RoomService.swift
//  Beerify
//
//  Peer-to-peer room service built on MultipeerConnectivity. Devices in
//  range discover each other over Wi-Fi/Bluetooth and share SquadMember
//  snapshots without any backend. Codes are generated locally.
//

import Foundation
import MultipeerConnectivity
import Observation

@Observable
final class RoomService: NSObject {

    static let shared = RoomService()

    // MARK: - Observed state

    private(set) var state: RoomState? = nil
    private(set) var isActive: Bool = false
    private(set) var errorMessage: String? = nil
    /// Bumps every time we receive a cheers from another peer, along with the
    /// sender's name so the UI can show a burst.
    private(set) var lastCheers: (id: Int, name: String)? = nil
    /// Squad leaderboard keyed by "<gameId>-<memberId>". Reads flow through
    /// SwiftUI observation so leaderboard views live-update.
    private(set) var scoreboard: [String: GameScoreEntry] = [:]
    /// The currently active Ranked round, mirrored across all peers.
    private(set) var rankedRound: RankedRoundState? = nil

    /// Exposed so views can compare against `rankedRound.pickerId`.
    var currentMemberId: String? { memberId }

    // MARK: - Constants

    // MC serviceType: <= 15 chars, lowercase / digits / hyphens.
    private static let serviceType = "beerify-room"
    // Confusable characters (0/O, 1/I) removed for legibility when sharing.
    private static let codeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private static let codeLength = 4

    // MARK: - Private (not observed)

    @ObservationIgnored private var peerID: MCPeerID?
    @ObservationIgnored private var session: MCSession?
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    @ObservationIgnored private var code: String?
    @ObservationIgnored private var memberId: String?
    @ObservationIgnored private var createdAt: Date = Date()
    @ObservationIgnored private var members: [String: SquadMember] = [:]
    @ObservationIgnored private var cloudKit: CloudKitRoomChannel?

    // MARK: - Public API

    /// Locally-generated 4-character room code, safe to share verbally.
    static func newCode() -> String {
        String((0..<codeLength).map { _ in codeAlphabet.randomElement()! })
    }

    /// Bring the service up under `code` with the given local `snapshot`.
    /// Both hosts and joiners call this — the mesh has no distinction after
    /// the initial handshake.
    @MainActor
    func activate(code rawCode: String, memberId: String, snapshot: SquadMember) {
        let code = rawCode.uppercased()
        // If we're already active on this exact code, just refresh our snapshot.
        if isActive, self.code == code, self.memberId == memberId {
            update(snapshot: snapshot)
            return
        }
        teardown()
        self.code = code
        self.memberId = memberId
        self.createdAt = Date()
        self.members = [memberId: snapshot]
        self.errorMessage = nil
        publishState()
        startup()
        activateCloudKit(code: code, snapshot: snapshot)
    }

    /// Replace the local member's snapshot and broadcast the change.
    @MainActor
    func update(snapshot: SquadMember) {
        guard let memberId else { return }
        members[memberId] = snapshot
        publishState()
        broadcast(.member(snapshot))
        if let code, let channel = cloudKit {
            Task { @MainActor in await channel.upsert(snapshot: snapshot, code: code) }
        }
    }

    /// Leave the room and stop advertising/browsing.
    @MainActor
    func leave() {
        if let memberId {
            broadcast(.leave(memberId: memberId))
        }
        if let code, let memberId, let channel = cloudKit {
            Task { @MainActor in await channel.leave(memberId: memberId, code: code) }
        }
        cloudKit = nil
        teardown()
        code = nil
        memberId = nil
        members.removeAll()
        state = nil
        isActive = false
        errorMessage = nil
    }

    /// Silent-push forwarder for AppDelegate.
    @MainActor
    func handleRemotePush() async {
        await cloudKit?.handlePush()
    }

    /// Broadcast a "cheers!" burst to everyone in the local mesh.
    @MainActor
    func sendCheers(fromName: String) {
        broadcast(.cheers(fromName: fromName))
        // Also show it locally.
        bumpCheers(name: fromName)
    }

    @MainActor
    private func bumpCheers(name: String) {
        let nextId = (lastCheers?.id ?? 0) + 1
        lastCheers = (nextId, name)
    }

    // MARK: - Ranked (multi-device)

    @MainActor
    func rankedStart(spiciness: Int) -> String? {
        guard let memberId else { return nil }
        let name = members[memberId]?.name ?? "You"
        let roundId = IDGen.new()
        let round = RankedRoundState(
            roundId: roundId, pickerId: memberId, pickerName: name,
            spiciness: spiciness
        )
        rankedRound = round
        broadcast(.rankedStart(roundId: roundId, pickerId: memberId, pickerName: name, spiciness: spiciness))
        return roundId
    }

    @MainActor
    func rankedSubmitRanking(_ ranking: [String]) {
        guard var round = rankedRound else { return }
        round.ranking = ranking
        rankedRound = round
        broadcast(.rankedRanking(roundId: round.roundId, ranking: ranking))
    }

    @MainActor
    func rankedSubmitShortlist(_ shortlist: [Int]) {
        guard var round = rankedRound else { return }
        round.shortlist = shortlist
        rankedRound = round
        broadcast(.rankedShortlist(roundId: round.roundId, shortlist: shortlist))
    }

    @MainActor
    func rankedSubmitGuess(_ guessedIdx: Int) {
        guard let memberId, var round = rankedRound else { return }
        round.guesses[memberId] = guessedIdx
        rankedRound = round
        broadcast(.rankedGuess(roundId: round.roundId, guesserId: memberId, guessedIdx: guessedIdx))
    }

    @MainActor
    func rankedReveal(_ questionIdx: Int) {
        guard var round = rankedRound else { return }
        round.revealedQuestionIdx = questionIdx
        rankedRound = round
        broadcast(.rankedReveal(roundId: round.roundId, questionIdx: questionIdx))
        // The picker doesn't guess, so no self-score. Other devices settle their
        // own scores in the message handler below.
    }

    @MainActor
    func rankedCancel() {
        guard let round = rankedRound else { return }
        rankedRound = nil
        broadcast(.rankedCancel(roundId: round.roundId))
    }

    // MARK: - Scores

    /// Report a game score. Keeps only your best per game and broadcasts it
    /// to the mesh. Silently no-ops when you're not in a room.
    @MainActor
    func reportScore(gameId: String, score: Int) {
        guard let memberId else { return }
        let name = members[memberId]?.name ?? "You"
        let key = "\(gameId)-\(memberId)"
        if let existing = scoreboard[key], existing.score >= score { return }
        let entry = GameScoreEntry(
            gameId: gameId, memberId: memberId, memberName: name,
            score: score, updatedAt: Date()
        )
        scoreboard[key] = entry
        broadcast(.score(entry))
    }

    @MainActor
    private func mergeScore(_ entry: GameScoreEntry) {
        let key = "\(entry.gameId)-\(entry.memberId)"
        if let existing = scoreboard[key], existing.score >= entry.score { return }
        scoreboard[key] = entry
    }

    /// Build a "resting" snapshot for a user idling on Home.
    static func restingSnapshot(memberId: String, profile: Profile) -> SquadMember {
        SquadMember(
            id: memberId,
            name: profile.name,
            bac: 0, units: 0, drinks: 0,
            targetId: .tipsy,
            status: "sober",
            inSession: false,
            updatedAt: Date()
        )
    }

    // MARK: - Setup / teardown

    private func startup() {
        guard let code, let memberId else { return }
        let name = members[memberId]?.name ?? "Beerify"
        // Embed memberId in displayName so peers can associate an MCPeerID
        // with a SquadMember without an extra handshake message.
        let display = "\(name.prefix(20))|\(memberId)"
        let peer = MCPeerID(displayName: String(display.prefix(63)))
        self.peerID = peer

        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        let adv = MCNearbyServiceAdvertiser(
            peer: peer,
            discoveryInfo: ["code": code],
            serviceType: Self.serviceType
        )
        adv.delegate = self
        adv.startAdvertisingPeer()
        self.advertiser = adv

        let br = MCNearbyServiceBrowser(peer: peer, serviceType: Self.serviceType)
        br.delegate = self
        br.startBrowsingForPeers()
        self.browser = br

        isActive = true
    }

    private func teardown() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser?.delegate = nil
        browser?.delegate = nil
        session?.delegate = nil
        advertiser = nil
        browser = nil
        session = nil
        peerID = nil
        isActive = false
    }

    // MARK: - Messaging

    private func broadcast(_ msg: RoomMessage) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        send(msg, to: session.connectedPeers)
    }

    private func send(_ msg: RoomMessage, to peers: [MCPeerID]) {
        guard let session, !peers.isEmpty else { return }
        do {
            let data = try Self.encoder.encode(msg)
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            // Non-fatal — future updates will retry.
        }
    }

    private func publishState() {
        guard let code else { state = nil; return }
        state = RoomState(
            code: code,
            createdAt: createdAt,
            members: Array(members.values)
        )
    }

    @MainActor
    private func activateCloudKit(code: String, snapshot: SquadMember) {
        let channel = CloudKitRoomChannel()
        channel.onMemberReceived = { [weak self] m in self?.mergeRemote(m) }
        channel.onError = { [weak self] msg in self?.errorMessage = msg }
        self.cloudKit = channel
        Task { @MainActor in
            await channel.activate(code: code)
            await channel.upsert(snapshot: snapshot, code: code)
        }
    }

    @MainActor
    private func mergeRemote(_ m: SquadMember) {
        // Don't clobber our own local snapshot with a stale echo of ourselves.
        if m.id == memberId { return }
        let existing = members[m.id]
        if existing == nil || existing!.updatedAt <= m.updatedAt {
            members[m.id] = m
            publishState()
        }
    }

    @MainActor
    fileprivate func handle(_ msg: RoomMessage) {
        switch msg {
        case .member(let m):
            let existing = members[m.id]
            if existing == nil || existing!.updatedAt <= m.updatedAt {
                members[m.id] = m
            }
        case .sync(let list):
            for m in list {
                let existing = members[m.id]
                if existing == nil || existing!.updatedAt <= m.updatedAt {
                    members[m.id] = m
                }
            }
        case .leave(let id):
            if id != memberId { members.removeValue(forKey: id) }
        case .cheers(let fromName):
            bumpCheers(name: fromName)
        case .score(let entry):
            mergeScore(entry)
        case .scoreSync(let list):
            for e in list { mergeScore(e) }
        case .rankedStart(let roundId, let pickerId, let pickerName, let spiciness):
            rankedRound = RankedRoundState(
                roundId: roundId, pickerId: pickerId, pickerName: pickerName,
                spiciness: spiciness
            )
        case .rankedRanking(let roundId, let ranking):
            if var round = rankedRound, round.roundId == roundId {
                round.ranking = ranking
                rankedRound = round
            }
        case .rankedShortlist(let roundId, let shortlist):
            if var round = rankedRound, round.roundId == roundId {
                round.shortlist = shortlist
                rankedRound = round
            }
        case .rankedGuess(let roundId, let guesserId, let guessedIdx):
            if var round = rankedRound, round.roundId == roundId {
                round.guesses[guesserId] = guessedIdx
                rankedRound = round
            }
        case .rankedReveal(let roundId, let questionIdx):
            if var round = rankedRound, round.roundId == roundId {
                round.revealedQuestionIdx = questionIdx
                rankedRound = round
                // If I'm a guesser (not the picker) and I got it right, add a
                // point to my ranked total.
                if let me = memberId,
                   round.pickerId != me,
                   round.guesses[me] == questionIdx {
                    let key = "ranked-\(me)"
                    let current = scoreboard[key]?.score ?? 0
                    reportScore(gameId: "ranked", score: current + 1)
                }
            }
        case .rankedCancel(let roundId):
            if rankedRound?.roundId == roundId { rankedRound = nil }
        case .rankedStateSync(let round):
            rankedRound = round
        }
        publishState()
    }

    @MainActor
    fileprivate func onPeerConnected(_ peer: MCPeerID) {
        let all = Array(members.values)
        send(.sync(all), to: [peer])
        let scores = Array(scoreboard.values)
        if !scores.isEmpty { send(.scoreSync(scores), to: [peer]) }
        // Bring newly-connected peers up to date on any active Ranked round.
        if rankedRound != nil { send(.rankedStateSync(rankedRound), to: [peer]) }
    }

    // MARK: - Codec

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .millisecondsSince1970
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .millisecondsSince1970
        return d
    }()
}

// MARK: - Wire format

enum RoomMessage: Codable {
    case member(SquadMember)
    case sync([SquadMember])
    case leave(memberId: String)
    case cheers(fromName: String)
    case score(GameScoreEntry)
    case scoreSync([GameScoreEntry])
    // Ranked multi-device round messages
    case rankedStart(roundId: String, pickerId: String, pickerName: String, spiciness: Int)
    case rankedRanking(roundId: String, ranking: [String])
    case rankedShortlist(roundId: String, shortlist: [Int])
    case rankedGuess(roundId: String, guesserId: String, guessedIdx: Int)
    case rankedReveal(roundId: String, questionIdx: Int)
    case rankedCancel(roundId: String)
    /// Full round dump used to bring newly-joined peers up to date.
    case rankedStateSync(RankedRoundState?)
}

// MARK: - MCSessionDelegate

extension RoomService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        guard state == .connected else { return }
        Task { @MainActor [weak self] in self?.onPeerConnected(peerID) }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let msg = try? Self.decoder.decode(RoomMessage.self, from: data) else { return }
        Task { @MainActor [weak self] in self?.handle(msg) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension RoomService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        guard let session,
              let code,
              let ctx = context,
              String(data: ctx, encoding: .utf8) == code else {
            invitationHandler(false, nil)
            return
        }
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor [weak self] in
            self?.errorMessage = "Local network access is off — enable it in Settings to use rooms."
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension RoomService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        // Only pair with peers advertising the same room code.
        guard let info,
              let code,
              info["code"] == code,
              let session,
              let ourPeer = self.peerID else { return }
        // Only the peer with the lexicographically smaller displayName sends
        // the invite; the other accepts. Prevents crossed invitations.
        guard ourPeer.displayName < peerID.displayName else { return }
        if session.connectedPeers.contains(peerID) { return }
        browser.invitePeer(peerID, to: session, withContext: code.data(using: .utf8), timeout: 15)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor [weak self] in
            self?.errorMessage = "Can't discover friends on this network right now."
        }
    }
}

// MARK: - Avatar mapping

enum Avatars {
    private static let all = ["🦊", "🐻", "🐼", "🦁", "🐨", "🐵", "🦄", "🐙", "🦖", "🐳", "🐹", "🐸"]

    static func avatar(for id: String) -> String {
        var hash: Int32 = 0
        for ch in id.unicodeScalars {
            hash = (hash &* 31) &+ Int32(ch.value)
        }
        return all[abs(Int(hash)) % all.count]
    }
}
