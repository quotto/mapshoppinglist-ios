import XCTest
@testable import MapShoppingList

@MainActor
final class ManualPlaceSelectionViewModelTests: XCTestCase {
    func testUpdateCoordinateUsesGeocodeResult() async throws {
        let geocoding = StubGeocodingService()
        geocoding.result = .success(GeocodeResult(primaryText: "テストストア", secondaryText: "東京都千代田区"))
        let repo = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repo)
        let viewModel = ManualPlaceSelectionViewModel(geocodingService: geocoding, createPlaceUseCase: useCase)

        viewModel.updateCoordinate(latitude: 35.0, longitude: 139.0)
        try await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(viewModel.latitudeText, "35.000000")
        XCTAssertEqual(viewModel.name, "テストストア")
        XCTAssertEqual(viewModel.note, "東京都千代田区")
    }

    func testSavePlaceValidatesFields() async throws {
        let geocoding = StubGeocodingService()
        let repo = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repo)
        let viewModel = ManualPlaceSelectionViewModel(geocodingService: geocoding, createPlaceUseCase: useCase)

        viewModel.latitudeText = "35.0"
        viewModel.longitudeText = "139.0"
        viewModel.name = "テスト"
        let place = await viewModel.savePlace()
        XCTAssertNotNil(place)
        let saved = try await repo.fetchAllPlaces()
        XCTAssertEqual(saved.count, 1)
    }
}

