import Foundation

/// 地点名称を更新するユースケース。
public struct UpdatePlaceNameUseCase {
    private let placesRepository: PlacesRepository

    public init(placesRepository: PlacesRepository) {
        self.placesRepository = placesRepository
    }

    public func execute(placeId: UUID, newName: String) async throws {
        guard var place = try await placesRepository.fetchPlace(id: placeId) else {
            throw DomainError.placeNotFound
        }
        place.name = newName
        place.lastUsedAt = Date()
        try await placesRepository.updatePlace(place)
    }
}
