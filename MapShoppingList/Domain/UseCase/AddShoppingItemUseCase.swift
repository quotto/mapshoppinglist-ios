import Foundation

/// アイテムを新規作成するユースケース。
public struct AddShoppingItemUseCase {
    private let itemRepository: ShoppingListRepository
    private let linkRepository: ItemPlaceLinkRepository
    public init(
        itemRepository: ShoppingListRepository,
        linkRepository: ItemPlaceLinkRepository
    ) {
        self.itemRepository = itemRepository
        self.linkRepository = linkRepository
    }

    public func execute(item: ShoppingItem, placeIds: Set<UUID>) async throws {
        var newItem = item
        newItem.placeIds = placeIds
        try await itemRepository.createItem(newItem)
        for placeId in placeIds {
            try await linkRepository.link(itemId: item.id, placeId: placeId)
        }
    }
}
