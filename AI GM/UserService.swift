//
//  UserService.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation
import FirebaseAuth
import os
internal import Combine

@MainActor
final class UserService: ObservableObject {
    static let shared = UserService()

    @Published private(set) var userId: String?
    @Published private(set) var isAuthenticating = true
    @Published private(set) var authErrorMessage: String?

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var hasCompletedInitialAuth = false

    var sessionStatus: FirebaseSessionStatus {
        FirebaseSessionGate.status(authUserID: userId, isAuthenticating: isAuthenticating)
    }

    private init() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }

                // 初次登入完成前，listener 會先用 nil 觸發一次，不要讓它蓋掉 isAuthenticating
                if user != nil || self.hasCompletedInitialAuth {
                    self.userId = user?.uid
                    self.isAuthenticating = false
                }

                if user != nil {
                    self.authErrorMessage = nil
                }
            }
        }

        Task {
            await ensureSignedIn()
        }
    }

    deinit {
        if let authStateListener {
            Auth.auth().removeStateDidChangeListener(authStateListener)
        }
    }

    func ensureSignedIn() async {
        if let currentUser = Auth.auth().currentUser {
            userId = currentUser.uid
            isAuthenticating = false
            hasCompletedInitialAuth = true
            authErrorMessage = nil
            return
        }

        isAuthenticating = true
        authErrorMessage = nil

        do {
            let result = try await signInAnonymously()
            userId = result.user.uid
            isAuthenticating = false
            hasCompletedInitialAuth = true
            authErrorMessage = nil
        } catch {
            userId = nil
            isAuthenticating = false
            hasCompletedInitialAuth = true

            let nsError = error as NSError
            AppLogger.auth.error("Firebase anonymous sign-in failed: \(nsError)")
            AppLogger.auth.error("Firebase sign-in error userInfo: \(nsError.userInfo)")

            authErrorMessage = "Firebase 匿名登入失敗：\(error.localizedDescription)"
        }
    }

    private func signInAnonymously() async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signInAnonymously { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result else {
                    continuation.resume(throwing: URLError(.userAuthenticationRequired))
                    return
                }

                continuation.resume(returning: result)
            }
        }
    }
}
