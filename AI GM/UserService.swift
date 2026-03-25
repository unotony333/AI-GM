//
//  UserService.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation

class UserService {
    static let shared = UserService()

    let userId: String

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "userId") {
            userId = saved
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "userId")
            userId = newId
        }
    }
}
