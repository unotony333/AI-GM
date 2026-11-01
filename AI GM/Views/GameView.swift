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

    @State private var didCopyRoomID = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 冒險紀錄與輸入區的最大寬度，避免在 iPad 上一行太長
    private let readingWidth: CGFloat = 640

    init(campaign: CampaignService, aiSettings: AISettingsViewModel) {
        self._campaign = ObservedObject(wrappedValue: campaign)
        self._aiSettings = ObservedObject(wrappedValue: aiSettings)
        self._vm = StateObject(wrappedValue: GameViewModel(campaign: campaign))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            partyBar

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            messageList
                                .padding(.horizontal, 20)
                                .padding(.vertical, 20)
                                .frame(maxWidth: readingWidth)
                                .frame(maxWidth: .infinity)
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

                    composerBar
                }

                // 展開的隊伍面板蓋在冒險紀錄上方
                if vm.isShowingRoomStatus {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea(edges: .bottom)
                        .onTapGesture { toggleRoomStatus() }
                        .transition(.opacity)

                    roomStatusPanel
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .clipped()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(campaign.campaignName.isEmpty ? "房間" : campaign.campaignName)
                        .serifFont(.title)
                        .foregroundStyle(Palette.vellum)
                        .lineLimit(1)

                    roomIDButton
                }

                Spacer(minLength: 8)

                if campaign.isHost {
                    Text("房主")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.vellum)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Palette.wax, in: Capsule())
                        .padding(.top, 10)

                    Button {
                        aiSettings.present()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.vellum)
                            .frame(width: 40, height: 40)
                            .background(Palette.feltRaised, in: Circle())
                            .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: 1))
                    }
                    .accessibilityLabel("AI 設定")
                }
            }

            HStack(spacing: 10) {
                phasePill

                HStack(spacing: 6) {
                    Text(campaign.provider.isEmpty ? "Provider 未設定" : campaign.provider)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.vellum.opacity(0.85))
                    Text(campaign.model.isEmpty ? "Model 未設定" : campaign.model)
                        .foregroundStyle(Palette.sage)
                        .truncationMode(.middle)
                }
                .font(.caption)
                .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var roomIDButton: some View {
        Button {
            vm.copyRoomID()
            didCopyRoomID = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                didCopyRoomID = false
            }
        } label: {
            HStack(spacing: 6) {
                Text(campaign.campaignId ?? "未知")
                    .font(.footnote.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: didCopyRoomID ? "checkmark" : "doc.on.doc")
                    .font(.caption.weight(.semibold))
                if didCopyRoomID {
                    Text("已複製")
                        .font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(didCopyRoomID ? Palette.moss : Palette.sage)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(didCopyRoomID ? "已複製房間 ID" : "複製房間 ID")
    }

    private var phasePill: some View {
        let color = phaseColor(campaign.phase)

        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(phaseLabel(campaign.phase))
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.28), lineWidth: 1))
        .fixedSize()
    }

    // MARK: - Party Bar

    private var hostCue: String? {
        guard campaign.isHost else { return nil }
        if campaign.phase == .lobby {
            return "可開始"
        }
        if campaign.phase == .collectingActions && campaign.areAllPlayersReady {
            return "可繼續"
        }
        return nil
    }

    private var partySummary: String {
        let count = campaign.players.count
        switch campaign.phase {
        case .collectingActions:
            let round = campaign.currentRoundNumber > 0 ? "第 \(campaign.currentRoundNumber) 回合，" : ""
            return "\(round)\(campaign.readyPlayerCount)/\(count) 人已確認"
        default:
            return "\(count) 位玩家"
        }
    }

    private var partyBar: some View {
        Button {
            toggleRoomStatus()
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: -8) {
                    ForEach(vm.sortedPlayers.prefix(5)) { player in
                        PlayerToken(name: player.name, isReady: isReady(player))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("隊伍")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.vellum)
                    Text(partySummary)
                        .font(.caption)
                        .foregroundStyle(Palette.sage)
                }

                Spacer(minLength: 8)

                if let hostCue {
                    Text(hostCue)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.candleInk)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Palette.candle, in: Capsule())
                }

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.sage)
                    .rotationEffect(.degrees(vm.isShowingRoomStatus ? 180 : 0))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Palette.feltDeep.opacity(0.55))
        .overlay(alignment: .top) { Palette.hairline.frame(height: 1) }
        .overlay(alignment: .bottom) { Palette.hairline.frame(height: 1) }
        .accessibilityLabel("隊伍，\(partySummary)")
        .accessibilityHint(vm.isShowingRoomStatus ? "收合隊伍資訊" : "展開隊伍資訊")
    }

    private var roomStatusPanel: some View {
        let content = VStack(spacing: 12) {
            ForEach(vm.sortedPlayers) { player in
                PlayerSheetRow(
                    player: player,
                    isHost: player.id == campaign.hostId,
                    confirmedAction: campaign.confirmedActions.first(where: { $0.playerId == player.id })
                )
            }

            actionStatusCard
        }
        .padding(16)
        .frame(maxWidth: readingWidth)
        .frame(maxWidth: .infinity)

        return ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .background(Palette.felt)
        .overlay(alignment: .bottom) { Palette.hairline.frame(height: 1) }
        .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
    }

    // MARK: - Action Status

    private var actionStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(statusDescription)
                .font(.subheadline)
                .foregroundStyle(Palette.sage)
                .frame(maxWidth: .infinity, alignment: .leading)

            hostAdvanceButton
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    /// 房主推進遊戲的按鈕：大廳時開始，全員確認後繼續
    @ViewBuilder
    private var hostAdvanceButton: some View {
        if campaign.phase == .lobby && campaign.isHost {
            actionButton(title: "開始遊戲", style: .primary, isDisabled: vm.isSubmitting || campaign.players.isEmpty) {
                vm.isShowingRoomStatus = false
                vm.startGame()
            }
        }

        if campaign.phase == .collectingActions && campaign.isHost && campaign.areAllPlayersReady {
            actionButton(title: vm.isSubmitting ? "結算中..." : "繼續", style: .primary, isDisabled: vm.isSubmitting) {
                vm.isShowingRoomStatus = false
                vm.continueRound()
            }
        }
    }

    // MARK: - Messages

    private var messageList: some View {
        LazyVStack(spacing: 28) {
            if campaign.typedMessages.isEmpty {
                VStack(spacing: 18) {
                    D20Emblem(glow: 0)
                        .frame(width: 64)
                    Text("房主開始遊戲後，AI 的開場白會出現在這裡。")
                        .font(.subheadline)
                        .foregroundStyle(Palette.sage)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
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

    private var composerBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            composerContent
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: readingWidth)
        .frame(maxWidth: .infinity)
        .background {
            Palette.feltDeep.opacity(0.88)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .overlay(alignment: .top) { Palette.hairline.frame(height: 1) }
    }

    @ViewBuilder
    private var composerContent: some View {
        switch campaign.phase {
        case .lobby:
            Text(campaign.isHost ? "玩家都到齊後，由房主開始遊戲。" : "等待房主開始遊戲。")
                .font(.subheadline)
                .foregroundStyle(Palette.sage)
                .frame(maxWidth: .infinity, alignment: campaign.isHost ? .leading : .center)

            hostAdvanceButton

        case .starting:
            thinkingRow("房主正在向 AI 取得開場白...")

        case .collectingActions:
            if let confirmed = campaign.myConfirmedAction {
                VStack(alignment: .leading, spacing: 8) {
                    Label("你已確認本回合行動", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.moss)

                    Text("「\(confirmed.text)」")
                        .serifFont(.quote)
                        .foregroundStyle(Palette.vellum)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    actionButton(title: "取消確認並編輯", style: .secondary, isDisabled: vm.isSubmitting) {
                        Task { await vm.cancelConfirmation(previousText: confirmed.text) }
                    }

                    hostAdvanceButton
                }
            } else {
                Text("本回合你的行動")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.sage)

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

        case .resolvingTurn:
            thinkingRow("房主正在把所有已確認行動交給 AI 結算...")

        case .finished:
            Text("這場冒險已經結束。")
                .font(.subheadline)
                .foregroundStyle(Palette.sage)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func thinkingRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            ThinkingDie()
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Palette.sage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        if campaign.isHost && vm.isSubmitting {
            actionButton(title: "取消", style: .secondary, isDisabled: false) {
                vm.cancelAIRequest()
            }
        }
    }

    // MARK: - Helpers

    private func isReady(_ player: Player) -> Bool {
        campaign.confirmedActions.contains { $0.playerId == player.id }
    }

    private func toggleRoomStatus() {
        withAnimation(.snappy(duration: 0.28)) {
            vm.isShowingRoomStatus.toggle()
        }
    }

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
