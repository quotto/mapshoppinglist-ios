import XCTest
@testable import MapShoppingList

@MainActor
final class PlaceCreationViewModelTests: XCTestCase {
    func testCreatePlace() async throws {
        let placeRepo = InMemoryPlacesRepository()
        let viewModel = PlaceCreationViewModel(createPlaceUseCase: CreatePlaceUseCase(placesRepository: placeRepo))
        viewModel.name = "テスト地点"
        viewModel.latitudeText = "35.0"
        viewModel.longitudeText = "139.0"
        let success = await viewModel.createPlace()
        XCTAssertTrue(success)
        let places = try await placeRepo.fetchAllPlaces()
        XCTAssertEqual(places.count, 1)
    }
}
