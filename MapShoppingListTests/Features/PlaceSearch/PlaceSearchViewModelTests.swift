import XCTest
import CoreLocation
import Combine
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
        let network = StubNetworkMonitor(isConnected: true)
        let viewModel = PlaceSearchViewModel(placesSearchService: stubService, createPlaceUseCase: useCase, geocodingService: geocoder, networkProvider: network)

        viewModel.query = "テスト"
        await viewModel.performSearch()
        XCTAssertEqual(viewModel.predictions.count, 1)
        XCTAssertEqual(stubService.receivedSessions.count, 1)
        if let firstEntry = stubService.receivedSessions.first {
            XCTAssertNil(firstEntry)
        } else {
            XCTFail("セッションが記録されていません")
        }

        await viewModel.selectPrediction(prediction)
        XCTAssertEqual(viewModel.displayText, "テスト店舗")
        XCTAssertNil(viewModel.searchErrorMessage)
        XCTAssertFalse(viewModel.isSearchRetryable)

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
        let network = StubNetworkMonitor(isConnected: true)
        let viewModel = PlaceSearchViewModel(placesSearchService: stubService, createPlaceUseCase: useCase, geocodingService: geocoder, networkProvider: network)

        viewModel.query = "テスト"
        await viewModel.performSearch()
        XCTAssertEqual(viewModel.predictions.count, 0)
        XCTAssertEqual(viewModel.searchErrorMessage, "キー未設定")
        XCTAssertTrue(viewModel.isSearchRetryable)

        let result = await viewModel.saveSelectedPlace()
        XCTAssertNil(result)
        XCTAssertEqual(viewModel.formErrorMessage, "地点が選択されていません")
    }

    func testUpdateCoordinateFromMapUsesGeocode() async {
        let stubService = StubPlacesSearchService()
        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        geocoder.result = .success(GeocodeResult(primaryText: "手動登録", secondaryText: "東京都千代田区"))
        let network = StubNetworkMonitor(isConnected: true)
        let viewModel = PlaceSearchViewModel(placesSearchService: stubService, createPlaceUseCase: useCase, geocodingService: geocoder, networkProvider: network)
    
        let coordinate = CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0)
        viewModel.updateCoordinateFromMap(coordinate)
        try? await Task.sleep(nanoseconds: 5_000_000)

        XCTAssertEqual(viewModel.selectedCoordinate?.latitude, 35.0)
        XCTAssertEqual(viewModel.displayText, "東京都千代田区")
    }

    func testAutocompleteSessionIsReusedWhenQueryIsRefined() async {
        let firstSessionToken = NSObject()
        let firstSession = PlacesAutocompleteSession(identifier: firstSessionToken)
        let secondSession = PlacesAutocompleteSession(identifier: NSObject())
        let prediction = PlaceAutocompletePrediction(
            id: "prediction",
            primaryText: "テスト",
            secondaryText: nil,
            distanceMeters: nil
        )

        let stubService = StubPlacesSearchService()
        stubService.enqueueAutocompleteResult(.success(PlacesAutocompleteResponse(session: firstSession, predictions: [prediction])))
        stubService.enqueueAutocompleteResult(.success(PlacesAutocompleteResponse(session: secondSession, predictions: [prediction])))

        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        let network = StubNetworkMonitor(isConnected: true)
        let viewModel = PlaceSearchViewModel(placesSearchService: stubService, createPlaceUseCase: useCase, geocodingService: geocoder, networkProvider: network)

        viewModel.query = "テスト"
        await viewModel.performSearch()

        viewModel.query = "テスト 店"
        await viewModel.performSearch()

        XCTAssertEqual(stubService.receivedSessions.count, 2)
        if let firstEntry = stubService.receivedSessions.first {
            XCTAssertNil(firstEntry)
        } else {
            XCTFail("1回目のセッションが記録されていません")
        }
        guard let secondEntry = stubService.receivedSessions.last, let reusedSession = secondEntry else {
            return XCTFail("2回目のセッションが取得できません")
        }
        XCTAssertTrue((reusedSession.identifier as AnyObject) === firstSession.identifier)
    }

    func testQuotaExceededErrorStopsRetry() async {
        let stubService = StubPlacesSearchService()
        stubService.autocompleteResult = .failure(PlacesSearchError.quotaExceeded("利用上限に達しました"))

        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        let network = StubNetworkMonitor(isConnected: true)
        let viewModel = PlaceSearchViewModel(placesSearchService: stubService, createPlaceUseCase: useCase, geocodingService: geocoder, networkProvider: network)

        viewModel.query = "テスト"
        await viewModel.performSearch()

        XCTAssertEqual(viewModel.searchErrorMessage, "利用上限に達しました")
        XCTAssertFalse(viewModel.isSearchRetryable)
        XCTAssertFalse(viewModel.isPredictionListVisible)
    }

    func testOfflineSearchShowsErrorImmediately() async {
        let stubService = StubPlacesSearchService()
        stubService.autocompleteResult = .success(
            PlacesAutocompleteResponse(session: PlacesAutocompleteSession(identifier: NSObject()), predictions: [])
        )

        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        let network = StubNetworkMonitor(isConnected: false)
        let viewModel = PlaceSearchViewModel(placesSearchService: stubService, createPlaceUseCase: useCase, geocodingService: geocoder, networkProvider: network)

        viewModel.query = "テスト"
        await viewModel.performSearch()

        XCTAssertEqual(viewModel.searchErrorMessage, "オフラインのため検索できません")
        XCTAssertFalse(viewModel.isSearchRetryable)
        XCTAssertEqual(stubService.receivedSessions.count, 0)
    }
}

private final class StubNetworkMonitor: NetworkStatusProviding {
    var isConnectedCurrent: Bool {
        isConnected
    }

    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        subject.eraseToAnyPublisher()
    }

    private let subject: CurrentValueSubject<Bool, Never>
    private var isConnected: Bool

    init(isConnected: Bool) {
        self.isConnected = isConnected
        subject = CurrentValueSubject(isConnected)
    }
}
