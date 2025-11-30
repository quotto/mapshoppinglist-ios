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
        let session = PlacesSearchSession(identifier: NSObject())
        let details = PlaceDetails(
            id: "test-place-id",
            name: "テスト店舗",
            latitude: 35.0,
            longitude: 139.0,
            formattedAddress: "東京都千代田区1-1"
        )
        let response = PlacesSearchResponse(session: session, places: [details])

        let stubService = StubPlacesSearchService()
        stubService.searchResult = .success(response)
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
        #expect(viewModel.places.count == 1)
        #expect(stubService.receivedSessions.count == 1)
        if let firstEntry = stubService.receivedSessions.first {
            #expect(firstEntry == nil)
        } else {
            Issue.record("セッションが記録されていません")
        }

        await viewModel.selectPlace(details)
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
        stubService.searchResult = .failure(PlacesSearchError.serviceUnavailable("キー未設定"))

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
        #expect(viewModel.places.isEmpty)
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

    @Test("text search does not rely on session reuse")
    func textSearchDoesNotRelyOnSessionReuse() async {
        let place = PlaceDetails(
            id: "prediction",
            name: "テスト",
            latitude: 0.0,
            longitude: 0.0,
            formattedAddress: "東京都",
        )

        let stubService = StubPlacesSearchService()
        stubService.enqueueSearchResult(.success(PlacesSearchResponse(session: PlacesSearchSession(identifier: NSObject()), places: [place])))
        stubService.enqueueSearchResult(.success(PlacesSearchResponse(session: PlacesSearchSession(identifier: NSObject()), places: [place])))

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
        #expect(stubService.receivedSessions.allSatisfy { $0 == nil })
    }

    @Test("quota exceeded error disables retry")
    func quotaExceededErrorStopsRetry() async {
        let stubService = StubPlacesSearchService()
        stubService.searchResult = .failure(PlacesSearchError.quotaExceeded("利用上限に達しました"))

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
        stubService.searchResult = .success(
            PlacesSearchResponse(session: PlacesSearchSession(identifier: NSObject()), places: [])
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

    @Test("search uses map center as origin")
    func searchUsesMapCenterAsOrigin() async {
        let session = PlacesSearchSession(identifier: NSObject())
        let place = PlaceDetails(
            id: "nearby",
            name: "最寄り店",
            latitude: 0.0,
            longitude: 0.0,
            formattedAddress: "東京都"
        )
        let response = PlacesSearchResponse(session: session, places: [place])

        let stubService = StubPlacesSearchService()
        stubService.searchResult = .success(response)

        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        let network = StubNetworkMonitor(isConnected: true)
        let permission = StubLocationPermissionManager(status: .authorizedWhenInUse)
        let locationProvider = StubCurrentLocationProvider(
            result: .success(CLLocationCoordinate2D(latitude: 10.0, longitude: 20.0))
        )
        let viewModel = PlaceSearchViewModel(
            placesSearchService: stubService,
            createPlaceUseCase: useCase,
            geocodingService: geocoder,
            networkProvider: network,
            locationPermissionManager: permission,
            locationProvider: locationProvider
        )

        viewModel.mapCenterCoordinate = CLLocationCoordinate2D(latitude: 11.0, longitude: 22.0)
        viewModel.query = "スーパー"
        await viewModel.performSearch()

        let recordedOrigin = stubService.receivedOrigins.first ?? nil
        #expect(recordedOrigin?.latitude == 11.0)
        #expect(recordedOrigin?.longitude == 22.0)
    }

    @Test("search uses latest map center after move")
    func searchUsesLatestMapCenterAfterMove() async {
        let firstSession = PlacesSearchSession(identifier: NSObject())
        let secondSession = PlacesSearchSession(identifier: NSObject())
        let place = PlaceDetails(
            id: "move",
            name: "移動後",
            latitude: 0.0,
            longitude: 0.0,
            formattedAddress: "東京都"
        )

        let stubService = StubPlacesSearchService()
        stubService.enqueueSearchResult(.success(PlacesSearchResponse(session: firstSession, places: [place])))
        stubService.enqueueSearchResult(.success(PlacesSearchResponse(session: secondSession, places: [place])))

        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        let network = StubNetworkMonitor(isConnected: true)
        let permission = StubLocationPermissionManager(status: .authorizedWhenInUse)
        let locationProvider = StubCurrentLocationProvider(
            result: .success(CLLocationCoordinate2D(latitude: 33.0, longitude: 44.0))
        )
        let viewModel = PlaceSearchViewModel(
            placesSearchService: stubService,
            createPlaceUseCase: useCase,
            geocodingService: geocoder,
            networkProvider: network,
            locationPermissionManager: permission,
            locationProvider: locationProvider
        )

        viewModel.mapCenterCoordinate = CLLocationCoordinate2D(latitude: 1.0, longitude: 2.0)
        viewModel.query = "スーパー"
        await viewModel.performSearch()

        viewModel.updateMapCenter(CLLocationCoordinate2D(latitude: 5.0, longitude: 6.0))
        viewModel.query = "スーパー2"
        await viewModel.performSearch()

        #expect(stubService.receivedOrigins.count == 2)
        let firstOrigin = stubService.receivedOrigins.first ?? nil
        let lastOrigin = stubService.receivedOrigins.last ?? nil
        #expect(firstOrigin?.latitude == 1.0)
        #expect(firstOrigin?.longitude == 2.0)
        #expect(lastOrigin?.latitude == 5.0)
        #expect(lastOrigin?.longitude == 6.0)
    }

    @Test("search falls back to initial camera when location unavailable")
    func searchFallsBackToInitialCameraWhenLocationUnavailable() async {
        let session = PlacesSearchSession(identifier: NSObject())
        let place = PlaceDetails(
            id: "fallback",
            name: "フォールバック店",
            latitude: 0.0,
            longitude: 0.0,
            formattedAddress: "東京都"
        )
        let response = PlacesSearchResponse(session: session, places: [place])

        let stubService = StubPlacesSearchService()
        stubService.searchResult = .success(response)

        let repository = InMemoryPlacesRepository()
        let useCase = CreatePlaceUseCase(placesRepository: repository)
        let geocoder = StubGeocodingService()
        let network = StubNetworkMonitor(isConnected: true)
        let permission = StubLocationPermissionManager(status: .denied)
        let locationProvider = StubCurrentLocationProvider(
            result: .failure(StubLocationError.noLocation)
        )
        let viewModel = PlaceSearchViewModel(
            placesSearchService: stubService,
            createPlaceUseCase: useCase,
            geocodingService: geocoder,
            networkProvider: network,
            locationPermissionManager: permission,
            locationProvider: locationProvider
        )

        viewModel.query = "コンビニ"
        await viewModel.performSearch()

        let recordedOrigin = stubService.receivedOrigins.first ?? nil
        #expect(recordedOrigin?.latitude == PlaceSearchViewModel.fallbackCoordinate.latitude)
        #expect(recordedOrigin?.longitude == PlaceSearchViewModel.fallbackCoordinate.longitude)
    }

//    @Test("predictions are sorted by distance when available")
//    func predictionsAreSortedByDistance() async {
//        let session = PlacesSearchSession(identifier: NSObject())
//        let first = PlaceDetails(
//            id: "far",
//            name: "遠い店",
//        )
//        let second = PlaceAutocompletePrediction(
//            id: "near",
//            primaryText: "近い店",
//            secondaryText: nil,
//            distanceMeters: 50
//        )
//        let third = PlaceAutocompletePrediction(
//            id: "unknown",
//            primaryText: "距離不明",
//            secondaryText: nil,
//            distanceMeters: nil
//        )
//        let response = PlacesSearchResponse(
//            session: session,
//            predictions: [first, second, third]
//        )
//
//        let stubService = StubPlacesSearchService()
//        stubService.autocompleteResult = .success(response)
//
//        let repository = InMemoryPlacesRepository()
//        let useCase = CreatePlaceUseCase(placesRepository: repository)
//        let geocoder = StubGeocodingService()
//        let network = StubNetworkMonitor(isConnected: true)
//        let permission = StubLocationPermissionManager(status: .authorizedAlways)
//        let locationProvider = StubCurrentLocationProvider(
//            result: .success(CLLocationCoordinate2D(latitude: 1.0, longitude: 2.0))
//        )
//        let viewModel = PlaceSearchViewModel(
//            placesSearchService: stubService,
//            createPlaceUseCase: useCase,
//            geocodingService: geocoder,
//            networkProvider: network,
//            locationPermissionManager: permission,
//            locationProvider: locationProvider
//        )
//
//        viewModel.query = "テスト"
//        await viewModel.performSearch()
//
//        let ids = viewModel.places.map(\.id)
//        #expect(ids == ["near", "far", "unknown"])
//    }
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
