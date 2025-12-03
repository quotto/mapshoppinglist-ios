import CoreData
import Foundation

enum UITestScenarioSeeder {
    static func seedIfNeeded(environment: AppEnvironment) {
        guard LaunchArguments.isUITesting else { return }
        guard let scenario = LaunchArguments.uiTestScenario else { return }
        let context = environment.coreDataStack.viewContext
        context.performAndWait {
            do {
                try clearExistingData(context: context)
                switch scenario {
                case UITestScenarios.placeManagementSeed:
                    try seedPlaceManagement(context: context)
                default:
                    break
                }
                try context.saveIfNeeded()
            } catch {
                debugPrint("[UITestScenarioSeeder] error: \(error)")
            }
        }
    }

    private static func clearExistingData(context: NSManagedObjectContext) throws {
        try deleteAll(entityName: ManagedKeys.Item.entityName, context: context)
        try deleteAll(entityName: ManagedKeys.Place.entityName, context: context)
        try deleteAll(entityName: ManagedKeys.NotifyState.entityName, context: context)
    }

    private static func deleteAll(entityName: String, context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        let objects = try context.fetch(request)
        for object in objects {
            context.delete(object)
        }
    }

    private static func seedPlaceManagement(context: NSManagedObjectContext) throws {
        _ = try createPlace(
            context: context,
            name: "テストスーパーA",
            latitudeE6: 35_689_487,
            longitudeE6: 139_691_706,
            note: "東京都千代田区1-1-1",
            lastUsedAt: Date(),
            isActive: true
        )
        _ = try createPlace(
            context: context,
            name: "ドラッグB",
            latitudeE6: 35_700_000,
            longitudeE6: 139_770_000,
            note: "東京都台東区2-2-2",
            lastUsedAt: Date().addingTimeInterval(-3_600),
            isActive: false
        )
        _ = try createPlace(
            context: context,
            name: "ベーカリーC",
            latitudeE6: 35_710_000,
            longitudeE6: 139_810_000,
            note: "東京都墨田区3-3-3",
            lastUsedAt: Date().addingTimeInterval(-7_200),
            isActive: false
        )
    }

    @discardableResult
    // テストデータ生成のため引数数が多いことを許容
    // swiftlint:disable:next function_parameter_count
    private static func createPlace(
        context: NSManagedObjectContext,
        name: String,
        latitudeE6: Int,
        longitudeE6: Int,
        note: String?,
        lastUsedAt: Date?,
        isActive: Bool
    ) throws -> NSManagedObject {
        guard let entity = NSEntityDescription.entity(
            forEntityName: ManagedKeys.Place.entityName,
            in: context
        ) else {
            throw NSError(
                domain: "UITestScenarioSeeder",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Place entity missing"]
            )
        }
        let object = NSManagedObject(entity: entity, insertInto: context)
        object.setValue(UUID(), forKey: ManagedKeys.Place.id)
        object.setValue(name, forKey: ManagedKeys.Place.name)
        object.setValue(latitudeE6, forKey: ManagedKeys.Place.latitudeE6)
        object.setValue(longitudeE6, forKey: ManagedKeys.Place.longitudeE6)
        object.setValue(note, forKey: ManagedKeys.Place.note)
        object.setValue(lastUsedAt, forKey: ManagedKeys.Place.lastUsedAt)
        object.setValue(isActive, forKey: ManagedKeys.Place.isActive)
        return object
    }
}
