//
//  CloudKitRoomChannel.swift
//  Beerify
//
//  Remote transport for rooms, backed by CloudKit's public database. Layered
//  alongside the MultipeerConnectivity mesh so remote friends stay in sync
//  even when they're not physically nearby.
//
//  ── One-time Xcode setup ────────────────────────────────────────────────
//  1. Signing & Capabilities → iCloud → enable CloudKit and pick a container
//     identifier (e.g. iCloud.com.yourteam.Beerify). Make sure it also lands
//     in Beerify.entitlements.
//  2. Push Notifications capability must be on (it already is via the APS
//     entitlement).
//  3. On first save the record type `SquadSnapshot` and its fields are
//     auto-created in the CloudKit *development* environment. When you're
//     ready to ship, deploy the schema to Production from CloudKit Dashboard
//     and make sure the `code` field is marked *Queryable*.
//  4. Users must be signed into iCloud on their device.
//

import Foundation
import CloudKit
import os.log

private let ckLog = Logger(subsystem: "com.Beerify", category: "CloudKit")

@MainActor
final class CloudKitRoomChannel {

    // MARK: - Callbacks (invoked on the main actor)

    var onMemberReceived: ((SquadMember) -> Void)?
    var onError: ((String) -> Void)?

    // MARK: - Constants

    static let recordType = "SquadSnapshot"

    // MARK: - State

    private let container: CKContainer
    private let database: CKDatabase
    private(set) var currentCode: String?
    private var subscriptionID: CKSubscription.ID?

    init(container: CKContainer = .default()) {
        self.container = container
        self.database = container.publicCloudDatabase
        ckLog.info("Channel init with container: \(container.containerIdentifier ?? "<none>", privacy: .public)")
    }

    // MARK: - Public API

    /// Start syncing for a room code: fetch existing members and install a
    /// query subscription so future changes stream in as silent pushes.
    func activate(code: String) async {
        currentCode = code
        ckLog.info("activate(code:\(code, privacy: .public))")
        guard await hasICloudAccount() else { return }
        await fetchAll(code: code)
        await installSubscription(code: code)
    }

    /// Save (or overwrite) the member's snapshot for the given code.
    func upsert(snapshot: SquadMember, code: String) async {
        guard await hasICloudAccount() else { return }
        let recordID = CKRecord.ID(recordName: recordName(code: code, memberId: snapshot.id))
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record["code"] = code as NSString
        record["memberId"] = snapshot.id as NSString
        record["name"] = snapshot.name as NSString
        record["bac"] = snapshot.bac as NSNumber
        record["units"] = snapshot.units as NSNumber
        record["drinks"] = snapshot.drinks as NSNumber
        record["targetId"] = snapshot.targetId.rawValue as NSString
        record["status"] = snapshot.status as NSString
        record["inSession"] = (snapshot.inSession ? 1 : 0) as NSNumber
        record["updatedAt"] = snapshot.updatedAt as NSDate

        let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        op.savePolicy = .allKeys
        op.qualityOfService = .userInitiated

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                op.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success: cont.resume(returning: ())
                    case .failure(let err): cont.resume(throwing: err)
                    }
                }
                database.add(op)
            }
            ckLog.info("upserted snapshot \(snapshot.id, privacy: .public) in room \(code, privacy: .public)")
        } catch {
            handle(error: error, context: "sync")
        }
    }

    /// Tear down: delete our own record and unregister the subscription.
    func leave(memberId: String, code: String) async {
        let recordID = CKRecord.ID(recordName: recordName(code: code, memberId: memberId))
        _ = try? await database.deleteRecord(withID: recordID)
        await uninstallSubscription()
        currentCode = nil
    }

    /// Handle a silent push forwarded by AppDelegate — refetch the room.
    func handlePush() async {
        guard let code = currentCode else { return }
        await fetchAll(code: code)
    }

    // MARK: - Internal helpers

    private func recordName(code: String, memberId: String) -> String {
        "\(code)-\(memberId)"
    }

    private func hasICloudAccount() async -> Bool {
        do {
            let status = try await container.accountStatus()
            let ok = status == .available
            if !ok {
                let label: String
                switch status {
                case .noAccount: label = "no iCloud account signed in"
                case .restricted: label = "iCloud is restricted (parental controls?)"
                case .couldNotDetermine: label = "couldn't determine iCloud status"
                case .temporarilyUnavailable: label = "iCloud temporarily unavailable"
                case .available: label = "available"
                @unknown default: label = "unknown iCloud status"
                }
                ckLog.error("iCloud account status: \(label, privacy: .public)")
                onError?("Remote sync off — \(label). Local room still works.")
            }
            return ok
        } catch {
            ckLog.error("accountStatus threw: \(error.localizedDescription, privacy: .public)")
            onError?("Can't reach iCloud: \(error.localizedDescription)")
            return false
        }
    }

    private func fetchAll(code: String) async {
        let predicate = NSPredicate(format: "code == %@", code)
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        do {
            let (matches, _) = try await database.records(matching: query, resultsLimit: 50)
            for (_, result) in matches {
                if case .success(let record) = result,
                   let member = Self.decode(record: record) {
                    onMemberReceived?(member)
                }
            }
        } catch {
            handle(error: error, context: "fetch")
        }
    }

    private func installSubscription(code: String) async {
        let subID = "beerify-room-\(code)"
        _ = try? await database.deleteSubscription(withID: subID)

        let predicate = NSPredicate(format: "code == %@", code)
        let sub = CKQuerySubscription(
            recordType: Self.recordType,
            predicate: predicate,
            subscriptionID: subID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        sub.notificationInfo = info

        do {
            _ = try await database.save(sub)
            subscriptionID = subID
        } catch {
            handle(error: error, context: "push setup")
        }
    }

    private func uninstallSubscription() async {
        guard let subID = subscriptionID else { return }
        _ = try? await database.deleteSubscription(withID: subID)
        subscriptionID = nil
    }

    private func handle(error: Error, context: String) {
        ckLog.error("\(context, privacy: .public) failed: \(error.localizedDescription, privacy: .public) — full: \(String(describing: error), privacy: .public)")
        onError?("\(context): \(error.localizedDescription)")
    }

    private static func decode(record: CKRecord) -> SquadMember? {
        guard let memberId = record["memberId"] as? String,
              let name = record["name"] as? String,
              let targetIdRaw = record["targetId"] as? String,
              let status = record["status"] as? String,
              let updatedAt = record["updatedAt"] as? Date else { return nil }
        let bac = (record["bac"] as? Double) ?? 0
        let units = (record["units"] as? Double) ?? 0
        let drinks = (record["drinks"] as? Int) ?? 0
        let inSessionN = (record["inSession"] as? Int) ?? 0
        let targetId = TargetId(rawValue: targetIdRaw) ?? .tipsy
        return SquadMember(
            id: memberId, name: name, bac: bac, units: units, drinks: drinks,
            targetId: targetId, status: status, inSession: inSessionN != 0,
            updatedAt: updatedAt
        )
    }
}
