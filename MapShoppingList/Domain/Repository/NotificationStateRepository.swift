import Foundation

/// 通知状態を保持する。
public protocol NotificationStateRepository {
    func fetchState(forPlace placeId: UUID) async throws -> NotificationState?
    func upsert(state: NotificationState) async throws
}
