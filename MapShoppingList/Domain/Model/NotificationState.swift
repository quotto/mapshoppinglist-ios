import Foundation

/// 通知状態のドメインモデル。
public struct NotificationState: Equatable {
    public let placeId: UUID
    public var lastNotifiedAt: Date?
    public init(placeId: UUID, lastNotifiedAt: Date?) {
        self.placeId = placeId
        self.lastNotifiedAt = lastNotifiedAt
    }
}
