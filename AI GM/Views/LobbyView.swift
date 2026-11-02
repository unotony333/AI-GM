//
//  LobbyView.swift
//  AI GM
//
//  Extracted from ContentView.swift
//

import SwiftUI

struct LobbyView: View {
    @ObservedObject var vm: LobbyViewModel
    @ObservedObject var campaign: CampaignService
    @ObservedObject var aiSettings: AISettingsViewModel

    private var trimmedPlayerName: String {
        vm.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                hero

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("你的暱稱")
                    GameTextField(placeholder: "其他玩家會看到這個名字", text: $vm.playerName)
                }

                if let firebaseBlockingMessage = vm.firebaseBlockingMessage {
                    connectionNotice(firebaseBlockingMessage) {
                        vm.retryFirebaseConnection()
                    }
                }

                // 曾經進過房間的人，多半是要回去繼續冒險
                if vm.hasSavedRoomID {
                    joinCard
                    hostCard
                } else {
                    hostCard
                    joinCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(alignment: .top) {
            candlelight
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 4) {
            D20Emblem()
                .frame(width: 104)
                .shadow(color: Palette.candle.opacity(0.35), radius: 28)
                .padding(.bottom, 16)

            Text("AI GM")
                .serifFont(.display)
                .foregroundStyle(Palette.vellum)

            Text("房主設定模型，玩家一起推進冒險")
                .font(.subheadline)
                .foregroundStyle(Palette.sage)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
    }

    /// AI 生成的燭光桌面插畫，模糊後當作頂部的環境光
    private var candlelight: some View {
        Image(.lobbyAmbience)
            .resizable()
            .scaledToFill()
            .frame(height: 520)
            .frame(maxWidth: .infinity)
            .clipped()
            .mask(
                LinearGradient(
                    colors: [.black, .black.opacity(0.55), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .blendMode(.screen)
            .opacity(0.7)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Host

    private var hostCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("建立房間")

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("房間名稱")
                GameTextField(placeholder: "冒險房間", text: $vm.roomName)
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("AI 主持")

                Button {
                    aiSettings.present()
                } label: {
                    aiSummaryRow
                }
                .buttonStyle(.plain)
                .disabled(vm.isSubmitting)

                if let hostingIssue = aiSettings.hostingIssue {
                    Text(hostingIssue)
                        .font(.caption)
                        .foregroundStyle(Palette.candle)
                } else {
                    Text("預設會自動帶入 Base URL 與建議 Model，API Key 要自行輸入。")
                        .font(.caption)
                        .foregroundStyle(Palette.sageDim)
                }
            }

            Button(vm.isSubmitting ? "建立中..." : "由房主建立房間") {
                Task { await vm.createRoom(campaign: campaign, configuration: aiSettings.configuration) }
            }
            .buttonStyle(GameButtonStyle(kind: vm.hasSavedRoomID ? .secondary : .primary))
            .disabled(
                vm.isSubmitting ||
                vm.firebaseBlockingMessage != nil ||
                trimmedPlayerName.isEmpty ||
                aiSettings.hostingIssue != nil
            )
        }
        .cardStyle()
    }

    private var aiSummaryRow: some View {
        let summary = aiSettings.summary

        return HStack(spacing: 12) {
            D20Emblem()
                .frame(width: 26)
                .frame(width: 44, height: 44)
                .background(Palette.felt, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(summary.title)
                        .font(.headline)
                        .foregroundStyle(Palette.vellum)

                    ForEach(summary.badges.filter { $0 != summary.title }, id: \.self) { badge in
                        headerChip(title: badge, color: Palette.sage)
                    }
                }

                Text(summary.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Palette.sage)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Text("設定 AI")
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.candle)
        }
        .padding(12)
        .background(Palette.feltSunken, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Join

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("加入房間")

                Text(vm.hasSavedRoomID ? "已帶入上次的房間 ID，可以直接回到冒險。" : "向房主索取 Room ID，或加回舊房間延續冒險。")
                    .font(.subheadline)
                    .foregroundStyle(Palette.sage)
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("房間 ID")
                GameTextField(placeholder: "貼上房主分享的 ID", text: $vm.campaignInput)
            }

            Button(vm.isSubmitting ? "加入房間中..." : "加入房間") {
                Task { await vm.joinRoom(campaign: campaign) }
            }
            .buttonStyle(GameButtonStyle(kind: vm.hasSavedRoomID ? .primary : .secondary))
            .disabled(
                vm.isSubmitting ||
                vm.firebaseBlockingMessage != nil ||
                trimmedPlayerName.isEmpty ||
                vm.campaignInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .cardStyle()
    }
}
