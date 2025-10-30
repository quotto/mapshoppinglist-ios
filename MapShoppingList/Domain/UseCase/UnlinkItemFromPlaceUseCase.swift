import Foundation

/// アイテムと地点の紐付けを解除するユースケース。
public struct UnlinkItemFromPlaceUseCase {
    private let itemRepository: ShoppingListRepository
    private let linkRepository: ItemPlaceLinkRepository

    public init(itemRepository: ShoppingListRepository, linkRepository: ItemPlaceLinkRepository) {
        self.itemRepository = itemRepository
        self.linkRepository = linkRepository
    }

    public func execute(itemId: UUID, placeId: UUID) async throws {
        guard try await itemRepository.fetchItem(id: itemId) != nil else {
            throw DomainError.itemNotFound
        }
        let current = try await linkRepository.fetchPlaceIds(forItem: itemId)
        guard current.contains(placeId) else {
            throw DomainError.linkNotFound
        }
        try await linkRepository.unlink(itemId: itemId, placeId: placeId)
    }
}
