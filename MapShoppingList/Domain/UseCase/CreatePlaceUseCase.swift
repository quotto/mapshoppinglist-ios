import Foundation

/// 地点を新規作成するユースケース。
public struct CreatePlaceUseCase {
    private let placesRepository: PlacesRepository

    public init(placesRepository: PlacesRepository) {
        self.placesRepository = placesRepository
    }

    public func execute(place: Place) async throws {
        if let duplicate = try await placesRepository.findPlace(latitudeE6: place.latitudeE6, longitudeE6: place.longitudeE6), duplicate.id != place.id {
            throw DomainError.duplicatePlace
        }
        let total = try await placesRepository.countPlaces()
        if total >= DomainConstants.placeLimit {
            throw DomainError.placeLimitExceeded(max: DomainConstants.placeLimit)
        }
        try await placesRepository.createPlace(place)
    }
}
