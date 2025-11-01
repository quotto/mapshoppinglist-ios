import XCTest
import CoreLocation
@testable import MapShoppingList

@MainActor
final class PlaceSearchViewModelTests: XCTestCase {
    func testSearchSelectAndSavePlace() async throws {
        let session = PlacesAutocompleteSession(identifier: NSObject())
        let prediction = PlaceAutocompletePrediction(
            id: "test-place-id",
            primaryText: "テスト店舗",
            secondaryText: "東京都千代田区",
            distanceMeters: 12.0
        )
        let response = PlacesAutocompleteResponse(session: session, predictions: [prediction])
        let details = PlaceDetails(
            id: "test-place-id",
            name: "テスト店舗",
            latitude: 35.0,
            longitude: 139.0,
            formattedAddress: "東京都千代田区1-1"
        )

        let stubService = StubPlacesSearchService()
        stubService.autocompleteResult = .success(response)
        stubService.detailsResult = .success(details)

        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        let viewModel = PlaceSearchViewModel(placesSearchService: stubService, createPlaceUseCase: useCase, geocodingService: geocoder)

        viewModel.query = "テスト"
        await viewModel.performSearch()
        XCTAssertEqual(viewModel.predictions.count, 1)

        await viewModel.selectPrediction(prediction)
        XCTAssertEqual(viewModel.displayText, "テスト店舗")

        let savedPlace = await viewModel.saveSelectedPlace()
        XCTAssertNotNil(savedPlace)
        let places = try await repository.fetchAllPlaces()
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places.first?.name, "テスト店舗")
    }

    func testMissingSelectionShowsError() async {
        let stubService = StubPlacesSearchService()
        stubService.autocompleteResult = .failure(PlacesSearchError.serviceUnavailable("キー未設定"))

        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        let viewModel = PlaceSearchViewModel(placesSearchService: stubService, createPlaceUseCase: useCase, geocodingService: geocoder)

        viewModel.query = "テスト"
        await viewModel.performSearch()
        XCTAssertEqual(viewModel.predictions.count, 0)
        XCTAssertEqual(viewModel.errorMessage, "キー未設定")

        let result = await viewModel.saveSelectedPlace()
        XCTAssertNil(result)
        XCTAssertEqual(viewModel.errorMessage, "地点が選択されていません")
    }

    func testUpdateCoordinateFromMapUsesGeocode() async {
        let stubService = StubPlacesSearchService()
        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        geocoder.result = .success(GeocodeResult(primaryText: "手動登録", secondaryText: "東京都千代田区"))
        let viewModel = PlaceSearchViewModel(placesSearchService: stubService, createPlaceUseCase: useCase, geocodingService: geocoder)

        let coordinate = CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0)
        viewModel.updateCoordinateFromMap(coordinate)
        try? await Task.sleep(nanoseconds: 5_000_000)

        XCTAssertEqual(viewModel.selectedCoordinate?.latitude, 35.0)
        XCTAssertEqual(viewModel.displayText, "東京都千代田区")
    }
}
