//
//  GameAction.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation

enum GameActionType {
    case attack
    case dodge
    case investigate
    case unknown
}

struct GameAction {
    let type: String
    let checkType: CheckType?
    let originalText: String
}
