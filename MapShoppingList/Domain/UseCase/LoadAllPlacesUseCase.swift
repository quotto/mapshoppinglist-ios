import Foundation

/// 登録済み地点を取得するユースケース。
public struct LoadAllPlacesUseCase {
    private let placesRepository: PlacesRepository

    public init(placesRepository: PlacesRepository) {
        self.placesRepository = placesRepository
    }

    public func execute() async throws -> [Place] {
        try await placesRepository.fetchAllPlaces()
    }
}
