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

    var statSummary: String {
        "\(name) HP \(hp)/\(maxHP), STR \(strength), DEX \(dexterity), INT \(intelligence)"
    }
}
