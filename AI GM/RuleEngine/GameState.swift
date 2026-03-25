//
//  GameState.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation
internal import Combine

class GameState: ObservableObject {
    @Published var players: [Player] = []
    
    // 👉 回合控制
    @Published var currentPlayerIndex: Int = 0
    
    init() {
        players = [
            Player(id: UUID().uuidString, name: "勇者", strength: 3, dexterity: 2, intelligence: 1, hp: 20, maxHP: 20),
            Player(id: UUID().uuidString, name: "盜賊", strength: 1, dexterity: 4, intelligence: 2, hp: 15, maxHP: 15)
        ]
    }
    
    var currentPlayer: Player {
        players[currentPlayerIndex]
    }
    
    func nextTurn() {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
    }
}
