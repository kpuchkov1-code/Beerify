//
//  RoomPanelView.swift
//  Beerify
//
//  Home-screen room panel: create / join / share / squad list.
//  Backed by a local MultipeerConnectivity mesh — no server required.
//

import SwiftUI

struct RoomPanelView: View {
    let profile: Profile
    let membership: RoomMembership?
    let onJoin: (RoomMembership) -> Void
    let onLeave: () -> Void

    @Environment(RoomService.self) private var roomService

    @State private var joinCode: String = ""
    @State private var busy: Bool = false
    @State private var localError: String? = nil

    var body: some View {
        Group {
            if let membership {
                joined(membership: membership)
            } else {
                notJoined
            }
        }
        .onAppear { resumeIfNeeded() }
        .onChange(of: membership?.code) { _, _ in resumeIfNeeded() }
    }

    // MARK: - Not in a room

    private var notJoined: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drink with friends")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 12) {
                Text("👯 Make a room, share the code, and keep an eye on each other's mugs all night.")
                    .foregroundStyle(Theme.inkSoft)

                Button {
                    createRoom()
                } label: {
                    Text(busy ? "Creating…" : "Create a room")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(busy)

                HStack {
                    TextField("CODE", text: $joinCode)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .textFieldStyle(BeerifyFieldStyle())
                    #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.characters)
                    #endif
                        .autocorrectionDisabled()
                        .onChange(of: joinCode) { _, new in
                            joinCode = String(new.uppercased().prefix(4))
                        }
                    Button("Join") {
                        joinExisting()
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accentDeep)
                    .disabled(busy || joinCode.count != 4)
                }

                if let msg = displayedError {
                    Text(msg).font(.caption).foregroundStyle(Theme.danger)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.9)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
        }
    }

    // MARK: - Joined a room

    private func joined(membership: RoomMembership) -> some View {
        let members = roomService.state?.members ?? []
        return VStack(alignment: .leading, spacing: 12) {
            Text("Your room").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(membership.code)
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .tracking(4)
                            .foregroundStyle(Theme.accentDeep)
                        Text("share this code")
                            .font(.caption).foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                    ShareLink(item: "Join my Beerify room tonight! Code: \(membership.code)") {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accentDeep)
                }

                if !members.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(members) { m in
                            SquadMemberRow(member: m, isSelf: m.id == membership.memberId)
                        }
                    }
                }
                if members.count <= 1 {
                    Text("Just you so far. Send the code to your crew!")
                        .font(.caption).foregroundStyle(Theme.inkSoft)
                }
                if let msg = displayedError {
                    Text(msg).font(.caption).foregroundStyle(Theme.danger)
                }

                Button(role: .destructive) {
                    handleLeave()
                } label: {
                    Text("Leave room").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.danger)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.9)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
        }
    }

    // MARK: - Actions

    private func createRoom() {
        busy = true
        localError = nil
        defer { busy = false }

        let code = RoomService.newCode()
        let memberId = IDGen.new()
        let snapshot = RoomService.restingSnapshot(memberId: memberId, profile: profile)
        roomService.activate(code: code, memberId: memberId, snapshot: snapshot)
        onJoin(RoomMembership(code: code, memberId: memberId))
    }

    private func joinExisting() {
        busy = true
        localError = nil
        defer { busy = false }

        let code = joinCode.trimmingCharacters(in: .whitespaces).uppercased()
        guard code.count == 4 else {
            localError = "Room codes are 4 characters"
            return
        }
        let memberId = IDGen.new()
        let snapshot = RoomService.restingSnapshot(memberId: memberId, profile: profile)
        roomService.activate(code: code, memberId: memberId, snapshot: snapshot)
        onJoin(RoomMembership(code: code, memberId: memberId))
        joinCode = ""
    }

    private func handleLeave() {
        roomService.leave()
        onLeave()
    }

    /// Re-activate the mesh when the view appears with a persisted membership
    /// (e.g. after cold launch) or when the code changes underneath us.
    private func resumeIfNeeded() {
        guard let membership else { return }
        if roomService.isActive, roomService.state?.code == membership.code { return }
        let snapshot = RoomService.restingSnapshot(memberId: membership.memberId, profile: profile)
        roomService.activate(code: membership.code, memberId: membership.memberId, snapshot: snapshot)
    }

    private var displayedError: String? {
        localError ?? roomService.errorMessage
    }
}
