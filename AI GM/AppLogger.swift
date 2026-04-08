//
//  AppLogger.swift
//  AI GM
//

import os

enum AppLogger {
    static let ai       = Logger(subsystem: "com.aigm", category: "AI")
    static let firebase = Logger(subsystem: "com.aigm", category: "Firebase")
    static let keychain = Logger(subsystem: "com.aigm", category: "Keychain")
    static let auth     = Logger(subsystem: "com.aigm", category: "Auth")
}
