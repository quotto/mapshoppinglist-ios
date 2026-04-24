import CoreData
import Foundation

final class CoreDataNearbySuggestionStateRepository: NearbySuggestionStateRepository {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    func fetchState(forItem itemId: UUID) async throws -> NearbySuggestionState? {
        let context = stack.viewContext
        return try await context.perform {
            guard let item = try context.fetchItem(id: itemId) else { return nil }
            let request = NSFetchRequest<NSManagedObject>(entityName: ManagedKeys.NearbySuggestionState.entityName)
            request.predicate = NSPredicate(format: "%K == %@", ManagedKeys.NearbySuggestionState.item, item)
            request.fetchLimit = 1
            guard let stateObject = try context.fetch(request).first else { return nil }
            return Self.toDomain(stateObject, itemId: itemId)
        }
    }

    func upsert(state: NearbySuggestionState) async throws {
        try await stack.performBackgroundTask { context in
            guard let item = try context.fetchItem(id: state.itemId) else {
                throw DomainError.itemNotFound
            }
            let request = NSFetchRequest<NSManagedObject>(entityName: ManagedKeys.NearbySuggestionState.entityName)
            request.predicate = NSPredicate(format: "%K == %@", ManagedKeys.NearbySuggestionState.item, item)
            request.fetchLimit = 1
            let object: NSManagedObject
            if let existing = try context.fetch(request).first {
                object = existing
            } else {
                guard let entity = NSEntityDescription.entity(
                    forEntityName: ManagedKeys.NearbySuggestionState.entityName,
                    in: context
                ) else {
                    fatalError("NearbySuggestionState entity missing")
                }
                object = NSManagedObject(entity: entity, insertInto: context)
                object.setValue(item, forKey: ManagedKeys.NearbySuggestionState.item)
            }

            object.setValue(state.lastNotifiedAt, forKey: ManagedKeys.NearbySuggestionState.lastNotifiedAt)
            object.setValue(
                state.lastNotifiedLatitudeE6,
                forKey: ManagedKeys.NearbySuggestionState.lastNotifiedLatitudeE6
            )
            object.setValue(
                state.lastNotifiedLongitudeE6,
                forKey: ManagedKeys.NearbySuggestionState.lastNotifiedLongitudeE6
            )
            object.setValue(
                state.lastSuggestedPlaceID,
                forKey: ManagedKeys.NearbySuggestionState.lastSuggestedPlaceID
            )
            object.setValue(
                state.lastSuggestedPlaceName,
                forKey: ManagedKeys.NearbySuggestionState.lastSuggestedPlaceName
            )
            try context.saveIfNeeded()
        }
    }
}

private extension CoreDataNearbySuggestionStateRepository {
    static func toDomain(_ object: NSManagedObject, itemId: UUID) -> NearbySuggestionState {
        NearbySuggestionState(
            itemId: itemId,
            lastNotifiedAt: object.value(forKey: ManagedKeys.NearbySuggestionState.lastNotifiedAt) as? Date,
            lastNotifiedLatitudeE6: object.value(
                forKey: ManagedKeys.NearbySuggestionState.lastNotifiedLatitudeE6
            ) as? Int,
            lastNotifiedLongitudeE6: object.value(
                forKey: ManagedKeys.NearbySuggestionState.lastNotifiedLongitudeE6
            ) as? Int,
            lastSuggestedPlaceID: object.value(
                forKey: ManagedKeys.NearbySuggestionState.lastSuggestedPlaceID
            ) as? String,
            lastSuggestedPlaceName: object.value(
                forKey: ManagedKeys.NearbySuggestionState.lastSuggestedPlaceName
            ) as? String
        )
    }
}
