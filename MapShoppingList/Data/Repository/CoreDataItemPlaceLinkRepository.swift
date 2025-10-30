import CoreData
import Foundation

final class CoreDataItemPlaceLinkRepository: ItemPlaceLinkRepository {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    func fetchPlaceIds(forItem itemId: UUID) async throws -> Set<UUID> {
        let context = stack.viewContext
        return try await context.perform {
            guard let item = try context.fetchItem(id: itemId) else { return [] }
            let set = item.mutableSetValue(forKey: ManagedKeys.Item.places)
            return Set(set.compactMap { ($0 as? NSManagedObject)?.value(forKey: ManagedKeys.Place.id) as? UUID })
        }
    }

    func link(itemId: UUID, placeId: UUID) async throws {
        try await performWrite { context in
            guard let item = try context.fetchItem(id: itemId) else {
                throw DomainError.itemNotFound
            }
            guard let place = try context.fetchPlace(id: placeId) else {
                throw DomainError.placeNotFound
            }
            item.mutableSetValue(forKey: ManagedKeys.Item.places).add(place)
            if let isPurchased = item.value(forKey: ManagedKeys.Item.isPurchased) as? Bool, isPurchased == false {
                place.setValue(true, forKey: ManagedKeys.Place.isActive)
            }
            place.setValue(Date(), forKey: ManagedKeys.Place.lastUsedAt)
            try context.saveIfNeeded()
        }
    }

    func unlink(itemId: UUID, placeId: UUID) async throws {
        try await performWrite { context in
            guard let item = try context.fetchItem(id: itemId) else {
                throw DomainError.itemNotFound
            }
            guard let place = try context.fetchPlace(id: placeId) else {
                throw DomainError.placeNotFound
            }
            let set = item.mutableSetValue(forKey: ManagedKeys.Item.places)
            guard set.contains(place) else { throw DomainError.linkNotFound }
            set.remove(place)
            try self.updateActiveFlag(for: place, context: context)
            try context.saveIfNeeded()
        }
    }

    private func performWrite(_ block: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        try await stack.performBackgroundTask { context in
            try block(context)
        }
    }

    private func updateActiveFlag(for place: NSManagedObject, context: NSManagedObjectContext) throws {
        let items = place.mutableSetValue(forKey: ManagedKeys.Place.items)
        let hasActive = items.contains { element in
            guard let item = element as? NSManagedObject else { return false }
            return (item.value(forKey: ManagedKeys.Item.isPurchased) as? Bool) == false
        }
        place.setValue(hasActive, forKey: ManagedKeys.Place.isActive)
        if hasActive {
            place.setValue(Date(), forKey: ManagedKeys.Place.lastUsedAt)
        }
        try context.saveIfNeeded()
    }
}
