//
//  LobbyView.swift
//  AI GM
//
//  Extracted from ContentView.swift
//

import SwiftUI

struct LobbyView: View {
    @ObservedObject var campaign: CampaignService
    @Binding var playerName: String
    @Binding var roomName: String
    @Binding var campaignInput: String
    @Binding var isSubmitting: Bool
    let aiSettingsSummary: AISettingsSummary
    let firebaseBlockingMessage: String?
    let onCreateRoom: () -> Void
    let onJoinRoom: () -> Void
    let onOpenAISettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 28)

                VStack(spacing: 10) {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 76))
                        .foregroundStyle(.pink, .orange)

                    Text("AI GM")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)

                    Text("房主設定模型，玩家一起推進冒險")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    GameTextField(placeholder: "你的暱稱", text: $playerName)
                }

                if campaignInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    hostCard
                    joinCard
                } else {
                    joinCard
                    hostCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    private var hostCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("建立房間")
            GameTextField(placeholder: "房間名稱", text: $roomName)

            if let firebaseBlockingMessage {
                Text(firebaseBlockingMessage)
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("AI 設定")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))

                VStack(alignment: .leading, spacing: 10) {
                    Text(aiSettingsSummary.title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(aiSettingsSummary.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))

                    HStack(spacing: 8) {
                        ForEach(aiSettingsSummary.badges, id: \.self) { badge in
                            headerChip(title: badge, color: badge == aiSettingsSummary.title ? .pink : .blue)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("預設會自動帶入 Base URL 與建議 Model，API Key要自行輸入。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))

                actionButton(title: "設定 AI", style: .secondary, isDisabled: isSubmitting) {
                    onOpenAISettings()
                }
            }

            Button {
                onCreateRoom()
            } label: {
                Text(isSubmitting ? "建立中..." : "由房主建立房間")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(
                isSubmitting ||
                firebaseBlockingMessage != nil ||
                playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .opacity(
                isSubmitting ||
                firebaseBlockingMessage != nil ||
                playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? 0.55 : 1
            )
        }
        .cardStyle()
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("加入房間")

            Text("可加回舊房間延續冒險。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            if let firebaseBlockingMessage {
                Text(firebaseBlockingMessage)
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.9))
            }

            GameTextField(placeholder: "房間 ID", text: $campaignInput)

            Button {
                onJoinRoom()
            } label: {
                Text(isSubmitting ? "加入中..." : "加入房間")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(
                isSubmitting ||
                firebaseBlockingMessage != nil ||
                playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                campaignInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .opacity(
                isSubmitting ||
                firebaseBlockingMessage != nil ||
                playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                campaignInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? 0.55 : 1
            )
        }
        .cardStyle()
    }
}
