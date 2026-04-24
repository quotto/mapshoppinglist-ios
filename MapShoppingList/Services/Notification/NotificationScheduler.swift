import Foundation
import CoreLocation
import UserNotifications

@MainActor
protocol NotificationCentering {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async -> Bool
    func removePendingRequests(withIdentifiers identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}

@MainActor
extension UNUserNotificationCenter: NotificationCentering {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization(options: options) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

@MainActor
protocol NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus
    @discardableResult
    func requestAuthorization() async -> UNAuthorizationStatus
    func requestAuthorizationIfNeeded() async
    func registerCategories()
    func schedule(place: Place, items: [ShoppingItem]) async
    func scheduleNearbySuggestion(
        item: ShoppingItem,
        placeName: String,
        coordinate: CLLocationCoordinate2D,
        distanceMeters: CLLocationDistance
    ) async
}

@MainActor
class NotificationScheduler: NotificationScheduling {
    private let center: NotificationCentering

    init(center: NotificationCentering = UNUserNotificationCenter.current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.authorizationStatus()
    }

    @discardableResult
    func requestAuthorization() async -> UNAuthorizationStatus {
        let current = await authorizationStatus()
        guard current == .notDetermined else { return current }
        _ = await center.requestAuthorization(options: [.alert, .sound, .badge])
        return await authorizationStatus()
    }

    func requestAuthorizationIfNeeded() async {
        _ = await requestAuthorization()
    }

    func registerCategories() {
        let purchased = UNNotificationAction(
            identifier: NearbySuggestionNotificationContext.purchasedActionIdentifier,
            title: "購入済み"
        )
        let delete = UNNotificationAction(
            identifier: NearbySuggestionNotificationContext.deleteActionIdentifier,
            title: "削除",
            options: [.destructive]
        )
        let map = UNNotificationAction(
            identifier: NearbySuggestionNotificationContext.mapActionIdentifier,
            title: "地図",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: NearbySuggestionNotificationContext.categoryIdentifier,
            actions: [purchased, delete, map],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func schedule(place: Place, items: [ShoppingItem]) async {
        let content = UNMutableNotificationContent()
        content.title = "近くに \(place.name)"
        content.body = body(for: items)
        content.sound = .default
        content.userInfo = [
            "placeId": place.id.uuidString
        ]
        let identifier = "place_\(place.id.uuidString)"
        center.removePendingRequests(withIdentifiers: [identifier])
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        do {
            try await center.add(request)
        } catch {
        }
    }

    func scheduleNearbySuggestion(
        item: ShoppingItem,
        placeName: String,
        coordinate: CLLocationCoordinate2D,
        distanceMeters: CLLocationDistance
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "\(item.title)が買えそうです"
        content.body = "\(placeName)(\(approximateDistanceText(for: distanceMeters)))"
        content.sound = .default
        content.categoryIdentifier = NearbySuggestionNotificationContext.categoryIdentifier
        content.userInfo = NearbySuggestionNotificationContext(
            itemId: item.id,
            placeName: placeName,
            placeLatitude: coordinate.latitude,
            placeLongitude: coordinate.longitude
        ).userInfo

        let identifier = nearbySuggestionIdentifier(for: item.id)
        center.removePendingRequests(withIdentifiers: [identifier])
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        do {
            try await center.add(request)
        } catch {
        }
    }

    func body(for items: [ShoppingItem]) -> String {
        let pending = items.prefix(4).map { $0.title }
        if pending.isEmpty { return "買う予定のアイテムはありません" }
        if items.count <= 4 {
            return pending.joined(separator: ", ")
        } else {
            return pending.joined(separator: ", ") + " ほか\(items.count - pending.count)件"
        }
    }

    func nearbySuggestionIdentifier(for itemId: UUID) -> String {
        "nearby_item_\(itemId.uuidString)"
    }

    func approximateDistanceText(for distanceMeters: CLLocationDistance) -> String {
        let roundedMeters = max(10, Int(distanceMeters.rounded(.toNearestOrAwayFromZero) / 10) * 10)
        return "約\(roundedMeters)m"
    }
}
