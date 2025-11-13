import Foundation
import UserNotifications

/// テストやプレビューで通知スケジューラを無効化する実装。
@MainActor
final class NoopNotificationScheduler: NotificationScheduling {
    private let status: UNAuthorizationStatus

    init(status: UNAuthorizationStatus = .authorized) {
        self.status = status
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    @discardableResult
    func requestAuthorization() async -> UNAuthorizationStatus { status }

    func requestAuthorizationIfNeeded() async {}

    func schedule(place: Place, items: [ShoppingItem]) async {}
}
