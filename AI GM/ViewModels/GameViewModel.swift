//
//  GameViewModel.swift
//  AI GM
//
//  Created by tony on 2026/4/6.
//

import Foundation
internal import Combine

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class GameViewModel: ObservableObject {
    let campaign: CampaignService
    private let engine = GameEngine()

    @Published var actionDraft = ""
    @Published var isSubmitting = false
    @Published var isShowingRoomStatus = false
    @Published var isAtBottom = true

    private var cancellables = Set<AnyCancellable>()

    init(campaign: CampaignService) {
        self.campaign = campaign

        campaign.$currentRoundId
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.actionDraft = ""
            }
            .store(in: &cancellables)
    }

    func startGame() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        await campaign.startGame(using: engine)
        isSubmitting = false
    }

    func continueRound() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        await campaign.continueRound(using: engine)
        isSubmitting = false
    }

    func confirmAction() async {
        guard !isSubmitting else { return }
        let draft = actionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else { return }

        isSubmitting = true
        do {
            try await campaign.confirmAction(text: draft)
        } catch {
            campaign.localErrorMessage = "確認行動失敗：\(error.localizedDescription)"
        }
        isSubmitting = false
    }

    func cancelConfirmation(previousText: String) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        actionDraft = previousText

        do {
            try await campaign.cancelConfirmedAction()
        } catch {
            campaign.localErrorMessage = "取消確認失敗：\(error.localizedDescription)"
        }
        isSubmitting = false
    }

    func copyRoomID() {
        #if os(iOS)
        UIPasteboard.general.string = campaign.campaignId
        #endif
    }
}
