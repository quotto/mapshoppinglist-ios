import Foundation

/// 指定地点に紐づく未購入アイテムをまとめて購入済みにする。
public struct MarkPlaceItemsPurchasedUseCase {
    private let itemRepository: ShoppingListRepository
    private let placesRepository: PlacesRepository

    public init(itemRepository: ShoppingListRepository, placesRepository: PlacesRepository) {
        self.itemRepository = itemRepository
        self.placesRepository = placesRepository
    }

    public func execute(placeId: UUID) async throws {
        guard try await placesRepository.fetchPlace(id: placeId) != nil else {
            throw DomainError.placeNotFound
        }
        try await itemRepository.markItemsPurchased(forPlace: placeId)
    }
}
