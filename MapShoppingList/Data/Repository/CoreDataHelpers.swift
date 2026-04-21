import CoreData
import Foundation

struct ManagedKeys {
    struct Item {
        static let entityName = "Item"
        static let id = "id"
        static let title = "title"
        static let note = "note"
        static let isPurchased = "isPurchased"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let places = "places"
    }

    struct Place {
        static let entityName = "Place"
        static let id = "id"
        static let name = "name"
        static let latitudeE6 = "latitudeE6"
        static let longitudeE6 = "longitudeE6"
        static let note = "note"
        static let lastUsedAt = "lastUsedAt"
        static let isActive = "isActive"
        static let items = "items"
    }

    struct NotifyState {
        static let entityName = "NotifyState"
        static let place = "place"
        static let lastNotifiedAt = "lastNotifiedAt"
    }

    struct NearbySuggestionState {
        static let entityName = "NearbySuggestionState"
        static let item = "item"
        static let lastNotifiedAt = "lastNotifiedAt"
        static let lastNotifiedLatitudeE6 = "lastNotifiedLatitudeE6"
        static let lastNotifiedLongitudeE6 = "lastNotifiedLongitudeE6"
        static let lastSuggestedPlaceID = "lastSuggestedPlaceID"
        static let lastSuggestedPlaceName = "lastSuggestedPlaceName"
    }
}

extension NSManagedObjectContext {
    func fetchItem(id: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: ManagedKeys.Item.entityName)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try fetch(request).first
    }

    func fetchPlace(id: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: ManagedKeys.Place.entityName)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try fetch(request).first
    }

    func saveIfNeeded() throws {
        if hasChanges {
            try save()
        }
    }
}
