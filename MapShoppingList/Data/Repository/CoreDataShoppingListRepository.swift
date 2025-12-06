import CoreData
import Foundation

final class CoreDataShoppingListRepository: ShoppingListRepository {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    func fetchItems() async throws -> [ShoppingItem] {
        let context = stack.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: ManagedKeys.Item.entityName)
            request.relationshipKeyPathsForPrefetching = [ManagedKeys.Item.places]
            let items = try context.fetch(request)
            return try items.map { try Self.toDomain(item: $0) }
        }
    }

    func fetchItem(id: UUID) async throws -> ShoppingItem? {
        let context = stack.viewContext
        return try await context.perform {
            guard let object = try context.fetchItem(id: id) else { return nil }
            return try Self.toDomain(item: object)
        }
    }

    func createItem(_ item: ShoppingItem) async throws {
        try await performWrite { context in
            guard let entity = NSEntityDescription.entity(
                forEntityName: ManagedKeys.Item.entityName,
                in: context
            ) else {
                fatalError("Item entity missing")
            }
            let object = NSManagedObject(entity: entity, insertInto: context)
            Self.fill(item: item, into: object, in: context)
        }
    }

    func updateItem(_ item: ShoppingItem) async throws {
        try await performWrite { context in
            guard let object = try context.fetchItem(id: item.id) else {
                throw DomainError.itemNotFound
            }
            Self.fill(item: item, into: object, in: context)
        }
    }

    func deleteItem(id: UUID) async throws {
        try await performWrite { context in
            guard let object = try context.fetchItem(id: id) else { return }
            context.delete(object)
        }
    }

    func updatePurchasedState(itemId: UUID, isPurchased: Bool) async throws {
        try await performWrite { context in
            guard let object = try context.fetchItem(id: itemId) else {
                throw DomainError.itemNotFound
            }
            object.setValue(isPurchased, forKey: ManagedKeys.Item.isPurchased)
            object.setValue(Date(), forKey: ManagedKeys.Item.updatedAt)
            try context.saveIfNeeded()
            try self.updateActiveFlags(for: object, in: context)
        }
    }

    func markItemsPurchased(forPlace placeId: UUID) async throws {
        try await performWrite { context in
            guard let placeObject = try context.fetchPlace(id: placeId) else {
                throw DomainError.placeNotFound
            }
            let items = placeObject.mutableSetValue(forKey: ManagedKeys.Place.items)
            for case let item as NSManagedObject in items {
                item.setValue(true, forKey: ManagedKeys.Item.isPurchased)
                item.setValue(Date(), forKey: ManagedKeys.Item.updatedAt)
            }
            try context.saveIfNeeded()
            try self.updateActiveFlag(forPlace: placeObject, in: context)
        }
    }

    // MARK: - Helpers

    private func performWrite(_ block: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        try await stack.performBackgroundTask { context in
            try block(context)
            try context.saveIfNeeded()
        }
    }

    private static func fill(item: ShoppingItem, into object: NSManagedObject, in context: NSManagedObjectContext) {
        object.setValue(item.id, forKey: ManagedKeys.Item.id)
        object.setValue(item.title, forKey: ManagedKeys.Item.title)
        object.setValue(item.note, forKey: ManagedKeys.Item.note)
        object.setValue(item.isPurchased, forKey: ManagedKeys.Item.isPurchased)
        object.setValue(item.createdAt, forKey: ManagedKeys.Item.createdAt)
        object.setValue(item.updatedAt, forKey: ManagedKeys.Item.updatedAt)

        if let placesRelation = object.mutableSetValue(forKey: ManagedKeys.Item.places) as NSMutableSet? {
            placesRelation.removeAllObjects()
            for placeId in item.placeIds {
                if let place = try? context.fetchPlace(id: placeId) {
                    placesRelation.add(place)
                }
            }
        }
    }

    private static func toDomain(item: NSManagedObject) throws -> ShoppingItem {
        guard
            let id = item.value(forKey: ManagedKeys.Item.id) as? UUID,
            let title = item.value(forKey: ManagedKeys.Item.title) as? String,
            let isPurchased = item.value(forKey: ManagedKeys.Item.isPurchased) as? Bool,
            let createdAt = item.value(forKey: ManagedKeys.Item.createdAt) as? Date,
            let updatedAt = item.value(forKey: ManagedKeys.Item.updatedAt) as? Date
        else {
            throw NSError(
                domain: "CoreDataShoppingListRepository",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Item entity is invalid"]
            )
        }
        let note = item.value(forKey: ManagedKeys.Item.note) as? String
        let places = item.mutableSetValue(forKey: ManagedKeys.Item.places)
        let placeIds = Set(places.compactMap { ($0 as? NSManagedObject)?.value(forKey: ManagedKeys.Place.id) as? UUID })
        return ShoppingItem(
            id: id,
            title: title,
            note: note,
            isPurchased: isPurchased,
            createdAt: createdAt,
            updatedAt: updatedAt,
            placeIds: placeIds
        )
    }

    private func updateActiveFlags(for item: NSManagedObject, in context: NSManagedObjectContext) throws {
        let places = item.mutableSetValue(forKey: ManagedKeys.Item.places)
        for case let place as NSManagedObject in places {
            try updateActiveFlag(forPlace: place, in: context)
        }
    }

    private func updateActiveFlag(forPlace place: NSManagedObject, in context: NSManagedObjectContext) throws {
        let items = place.mutableSetValue(forKey: ManagedKeys.Place.items)
        let hasUnpurchased = items.contains { element in
            guard let item = element as? NSManagedObject else { return false }
            return (item.value(forKey: ManagedKeys.Item.isPurchased) as? Bool) == false
        }
        place.setValue(hasUnpurchased, forKey: ManagedKeys.Place.isActive)
        if hasUnpurchased {
            place.setValue(Date(), forKey: ManagedKeys.Place.lastUsedAt)
        }
        try context.saveIfNeeded()
    }
}
