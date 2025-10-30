import Foundation
import Combine

@MainActor
final class PlaceSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var predictions: [PlaceAutocompletePrediction] = []
    @Published var isSearching = false
    @Published var isLoadingDetails = false
    @Published var selectedPredictionId: String?
    @Published var selectedDetails: PlaceDetails?
    @Published var customName: String = ""
    @Published var note: String = ""
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let placesSearchService: PlacesSearchService
    private let createPlaceUseCase: CreatePlaceUseCase
    private var currentSession: PlacesAutocompleteSession?

    init(
        placesSearchService: PlacesSearchService,
        createPlaceUseCase: CreatePlaceUseCase
    ) {
        self.placesSearchService = placesSearchService
        self.createPlaceUseCase = createPlaceUseCase
    }

    convenience init(environment: AppEnvironment) {
        self.init(
            placesSearchService: environment.placesSearchService,
            createPlaceUseCase: environment.createPlaceUseCase
        )
    }

    func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            predictions = []
            selectedPredictionId = nil
            selectedDetails = nil
            errorMessage = nil
            return
        }
        isSearching = true
        errorMessage = nil
        predictions = []
        do {
            let response = try await placesSearchService.autocomplete(query: trimmed)
            currentSession = response.session
            predictions = response.predictions
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    func selectPrediction(_ prediction: PlaceAutocompletePrediction) async {
        guard let session = currentSession else {
            errorMessage = "検索セッションが無効です。もう一度検索してください。"
            return
        }
        selectedPredictionId = prediction.id
        isLoadingDetails = true
        errorMessage = nil
        do {
            let details = try await placesSearchService.fetchPlaceDetails(placeId: prediction.id, session: session)
            selectedDetails = details
            customName = details.name
            note = details.formattedAddress ?? ""
        } catch {
            errorMessage = error.localizedDescription
            selectedDetails = nil
        }
        isLoadingDetails = false
    }

    func saveSelectedPlace() async -> Place? {
        guard let details = selectedDetails else {
            errorMessage = "地点が選択されていません"
            return nil
        }
        let trimmedName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            errorMessage = "名称を入力してください"
            return nil
        }

        isSaving = true
        errorMessage = nil

        let place = Place(
            id: UUID(),
            name: trimmedName,
            latitudeE6: Self.toE6(details.latitude),
            longitudeE6: Self.toE6(details.longitude),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
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
        selectedPredictionId = nil
        selectedDetails = nil
        customName = ""
        note = ""
    }

    func handlePlaceCreated(_ place: Place) {
        predictions = []
        selectedPredictionId = place.id.uuidString
        selectedDetails = PlaceDetails(
            id: place.id.uuidString,
            name: place.name,
            latitude: Double(place.latitudeE6) / 1_000_000,
            longitude: Double(place.longitudeE6) / 1_000_000,
            formattedAddress: place.note
        )
        customName = place.name
        note = place.note ?? ""
    }

    private static func toE6(_ value: Double) -> Int {
        Int((value * 1_000_000).rounded())
    }
}
