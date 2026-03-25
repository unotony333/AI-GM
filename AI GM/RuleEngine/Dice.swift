//
//  Dice.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation

struct Dice {
    static func rollD20() -> Int {
        return Int.random(in: 1...20)
    }
}
