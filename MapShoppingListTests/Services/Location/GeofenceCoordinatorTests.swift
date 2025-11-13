import Testing
import Foundation
import UserNotifications
@testable import MapShoppingList

@Suite("GeofenceCoordinatorTests")
@MainActor
struct GeofenceCoordinatorTests {
    @Test("sync registers/unregisters active geofences")
    func syncRegistersAndUnregisters() async {
        let geofenceRepo = StubGeofenceRepository()
        let placesRepo = StubPlacesRepository()
        let itemsRepo = StubShoppingListRepository()
        let notificationRepo = StubNotificationStateRepository()

        let placeA = Place(id: UUID(), name: "A", latitudeE6: 100, longitudeE6: 200, note: nil, lastUsedAt: Date(), isActive: true)
        let placeB = Place(id: UUID(), name: "B", latitudeE6: 300, longitudeE6: 400, note: nil, lastUsedAt: nil, isActive: false)
        placesRepo.places = [placeA, placeB]

        let coordinator = GeofenceCoordinator(
            placesRepository: placesRepo,
            loadAllPlacesUseCase: LoadAllPlacesUseCase(placesRepository: placesRepo),
            loadShoppingItemsUseCase: LoadShoppingItemsUseCase(repository: itemsRepo),
            notificationStateRepository: notificationRepo,
            shouldSendNotificationUseCase: ShouldSendNotificationUseCase(),
            buildGeofenceSyncPlanUseCase: BuildGeofenceSyncPlanUseCase(registryRepository: geofenceRepo),
            geofenceRepository: geofenceRepo,
            notificationScheduler: NotificationScheduler()
        )

        let initialIds = geofenceRepo.current.map { $0.id }
        await coordinator.syncActiveGeofences()

        #expect(geofenceRepo.registered.count == 1)
        #expect(geofenceRepo.registered.first?.placeId == placeA.id)
        #expect(geofenceRepo.unregistered.count == 1)
        #expect(initialIds.contains(where: { $0 == geofenceRepo.unregistered.first?.id }))
    }

    @Test("handle region entry schedules notification")
    func handleRegionEntrySchedulesNotification() async throws {
        let geofenceRepo = StubGeofenceRepository()
        let placesRepo = StubPlacesRepository()
        let itemsRepo = StubShoppingListRepository()
        let notificationRepo = StubNotificationStateRepository()
        let scheduler = StubNotificationScheduler()

        let placeId = UUID()
        let place = Place(id: placeId, name: "スーパー", latitudeE6: 100, longitudeE6: 200, note: nil, lastUsedAt: Date(), isActive: true)
        placesRepo.places = [place]
        itemsRepo.items = [
            ShoppingItem(id: UUID(), title: "牛乳", note: nil, isPurchased: false, createdAt: Date(), updatedAt: Date(), placeIds: [placeId])
        ]

        let coordinator = GeofenceCoordinator(
            placesRepository: placesRepo,
            loadAllPlacesUseCase: LoadAllPlacesUseCase(placesRepository: placesRepo),
            loadShoppingItemsUseCase: LoadShoppingItemsUseCase(repository: itemsRepo),
            notificationStateRepository: notificationRepo,
            shouldSendNotificationUseCase: ShouldSendNotificationUseCase(),
            buildGeofenceSyncPlanUseCase: BuildGeofenceSyncPlanUseCase(registryRepository: geofenceRepo),
            geofenceRepository: geofenceRepo,
            notificationScheduler: scheduler
        )

        await coordinator.handleRegionEntry(placeId: placeId)

        #expect(scheduler.scheduledPlaceId == placeId)
        let savedState = try await notificationRepo.fetchState(forPlace: placeId)
        #expect(savedState?.lastNotifiedAt != nil)
    }
}

// MARK: - Stubs

@MainActor
private final class StubGeofenceRepository: GeofenceRegistryRepository {
    var current: [GeofenceSpec] = [
        GeofenceSpec(id: "place_\(UUID().uuidString)", placeId: UUID(), latitudeE6: 0, longitudeE6: 0, radius: 100)
    ]
    private(set) var registered: [GeofenceSpec] = []
    private(set) var unregistered: [GeofenceSpec] = []
    var onRegionEntered: ((UUID) -> Void)?

    func fetchRegisteredGeofences() async throws -> [GeofenceSpec] {
        current
    }

    func registerGeofences(_ geofences: [GeofenceSpec]) async throws {
        registered.append(contentsOf: geofences)
        current.append(contentsOf: geofences)
    }

    func unregisterGeofences(_ geofences: [GeofenceSpec]) async throws {
        unregistered.append(contentsOf: geofences)
        current.removeAll { spec in geofences.contains(where: { $0.id == spec.id }) }
    }
}

@MainActor
private final class StubPlacesRepository: PlacesRepository {
    var places: [Place] = []

    func fetchAllPlaces() async throws -> [Place] { places }
    func fetchPlace(id: UUID) async throws -> Place? { places.first { $0.id == id } }
    func fetchRecentPlaces(limit: Int) async throws -> [Place] { Array(places.prefix(limit)) }
    func findPlace(latitudeE6: Int, longitudeE6: Int) async throws -> Place? { nil }
    func createPlace(_ place: Place) async throws { places.append(place) }
    func updatePlace(_ place: Place) async throws {}
    func deletePlace(id: UUID) async throws {}
    func countPlaces() async throws -> Int { places.count }
}

@MainActor
private final class StubShoppingListRepository: ShoppingListRepository {
    var items: [ShoppingItem] = []

    func fetchItems() async throws -> [ShoppingItem] { items }
    func fetchItem(id: UUID) async throws -> ShoppingItem? { items.first { $0.id == id } }
    func createItem(_ item: ShoppingItem) async throws {}
    func updateItem(_ item: ShoppingItem) async throws {}
    func deleteItem(id: UUID) async throws {}
    func updatePurchasedState(itemId: UUID, isPurchased: Bool) async throws {}
    func markItemsPurchased(forPlace placeId: UUID) async throws {}
}

@MainActor
private final class StubNotificationStateRepository: NotificationStateRepository {
    private var storage: [UUID: NotificationState] = [:]

    func fetchState(forPlace placeId: UUID) async throws -> NotificationState? {
        storage[placeId]
    }

    func upsert(state: NotificationState) async throws {
        storage[state.placeId] = state
    }
}

@MainActor
private final class StubNotificationScheduler: NotificationScheduling {
    var scheduledPlaceId: UUID?

    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }

    @discardableResult
    func requestAuthorization() async -> UNAuthorizationStatus { .authorized }

    func requestAuthorizationIfNeeded() async {}

    func schedule(place: Place, items: [ShoppingItem]) async {
        scheduledPlaceId = place.id
    }
}
