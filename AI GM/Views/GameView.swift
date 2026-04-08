//
//  GameView.swift
//  AI GM
//
//  Extracted from ContentView.swift
//

import SwiftUI

struct GameView: View {
    @ObservedObject var campaign: CampaignService
    @ObservedObject var aiSettings: AISettingsViewModel
    @StateObject private var vm: GameViewModel

    init(campaign: CampaignService, aiSettings: AISettingsViewModel) {
        self._campaign = ObservedObject(wrappedValue: campaign)
        self._aiSettings = ObservedObject(wrappedValue: aiSettings)
        self._vm = StateObject(wrappedValue: GameViewModel(campaign: campaign))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 52)

                    ScrollViewReader { proxy in
                        ScrollView {
                            messageList
                                .padding(16)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: campaign.typedMessages) { _, _ in
                            scrollToBottomIfNeeded(proxy)
                        }
                        .onChange(of: campaign.phase) { _, _ in
                            scrollToBottomIfNeeded(proxy, delay: 0.15)
                        }
                        .onChange(of: campaign.myConfirmedAction?.text) { _, _ in
                            scrollToBottomIfNeeded(proxy, delay: 0.15)
                        }
                        .onAppear {
                            scrollToBottomIfNeeded(proxy, delay: 0.1, force: true)
                        }
                    }

                    VStack(spacing: 0) {
                        Divider().background(Color.white.opacity(0.15))
                        actionComposerCard
                            .padding(16)
                            .background(Color.black.opacity(0.2))
                    }
                }

                // 懸浮在上面的狀態列表 (DisclosureGroup)
                VStack(spacing: 0) {
                    DisclosureGroup(isExpanded: $vm.isShowingRoomStatus) {
                        VStack(spacing: 16) {
                            playerStatusCard
                            actionStatusCard
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    } label: {
                        HStack {
                            Image(systemName: "info.circle.fill")
                            Text("房間與玩家狀態")
                                .font(.headline)
                            Spacer()
                            if campaign.phase == .collectingActions && campaign.isHost && campaign.areAllPlayersReady {
                                Text("可繼續")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .clipShape(Capsule())
                                    .foregroundStyle(.white)
                            } else if campaign.phase == .lobby && campaign.isHost {
                                Text("可開始")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.statusBarBackground)

                    Divider().background(Color.white.opacity(0.15))
                }
                .shadow(color: vm.isShowingRoomStatus ? .black.opacity(0.5) : .clear, radius: 8, y: 4)
            }
        }
    }

    // MARK: - Header

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
                            vm.copyRoomID()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                Spacer()

                if campaign.isHost {
                    HStack(spacing: 8) {
                        Button {
                            aiSettings.present()
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }

                        Text("房主")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.28))
                            .clipShape(Capsule())
                    }
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

    // MARK: - Player Status

    private var playerStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("房內玩家")
                Spacer()
                Text("\(campaign.readyPlayerCount)/\(campaign.players.count) 已確認")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            ForEach(vm.sortedPlayers) { player in
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

    // MARK: - Action Status

    private var actionStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("房間進度")
                Spacer()

                if campaign.phase == .lobby && campaign.isHost {
                    actionButton(title: "開始遊戲", style: .primary, isDisabled: vm.isSubmitting || campaign.players.isEmpty) {
                        vm.startGame()
                    }
                }

                if campaign.phase == .collectingActions && campaign.isHost && campaign.areAllPlayersReady {
                    actionButton(title: vm.isSubmitting ? "結算中..." : "繼續", style: .primary, isDisabled: vm.isSubmitting) {
                        vm.continueRound()
                    }
                }
            }

            Text(statusDescription)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
        }
        .cardStyle()
    }

    // MARK: - Messages

    private var messageList: some View {
        LazyVStack(spacing: 16) {
            if campaign.typedMessages.isEmpty {
                Text("房主開始遊戲後，AI 的開場白會出現在這裡。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ForEach(campaign.typedMessages) { message in
                    MessageBubbleView(message: message)
                }
            }

            Color.clear
                .frame(height: 1)
                .id("BOTTOM_MARKER")
                .onAppear {
                    vm.isAtBottom = true
                }
                .onDisappear {
                    vm.isAtBottom = false
                }
        }
    }

    // MARK: - Action Composer

    private var actionComposerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch campaign.phase {
            case .lobby:
                Text(campaign.isHost ? "玩家都到齊後，由房主開始遊戲。" : "等待房主開始遊戲。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)

            case .starting:
                VStack(spacing: 8) {
                    Text("房主正在向 AI 取得開場白...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)

                    if campaign.isHost && vm.isSubmitting {
                        actionButton(title: "取消", style: .secondary, isDisabled: false) {
                            vm.cancelAIRequest()
                        }
                    }
                }

            case .collectingActions:
                if let confirmed = campaign.myConfirmedAction {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("你已確認本回合行動：")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))

                        Text(confirmed.text)
                            .foregroundStyle(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        actionButton(title: "取消確認並編輯", style: .secondary, isDisabled: vm.isSubmitting) {
                            Task { await vm.cancelConfirmation(previousText: confirmed.text) }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        HStack {
                            Text("本回合你的行動")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer()
                        }

                        GameTextEditor(
                            placeholder: "描述你這回合想做的事",
                            text: $vm.actionDraft
                        )

                        actionButton(
                            title: vm.isSubmitting ? "確認中..." : "確認本回合行動",
                            style: .primary,
                            isDisabled: vm.isSubmitting || vm.actionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            Task { await vm.confirmAction() }
                        }
                    }
                }

            case .resolvingTurn:
                VStack(spacing: 8) {
                    Text("房主正在把所有已確認行動交給 AI 結算...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)

                    if campaign.isHost && vm.isSubmitting {
                        actionButton(title: "取消", style: .secondary, isDisabled: false) {
                            vm.cancelAIRequest()
                        }
                    }
                }

            case .finished:
                Text("這場冒險已經結束。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private func scrollToBottomIfNeeded(_ proxy: ScrollViewProxy, delay: TimeInterval = 0, force: Bool = false) {
        guard force || vm.isAtBottom else { return }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation { proxy.scrollTo("BOTTOM_MARKER", anchor: .bottom) }
            }
        } else {
            withAnimation { proxy.scrollTo("BOTTOM_MARKER", anchor: .bottom) }
        }
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
}
