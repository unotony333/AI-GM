import Foundation

@discardableResult
private func assertEqual<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ message: String
) -> Bool {
    guard actual == expected else {
        fputs("Assertion failed: \(message)\nExpected: \(expected)\nActual: \(actual)\n", stderr)
        exit(1)
    }

    return true
}

private func assertNil(
    _ actual: String?,
    _ message: String
) {
    guard actual == nil else {
        fputs("Assertion failed: \(message)\nExpected: nil\nActual: \(actual ?? "<nil>")\n", stderr)
        exit(1)
    }
}

private func testSignedOutSessionBlocksFirestoreActions() {
    let signedOut = FirebaseSessionGate.status(authUserID: nil, isAuthenticating: false)
    let signingIn = FirebaseSessionGate.status(authUserID: nil, isAuthenticating: true)

    assertNil(signedOut.userID, "未登入時不應該提供 Firestore 使用者 ID")
    assertEqual(
        signedOut.blockingMessage,
        "尚未連線到 Firebase，請稍後再試。",
        "未登入時應顯示清楚的阻擋訊息"
    )
    assertEqual(
        signingIn.blockingMessage,
        "正在連線到 Firebase，請稍後再試。",
        "登入進行中時應顯示等待訊息"
    )
}

private func testAuthenticatedSessionUsesFirebaseUID() {
    let status = FirebaseSessionGate.status(authUserID: "firebase-user-123", isAuthenticating: false)

    assertEqual(status.userID, "firebase-user-123", "登入後必須使用 Firebase auth.uid 當作使用者 ID")
    assertNil(status.blockingMessage, "登入完成後不應阻擋 Firestore 操作")
}

@main
struct FirebaseSessionGateManualTestsRunner {
    static func main() {
        testSignedOutSessionBlocksFirestoreActions()
        testAuthenticatedSessionUsesFirebaseUID()
        print("FirebaseSessionGate manual tests passed")
    }
}
