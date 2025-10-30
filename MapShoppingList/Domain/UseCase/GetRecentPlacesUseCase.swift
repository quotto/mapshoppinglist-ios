import Foundation

/// 最近利用した地点を取得するユースケース。
public struct GetRecentPlacesUseCase {
    private let placesRepository: PlacesRepository

    public init(placesRepository: PlacesRepository) {
        self.placesRepository = placesRepository
    }

    public func execute(limit: Int) async throws -> [Place] {
        try await placesRepository.fetchRecentPlaces(limit: limit)
    }
}
