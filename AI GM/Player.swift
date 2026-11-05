//
//  Player.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation

struct Player: Identifiable {
    let id: String

    var name: String
    var strength: Int
    var dexterity: Int
    var intelligence: Int

    private(set) var hp: Int
    private(set) var maxHP: Int

    init(
        id: String,
        name: String,
        strength: Int,
        dexterity: Int,
        intelligence: Int,
        hp: Int,
        maxHP: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.strength = strength
        self.dexterity = dexterity
        self.intelligence = intelligence
        self.hp = max(hp, 0)
        self.maxHP = max(maxHP ?? hp, self.hp)
    }

    mutating func setHP(_ hp: Int) {
        self.hp = min(max(hp, 0), maxHP)
    }

    mutating func setMaxHP(_ maxHP: Int) {
        self.maxHP = max(maxHP, hp)
    }

    var isDown: Bool {
        hp == 0
    }

    func modifier(for stat: PlayerStat) -> Int {
        switch stat {
        case .strength: return strength
        case .dexterity: return dexterity
        case .intelligence: return intelligence
        }
    }

    var statSummary: String {
        "\(name) HP \(hp)/\(maxHP)\(isDown ? "（已倒下）" : ""), STR \(strength), DEX \(dexterity), INT \(intelligence)"
    }
}

extension Array where Element == Player {
    /// HP 存在房間資料上；玩家資料裡的 HP 只是加入房間時的初始值
    func applyingHP(_ hp: [String: Int]) -> [Player] {
        map { player in
            var player = player
            if let currentHP = hp[player.id] {
                player.setHP(currentHP)
            }
            return player
        }
    }
}
