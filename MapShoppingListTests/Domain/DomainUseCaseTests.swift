import Testing
import Foundation
@testable import MapShoppingList

@Suite("DomainUseCaseTests")
struct DomainUseCaseTests {
    @Test("CreatePlace detects duplicates")
    func createPlaceDetectsDuplicate() async throws {
        let repo = InMemoryPlacesRepository()
        let place = Place(id: UUID(), name: "A店", latitudeE6: 100, longitudeE6: 200, note: nil, lastUsedAt: nil, isActive: true)
        try await repo.createPlace(place)
        let useCase = CreatePlaceUseCase(placesRepository: repo)
        let duplicate = Place(id: UUID(), name: "B店", latitudeE6: 100, longitudeE6: 200, note: nil, lastUsedAt: nil, isActive: false)

        let error = await #expect(throws: DomainError.self) {
            try await useCase.execute(place: duplicate)
        }
        #expect(error == .duplicatePlace)
    }

    @Test("CreatePlace enforces limit")
    func createPlaceRespectsLimit() async throws {
        let repo = InMemoryPlacesRepository()
        for _ in 0..<DomainConstants.placeLimit {
            let id = UUID()
            let place = Place(id: id, name: "店\(id)", latitudeE6: Int.random(in: 0...1000), longitudeE6: Int.random(in: 0...1000), note: nil, lastUsedAt: nil, isActive: false)
            try await repo.createPlace(place)
        }
        let useCase = CreatePlaceUseCase(placesRepository: repo)
        let newPlace = Place(id: UUID(), name: "上限超え", latitudeE6: 9999, longitudeE6: 9999, note: nil, lastUsedAt: nil, isActive: false)

        let error = await #expect(throws: DomainError.self) {
            try await useCase.execute(place: newPlace)
        }
        guard let error else {
            Issue.record("想定外のエラー: nil")
            return
        }
        guard case let .placeLimitExceeded(max) = error else {
            Issue.record("想定外のエラー: \(error)")
            return
        }
        #expect(max == DomainConstants.placeLimit)
    }

    @Test("Add/Update item syncs links")
    func addAndUpdateItemSyncsLinks() async throws {
        let itemRepo = InMemoryShoppingListRepository()
        let linkRepo = InMemoryItemPlaceLinkRepository()
        let addUseCase = AddShoppingItemUseCase(itemRepository: itemRepo, linkRepository: linkRepo)
        let updateUseCase = UpdateItemUseCase(itemRepository: itemRepo, linkRepository: linkRepo)

        let itemId = UUID()
        let now = Date()
        let item = ShoppingItem(id: itemId, title: "牛乳", note: nil, isPurchased: false, createdAt: now, updatedAt: now, placeIds: [])
        let placeA = UUID()
        try await addUseCase.execute(item: item, placeIds: [placeA])
        let linkedAfterCreate = try await linkRepo.fetchPlaceIds(forItem: itemId)
        #expect(linkedAfterCreate == [placeA])

        let placeB = UUID()
        var updatedItem = item
        updatedItem.title = "牛乳とパン"
        updatedItem.placeIds = [placeA, placeB]
        try await updateUseCase.execute(item: updatedItem, updatedPlaceIds: [placeA, placeB])
        let linkedAfterUpdate = try await linkRepo.fetchPlaceIds(forItem: itemId)
        #expect(linkedAfterUpdate == [placeA, placeB])
    }

    @Test("BuildGeofenceSyncPlan respects monitor limit")
    func buildGeofenceSyncPlanRespectsLimit() async throws {
        let registry = InMemoryGeofenceRegistryRepository()
        let useCase = BuildGeofenceSyncPlanUseCase(registryRepository: registry)
        let now = Date()
        let places = (0..<25).map { index in
            Place(
                id: UUID(),
                name: "地点\(index)",
                latitudeE6: index,
                longitudeE6: index,
                note: nil,
                lastUsedAt: now.addingTimeInterval(TimeInterval(-index * 60)),
                isActive: true
            )
        }

        let plan = try await useCase.execute(activePlaces: places)
        #expect(plan.toRegister.count == DomainConstants.geofenceMonitorLimit)
        #expect(plan.toUnregister.isEmpty)

        try await registry.registerGeofences(plan.toRegister)
        let secondPlan = try await useCase.execute(activePlaces: Array(places.prefix(10)))
        #expect(secondPlan.toRegister.isEmpty)
        #expect(secondPlan.toUnregister.count == DomainConstants.geofenceMonitorLimit - 10)
    }

    @Test("ShouldSendNotification returns true")
    func shouldSendNotificationAlwaysTrue() throws {
        let useCase = ShouldSendNotificationUseCase()
        let now = Date()

        let state = NotificationState(placeId: UUID(), lastNotifiedAt: now)
        #expect(try useCase.execute(state: state, now: now))
        #expect(try useCase.execute(state: nil, now: now))
    }

    @Test("MarkPlaceItemsPurchased updates repository")
    func markPlaceItemsPurchased() async throws {
        let itemRepo = InMemoryShoppingListRepository()
        let placeRepo = InMemoryPlacesRepository()
        let placeId = UUID()
        let place = Place(id: placeId, name: "スーパー", latitudeE6: 1, longitudeE6: 1, note: nil, lastUsedAt: nil, isActive: true)
        try await placeRepo.createPlace(place)

        let itemId = UUID()
        let now = Date()
        let item = ShoppingItem(id: itemId, title: "卵", note: nil, isPurchased: false, createdAt: now, updatedAt: now, placeIds: [placeId])
        try await itemRepo.createItem(item)

        let useCase = MarkPlaceItemsPurchasedUseCase(itemRepository: itemRepo, placesRepository: placeRepo)
        try await useCase.execute(placeId: placeId)

        let updated = try await itemRepo.fetchItem(id: itemId)
        #expect(updated?.isPurchased == true)
    }
}
