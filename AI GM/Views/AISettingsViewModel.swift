//
//  AISettingsViewModel.swift
//  AI GM
//
//  Created by tony on 2026/4/6.
//

import Foundation
import os
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

    /// 目前設定不能拿來建房的原因（例如雲端供應商沒填 API Key），沒問題時是 nil
    var hostingIssue: String? {
        do {
            _ = try configuration.validatedForHosting()
            return nil
        } catch {
            return error.localizedDescription
        }
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

        if campaign.campaignId == nil {
            saveAsLastUsed()
        } else if campaign.isHost {
            Task {
                await campaign.updateAIConfiguration(configuration)
            }
        }
    }

    /// 在大廳改的設定也要馬上存，不然還沒建房就關掉 App 會整個不見。
    /// 格式不對時先不存，大廳會直接顯示問題
    private func saveAsLastUsed() {
        do {
            try AIHostConfigurationStore.saveLastUsed(configuration)
        } catch {
            AppLogger.ai.error("Saving lobby AI settings failed: \(error.localizedDescription)")
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
