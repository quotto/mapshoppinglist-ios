import Testing
import Foundation
import CoreLocation
import UserNotifications
@testable import MapShoppingList

@Suite("NotificationSchedulerTests")
@MainActor
struct NotificationSchedulerTests {
    @Test("body describes empty list")
    func bodyForNoItems() async {
        let scheduler = NotificationScheduler(center: StubNotificationCenter())
        #expect(scheduler.body(for: []) == "買う予定のアイテムはありません")
    }

    @Test("body truncates over four items")
    func bodyForMultipleItemsTruncatesOverFour() async {
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
        #expect(body == "アイテム1, アイテム2, アイテム3, アイテム4 ほか2件")
    }

    @Test("schedule removes pending requests and enqueues new one")
    func scheduleRemovesExistingAndAddsRequest() async {
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

        #expect(center.removedIdentifiers == ["place_\(place.id.uuidString)"])
        #expect(center.addedRequests.count == 1)
        #expect(center.addedRequests.first?.content.body == "牛乳")
        #expect(center.addedRequests.first?.content.title == "近くに スーパー")
    }

    @Test("nearby suggestion notification formats title body and actions")
    func scheduleNearbySuggestionBuildsItemNotification() async {
        let center = StubNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let item = ShoppingItem(
            id: UUID(),
            title: "牛乳",
            note: nil,
            isPurchased: false,
            createdAt: Date(),
            updatedAt: Date(),
            placeIds: []
        )

        await scheduler.scheduleNearbySuggestion(
            item: item,
            placeName: "まいばすけっと",
            coordinate: CLLocationCoordinate2D(latitude: 35.68, longitude: 139.76),
            distanceMeters: 142
        )

        #expect(center.removedIdentifiers == ["nearby_item_\(item.id.uuidString)"])
        #expect(center.addedRequests.count == 1)
        #expect(center.addedRequests.first?.content.title == "牛乳が買えそうです")
        #expect(center.addedRequests.first?.content.body == "まいばすけっと(約140m)")
        #expect(center.addedRequests.first?.content.categoryIdentifier == NearbySuggestionNotificationContext.categoryIdentifier)
        #expect(center.addedRequests.first?.content.userInfo[AppNotificationUserInfoKey.itemId] as? String == item.id.uuidString)
    }

    @Test("requestAuthorization requests when notDetermined")
    func requestAuthorizationRequestsWhenNotDetermined() async {
        let center = StubNotificationCenter()
        center.status = .notDetermined
        let scheduler = NotificationScheduler(center: center)

        let result = await scheduler.requestAuthorization()

        #expect(center.requestedOptions == [.alert, .sound, .badge])
        #expect(result == .authorized)
        #expect(center.status == .authorized)
    }

    @Test("default notification action opens item detail")
    func defaultActionOpensItemDetail() async {
        let repository = InMemoryShoppingListRepository()
        let item = makeItem()
        try? await repository.createItem(item)
        let router = StubNotificationItemRouter()
        let handler = NotificationActionHandler(
            updatePurchasedUseCase: UpdatePurchasedStateUseCase(itemRepository: repository),
            deleteShoppingItemUseCase: DeleteShoppingItemUseCase(
                itemRepository: repository,
                linkRepository: InMemoryItemPlaceLinkRepository()
            ),
            itemRouter: router,
            mapRouter: StubNotificationMapRouter()
        )

        await handler.handle(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            context: makeContext(itemId: item.id)
        )

        #expect(router.openedItemIds == [item.id])
    }

    @Test("purchased action updates item state")
    func purchasedActionMarksItemPurchased() async throws {
        let repository = InMemoryShoppingListRepository()
        let item = makeItem()
        try await repository.createItem(item)
        let handler = NotificationActionHandler(
            updatePurchasedUseCase: UpdatePurchasedStateUseCase(itemRepository: repository),
            deleteShoppingItemUseCase: DeleteShoppingItemUseCase(
                itemRepository: repository,
                linkRepository: InMemoryItemPlaceLinkRepository()
            ),
            itemRouter: StubNotificationItemRouter(),
            mapRouter: StubNotificationMapRouter()
        )

        await handler.handle(
            actionIdentifier: NearbySuggestionNotificationContext.purchasedActionIdentifier,
            context: makeContext(itemId: item.id)
        )

        let updated = try await repository.fetchItem(id: item.id)
        #expect(updated?.isPurchased == true)
    }

    @Test("delete action removes item")
    func deleteActionDeletesItem() async throws {
        let repository = InMemoryShoppingListRepository()
        let item = makeItem()
        try await repository.createItem(item)
        let handler = NotificationActionHandler(
            updatePurchasedUseCase: UpdatePurchasedStateUseCase(itemRepository: repository),
            deleteShoppingItemUseCase: DeleteShoppingItemUseCase(
                itemRepository: repository,
                linkRepository: InMemoryItemPlaceLinkRepository()
            ),
            itemRouter: StubNotificationItemRouter(),
            mapRouter: StubNotificationMapRouter()
        )

        await handler.handle(
            actionIdentifier: NearbySuggestionNotificationContext.deleteActionIdentifier,
            context: makeContext(itemId: item.id)
        )

        let updated = try await repository.fetchItem(id: item.id)
        #expect(updated == nil)
    }

    @Test("map action falls back to item detail when map app cannot open")
    func mapActionFallsBackToItemDetail() async {
        let repository = InMemoryShoppingListRepository()
        let item = makeItem()
        try? await repository.createItem(item)
        let router = StubNotificationItemRouter()
        let mapRouter = StubNotificationMapRouter(result: false)
        let handler = NotificationActionHandler(
            updatePurchasedUseCase: UpdatePurchasedStateUseCase(itemRepository: repository),
            deleteShoppingItemUseCase: DeleteShoppingItemUseCase(
                itemRepository: repository,
                linkRepository: InMemoryItemPlaceLinkRepository()
            ),
            itemRouter: router,
            mapRouter: mapRouter
        )
        let context = makeContext(itemId: item.id)

        await handler.handle(
            actionIdentifier: NearbySuggestionNotificationContext.mapActionIdentifier,
            context: context
        )

        #expect(mapRouter.openedContexts == [context])
        #expect(router.openedItemIds == [item.id])
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

@MainActor
private final class StubNotificationItemRouter: NotificationItemRouting {
    private(set) var openedItemIds: [UUID] = []

    func openItemDetail(itemId: UUID) {
        openedItemIds.append(itemId)
    }
}

@MainActor
private final class StubNotificationMapRouter: NotificationMapRouting {
    private let result: Bool
    private(set) var openedContexts: [NearbySuggestionNotificationContext] = []

    init(result: Bool = true) {
        self.result = result
    }

    func openMap(for context: NearbySuggestionNotificationContext) async -> Bool {
        openedContexts.append(context)
        return result
    }
}

private extension NotificationSchedulerTests {
    func makeItem() -> ShoppingItem {
        ShoppingItem(
            id: UUID(),
            title: "牛乳",
            note: nil,
            isPurchased: false,
            createdAt: Date(),
            updatedAt: Date(),
            placeIds: []
        )
    }

    func makeContext(itemId: UUID) -> NearbySuggestionNotificationContext {
        NearbySuggestionNotificationContext(
            itemId: itemId,
            placeName: "まいばすけっと",
            placeLatitude: 35.68,
            placeLongitude: 139.76
        )
    }
}
