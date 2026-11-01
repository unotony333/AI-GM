//
//  CampaignService.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation
import FirebaseFirestore
import os
internal import Combine

@MainActor
final class CampaignService: ObservableObject {
    enum CampaignServiceError: LocalizedError {
        case campaignNotFound
        case unavailableUserSession(String)

        var errorDescription: String? {
            switch self {
            case .campaignNotFound:
                return "找不到這個房間"
            case .unavailableUserSession(let message):
                return message
            }
        }
    }

    let db = Firestore.firestore()

    @Published var campaignId: String?
    @Published var campaignName: String = ""
    @Published var hostId: String = ""
    @Published var phase: CampaignPhase = .lobby
    @Published var provider: String = ""
    @Published var model: String = ""
    @Published var currentRoundId: String?
    @Published var currentRoundNumber: Int = 0
    @Published var typedMessages: [CampaignMessage] = []
    @Published var players: [Player] = []
    @Published var confirmedActions: [CampaignAction] = []
    @Published var localErrorMessage: String?

    var listeners: [ListenerRegistration] = []
    var currentRoundListener: ListenerRegistration?
    var currentRoundActionsListener: ListenerRegistration?

    private enum DefaultStats {
        static let hp = 20
        static let strength = 2
        static let dexterity = 2
        static let intelligence = 2
    }

    var isHost: Bool {
        guard let userId = UserService.shared.sessionStatus.userID else { return false }
        return hostId == userId
    }

    var readyPlayerCount: Int {
        confirmedActions.count
    }

    var areAllPlayersReady: Bool {
        !players.isEmpty && confirmedActions.count == players.count
    }

    var playersWithoutAction: [Player] {
        players.filter { player in
            !confirmedActions.contains { $0.playerId == player.id }
        }
    }

    var myConfirmedAction: CampaignAction? {
        guard let userId = UserService.shared.sessionStatus.userID else { return nil }
        return confirmedActions.first { $0.playerId == userId }
    }

    // MARK: - Create / Join

    func createCampaign(name: String, playerName: String, configuration: AIHostConfiguration) async {
        do {
            let userId = try requireUserID()
            let validatedConfiguration = try configuration.validated()
            let doc = db.collection("campaigns").document()
            let now = Timestamp()

            try AIHostConfigurationStore.save(validatedConfiguration, campaignId: doc.documentID)
            try AIHostConfigurationStore.saveLastUsed(validatedConfiguration)

            try await doc.setData([
                "name": name,
                "hostId": userId,
                "phase": CampaignPhase.lobby.rawValue,
                "provider": validatedConfiguration.provider,
                "model": validatedConfiguration.model,
                "createdAt": now,
                "updatedAt": now
            ])

            try await upsertPlayer(
                campaignId: doc.documentID,
                playerId: userId,
                playerName: playerName
            )

            campaignId = doc.documentID
            AppLogger.firebase.info("Campaign created: \(doc.documentID)")
            startListening()
        } catch {
            localErrorMessage = "建立房間失敗：\(error.localizedDescription)"
        }
    }

    func joinCampaign(campaignId: String, playerName: String) async {
        let trimmedCampaignId = campaignId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlayerName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let userId = try requireUserID()
            let campaignDocument = db.collection("campaigns").document(trimmedCampaignId)
            let snapshot = try await campaignDocument.getDocument()
            guard snapshot.exists else {
                throw CampaignServiceError.campaignNotFound
            }

            try await upsertPlayer(
                campaignId: trimmedCampaignId,
                playerId: userId,
                playerName: trimmedPlayerName
            )

            self.campaignId = trimmedCampaignId
            startListening()
        } catch {
            self.campaignId = nil
            localErrorMessage = "加入房間失敗：\(error.localizedDescription)"
        }
    }

    /// 回到大廳；房間資料留在 Firestore，之後可以用房間 ID 再加入
    func leaveCampaign() {
        stopListening()
        campaignId = nil
        campaignName = ""
        hostId = ""
        phase = .lobby
        provider = ""
        model = ""
        currentRoundId = nil
        currentRoundNumber = 0
        typedMessages = []
        players = []
        confirmedActions = []
    }

    private func upsertPlayer(campaignId: String, playerId: String, playerName: String) async throws {
        try await db.collection("campaigns")
            .document(campaignId)
            .collection("players")
            .document(playerId)
            .setData([
                "name": playerName,
                "hp": DefaultStats.hp,
                "maxHP": DefaultStats.hp,
                "strength": DefaultStats.strength,
                "dexterity": DefaultStats.dexterity,
                "intelligence": DefaultStats.intelligence,
                "isConnected": true,
                "joinedAt": Timestamp()
            ], merge: true)
    }

    func updateAIConfiguration(_ configuration: AIHostConfiguration) async {
        guard isHost, let campaignId else { return }

        do {
            let validatedConfiguration = try configuration.validated()
            
            try AIHostConfigurationStore.save(validatedConfiguration, campaignId: campaignId)
            
            try AIHostConfigurationStore.saveLastUsed(validatedConfiguration)

            try await updateCampaign(campaignId, [
                "provider": validatedConfiguration.provider,
                "model": validatedConfiguration.model,
                "updatedAt": Timestamp()
            ])
            
            self.provider = validatedConfiguration.provider
            self.model = validatedConfiguration.model
        } catch {
            localErrorMessage = "更新 AI 設定失敗：\(error.localizedDescription)"
        }
    }

    // MARK: - Messaging

    func sendMessage(_ text: String) {
        Task {
            do {
                try await publishMessage(
                    kind: .player,
                    text: text,
                    roundNumber: currentRoundNumber == 0 ? nil : currentRoundNumber
                )
            } catch {
                localErrorMessage = "送出訊息失敗：\(error.localizedDescription)"
            }
        }
    }

    private func publishMessage(kind: CampaignMessageKind, text: String, roundNumber: Int?) async throws {
        guard let campaignId else { return }

        let document = db.collection("campaigns")
            .document(campaignId)
            .collection("messages")
            .document()

        try await document.setData(messagePayload(kind: kind, text: text, roundNumber: roundNumber))
    }

    private func messagePayload(kind: CampaignMessageKind, text: String, roundNumber: Int?) -> [String: Any] {
        var payload: [String: Any] = [
            "kind": kind.rawValue,
            "text": text,
            "timestamp": Timestamp()
        ]

        if let roundNumber {
            payload["roundNumber"] = roundNumber
        }

        return payload
    }

    // MARK: - Actions

    func confirmAction(text: String) async throws {
        guard let campaignId, let currentRoundId else { return }
        let userId = try requireUserID()

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let playerName = players.first(where: { $0.id == userId })?.name ?? ""

        try await db.collection("campaigns")
            .document(campaignId)
            .collection("rounds")
            .document(currentRoundId)
            .collection("actions")
            .document(userId)
            .setData([
                "playerId": userId,
                "playerName": playerName,
                "text": trimmedText,
                "isConfirmed": true,
                "confirmedAt": Timestamp(),
                "updatedAt": Timestamp()
            ], merge: true)
    }

    func cancelConfirmedAction() async throws {
        guard let campaignId, let currentRoundId else { return }
        let userId = try requireUserID()

        // 標記為未確認而不是刪除：README 建議的 Firestore 規則只開放 create / update，
        // 行動監聽本來就只抓已確認的行動
        try await db.collection("campaigns")
            .document(campaignId)
            .collection("rounds")
            .document(currentRoundId)
            .collection("actions")
            .document(userId)
            .setData([
                "isConfirmed": false,
                "updatedAt": Timestamp()
            ], merge: true)
    }

    // MARK: - Flow

    func startGame(using engine: GameEngine) async {
        guard isHost, let campaignId else { return }

        do {
            guard let configuration = try AIHostConfigurationStore.load(campaignId: campaignId) else {
                localErrorMessage = "找不到房主 AI 設定"
                return
            }

            try await updateCampaign(campaignId, [
                "phase": CampaignPhase.starting.rawValue,
                "updatedAt": Timestamp()
            ])
            AppLogger.firebase.info("Game starting for campaign \(campaignId)")

            let narration = try await engine.generateOpeningNarration(
                players: players,
                configuration: configuration
            )

            try await commitNarration(
                campaignId: campaignId,
                kind: .opening,
                text: narration,
                roundNumber: nil,
                nextRoundNumber: 1
            )
        } catch {
            // 用開始時的 campaignId 退回，房主中途離開房間也能還原
            try? await updateCampaign(campaignId, [
                "phase": CampaignPhase.lobby.rawValue,
                "updatedAt": Timestamp()
            ])
            if !isCancellation(error) {
                localErrorMessage = "開始遊戲失敗：\(error.localizedDescription)"
            }
        }
    }

    /// 至少一人確認就能結算，沒確認的玩家這回合視為沒有行動，避免有人離線就卡住
    func continueRound(using engine: GameEngine) async {
        guard isHost, !confirmedActions.isEmpty, let campaignId else { return }

        do {
            guard let configuration = try AIHostConfigurationStore.load(campaignId: campaignId) else {
                localErrorMessage = "找不到房主 AI 設定"
                return
            }

            try await updateCampaign(campaignId, [
                "phase": CampaignPhase.resolvingTurn.rawValue,
                "updatedAt": Timestamp()
            ])
            AppLogger.firebase.info("Resolving round \(self.currentRoundNumber) for campaign \(campaignId)")

            let narration = try await engine.resolveRound(
                messages: typedMessages,
                players: players,
                actions: confirmedActions,
                configuration: configuration
            )

            try await commitNarration(
                campaignId: campaignId,
                kind: .narration,
                text: narration,
                roundNumber: currentRoundNumber == 0 ? nil : currentRoundNumber,
                nextRoundNumber: currentRoundNumber + 1
            )
        } catch {
            try? await updateCampaign(campaignId, [
                "phase": CampaignPhase.collectingActions.rawValue,
                "updatedAt": Timestamp()
            ])
            if !isCancellation(error) {
                localErrorMessage = "結算回合失敗：\(error.localizedDescription)"
            }
        }
    }

    /// 敘事、下一回合與 phase 一次寫入，避免中途失敗留下重複的敘事或半套回合
    private func commitNarration(
        campaignId: String,
        kind: CampaignMessageKind,
        text: String,
        roundNumber: Int?,
        nextRoundNumber: Int
    ) async throws {
        let campaignDocument = db.collection("campaigns").document(campaignId)
        let messageDocument = campaignDocument.collection("messages").document()
        let roundDocument = campaignDocument.collection("rounds").document()

        let batch = db.batch()
        batch.setData(messagePayload(kind: kind, text: text, roundNumber: roundNumber), forDocument: messageDocument)
        batch.setData([
            "number": nextRoundNumber,
            "status": RoundStatus.collecting.rawValue,
            "createdAt": Timestamp()
        ], forDocument: roundDocument)
        batch.setData([
            "currentRoundId": roundDocument.documentID,
            "phase": CampaignPhase.collectingActions.rawValue,
            "updatedAt": Timestamp()
        ], forDocument: campaignDocument, merge: true)
        try await batch.commit()
    }

    private func updateCampaign(_ campaignId: String, _ data: [String: Any]) async throws {
        try await db.collection("campaigns")
            .document(campaignId)
            .setData(data, merge: true)
    }

    /// 進行中的網路請求被取消時，URLSession 丟的是 URLError.cancelled 而不是 CancellationError
    private func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    private func requireUserID() throws -> String {
        let userService = UserService.shared
        let status = userService.sessionStatus

        if let userId = status.userID {
            return userId
        }

        throw CampaignServiceError.unavailableUserSession(
            userService.authErrorMessage ?? status.blockingMessage ?? "尚未連線到 Firebase，請稍後再試。"
        )
    }

}
