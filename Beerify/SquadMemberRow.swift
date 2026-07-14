//
//  SquadMemberRow.swift
//  Beerify
//

import SwiftUI

private let STATUS_LABEL: [String: String] = [
    "sober": "Sober",
    "warming": "Warming up",
    "in-zone": "In the zone",
    "over": "Over the zone",
    "way-over": "Needs water!",
]

struct SquadMemberRow: View {
    let member: SquadMember
    let isSelf: Bool

    var body: some View {
        let target = TargetsCatalog.target(member.targetId)
        let stale = Date().timeIntervalSince(member.updatedAt) > 10 * 60
        let resting = !member.inSession || stale
        let fillPct = min(member.bac / 0.14, 1)

        HStack(spacing: 12) {
            Text(Avatars.avatar(for: member.id)).font(.system(size: 30))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(member.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    if isSelf {
                        Text("(you)").font(.caption).foregroundStyle(Theme.inkSoft)
                    }
                }
                Text(detailText(resting: resting))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }

            Spacer()

            if !resting {
                HStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Theme.inkSoft.opacity(0.5), lineWidth: 1)
                            .frame(width: 16, height: 26)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(
                                colors: [Theme.accent, Theme.accentDeep],
                                startPoint: .top, endPoint: .bottom))
                            .frame(width: 12, height: max(3, CGFloat(fillPct) * 24))
                            .padding(1)
                    }
                    Text(target.emoji).font(.caption)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            (member.status == "way-over" && !resting)
                ? Theme.danger.opacity(0.12)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func detailText(resting: Bool) -> String {
        if resting {
            return "Resting · \(Fmt.timeAgo(from: member.updatedAt))"
        } else {
            let label = STATUS_LABEL[member.status] ?? "Out"
            let plural = member.drinks == 1 ? "" : "s"
            return "\(label) · \(member.drinks) drink\(plural) · \(Fmt.units(member.units)) units"
        }
    }
}
