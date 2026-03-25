//
//  ActionRule.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation

struct ActionRule: Decodable {
    let keywords: [String]
    let type: String
    let check: String?
}
