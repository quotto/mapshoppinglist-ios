import Foundation

/// アイテム一覧を取得するユースケース。
public struct LoadShoppingItemsUseCase {
    private let repository: ShoppingListRepository

    public init(repository: ShoppingListRepository) {
        self.repository = repository
    }

    public func execute() async throws -> [ShoppingItem] {
        try await repository.fetchItems()
    }
}
