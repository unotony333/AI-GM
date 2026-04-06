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

                    GameTextField(placeholder: "你的暱稱", text: $vm.playerName)
                }

                if vm.hasSavedRoomID {
                    joinCard
                    hostCard
                } else {
                    hostCard
                    joinCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    private var hostCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("建立房間")
            GameTextField(placeholder: "房間名稱", text: $vm.roomName)

            if let firebaseBlockingMessage = vm.firebaseBlockingMessage {
                HStack(spacing: 8) {
                    Text(firebaseBlockingMessage)
                        .font(.caption)
                        .foregroundStyle(.orange.opacity(0.9))

                    Spacer()

                    Button("重試") {
                        vm.retryFirebaseConnection()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("AI 設定")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))

                VStack(alignment: .leading, spacing: 10) {
                    Text(aiSettings.summary.title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(aiSettings.summary.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))

                    HStack(spacing: 8) {
                        ForEach(aiSettings.summary.badges, id: \.self) { badge in
                            headerChip(title: badge, color: badge == aiSettings.summary.title ? .pink : .blue)
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

                actionButton(title: "設定 AI", style: .secondary, isDisabled: vm.isSubmitting) {
                    aiSettings.present()
                }
            }

            Button {
                Task { await vm.createRoom(campaign: campaign, configuration: aiSettings.configuration) }
            } label: {
                Text(vm.isSubmitting ? "建立中..." : "由房主建立房間")
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
            .disabledState(
                vm.isSubmitting ||
                vm.firebaseBlockingMessage != nil ||
                vm.playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

            if let firebaseBlockingMessage = vm.firebaseBlockingMessage {
                HStack(spacing: 8) {
                    Text(firebaseBlockingMessage)
                        .font(.caption)
                        .foregroundStyle(.orange.opacity(0.9))

                    Spacer()

                    Button("重試") {
                        vm.retryFirebaseConnection()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                }
            }

            GameTextField(placeholder: "房間 ID", text: $vm.campaignInput)

            Button {
                Task { await vm.joinRoom(campaign: campaign) }
            } label: {
                Text(vm.isSubmitting ? "加入房間中..." : "加入房間")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabledState(
                vm.isSubmitting ||
                vm.firebaseBlockingMessage != nil ||
                vm.playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                vm.campaignInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .cardStyle()
    }
}
