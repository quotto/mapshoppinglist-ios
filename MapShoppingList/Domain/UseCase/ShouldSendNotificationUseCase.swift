import Foundation

/// 通知送信可否を判定するユースケース。
public struct ShouldSendNotificationUseCase {
    public init() {}

    public func execute(state: NotificationState?, now: Date = Date()) throws -> Bool {
        if let snooze = state?.snoozeUntil, snooze > now {
            throw DomainError.notificationCooldown
        }
        if let last = state?.lastNotifiedAt, now.timeIntervalSince(last) < DomainConstants.notificationCooldownInterval {
            throw DomainError.notificationCooldown
        }
        return true
    }
}
