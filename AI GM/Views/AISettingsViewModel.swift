//
//  AISettingsViewModel.swift
//  AI GM
//
//  Created by tony on 2026/4/6.
//

import Foundation
internal import Combine

@MainActor
final class AISettingsViewModel: ObservableObject {
    @Published var settings: AISettingsDraft
    @Published var draft: AISettingsDraft
    @Published var isPresented = false

    private var hasLoadedSavedSettings = false

    private static let defaultDraft = AISettingsDraft(
        providerPreset: .openAI,
        apiFormat: AIProviderPreset.openAI.apiFormat,
        baseURL: AIProviderPreset.openAI.baseURL,
        model: AIProviderPreset.openAI.model,
        apiKey: "",
        systemPrompt: "你是一個TRPG GM。"
    )

    init() {
        let draft = Self.defaultDraft
        self.settings = draft
        self.draft = draft
    }

    var hasPendingChanges: Bool {
        draft != settings
    }

    var summary: AISettingsSummary {
        AISettingsSummary(
            provider: settings.providerPreset.provider,
            model: settings.model,
            apiFormat: settings.apiFormat
        )
    }

    var configuration: AIHostConfiguration {
        settings.configuration
    }

    func present() {
        draft = settings
        isPresented = true
    }

    func dismiss() {
        draft = settings
        isPresented = false
    }

    func commit(campaign: CampaignService) {
        settings = draft
        isPresented = false

        if campaign.campaignId != nil && campaign.isHost {
            Task {
                await campaign.updateAIConfiguration(configuration)
            }
        }
    }

    func restoreLastUsedIfNeeded(onError: (String) -> Void) {
        guard !hasLoadedSavedSettings else { return }
        hasLoadedSavedSettings = true

        do {
            guard let saved = try AIHostConfigurationStore.loadLastUsed() else { return }
            apply(saved)
        } catch {
            onError("讀取上次 AI 設定失敗：\(error.localizedDescription)")
        }
    }

    private func apply(_ configuration: AIHostConfiguration) {
        let canonical = configuration.canonicalized()
        let preset = AIProviderPreset.inferred(from: canonical)
        settings = AISettingsDraft(configuration: canonical, providerPreset: preset)
        draft = settings
    }
}
