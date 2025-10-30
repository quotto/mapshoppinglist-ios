import XCTest
import CoreData
@testable import MapShoppingList

final class CoreDataStackTests: XCTestCase {
    /// インメモリ構成でもモデルが読み込めることを確認する。
    func testInMemoryStackLoadsModel() throws {
        let stack = CoreDataStack.makeInMemory()
        XCTAssertNotNil(stack.viewContext.persistentStoreCoordinator)
    }

    /// Item と Place の関連が保存・復元できることを確認する。
    func testItemPlaceRelationshipPersists() throws {
        let stack = CoreDataStack.makeInMemory()
        let context = stack.viewContext

        let place = NSEntityDescription.insertNewObject(forEntityName: "Place", into: context)
        place.setValue(UUID(), forKey: "id")
        place.setValue("テストスーパー", forKey: "name")
        place.setValue(35_658_000, forKey: "latitudeE6")
        place.setValue(139_745_000, forKey: "longitudeE6")
        place.setValue(false, forKey: "isActive")

        let item = NSEntityDescription.insertNewObject(forEntityName: "Item", into: context)
        item.setValue(UUID(), forKey: "id")
        item.setValue("牛乳", forKey: "title")
        item.setValue(Date(), forKey: "createdAt")
        item.setValue(Date(), forKey: "updatedAt")
        item.setValue(false, forKey: "isPurchased")

        let placesRelation = item.mutableSetValue(forKey: "places")
        placesRelation.add(place)

        try context.save()
        context.reset()

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Item")
        fetchRequest.returnsObjectsAsFaults = false
        let storedItems = try context.fetch(fetchRequest)
        XCTAssertEqual(storedItems.count, 1)
        let storedItem = storedItems.first
        XCTAssertNotNil(storedItem)
        let storedPlaces = storedItem?.value(forKey: "places") as? Set<NSManagedObject>
        XCTAssertEqual(storedPlaces?.count, 1)
        let storedPlace = storedPlaces?.first
        XCTAssertEqual(storedPlace?.value(forKey: "name") as? String, "テストスーパー")
        XCTAssertEqual(storedPlace?.value(forKey: "latitudeE6") as? Int, 35_658_000)
        XCTAssertEqual(storedPlace?.value(forKey: "longitudeE6") as? Int, 139_745_000)
    }

    /// バックグラウンドコンテキストの設定が共有と同じであることを確認する。
    func testBackgroundContextConfiguration() {
        let stack = CoreDataStack.makeInMemory()
        let background = stack.newBackgroundContext()
        let mergePolicy = background.mergePolicy as? NSMergePolicy
        XCTAssertNotNil(mergePolicy)
        XCTAssertTrue(mergePolicy === NSErrorMergePolicy)
        XCTAssertTrue(background.automaticallyMergesChangesFromParent)
        XCTAssertNil(background.undoManager)
    }
}
