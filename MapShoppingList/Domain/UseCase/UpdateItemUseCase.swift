import Foundation

/// アイテムを更新するユースケース。
public struct UpdateItemUseCase {
    private let itemRepository: ShoppingListRepository
    private let linkRepository: ItemPlaceLinkRepository
    public init(
        itemRepository: ShoppingListRepository,
        linkRepository: ItemPlaceLinkRepository
    ) {
        self.itemRepository = itemRepository
        self.linkRepository = linkRepository
    }

    public func execute(item: ShoppingItem, updatedPlaceIds: Set<UUID>) async throws {
        guard try await itemRepository.fetchItem(id: item.id) != nil else {
            throw DomainError.itemNotFound
        }
        try await itemRepository.updateItem(item)
        try await syncLinks(itemId: item.id, updatedPlaceIds: updatedPlaceIds)
    }

    private func syncLinks(itemId: UUID, updatedPlaceIds: Set<UUID>) async throws {
        let current = try await linkRepository.fetchPlaceIds(forItem: itemId)
        let toAdd = updatedPlaceIds.subtracting(current)
        let toRemove = current.subtracting(updatedPlaceIds)

        for placeId in toRemove {
            try await linkRepository.unlink(itemId: itemId, placeId: placeId)
        }
        for placeId in toAdd {
            try await linkRepository.link(itemId: itemId, placeId: placeId)
        }
    }
}
