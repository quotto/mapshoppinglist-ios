import Testing
import Foundation
@testable import MapShoppingList

@Suite("PlaceCreationViewModelTests")
@MainActor
struct PlaceCreationViewModelTests {
    @Test("createPlace persists locations")
    func createPlace() async throws {
        let placeRepo = InMemoryPlacesRepository()
        let viewModel = PlaceCreationViewModel(createPlaceUseCase: CreatePlaceUseCase(placesRepository: placeRepo))
        viewModel.name = "テスト地点"
        viewModel.latitudeText = "35.0"
        viewModel.longitudeText = "139.0"
        let success = await viewModel.createPlace()
        #expect(success)
        let places = try await placeRepo.fetchAllPlaces()
        #expect(places.count == 1)
    }
}
