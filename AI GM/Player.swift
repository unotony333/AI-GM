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

    var hp: Int
    var maxHP: Int
}
