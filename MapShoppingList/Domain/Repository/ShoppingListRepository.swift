import Foundation

/// アイテム関連データへのアクセスを担う。
public protocol ShoppingListRepository {
    func fetchItems() async throws -> [ShoppingItem]
    func fetchItem(id: UUID) async throws -> ShoppingItem?
    func createItem(_ item: ShoppingItem) async throws
    func updateItem(_ item: ShoppingItem) async throws
    func deleteItem(id: UUID) async throws
    func updatePurchasedState(itemId: UUID, isPurchased: Bool) async throws
    func markItemsPurchased(forPlace placeId: UUID) async throws
}
