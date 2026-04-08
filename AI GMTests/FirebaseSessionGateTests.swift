//
//  FirebaseSessionGateTests.swift
//  AI GMTests
//

import XCTest
@testable import AI_GM

final class FirebaseSessionGateTests: XCTestCase {

    func testSignedOutSessionBlocksFirestoreActions() {
        let signedOut = FirebaseSessionGate.status(authUserID: nil, isAuthenticating: false)
        let signingIn = FirebaseSessionGate.status(authUserID: nil, isAuthenticating: true)

        XCTAssertNil(signedOut.userID, "未登入時不應該提供 Firestore 使用者 ID")
        XCTAssertEqual(
            signedOut.blockingMessage,
            "尚未連線到 Firebase，請稍後再試。",
            "未登入時應顯示清楚的阻擋訊息"
        )
        XCTAssertEqual(
            signingIn.blockingMessage,
            "正在連線到 Firebase，請稍後再試。",
            "登入進行中時應顯示等待訊息"
        )
    }

    func testAuthenticatedSessionUsesFirebaseUID() {
        let status = FirebaseSessionGate.status(authUserID: "firebase-user-123", isAuthenticating: false)

        XCTAssertEqual(status.userID, "firebase-user-123", "登入後必須使用 Firebase auth.uid 當作使用者 ID")
        XCTAssertNil(status.blockingMessage, "登入完成後不應阻擋 Firestore 操作")
    }
}
