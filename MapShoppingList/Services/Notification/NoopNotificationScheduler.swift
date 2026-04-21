import Foundation
import CoreLocation
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

    func registerCategories() {}

    func schedule(place: Place, items: [ShoppingItem]) async {}

    func scheduleNearbySuggestion(
        item: ShoppingItem,
        placeName: String,
        coordinate: CLLocationCoordinate2D,
        distanceMeters: CLLocationDistance
    ) async {}
}
