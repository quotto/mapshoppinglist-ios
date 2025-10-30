import Foundation

/// 通知状態のドメインモデル。
public struct NotificationState: Equatable {
    public let placeId: UUID
    public var lastNotifiedAt: Date?
    public var snoozeUntil: Date?

    public init(placeId: UUID, lastNotifiedAt: Date?, snoozeUntil: Date?) {
        self.placeId = placeId
        self.lastNotifiedAt = lastNotifiedAt
        self.snoozeUntil = snoozeUntil
    }
}
