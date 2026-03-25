//
//  AI_GMApp.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import SwiftUI
import FirebaseCore

@main
struct AI_GMApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
