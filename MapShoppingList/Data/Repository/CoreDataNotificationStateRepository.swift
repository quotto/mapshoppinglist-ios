import CoreData
import Foundation

final class CoreDataNotificationStateRepository: NotificationStateRepository {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    func fetchState(forPlace placeId: UUID) async throws -> NotificationState? {
        let context = stack.viewContext
        return try await context.perform {
            guard let place = try context.fetchPlace(id: placeId) else { return nil }
            let request = NSFetchRequest<NSManagedObject>(entityName: ManagedKeys.NotifyState.entityName)
            request.predicate = NSPredicate(format: "%K == %@", ManagedKeys.NotifyState.place, place)
            request.fetchLimit = 1
            guard let stateObject = try context.fetch(request).first else { return nil }
            return NotificationState(
                placeId: placeId,
                lastNotifiedAt: stateObject.value(forKey: ManagedKeys.NotifyState.lastNotifiedAt) as? Date,
                snoozeUntil: stateObject.value(forKey: ManagedKeys.NotifyState.snoozeUntil) as? Date
            )
        }
    }

    func upsert(state: NotificationState) async throws {
        try await stack.performBackgroundTask { context in
            guard let place = try context.fetchPlace(id: state.placeId) else {
                throw DomainError.placeNotFound
            }
            let request = NSFetchRequest<NSManagedObject>(entityName: ManagedKeys.NotifyState.entityName)
            request.predicate = NSPredicate(format: "%K == %@", ManagedKeys.NotifyState.place, place)
            request.fetchLimit = 1
            let object: NSManagedObject
            if let existing = try context.fetch(request).first {
                object = existing
            } else {
                guard let entity = NSEntityDescription.entity(forEntityName: ManagedKeys.NotifyState.entityName, in: context) else {
                    fatalError("NotifyState entity missing")
                }
                object = NSManagedObject(entity: entity, insertInto: context)
                object.setValue(place, forKey: ManagedKeys.NotifyState.place)
            }
            object.setValue(state.lastNotifiedAt, forKey: ManagedKeys.NotifyState.lastNotifiedAt)
            object.setValue(state.snoozeUntil, forKey: ManagedKeys.NotifyState.snoozeUntil)
            try context.saveIfNeeded()
        }
    }
}
