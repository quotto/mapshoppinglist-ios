import XCTest
import UserNotifications
@testable import MapShoppingList

@MainActor
final class NotificationSchedulerTests: XCTestCase {
    func testBodyForNoItems() {
        let scheduler = NotificationScheduler(center: StubNotificationCenter())
        XCTAssertEqual(scheduler.body(for: []), "買う予定のアイテムはありません")
    }

    func testBodyForMultipleItemsTruncatesOverFour() {
        let scheduler = NotificationScheduler(center: StubNotificationCenter())
        let items = (1...6).map { index in
            ShoppingItem(
                id: UUID(),
                title: "アイテム\(index)",
                note: nil,
                isPurchased: false,
                createdAt: Date(),
                updatedAt: Date(),
                placeIds: []
            )
        }
        let body = scheduler.body(for: items)
        XCTAssertEqual(body, "アイテム1, アイテム2, アイテム3, アイテム4 ほか2件")
    }

    func testScheduleRemovesExistingAndAddsRequest() async {
        let center = StubNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let place = Place(
            id: UUID(),
            name: "スーパー",
            latitudeE6: 100,
            longitudeE6: 200,
            note: nil,
            lastUsedAt: Date(),
            isActive: true
        )
        let items = [
            ShoppingItem(id: UUID(), title: "牛乳", note: nil, isPurchased: false, createdAt: Date(), updatedAt: Date(), placeIds: [place.id])
        ]

        await scheduler.schedule(place: place, items: items)

        XCTAssertEqual(center.removedIdentifiers, ["place_\(place.id.uuidString)"])
        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(center.addedRequests.first?.content.body, "牛乳")
        XCTAssertEqual(center.addedRequests.first?.content.title, "近くに スーパー")
    }

    func testRequestAuthorizationRequestsWhenNotDetermined() async {
        let center = StubNotificationCenter()
        center.status = .notDetermined
        let scheduler = NotificationScheduler(center: center)

        let result = await scheduler.requestAuthorization()

        XCTAssertEqual(center.requestedOptions, [.alert, .sound, .badge])
        XCTAssertEqual(result, .authorized)
        XCTAssertEqual(center.status, .authorized)
    }
}

// MARK: - Stubs

@MainActor
private final class StubNotificationCenter: NotificationCentering {
    var status: UNAuthorizationStatus = .authorized
    var requestShouldSucceed: Bool = true
    private(set) var requestedOptions: UNAuthorizationOptions?
    private(set) var removedIdentifiers: [String] = []
    private(set) var addedRequests: [UNNotificationRequest] = []

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async -> Bool {
        requestedOptions = options
        status = requestShouldSucceed ? .authorized : .denied
        return requestShouldSucceed
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
        if requestShouldSucceed == false {
            throw StubError.failed
        }
    }

    enum StubError: Error {
        case failed
    }
}
