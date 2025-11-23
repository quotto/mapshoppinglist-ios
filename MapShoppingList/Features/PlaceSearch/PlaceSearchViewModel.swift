import Foundation
import Combine
import CoreLocation
import GooglePlaces

@MainActor
final class PlaceSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var predictions: [PlaceAutocompletePrediction] = []
    @Published var isPredictionListVisible = false
    @Published var isSearching = false
    @Published var isLoadingDetails = false
    @Published var isGeocoding = false
    @Published var selectedCoordinate: CLLocationCoordinate2D?
    @Published var displayText: String?
    @Published var isSaving = false
    @Published var searchErrorMessage: String?
    @Published var isSearchRetryable: Bool = false
    @Published var geocodeErrorMessage: String?
    @Published var formErrorMessage: String?
    @Published var isOffline: Bool = false
    @Published var initialCameraCoordinate: CLLocationCoordinate2D?

    private let placesSearchService: PlacesSearchService
    private let createPlaceUseCase: CreatePlaceUseCase
    private let geocodingService: GeocodingService
    private let networkProvider: NetworkStatusProviding
    private let locationPermissionManager: LocationPermissionManager
    private let locationProvider: CurrentLocationProviding
    private var cancellable: AnyCancellable?
    private var currentSession: PlacesAutocompleteSession?
    private var lastQuery: String?
    private var didLoadInitialCamera = false

    private var selectedName: String?
    private var selectedAddress: String?
    static let fallbackCoordinate = CLLocationCoordinate2D(latitude: 35.6813, longitude: 139.767066)

    init(
        placesSearchService: PlacesSearchService,
        createPlaceUseCase: CreatePlaceUseCase,
        geocodingService: GeocodingService,
        networkProvider: NetworkStatusProviding,
        locationPermissionManager: LocationPermissionManager,
        locationProvider: CurrentLocationProviding
    ) {
        self.placesSearchService = placesSearchService
        self.createPlaceUseCase = createPlaceUseCase
        self.geocodingService = geocodingService
        self.networkProvider = networkProvider
        self.locationPermissionManager = locationPermissionManager
        self.locationProvider = locationProvider
        isOffline = networkProvider.isConnectedCurrent == false
        cancellable = networkProvider.isConnectedPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnected in
                self?.isOffline = (isConnected == false)
            }
    }

    convenience init(environment: AppEnvironment) {
        self.init(
            placesSearchService: environment.placesSearchService,
            createPlaceUseCase: environment.createPlaceUseCase,
            geocodingService: environment.geocodingService,
            networkProvider: environment.networkMonitor,
            locationPermissionManager: environment.locationPermissionManager,
            locationProvider: environment.currentLocationProvider
        )
    }

    func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            predictions = []
            isPredictionListVisible = false
            currentSession = nil
            searchErrorMessage = nil
            isSearchRetryable = false
            lastQuery = nil
            return
        }
        guard isOffline == false else {
            searchErrorMessage = "オフラインのため検索できません"
            isSearchRetryable = false
            return
        }
        isSearching = true
        searchErrorMessage = nil
        isSearchRetryable = false
        do {
            let reuseSession = (
                currentSession != nil &&
                (lastQuery.map { trimmed.hasPrefix($0) } ?? false)
            )
            let response = try await placesSearchService.autocomplete(
                query: trimmed,
                session: reuseSession ? currentSession : nil
            )
            currentSession = response.session
            predictions = response.predictions
            isPredictionListVisible = response.predictions.isEmpty == false
            if response.predictions.isEmpty {
                searchErrorMessage = "候補が見つかりませんでした。条件を変えて検索してください。"
                isSearchRetryable = false
            }
            lastQuery = trimmed
        } catch let error as PlacesSearchError {
            handleSearchError(error)
        } catch {
            let wrapped = PlacesSearchError.underlying(error)
            handleSearchError(wrapped)
        }
        isSearching = false
    }

    func selectPrediction(_ prediction: PlaceAutocompletePrediction) async {
        guard let session = currentSession else {
            searchErrorMessage = "検索セッションが無効です。もう一度検索してください。"
            return
        }
        isPredictionListVisible = false
        isLoadingDetails = true
        searchErrorMessage = nil
        isSearchRetryable = false
        geocodeErrorMessage = nil
        guard isOffline == false else {
            searchErrorMessage = "オフラインのため詳細を取得できません"
            isSearchRetryable = false
            isLoadingDetails = false
            return
        }
        do {
            let details = try await placesSearchService.fetchPlaceDetails(placeId: prediction.id, session: session)
            apply(details: details)
            currentSession = nil
            lastQuery = nil
        } catch let error as PlacesSearchError {
            searchErrorMessage = error.errorDescription
            isSearchRetryable = error.isRetryable
        } catch {
            let wrapped = PlacesSearchError.underlying(error)
            searchErrorMessage = wrapped.errorDescription
            isSearchRetryable = wrapped.isRetryable
        }
        isLoadingDetails = false
    }

    func selectPlace(by placeID: String) async {
        isPredictionListVisible = false
        isLoadingDetails = true
        searchErrorMessage = nil
        isSearchRetryable = false
        geocodeErrorMessage = nil
        guard isOffline == false else {
            searchErrorMessage = "オフラインのため詳細を取得できません"
            isSearchRetryable = false
            isLoadingDetails = false
            return
        }
        do {
            let details = try await placesSearchService.fetchPlaceDetails(placeId: placeID)
            apply(details: details)
            currentSession = nil
            lastQuery = nil
        } catch let error as PlacesSearchError {
            searchErrorMessage = error.errorDescription
            isSearchRetryable = error.isRetryable
        } catch {
            let wrapped = PlacesSearchError.underlying(error)
            searchErrorMessage = wrapped.errorDescription
            isSearchRetryable = wrapped.isRetryable
        }
        isLoadingDetails = false
    }

    func updateCoordinateFromMap(_ coordinate: CLLocationCoordinate2D) {
        selectedCoordinate = coordinate
        selectedName = nil
        selectedAddress = nil
        displayText = nil
        isPredictionListVisible = false
        currentSession = nil
        predictions = []
        searchErrorMessage = nil
        isSearchRetryable = false
        geocodeErrorMessage = nil
        formErrorMessage = nil
        Task { await reverseGeocodeIfNeeded(for: coordinate) }
    }

    func saveSelectedPlace() async -> Place? {
        guard let coordinate = selectedCoordinate else {
            formErrorMessage = "地点が選択されていません"
            return nil
        }
        let rawName = (selectedName ?? selectedAddress)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (rawName?.isEmpty == false ? rawName : nil) ?? "新しい地点"
        let trimmedAddress = selectedAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        formErrorMessage = nil

        let place = Place(
            id: UUID(),
            name: name,
            latitudeE6: Self.toE6(coordinate.latitude),
            longitudeE6: Self.toE6(coordinate.longitude),
            note: trimmedAddress?.isEmpty == false ? trimmedAddress : nil,
            lastUsedAt: Date(),
            isActive: false
        )

        do {
            try await createPlaceUseCase.execute(place: place)
            isSaving = false
            NotificationCenter.default.post(name: .geofenceNeedsSync, object: nil)
            return place
        } catch {
            formErrorMessage = error.localizedDescription
            isSaving = false
            return nil
        }
    }

    func resetSelection() {
        selectedCoordinate = nil
        selectedName = nil
        selectedAddress = nil
        displayText = nil
        predictions = []
        isPredictionListVisible = false
        currentSession = nil
        searchErrorMessage = nil
        isSearchRetryable = false
        geocodeErrorMessage = nil
        formErrorMessage = nil
    }

    func loadInitialCameraIfNeeded() async {
        guard didLoadInitialCamera == false else { return }
        didLoadInitialCamera = true

        let status = locationPermissionManager.authorizationStatus()
        guard status.isAuthorized else {
            initialCameraCoordinate = Self.fallbackCoordinate
            return
        }

        do {
            let coordinate = try await locationProvider.currentLocation()
            initialCameraCoordinate = coordinate
        } catch {
            // 現在地が取得できない場合は東京駅でフォールバックする
            initialCameraCoordinate = Self.fallbackCoordinate
        }
    }

    private func apply(details: PlaceDetails) {
        selectedCoordinate = CLLocationCoordinate2D(latitude: details.latitude, longitude: details.longitude)
        selectedName = details.name.isEmpty ? details.formattedAddress : details.name
        selectedAddress = details.formattedAddress
        displayText = selectedName ?? selectedAddress
        geocodeErrorMessage = nil
        formErrorMessage = nil
    }

    private func handleSearchError(_ error: PlacesSearchError) {
        searchErrorMessage = error.errorDescription ?? "地点検索に失敗しました。"
        isSearchRetryable = error.isRetryable
        predictions = []
        isPredictionListVisible = false
        if error.isRetryable == false {
            currentSession = nil
        }
        lastQuery = nil
    }

    private static func toE6(_ value: Double) -> Int {
        Int((value * 1_000_000).rounded())
    }

    private func reverseGeocodeIfNeeded(for coordinate: CLLocationCoordinate2D) async {
        isGeocoding = true
        geocodeErrorMessage = nil
        let result = await geocodingService.reverseGeocode(latitude: coordinate.latitude, longitude: coordinate.longitude)
        switch result {
        case let .success(geocode):
            selectedName = geocode.primaryText ?? geocode.secondaryText ?? "新しい地点"
            selectedAddress = geocode.secondaryText
            displayText = selectedAddress ?? selectedName
        case let .failure(error):
            geocodeErrorMessage = error.localizedDescription
        }
        isGeocoding = false
    }
}
