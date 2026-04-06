//
//  ContentView.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @StateObject private var campaign = CampaignService()
    @StateObject private var userService = UserService.shared
    private let engine = GameEngine()

    @AppStorage("savedPlayerName") private var playerName = ""
    @State private var roomName = "冒險房間"
    @AppStorage("savedRoomID") private var campaignInput = ""
    @State private var aiSettings = AISettingsDraft(
        providerPreset: .openAI,
        apiFormat: AIProviderPreset.openAI.apiFormat,
        baseURL: AIProviderPreset.openAI.baseURL,
        model: AIProviderPreset.openAI.model,
        apiKey: "",
        systemPrompt: "你是一個TRPG GM。"
    )
    @State private var actionDraft = ""
    @State private var isSubmitting = false
    @State private var isShowingAISettings = false
    @State private var hasLoadedSavedAISettings = false
    @State private var isShowingRoomStatus = false
    @State private var isAtBottom = true
    @State private var aiSettingsDraft = AISettingsDraft(
        providerPreset: .openAI,
        apiFormat: AIProviderPreset.openAI.apiFormat,
        baseURL: AIProviderPreset.openAI.baseURL,
        model: AIProviderPreset.openAI.model,
        apiKey: "",
        systemPrompt: "你是一個TRPG GM。"
    )

    private var showErrorAlert: Binding<Bool> {
        Binding(
            get: { campaign.localErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    campaign.localErrorMessage = nil
                }
            }
        )
    }

    private var aiSettingsSummary: AISettingsSummary {
        AISettingsSummary(provider: aiSettings.providerPreset.provider, model: aiSettings.model, apiFormat: aiSettings.apiFormat)
    }

    private var firebaseBlockingMessage: String? {
        userService.authErrorMessage ?? userService.sessionStatus.blockingMessage
    }

    private var currentAIConfiguration: AIHostConfiguration {
        aiSettings.configuration
    }

    private var hasPendingAISettingsChanges: Bool {
        aiSettingsDraft != aiSettings
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                appBackgroundGradient
                    .ignoresSafeArea()

                if campaign.campaignId == nil {
                    LobbyView(
                        campaign: campaign,
                        playerName: $playerName,
                        roomName: $roomName,
                        campaignInput: $campaignInput,
                        isSubmitting: $isSubmitting,
                        aiSettingsSummary: aiSettingsSummary,
                        firebaseBlockingMessage: firebaseBlockingMessage,
                        onCreateRoom: createRoom,
                        onJoinRoom: joinRoom,
                        onOpenAISettings: presentAISettings
                    )
                } else {
                    GameView(
                        campaign: campaign,
                        actionDraft: $actionDraft,
                        isSubmitting: $isSubmitting,
                        isShowingRoomStatus: $isShowingRoomStatus,
                        isAtBottom: $isAtBottom,
                        onStartGame: startGame,
                        onContinueRound: continueRound,
                        onConfirmAction: confirmCurrentAction,
                        onCancelConfirmation: cancelConfirmation,
                        onCopyRoomID: copyRoomID,
                        onOpenAISettings: presentAISettings
                    )
                }
            }
            .alert("錯誤", isPresented: showErrorAlert) {
                Button("好") {
                    campaign.localErrorMessage = nil
                }
            } message: {
                Text(campaign.localErrorMessage ?? "")
            }
            .onChange(of: campaign.currentRoundId) { _, _ in
                actionDraft = ""
            }
            .onChange(of: campaign.campaignId) { _, newCampaignId in
                if let newCampaignId = newCampaignId {
                    campaignInput = newCampaignId
                }
            }
            .onAppear {
                restoreLastUsedAISettingsIfNeeded()
            }
            .sheet(isPresented: $isShowingAISettings) {
                AISettingsSheet(
                    draft: $aiSettingsDraft,
                    hasPendingChanges: hasPendingAISettingsChanges,
                    onCommit: commitAISettings,
                    onDismiss: dismissAISettings
                )
            }
        }
    }

    // MARK: - Actions

    private func createRoom() {
        guard !isSubmitting else { return }

        let configuration = currentAIConfiguration

        isSubmitting = true
        Task {
            await campaign.createCampaign(
                name: roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "冒險房間" : roomName,
                playerName: playerName,
                configuration: configuration
            )
            isSubmitting = false
        }
    }

    private func joinRoom() {
        guard !isSubmitting else { return }
        isSubmitting = true

        let trimmedCampaignId = campaignInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlayerName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            await campaign.joinCampaign(campaignId: trimmedCampaignId, playerName: trimmedPlayerName)
            isSubmitting = false
        }
    }

    private func startGame() {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            await campaign.startGame(using: engine)
            isSubmitting = false
        }
    }

    private func continueRound() {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            await campaign.continueRound(using: engine)
            isSubmitting = false
        }
    }

    private func confirmCurrentAction() {
        guard !isSubmitting else { return }
        let draft = actionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else { return }

        isSubmitting = true
        Task {
            do {
                try await campaign.confirmAction(text: draft)
            } catch {
                campaign.localErrorMessage = "確認行動失敗：\(error.localizedDescription)"
            }
            isSubmitting = false
        }
    }

    private func cancelConfirmation(_ previousText: String) {
        guard !isSubmitting else { return }
        isSubmitting = true
        actionDraft = previousText

        Task {
            do {
                try await campaign.cancelConfirmedAction()
            } catch {
                campaign.localErrorMessage = "取消確認失敗：\(error.localizedDescription)"
            }
            isSubmitting = false
        }
    }

    private func copyRoomID() {
        #if os(iOS)
        UIPasteboard.general.string = campaign.campaignId
        #endif
    }

    // MARK: - AI Settings

    private func presentAISettings() {
        aiSettingsDraft = aiSettings
        isShowingAISettings = true
    }

    private func dismissAISettings() {
        aiSettingsDraft = aiSettings
        isShowingAISettings = false
    }

    private func commitAISettings() {
        aiSettings = aiSettingsDraft
        isShowingAISettings = false

        if campaign.campaignId != nil && campaign.isHost {
            Task {
                await campaign.updateAIConfiguration(currentAIConfiguration)
            }
        }
    }

    private func restoreLastUsedAISettingsIfNeeded() {
        guard !hasLoadedSavedAISettings else { return }
        hasLoadedSavedAISettings = true

        do {
            guard let configuration = try AIHostConfigurationStore.loadLastUsed() else { return }
            applyAIConfiguration(configuration)
        } catch {
            campaign.localErrorMessage = "讀取上次 AI 設定失敗：\(error.localizedDescription)"
        }
    }

    private func applyAIConfiguration(_ configuration: AIHostConfiguration) {
        let canonicalConfiguration = configuration.canonicalized()
        let inferredPreset = AIProviderPreset.inferred(from: canonicalConfiguration)

        aiSettings = AISettingsDraft(configuration: canonicalConfiguration, providerPreset: inferredPreset)
        aiSettingsDraft = aiSettings
    }
}

#Preview {
    ContentView()
}
