import Foundation

/// アイテムを削除するユースケース。
public struct DeleteShoppingItemUseCase {
    private let itemRepository: ShoppingListRepository
    private let linkRepository: ItemPlaceLinkRepository

    public init(itemRepository: ShoppingListRepository, linkRepository: ItemPlaceLinkRepository) {
        self.itemRepository = itemRepository
        self.linkRepository = linkRepository
    }

    public func execute(itemId: UUID) async throws {
        guard let existing = try await itemRepository.fetchItem(id: itemId) else {
            throw DomainError.itemNotFound
        }
        for placeId in existing.placeIds {
            try await linkRepository.unlink(itemId: itemId, placeId: placeId)
        }
        try await itemRepository.deleteItem(id: itemId)
    }
}
