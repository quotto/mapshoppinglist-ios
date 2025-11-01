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
    @Published var errorMessage: String?

    private let placesSearchService: PlacesSearchService
    private let createPlaceUseCase: CreatePlaceUseCase
    private let geocodingService: GeocodingService
    private var currentSession: PlacesAutocompleteSession?

    private var selectedName: String?
    private var selectedAddress: String?

    init(
        placesSearchService: PlacesSearchService,
        createPlaceUseCase: CreatePlaceUseCase,
        geocodingService: GeocodingService
    ) {
        self.placesSearchService = placesSearchService
        self.createPlaceUseCase = createPlaceUseCase
        self.geocodingService = geocodingService
    }

    convenience init(environment: AppEnvironment) {
        self.init(
            placesSearchService: environment.placesSearchService,
            createPlaceUseCase: environment.createPlaceUseCase,
            geocodingService: environment.geocodingService
        )
    }

    func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            predictions = []
            isPredictionListVisible = false
            currentSession = nil
            return
        }
        isSearching = true
        errorMessage = nil
        do {
            let response = try await placesSearchService.autocomplete(query: trimmed)
            currentSession = response.session
            predictions = response.predictions
            isPredictionListVisible = true
        } catch {
            errorMessage = error.localizedDescription
            predictions = []
            isPredictionListVisible = false
        }
        isSearching = false
    }

    func selectPrediction(_ prediction: PlaceAutocompletePrediction) async {
        guard let session = currentSession else {
            errorMessage = "検索セッションが無効です。もう一度検索してください。"
            return
        }
        isPredictionListVisible = false
        isLoadingDetails = true
        errorMessage = nil
        do {
            let details = try await placesSearchService.fetchPlaceDetails(placeId: prediction.id, session: session)
            apply(details: details)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingDetails = false
    }

    func selectPlace(by placeID: String) async {
        isPredictionListVisible = false
        isLoadingDetails = true
        errorMessage = nil
        do {
            let details = try await placesSearchService.fetchPlaceDetails(placeId: placeID)
            apply(details: details)
        } catch {
            errorMessage = error.localizedDescription
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
        errorMessage = nil
        Task { await reverseGeocodeIfNeeded(for: coordinate) }
    }

    func saveSelectedPlace() async -> Place? {
        guard let coordinate = selectedCoordinate else {
            errorMessage = "地点が選択されていません"
            return nil
        }
        let rawName = (selectedName ?? selectedAddress)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (rawName?.isEmpty == false ? rawName : nil) ?? "新しい地点"
        let trimmedAddress = selectedAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        errorMessage = nil

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
            return place
        } catch {
            errorMessage = error.localizedDescription
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
    }

    private func apply(details: PlaceDetails) {
        selectedCoordinate = CLLocationCoordinate2D(latitude: details.latitude, longitude: details.longitude)
        selectedName = details.name.isEmpty ? details.formattedAddress : details.name
        selectedAddress = details.formattedAddress
        displayText = selectedName ?? selectedAddress
        errorMessage = nil
    }

    private static func toE6(_ value: Double) -> Int {
        Int((value * 1_000_000).rounded())
    }

    private func reverseGeocodeIfNeeded(for coordinate: CLLocationCoordinate2D) async {
        isGeocoding = true
        let result = await geocodingService.reverseGeocode(latitude: coordinate.latitude, longitude: coordinate.longitude)
        switch result {
        case let .success(geocode):
            selectedName = geocode.primaryText ?? geocode.secondaryText ?? "新しい地点"
            selectedAddress = geocode.secondaryText
            displayText = selectedAddress ?? selectedName
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
        isGeocoding = false
    }
}
