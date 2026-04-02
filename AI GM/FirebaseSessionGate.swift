import Foundation

struct FirebaseSessionStatus: Equatable {
    let userID: String?
    let blockingMessage: String?
}

enum FirebaseSessionGate {
    static func status(authUserID: String?, isAuthenticating: Bool) -> FirebaseSessionStatus {
        let trimmedUserID = authUserID?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedUserID, !trimmedUserID.isEmpty {
            return FirebaseSessionStatus(userID: trimmedUserID, blockingMessage: nil)
        }

        if isAuthenticating {
            return FirebaseSessionStatus(
                userID: nil,
                blockingMessage: "正在連線到 Firebase，請稍後再試。"
            )
        }

        return FirebaseSessionStatus(
            userID: nil,
            blockingMessage: "尚未連線到 Firebase，請稍後再試。"
        )
    }
}
