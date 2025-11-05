import Foundation

/// 通知送信可否を判定するユースケース。
public struct ShouldSendNotificationUseCase {
    public init() {}

    public func execute(state: NotificationState?, now: Date = Date()) throws -> Bool {
        // スヌーズ中の場合は通知しない
        if let snooze = state?.snoozeUntil, snooze > now {
            throw DomainError.notificationSuppressed
        }
        return true
    }
}
