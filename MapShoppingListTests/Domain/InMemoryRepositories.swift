import Foundation
@testable import MapShoppingList

final class InMemoryShoppingListRepository: ShoppingListRepository {
    private var storage: [UUID: ShoppingItem] = [:]

    func fetchItems() async throws -> [ShoppingItem] {
        Array(storage.values)
    }

    func fetchItem(id: UUID) async throws -> ShoppingItem? {
        storage[id]
    }

    func createItem(_ item: ShoppingItem) async throws {
        storage[item.id] = item
    }

    func updateItem(_ item: ShoppingItem) async throws {
        storage[item.id] = item
    }

    func deleteItem(id: UUID) async throws {
        storage.removeValue(forKey: id)
    }

    func updatePurchasedState(itemId: UUID, isPurchased: Bool) async throws {
        guard var item = storage[itemId] else { throw DomainError.itemNotFound }
        item.isPurchased = isPurchased
        storage[itemId] = item
    }

    func markItemsPurchased(forPlace placeId: UUID) async throws {
        for (id, item) in storage {
            if item.placeIds.contains(placeId) {
                var updated = item
                updated.isPurchased = true
                storage[id] = updated
            }
        }
    }
}

final class InMemoryItemPlaceLinkRepository: ItemPlaceLinkRepository {
    private var links: [UUID: Set<UUID>] = [:]

    func fetchPlaceIds(forItem itemId: UUID) async throws -> Set<UUID> {
        links[itemId] ?? []
    }

    func link(itemId: UUID, placeId: UUID) async throws {
        var set = links[itemId] ?? []
        set.insert(placeId)
        links[itemId] = set
    }

    func unlink(itemId: UUID, placeId: UUID) async throws {
        guard var set = links[itemId] else { return }
        set.remove(placeId)
        links[itemId] = set
    }
}

final class InMemoryPlacesRepository: PlacesRepository {
    private var storage: [UUID: Place] = [:]

    func fetchAllPlaces() async throws -> [Place] {
        Array(storage.values)
    }

    func fetchPlace(id: UUID) async throws -> Place? {
        storage[id]
    }

    func fetchRecentPlaces(limit: Int) async throws -> [Place] {
        Array(storage.values)
            .sorted { (lhs, rhs) in
                switch (lhs.lastUsedAt, rhs.lastUsedAt) {
                case let (l?, r?): return l > r
                case (.some, .none): return true
                case (.none, .some): return false
                default: return lhs.name < rhs.name
                }
            }
            .prefix(limit)
            .map { $0 }
    }

    func findPlace(latitudeE6: Int, longitudeE6: Int) async throws -> Place? {
        storage.values.first { $0.latitudeE6 == latitudeE6 && $0.longitudeE6 == longitudeE6 }
    }

    func createPlace(_ place: Place) async throws {
        storage[place.id] = place
    }

    func updatePlace(_ place: Place) async throws {
        storage[place.id] = place
    }

    func deletePlace(id: UUID) async throws {
        storage.removeValue(forKey: id)
    }

    func countPlaces() async throws -> Int {
        storage.count
    }
}

final class InMemoryGeofenceRegistryRepository: GeofenceRegistryRepository {
    private var storage: [String: GeofenceSpec] = [:]

    func fetchRegisteredGeofences() async throws -> [GeofenceSpec] {
        Array(storage.values)
    }

    func registerGeofences(_ geofences: [GeofenceSpec]) async throws {
        for item in geofences {
            storage[item.id] = item
        }
    }

    func unregisterGeofences(_ geofences: [GeofenceSpec]) async throws {
        for item in geofences {
            storage.removeValue(forKey: item.id)
        }
    }
}

final class InMemoryNotificationStateRepository: NotificationStateRepository {
    private var storage: [UUID: NotificationState] = [:]

    func fetchState(forPlace placeId: UUID) async throws -> NotificationState? {
        storage[placeId]
    }

    func upsert(state: NotificationState) async throws {
        storage[state.placeId] = state
    }
}
