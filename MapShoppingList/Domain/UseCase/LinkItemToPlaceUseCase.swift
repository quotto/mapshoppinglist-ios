import Foundation

/// アイテムと地点を紐付けるユースケース。
public struct LinkItemToPlaceUseCase {
    private let itemRepository: ShoppingListRepository
    private let placesRepository: PlacesRepository
    private let linkRepository: ItemPlaceLinkRepository

    public init(
        itemRepository: ShoppingListRepository,
        placesRepository: PlacesRepository,
        linkRepository: ItemPlaceLinkRepository
    ) {
        self.itemRepository = itemRepository
        self.placesRepository = placesRepository
        self.linkRepository = linkRepository
    }

    public func execute(itemId: UUID, placeId: UUID) async throws {
        guard try await itemRepository.fetchItem(id: itemId) != nil else {
            throw DomainError.itemNotFound
        }
        guard try await placesRepository.fetchPlace(id: placeId) != nil else {
            throw DomainError.placeNotFound
        }
        let current = try await linkRepository.fetchPlaceIds(forItem: itemId)
        if current.contains(placeId) { return }
        try await linkRepository.link(itemId: itemId, placeId: placeId)
    }
}
