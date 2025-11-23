import Testing
import Foundation
import CoreLocation
import Combine
@testable import MapShoppingList

@Suite("PlaceSearchViewModelTests")
@MainActor
struct PlaceSearchViewModelTests {
    @Test("search, select, and save place")
    func searchSelectAndSavePlace() async throws {
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
        let permission = StubLocationPermissionManager(status: .authorizedAlways)
        let locationProvider = StubCurrentLocationProvider(result: .failure(StubLocationError.noLocation))
        let viewModel = PlaceSearchViewModel(
            placesSearchService: stubService,
            createPlaceUseCase: useCase,
            geocodingService: geocoder,
            networkProvider: network,
            locationPermissionManager: permission,
            locationProvider: locationProvider
        )

        viewModel.query = "テスト"
        await viewModel.performSearch()
        #expect(viewModel.predictions.count == 1)
        #expect(stubService.receivedSessions.count == 1)
        if let firstEntry = stubService.receivedSessions.first {
            #expect(firstEntry == nil)
        } else {
            Issue.record("セッションが記録されていません")
        }

        await viewModel.selectPrediction(prediction)
        #expect(viewModel.displayText == "テスト店舗")
        #expect(viewModel.searchErrorMessage == nil)
        #expect(viewModel.isSearchRetryable == false)

        let savedPlace = await viewModel.saveSelectedPlace()
        #expect(savedPlace != nil)
        let places = try await repository.fetchAllPlaces()
        #expect(places.count == 1)
        #expect(places.first?.name == "テスト店舗")
    }

    @Test("missing selection shows error")
    func missingSelectionShowsError() async {
        let stubService = StubPlacesSearchService()
        stubService.autocompleteResult = .failure(PlacesSearchError.serviceUnavailable("キー未設定"))

        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        let network = StubNetworkMonitor(isConnected: true)
        let permission = StubLocationPermissionManager(status: .authorizedAlways)
        let locationProvider = StubCurrentLocationProvider(result: .failure(StubLocationError.noLocation))
        let viewModel = PlaceSearchViewModel(
            placesSearchService: stubService,
            createPlaceUseCase: useCase,
            geocodingService: geocoder,
            networkProvider: network,
            locationPermissionManager: permission,
            locationProvider: locationProvider
        )

        viewModel.query = "テスト"
        await viewModel.performSearch()
        #expect(viewModel.predictions.isEmpty)
        #expect(viewModel.searchErrorMessage == "キー未設定")
        #expect(viewModel.isSearchRetryable)

        let result = await viewModel.saveSelectedPlace()
        #expect(result == nil)
        #expect(viewModel.formErrorMessage == "地点が選択されていません")
    }

    @Test("updateCoordinateFromMap triggers reverse geocode")
    func updateCoordinateFromMapUsesGeocode() async {
        let stubService = StubPlacesSearchService()
        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        geocoder.result = .success(GeocodeResult(primaryText: "手動登録", secondaryText: "東京都千代田区"))
        let network = StubNetworkMonitor(isConnected: true)
        let permission = StubLocationPermissionManager(status: .authorizedAlways)
        let locationProvider = StubCurrentLocationProvider(result: .failure(StubLocationError.noLocation))
        let viewModel = PlaceSearchViewModel(
            placesSearchService: stubService,
            createPlaceUseCase: useCase,
            geocodingService: geocoder,
            networkProvider: network,
            locationPermissionManager: permission,
            locationProvider: locationProvider
        )

        let coordinate = CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0)
        viewModel.updateCoordinateFromMap(coordinate)
        try? await Task.sleep(nanoseconds: 5_000_000)

        #expect(viewModel.selectedCoordinate?.latitude == 35.0)
        #expect(viewModel.displayText == "東京都千代田区")
    }

    @Test("autocomplete session is reused when refining query")
    func autocompleteSessionIsReusedWhenQueryIsRefined() async {
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
        let permission = StubLocationPermissionManager(status: .authorizedAlways)
        let locationProvider = StubCurrentLocationProvider(result: .failure(StubLocationError.noLocation))
        let viewModel = PlaceSearchViewModel(
            placesSearchService: stubService,
            createPlaceUseCase: useCase,
            geocodingService: geocoder,
            networkProvider: network,
            locationPermissionManager: permission,
            locationProvider: locationProvider
        )

        viewModel.query = "テスト"
        await viewModel.performSearch()

        viewModel.query = "テスト 店"
        await viewModel.performSearch()

        #expect(stubService.receivedSessions.count == 2)
        if let firstEntry = stubService.receivedSessions.first {
            #expect(firstEntry == nil)
        } else {
            Issue.record("1回目のセッションが記録されていません")
        }
        guard let secondEntry = stubService.receivedSessions.last else {
            Issue.record("2回目のセッションが不足しています")
            return
        }
        guard let reusedSession = secondEntry else {
            Issue.record("2回目のセッションがnilです")
            return
        }
        #expect((reusedSession.identifier as AnyObject) === firstSession.identifier as AnyObject)
    }

    @Test("quota exceeded error disables retry")
    func quotaExceededErrorStopsRetry() async {
        let stubService = StubPlacesSearchService()
        stubService.autocompleteResult = .failure(PlacesSearchError.quotaExceeded("利用上限に達しました"))

        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        let network = StubNetworkMonitor(isConnected: true)
        let permission = StubLocationPermissionManager(status: .authorizedAlways)
        let locationProvider = StubCurrentLocationProvider(result: .failure(StubLocationError.noLocation))
        let viewModel = PlaceSearchViewModel(
            placesSearchService: stubService,
            createPlaceUseCase: useCase,
            geocodingService: geocoder,
            networkProvider: network,
            locationPermissionManager: permission,
            locationProvider: locationProvider
        )

        viewModel.query = "テスト"
        await viewModel.performSearch()

        #expect(viewModel.searchErrorMessage == "利用上限に達しました")
        #expect(viewModel.isSearchRetryable == false)
        #expect(viewModel.isPredictionListVisible == false)
    }

    @Test("offline search shows error immediately")
    func offlineSearchShowsErrorImmediately() async {
        let stubService = StubPlacesSearchService()
        stubService.autocompleteResult = .success(
            PlacesAutocompleteResponse(session: PlacesAutocompleteSession(identifier: NSObject()), predictions: [])
        )

        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        let network = StubNetworkMonitor(isConnected: false)
        let permission = StubLocationPermissionManager(status: .authorizedAlways)
        let locationProvider = StubCurrentLocationProvider(result: .failure(StubLocationError.noLocation))
        let viewModel = PlaceSearchViewModel(
            placesSearchService: stubService,
            createPlaceUseCase: useCase,
            geocodingService: geocoder,
            networkProvider: network,
            locationPermissionManager: permission,
            locationProvider: locationProvider
        )

        viewModel.query = "テスト"
        await viewModel.performSearch()

        #expect(viewModel.searchErrorMessage == "オフラインのため検索できません")
        #expect(viewModel.isSearchRetryable == false)
        #expect(stubService.receivedSessions.isEmpty)
    }

    @Test("initial camera uses current location when authorized")
    func initialCameraUsesCurrentLocation() async {
        let stubService = StubPlacesSearchService()
        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        let network = StubNetworkMonitor(isConnected: true)
        let permission = StubLocationPermissionManager(status: .authorizedWhenInUse)
        let locationProvider = StubCurrentLocationProvider(
            result: .success(CLLocationCoordinate2D(latitude: 1.23, longitude: 4.56))
        )
        let viewModel = PlaceSearchViewModel(
            placesSearchService: stubService,
            createPlaceUseCase: useCase,
            geocodingService: geocoder,
            networkProvider: network,
            locationPermissionManager: permission,
            locationProvider: locationProvider
        )

        await viewModel.loadInitialCameraIfNeeded()

        #expect(viewModel.initialCameraCoordinate?.latitude == 1.23)
        #expect(viewModel.initialCameraCoordinate?.longitude == 4.56)
    }

    @Test("initial camera falls back when permission denied")
    func initialCameraFallsBackWhenDenied() async {
        let stubService = StubPlacesSearchService()
        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        let network = StubNetworkMonitor(isConnected: true)
        let permission = StubLocationPermissionManager(status: .denied)
        let locationProvider = StubCurrentLocationProvider(
            result: .success(CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0))
        )
        let viewModel = PlaceSearchViewModel(
            placesSearchService: stubService,
            createPlaceUseCase: useCase,
            geocodingService: geocoder,
            networkProvider: network,
            locationPermissionManager: permission,
            locationProvider: locationProvider
        )

        await viewModel.loadInitialCameraIfNeeded()

        #expect(viewModel.initialCameraCoordinate?.latitude == 35.6813)
        #expect(viewModel.initialCameraCoordinate?.longitude == 139.767066)
    }
}

private final class StubNetworkMonitor: NetworkStatusProviding {
    var isConnectedCurrent: Bool { isConnected }

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

@MainActor
private final class StubLocationPermissionManager: LocationPermissionManager {
    private let status: CLAuthorizationStatus

    init(status: CLAuthorizationStatus) {
        self.status = status
    }

    func authorizationStatus() -> CLAuthorizationStatus { status }

    func requestAuthorization() async -> CLAuthorizationStatus { status }
}

@MainActor
private final class StubCurrentLocationProvider: CurrentLocationProviding {
    var result: Result<CLLocationCoordinate2D, Error>

    init(result: Result<CLLocationCoordinate2D, Error>) {
        self.result = result
    }

    func currentLocation() async throws -> CLLocationCoordinate2D {
        try result.get()
    }
}

private enum StubLocationError: Error {
    case noLocation
}
