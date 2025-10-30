import Foundation

/// 購入状態を更新するユースケース。
public struct UpdatePurchasedStateUseCase {
    private let itemRepository: ShoppingListRepository

    public init(itemRepository: ShoppingListRepository) {
        self.itemRepository = itemRepository
    }

    public func execute(itemId: UUID, isPurchased: Bool) async throws {
        guard try await itemRepository.fetchItem(id: itemId) != nil else {
            throw DomainError.itemNotFound
        }
        try await itemRepository.updatePurchasedState(itemId: itemId, isPurchased: isPurchased)
    }
}
