//
//  PartyViews.swift
//  AI GM
//
//  隊伍列的玩家頭像與角色卡。
//

import SwiftUI

/// 圓形頭像：取名字第一個字，已確認行動時外圈亮起。
struct PlayerToken: View {
    let name: String
    let isReady: Bool
    var isDown: Bool = false
    var size: CGFloat = 32

    private var initial: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
    }

    var body: some View {
        Text(initial)
            .serifFont(.quote)
            .foregroundStyle(Palette.vellum)
            .frame(width: size, height: size)
            .background(Palette.feltRaised, in: Circle())
            .overlay(
                Circle().strokeBorder(isReady ? Palette.moss : Palette.sageDim.opacity(0.6), lineWidth: isReady ? 2 : 1)
            )
            .overlay(Circle().stroke(Palette.feltDeep, lineWidth: 2))
            .opacity(isDown ? 0.45 : 1)
            .accessibilityLabel("\(name)，\(isDown ? "已倒下" : isReady ? "已確認" : "等待確認")")
    }
}

struct HPBar: View {
    let hp: Int
    let maxHP: Int

    private var ratio: CGFloat {
        guard maxHP > 0 else { return 0 }
        return CGFloat(hp) / CGFloat(maxHP)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("HP")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Palette.sage)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.feltSunken)
                    Capsule()
                        .fill(Palette.wax)
                        .frame(width: proxy.size.width * ratio)
                }
            }
            .frame(height: 6)

            Text("\(hp)/\(maxHP)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Palette.vellum)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("HP \(hp) / \(maxHP)")
    }
}

/// 展開隊伍面板時的一列角色資料
struct PlayerSheetRow: View {
    let player: Player
    let isHost: Bool
    let confirmedAction: CampaignAction?
    var showsActionStatus: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PlayerToken(name: player.name, isReady: confirmedAction != nil, isDown: player.isDown, size: 38)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(player.name)
                        .font(.headline)
                        .foregroundStyle(Palette.vellum)
                        .lineLimit(1)

                    if isHost {
                        Text("房主")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Palette.vellum)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Palette.wax, in: Capsule())
                    }

                    if player.isDown {
                        headerChip(title: "倒下", color: Palette.ember)
                    }

                    Spacer(minLength: 4)

                    if showsActionStatus {
                        Label(confirmedAction == nil ? "等待確認" : "已確認",
                              systemImage: confirmedAction == nil ? "hourglass" : "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(confirmedAction == nil ? Palette.sage : Palette.moss)
                    }
                }

                HPBar(hp: player.hp, maxHP: player.maxHP)

                HStack(spacing: 16) {
                    stat("STR", player.strength)
                    stat("DEX", player.dexterity)
                    stat("INT", player.intelligence)
                }

                if let confirmedAction {
                    Text("「\(confirmedAction.text)」")
                        .serifFont(.quote)
                        .foregroundStyle(Palette.vellum.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(Palette.feltRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Palette.sage)
            Text("\(value)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Palette.vellum)
        }
    }
}
