//
//  CampaignService+Listeners.swift
//  AI GM
//
//  Created by tony on 2026/4/6.
//

import Foundation
import FirebaseFirestore

extension CampaignService {

    // MARK: - Listening

    func startListening() {
        stopListening()

        listenCampaign()
        listenMessages()
        listenPlayers()
        refreshRoundListeners()
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        currentRoundListener?.remove()
        currentRoundListener = nil
        currentRoundActionsListener?.remove()
        currentRoundActionsListener = nil
    }

    internal func listenCampaign() {
        guard let campaignId else { return }

        let listener = db.collection("campaigns")
            .document(campaignId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.localErrorMessage = "房間監聽異常：\(error.localizedDescription)"
                    return
                }
                let data = snapshot?.data() ?? [:]

                self.campaignName = data["name"] as? String ?? ""
                self.hostId = data["hostId"] as? String ?? ""
                self.phase = CampaignPhase(rawValue: data["phase"] as? String ?? "") ?? .lobby
                self.provider = data["provider"] as? String ?? ""
                self.model = data["model"] as? String ?? ""
                let nextRoundId = data["currentRoundId"] as? String
                if nextRoundId != self.currentRoundId {
                    self.currentRoundId = nextRoundId
                    self.refreshRoundListeners()
                }
            }

        listeners.append(listener)
    }

    internal func listenMessages() {
        guard let campaignId else { return }

        let listener = db.collection("campaigns")
            .document(campaignId)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.localErrorMessage = "訊息監聽異常：\(error.localizedDescription)"
                    return
                }
                self.typedMessages = snapshot?.documents.map { self.decodeMessage(from: $0) } ?? []
                self.messages = self.typedMessages.map(\.text)
            }

        listeners.append(listener)
    }

    internal func listenPlayers() {
        guard let campaignId else { return }

        let listener = db.collection("campaigns")
            .document(campaignId)
            .collection("players")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.localErrorMessage = "玩家監聽異常：\(error.localizedDescription)"
                    return
                }
                self.players = snapshot?.documents.map { self.decodePlayer(from: $0) } ?? []
            }

        listeners.append(listener)
    }

    internal func refreshRoundListeners() {
        currentRoundListener?.remove()
        currentRoundListener = nil
        currentRoundActionsListener?.remove()
        currentRoundActionsListener = nil
        confirmedActions = []
        currentRoundNumber = 0

        guard let campaignId, let currentRoundId else { return }

        currentRoundListener = db.collection("campaigns")
            .document(campaignId)
            .collection("rounds")
            .document(currentRoundId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.localErrorMessage = "回合監聽異常：\(error.localizedDescription)"
                    return
                }
                let data = snapshot?.data() ?? [:]
                self.currentRoundNumber = data["number"] as? Int ?? 0
            }

        currentRoundActionsListener = db.collection("campaigns")
            .document(campaignId)
            .collection("rounds")
            .document(currentRoundId)
            .collection("actions")
            .whereField("isConfirmed", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.localErrorMessage = "行動監聽異常：\(error.localizedDescription)"
                    return
                }
                self.confirmedActions = snapshot?.documents.map { self.decodeAction(from: $0) } ?? []
            }
    }

    // MARK: - Decoding

    internal func decodePlayer(from document: QueryDocumentSnapshot) -> Player {
        let data = document.data()
        return Player(
            id: document.documentID,
            name: data["name"] as? String ?? "",
            strength: data["strength"] as? Int ?? 0,
            dexterity: data["dexterity"] as? Int ?? 0,
            intelligence: data["intelligence"] as? Int ?? 0,
            hp: data["hp"] as? Int ?? 0,
            maxHP: data["maxHP"] as? Int
        )
    }

    internal func decodeAction(from document: QueryDocumentSnapshot) -> CampaignAction {
        let data = document.data()
        return CampaignAction(
            id: document.documentID,
            playerId: data["playerId"] as? String ?? document.documentID,
            playerName: data["playerName"] as? String ?? "",
            text: data["text"] as? String ?? "",
            isConfirmed: data["isConfirmed"] as? Bool ?? false
        )
    }

    internal func decodeMessage(from document: QueryDocumentSnapshot) -> CampaignMessage {
        let data = document.data()
        return CampaignMessage(
            id: document.documentID,
            kind: CampaignMessageKind(rawValue: data["kind"] as? String ?? "") ?? .system,
            text: data["text"] as? String ?? "",
            roundNumber: data["roundNumber"] as? Int
        )
    }
}
