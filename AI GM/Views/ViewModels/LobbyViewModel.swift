//
//  LobbyViewModel.swift
//  AI GM
//
//  Created by tony on 2026/4/6.
//

import Foundation
internal import Combine

@MainActor
final class LobbyViewModel: ObservableObject {
    @Published var playerName: String {
        didSet { UserDefaults.standard.set(playerName, forKey: "savedPlayerName") }
    }
    @Published var roomName = "冒險房間"
    @Published var campaignInput: String {
        didSet { UserDefaults.standard.set(campaignInput, forKey: "savedRoomID") }
    }
    @Published var isSubmitting = false
    @Published private(set) var firebaseBlockingMessage: String?

    /// 啟動時是否已有上次儲存的房間 ID（曾加入或建立過房間），用來決定卡片排序，避免打字時重排
    let hasSavedRoomID: Bool

    private var cancellables = Set<AnyCancellable>()

    init() {
        let savedName = UserDefaults.standard.string(forKey: "savedPlayerName") ?? ""
        let savedRoomID = UserDefaults.standard.string(forKey: "savedRoomID") ?? ""
        self.playerName = savedName
        self.campaignInput = savedRoomID
        self.hasSavedRoomID = !savedRoomID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let userService = UserService.shared

        // 設定初始值
        let status = userService.sessionStatus
        self.firebaseBlockingMessage = userService.authErrorMessage ?? status.blockingMessage

        // 訂閱 UserService 的變化，讓 UI 能即時反映連線狀態
        Publishers.CombineLatest3(
            userService.$userId,
            userService.$isAuthenticating,
            userService.$authErrorMessage
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] userId, isAuthenticating, authError in
            let status = FirebaseSessionGate.status(authUserID: userId, isAuthenticating: isAuthenticating)
            self?.firebaseBlockingMessage = authError ?? status.blockingMessage
        }
        .store(in: &cancellables)
    }

    func retryFirebaseConnection() {
        Task {
            await UserService.shared.ensureSignedIn()
        }
    }

    func createRoom(campaign: CampaignService, configuration: AIHostConfiguration) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        await campaign.createCampaign(
            name: roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "冒險房間" : roomName,
            playerName: playerName,
            configuration: configuration
        )
        isSubmitting = false
    }

    func joinRoom(campaign: CampaignService) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        await campaign.joinCampaign(
            campaignId: campaignInput.trimmingCharacters(in: .whitespacesAndNewlines),
            playerName: playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        isSubmitting = false
    }
}
