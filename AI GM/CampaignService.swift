//
//  CampaignService.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation
import FirebaseFirestore
internal import Combine

class CampaignService: ObservableObject {
    
    private let db = Firestore.firestore()
    
    @Published var campaignId: String?
    @Published var messages: [String] = []
    @Published var players: [Player] = []
    @Published var currentTurn: String = ""
    
    let userId = UserService.shared.userId
    
    private var listeners: [ListenerRegistration] = []
    
    private enum DefaultStats {
        static let hp = 20
        static let strength = 2
        static let dexterity = 2
        static let intelligence = 2
    }
    
    // MARK: - Create / Join
    
    func createCampaign(name: String, playerName: String) {
        let doc = db.collection("campaigns").document()
        campaignId = doc.documentID
        
        doc.setData([
            "name": name,
            "hostId": userId,
            "currentTurn": userId
        ])
        
        doc.collection("players").document(userId).setData([
            "name": playerName,
            "hp": DefaultStats.hp,
            "strength": DefaultStats.strength,
            "dexterity": DefaultStats.dexterity,
            "intelligence": DefaultStats.intelligence
        ])
        
        startListening()
    }
    
    func joinCampaign(campaignId: String, playerName: String) {
        self.campaignId = campaignId
        
        db.collection("campaigns")
            .document(campaignId)
            .collection("players")
            .document(userId)
            .setData([
                "name": playerName,
                "hp": DefaultStats.hp,
                "strength": DefaultStats.strength,
                "dexterity": DefaultStats.dexterity,
                "intelligence": DefaultStats.intelligence
            ])
        
        startListening()
    }
    
    // MARK: - Listening
    
    func startListening() {
        stopListening()
        
        listenMessages()
        listenPlayers()
        listenCampaign()
    }
    
    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    private func listenMessages() {
        guard let campaignId else { return }
        
        let listener = db.collection("campaigns")
            .document(campaignId)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { snapshot, _ in
                
                self.messages = snapshot?.documents.compactMap {
                    $0["text"] as? String
                } ?? []
            }
        listeners.append(listener)
    }
    
    private func listenPlayers() {
        guard let campaignId else { return }
        
        let listener = db.collection("campaigns")
            .document(campaignId)
            .collection("players")
            .addSnapshotListener { snapshot, _ in
                
                self.players = snapshot?.documents.compactMap { doc in
                    let d = doc.data()
                    return Player(
                        id: doc.documentID,
                        name: d["name"] as? String ?? "",
                        strength: d["strength"] as? Int ?? 0,
                        dexterity: d["dexterity"] as? Int ?? 0,
                        intelligence: d["intelligence"] as? Int ?? 0,
                        hp: d["hp"] as? Int ?? 0,
                        maxHP: d["hp"] as? Int ?? 0
                    )
                } ?? []
            }
        listeners.append(listener)
    }
    
    private func listenCampaign() {
        guard let campaignId else { return }
        
        let listener = db.collection("campaigns")
            .document(campaignId)
            .addSnapshotListener { snapshot, _ in
                
                let data = snapshot?.data()
                self.currentTurn = data?["currentTurn"] as? String ?? ""
            }
        listeners.append(listener)
    }

    // MARK: - Messaging

    func sendMessage(_ text: String) {
        guard let campaignId else { return }

        db.collection("campaigns")
            .document(campaignId)
            .collection("messages")
            .addDocument(data: [
                "text": text,
                "timestamp": Timestamp()
            ])
    }

    // MARK: - Turn

    func advanceTurn() {
        guard let campaignId else { return }

        guard let index = players.firstIndex(where: { $0.id == currentTurn }) else { return }

        let nextIndex = (index + 1) % players.count
        let nextPlayerId = players[nextIndex].id

        db.collection("campaigns")
            .document(campaignId)
            .updateData([
                "currentTurn": nextPlayerId
            ])
    }
}
