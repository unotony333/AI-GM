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

    @State private var playerName = ""
    @State private var roomName = "冒險房間"
    @State private var campaignInput = ""
    @State private var providerPreset: AIProviderPreset = .openAI
    @State private var apiFormat: AIAPIFormat = AIProviderPreset.openAI.apiFormat
    @State private var baseURL = AIProviderPreset.openAI.baseURL
    @State private var model = AIProviderPreset.openAI.model
    @State private var apiKey = ""
    @State private var systemPrompt = "你是一個TRPG GM。"
    @State private var actionDraft = ""
    @State private var isSubmitting = false
    @State private var isShowingAISettings = false
    @State private var isShowingDiscardAISettingsConfirmation = false
    @State private var hasLoadedSavedAISettings = false
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

    private var sortedPlayers: [Player] {
        campaign.players.sorted { lhs, rhs in
            if lhs.id == campaign.hostId { return true }
            if rhs.id == campaign.hostId { return false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var aiSettingsSummary: AISettingsSummary {
        AISettingsSummary(provider: providerPreset.provider, model: model, apiFormat: apiFormat)
    }

    private var firebaseBlockingMessage: String? {
        userService.authErrorMessage ?? userService.sessionStatus.blockingMessage
    }

    private var currentAIConfiguration: AIHostConfiguration {
        AIHostConfiguration(
            provider: providerPreset.provider,
            apiFormat: apiFormat,
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            systemPrompt: systemPrompt
        )
    }

    private var hasPendingAISettingsChanges: Bool {
        aiSettingsDraft.hasChanges(comparedTo: currentAIConfiguration, providerPreset: providerPreset)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.08, blue: 0.14),
                        Color(red: 0.14, green: 0.09, blue: 0.18),
                        Color(red: 0.08, green: 0.1, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if campaign.campaignId == nil {
                    lobbyView
                } else {
                    gameView
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
            .onAppear {
                restoreLastUsedAISettingsIfNeeded()
            }
            .sheet(isPresented: $isShowingAISettings) {
                aiSettingsSheet
            }
        }
    }

    private var lobbyView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 28)

                VStack(spacing: 10) {
                    Image(systemName: "dice.3d.fill")
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

                hostCard
                joinCard
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

                Text("供應商預設會自動帶入 Base URL 與建議 Model，細節可在設定畫面中修改。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))

                actionButton(title: "設定 AI", style: .secondary, isDisabled: isSubmitting) {
                    presentAISettings()
                }
            }

            Button {
                createRoom()
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

    private var aiSettingsSheet: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.07, blue: 0.12),
                        Color(red: 0.12, green: 0.09, blue: 0.17)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionTitle("AI 供應商")

                            Picker("AI 供應商", selection: providerPresetDraftBinding) {
                                ForEach(AIProviderPreset.allCases) { preset in
                                    Text(preset.provider).tag(preset)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text(aiSettingsDraft.providerPreset.description)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("連線設定")

                            HStack(spacing: 8) {
                                headerChip(title: aiSettingsDraft.providerPreset.provider, color: .pink)
                                headerChip(title: formatLabel(aiSettingsDraft.apiFormat), color: .blue)
                            }

                            GameTextField(placeholder: "Base URL，例如 https://api.openai.com/v1", text: $aiSettingsDraft.baseURL)
                            GameTextField(placeholder: "Model，例如 gpt-4o-mini / llama3.1", text: $aiSettingsDraft.model)
                            GameSecureField(placeholder: "API Key", text: $aiSettingsDraft.apiKey)
                        }
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("主持風格")
                            GameTextEditor(placeholder: "System Prompt", text: $aiSettingsDraft.systemPrompt, minHeight: 180)
                        }
                        .cardStyle()
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") {
                        requestDismissAISettings()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }

                ToolbarItem(placement: .principal) {
                    Text("AI 設定")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        commitAISettings()
                    }
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(hasPendingAISettingsChanges)
        .alert("放棄這次 AI 設定變更？", isPresented: $isShowingDiscardAISettingsConfirmation) {
            Button("繼續編輯", role: .cancel) { }
            Button("放棄變更", role: .destructive) {
                dismissAISettings(forceDiscard: true)
            }
        } message: {
            Text("你在 AI 設定中的修改尚未套用。")
        }
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("加入房間")

            Text("其他玩家只需要暱稱與房間 ID，會看到房主使用的 provider 與 model。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            if !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("目前暱稱：\(playerName)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            if let firebaseBlockingMessage {
                Text(firebaseBlockingMessage)
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.9))
            }

            GameTextField(placeholder: "房間 ID", text: $campaignInput)

            Button {
                joinRoom()
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

    private var gameView: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(spacing: 16) {
                    playerStatusCard
                    actionStatusCard
                    messageList
                    actionComposerCard
                }
                .padding(16)
                .padding(.bottom, 20)
            }
        }
    }

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(campaign.campaignName.isEmpty ? "房間" : campaign.campaignName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        Text(campaign.campaignId ?? "未知")
                            .font(.footnote.monospaced())
                            .foregroundStyle(.white.opacity(0.7))

                        Button {
                            copyRoomID()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                Spacer()

                if campaign.isHost {
                    Text("房主")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.28))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 8) {
                headerChip(title: campaign.provider.isEmpty ? "Provider 未設定" : campaign.provider, color: .pink)
                headerChip(title: campaign.model.isEmpty ? "Model 未設定" : campaign.model, color: .orange)
                headerChip(title: phaseLabel(campaign.phase), color: phaseColor(campaign.phase))
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.22))
    }

    private var playerStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("房內玩家")
                Spacer()
                Text("\(campaign.readyPlayerCount)/\(campaign.players.count) 已確認")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            ForEach(sortedPlayers) { player in
                let confirmedAction = campaign.confirmedActions.first(where: { $0.playerId == player.id })

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(player.name)
                            .font(.headline)
                            .foregroundStyle(.white)

                        if player.id == campaign.hostId {
                            Text("Host")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.28))
                                .clipShape(Capsule())
                        }

                        Spacer()

                        Text(confirmedAction == nil ? "等待確認" : "已確認")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(confirmedAction == nil ? .orange : .green)
                    }

                    Text(player.statSummary)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))

                    if let confirmedAction {
                        Text(confirmedAction.text)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .cardStyle()
    }

    private var actionStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("房間進度")
                Spacer()

                if campaign.phase == .lobby && campaign.isHost {
                    actionButton(title: "開始遊戲", style: .primary, isDisabled: isSubmitting || campaign.players.isEmpty) {
                        startGame()
                    }
                }

                if campaign.phase == .collectingActions && campaign.isHost && campaign.areAllPlayersReady {
                    actionButton(title: isSubmitting ? "結算中..." : "房主繼續", style: .primary, isDisabled: isSubmitting) {
                        continueRound()
                    }
                }
            }

            Text(statusDescription)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
        }
        .cardStyle()
    }

    private var messageList: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("劇情紀錄")

            if campaign.typedMessages.isEmpty {
                Text("房主開始遊戲後，AI 的開場白會出現在這裡。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ForEach(campaign.typedMessages) { message in
                    messageBubble(message)
                }
            }
        }
        .cardStyle()
    }

    private func messageBubble(_ message: CampaignMessage) -> some View {
        let isPlayer = message.kind == .player

        return HStack {
            if isPlayer { Spacer(minLength: 30) }

            VStack(alignment: .leading, spacing: 6) {
                Text(messageKindLabel(message.kind))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isPlayer ? Color.white.opacity(0.8) : Color.orange.opacity(0.9))

                Text(message.text)
                    .font(.body)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: 320, alignment: .leading)
            .background(isPlayer ? Color.pink.opacity(0.45) : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !isPlayer { Spacer(minLength: 30) }
        }
    }

    private var actionComposerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("本回合行動")

            switch campaign.phase {
            case .lobby:
                Text(campaign.isHost ? "玩家都到齊後，由房主開始遊戲。" : "等待房主開始遊戲。")
                    .foregroundStyle(.white.opacity(0.7))

            case .starting:
                Text("房主正在向 AI 取得開場白。")
                    .foregroundStyle(.white.opacity(0.7))

            case .collectingActions:
                if let confirmed = campaign.myConfirmedAction {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("你已確認本回合行動：")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))

                        Text(confirmed.text)
                            .foregroundStyle(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        actionButton(title: "取消確認並編輯", style: .secondary, isDisabled: isSubmitting) {
                            cancelConfirmation(confirmed.text)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        GameTextEditor(
                            placeholder: "描述你這回合想做的事",
                            text: $actionDraft,
                            minHeight: 110
                        )

                        actionButton(
                            title: isSubmitting ? "確認中..." : "確認本回合行動",
                            style: .primary,
                            isDisabled: isSubmitting || actionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            confirmCurrentAction()
                        }
                    }
                }

            case .resolvingTurn:
                Text("房主正在把所有已確認行動交給 AI 結算。")
                    .foregroundStyle(.white.opacity(0.7))

            case .finished:
                Text("這場冒險已經結束。")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .cardStyle()
    }

    private var statusDescription: String {
        switch campaign.phase {
        case .lobby:
            return campaign.isHost ? "房主可在玩家加入後開始遊戲。" : "等待房主開始遊戲。"
        case .starting:
            return "房主正在取得開場白。"
        case .collectingActions:
            if campaign.areAllPlayersReady {
                return campaign.isHost ? "所有玩家都已確認，房主可以繼續。" : "所有玩家都已確認，等待房主繼續。"
            }
            return "每位玩家先編輯自己的草稿，確認後才會公開。"
        case .resolvingTurn:
            return "AI 正在結算本回合。"
        case .finished:
            return "本房間已結束。"
        }
    }

    // MARK: - Actions

    private func createRoom() {
        guard !isSubmitting else { return }

        let configuration = AIHostConfiguration(
            provider: providerPreset.provider,
            apiFormat: apiFormat,
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            systemPrompt: systemPrompt
        )

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

    private var providerPresetDraftBinding: Binding<AIProviderPreset> {
        Binding(
            get: { aiSettingsDraft.providerPreset },
            set: { preset in
                aiSettingsDraft.applyPreset(preset)
            }
        )
    }

    private func presentAISettings() {
        aiSettingsDraft = AISettingsDraft(configuration: currentAIConfiguration, providerPreset: providerPreset)
        isShowingAISettings = true
    }

    private func requestDismissAISettings() {
        if hasPendingAISettingsChanges {
            isShowingDiscardAISettingsConfirmation = true
            return
        }

        dismissAISettings(forceDiscard: false)
    }

    private func dismissAISettings(forceDiscard: Bool) {
        if forceDiscard {
            aiSettingsDraft = AISettingsDraft(configuration: currentAIConfiguration, providerPreset: providerPreset)
        }
        isShowingAISettings = false
    }

    private func commitAISettings() {
        providerPreset = aiSettingsDraft.providerPreset
        apiFormat = aiSettingsDraft.apiFormat
        baseURL = aiSettingsDraft.baseURL
        model = aiSettingsDraft.model
        apiKey = aiSettingsDraft.apiKey
        systemPrompt = aiSettingsDraft.systemPrompt
        isShowingAISettings = false
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

        providerPreset = inferredPreset
        apiFormat = canonicalConfiguration.apiFormat
        baseURL = canonicalConfiguration.baseURL
        model = canonicalConfiguration.model
        apiKey = canonicalConfiguration.apiKey
        systemPrompt = canonicalConfiguration.systemPrompt
        aiSettingsDraft = AISettingsDraft(
            configuration: canonicalConfiguration,
            providerPreset: inferredPreset
        )
    }

    // MARK: - UI Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.white)
    }

    private func headerChip(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.24))
            .clipShape(Capsule())
    }

    private func actionButton(title: String, style: ActionButtonStyle, isDisabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(style.background)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }

    private func phaseLabel(_ phase: CampaignPhase) -> String {
        switch phase {
        case .lobby: return "大廳"
        case .starting: return "開場中"
        case .collectingActions: return "等待行動"
        case .resolvingTurn: return "結算中"
        case .finished: return "已結束"
        }
    }

    private func phaseColor(_ phase: CampaignPhase) -> Color {
        switch phase {
        case .lobby: return .blue
        case .starting: return .purple
        case .collectingActions: return .green
        case .resolvingTurn: return .orange
        case .finished: return .gray
        }
    }

    private func formatLabel(_ format: AIAPIFormat) -> String {
        switch format {
        case .openAICompatible: return "OpenAI"
        case .ollama: return "Ollama"
        }
    }

    private func messageKindLabel(_ kind: CampaignMessageKind) -> String {
        switch kind {
        case .opening: return "開場"
        case .system: return "系統"
        case .narration: return "GM"
        case .player: return "玩家"
        }
    }
}

private enum ActionButtonStyle {
    case primary
    case secondary

    var background: LinearGradient {
        switch self {
        case .primary:
            return LinearGradient(
                colors: [.orange, .pink],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .secondary:
            return LinearGradient(
                colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

private extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

struct GameTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            }

            TextField("", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .padding(12)
        }
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct GameSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            }

            SecureField("", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .padding(12)
        }
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct GameTextEditor: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.1))

            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .textInputAutocapitalization(.sentences)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: minHeight)
        }
        .frame(minHeight: minHeight)
    }
}

#Preview {
    ContentView()
}
