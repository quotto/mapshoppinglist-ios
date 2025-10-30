import CoreData
import Foundation

final class CoreDataPlacesRepository: PlacesRepository {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    func fetchAllPlaces() async throws -> [Place] {
        let context = stack.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: ManagedKeys.Place.entityName)
            request.sortDescriptors = [NSSortDescriptor(key: ManagedKeys.Place.name, ascending: true)]
            let result = try context.fetch(request)
            return try result.map { try Self.toDomain(place: $0) }
        }
    }

    func fetchPlace(id: UUID) async throws -> Place? {
        let context = stack.viewContext
        return try await context.perform {
            guard let place = try context.fetchPlace(id: id) else { return nil }
            return try Self.toDomain(place: place)
        }
    }

    func fetchRecentPlaces(limit: Int) async throws -> [Place] {
        let context = stack.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: ManagedKeys.Place.entityName)
            request.sortDescriptors = [
                NSSortDescriptor(key: ManagedKeys.Place.lastUsedAt, ascending: false),
                NSSortDescriptor(key: ManagedKeys.Place.name, ascending: true)
            ]
            request.fetchLimit = limit
            let result = try context.fetch(request)
            return try result.map { try Self.toDomain(place: $0) }
        }
    }

    func findPlace(latitudeE6: Int, longitudeE6: Int) async throws -> Place? {
        let context = stack.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: ManagedKeys.Place.entityName)
            request.predicate = NSPredicate(format: "latitudeE6 == %d AND longitudeE6 == %d", latitudeE6, longitudeE6)
            request.fetchLimit = 1
            guard let found = try context.fetch(request).first else { return nil }
            return try Self.toDomain(place: found)
        }
    }

    func createPlace(_ place: Place) async throws {
        try await performWrite { context in
            guard let entity = NSEntityDescription.entity(forEntityName: ManagedKeys.Place.entityName, in: context) else {
                fatalError("Place entity missing")
            }
            let object = NSManagedObject(entity: entity, insertInto: context)
            Self.fill(place: place, into: object)
        }
    }

    func updatePlace(_ place: Place) async throws {
        try await performWrite { context in
            guard let object = try context.fetchPlace(id: place.id) else {
                throw DomainError.placeNotFound
            }
            Self.fill(place: place, into: object)
        }
    }

    func deletePlace(id: UUID) async throws {
        try await performWrite { context in
            guard let object = try context.fetchPlace(id: id) else { return }
            context.delete(object)
        }
    }

    func countPlaces() async throws -> Int {
        let context = stack.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: ManagedKeys.Place.entityName)
            return try context.count(for: request)
        }
    }

    // MARK: - Helpers

    private func performWrite(_ block: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        try await stack.performBackgroundTask { context in
            try block(context)
            try context.saveIfNeeded()
        }
    }

    private static func fill(place: Place, into object: NSManagedObject) {
        object.setValue(place.id, forKey: ManagedKeys.Place.id)
        object.setValue(place.name, forKey: ManagedKeys.Place.name)
        object.setValue(place.latitudeE6, forKey: ManagedKeys.Place.latitudeE6)
        object.setValue(place.longitudeE6, forKey: ManagedKeys.Place.longitudeE6)
        object.setValue(place.note, forKey: ManagedKeys.Place.note)
        object.setValue(place.lastUsedAt, forKey: ManagedKeys.Place.lastUsedAt)
        object.setValue(place.isActive, forKey: ManagedKeys.Place.isActive)
    }

    private static func toDomain(place: NSManagedObject) throws -> Place {
        guard
            let id = place.value(forKey: ManagedKeys.Place.id) as? UUID,
            let name = place.value(forKey: ManagedKeys.Place.name) as? String,
            let latitudeE6 = place.value(forKey: ManagedKeys.Place.latitudeE6) as? Int,
            let longitudeE6 = place.value(forKey: ManagedKeys.Place.longitudeE6) as? Int,
            let isActive = place.value(forKey: ManagedKeys.Place.isActive) as? Bool
        else {
            throw NSError(domain: "CoreDataPlacesRepository", code: 0, userInfo: [NSLocalizedDescriptionKey: "Place entity is invalid"])
        }
        let note = place.value(forKey: ManagedKeys.Place.note) as? String
        let lastUsedAt = place.value(forKey: ManagedKeys.Place.lastUsedAt) as? Date
        return Place(
            id: id,
            name: name,
            latitudeE6: latitudeE6,
            longitudeE6: longitudeE6,
            note: note,
            lastUsedAt: lastUsedAt,
            isActive: isActive
        )
    }
}
