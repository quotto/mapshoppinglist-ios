import Foundation

/// 地点を削除するユースケース。
public struct DeletePlaceUseCase {
    private let placesRepository: PlacesRepository

    public init(placesRepository: PlacesRepository) {
        self.placesRepository = placesRepository
    }

    public func execute(placeId: UUID) async throws {
        guard try await placesRepository.fetchPlace(id: placeId) != nil else {
            throw DomainError.placeNotFound
        }
        try await placesRepository.deletePlace(id: placeId)
    }
}
