import Foundation

/// 指定したアイテムを取得するユースケース。
public struct GetShoppingItemUseCase {
    private let repository: ShoppingListRepository

    public init(repository: ShoppingListRepository) {
        self.repository = repository
    }

    public func execute(id: UUID) async throws -> ShoppingItem {
        guard let item = try await repository.fetchItem(id: id) else {
            throw DomainError.itemNotFound
        }
        return item
    }
}
