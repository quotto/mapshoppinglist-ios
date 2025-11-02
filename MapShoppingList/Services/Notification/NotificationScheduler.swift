import Foundation
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
    func schedule(place: Place, items: [ShoppingItem]) async
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

    func body(for items: [ShoppingItem]) -> String {
        let pending = items.prefix(4).map { $0.title }
        if pending.isEmpty { return "買う予定のアイテムはありません" }
        if items.count <= 4 {
            return pending.joined(separator: ", ")
        } else {
            return pending.joined(separator: ", ") + " ほか\(items.count - pending.count)件"
        }
    }
}
