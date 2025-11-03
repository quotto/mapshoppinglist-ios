import Foundation
@testable import MapShoppingList

final class StubPlacesSearchService: PlacesSearchService {
    var autocompleteResult: Result<PlacesAutocompleteResponse, Error>? {
        didSet { autocompleteResultsQueue.removeAll() }
    }
    var detailsResult: Result<PlaceDetails, Error>? {
        didSet { detailsResultsQueue.removeAll() }
    }
    private var autocompleteResultsQueue: [Result<PlacesAutocompleteResponse, Error>] = []
    private var detailsResultsQueue: [Result<PlaceDetails, Error>] = []

    private(set) var receivedSessions: [PlacesAutocompleteSession?] = []

    func enqueueAutocompleteResult(_ result: Result<PlacesAutocompleteResponse, Error>) {
        autocompleteResultsQueue.append(result)
    }

    func enqueueDetailsResult(_ result: Result<PlaceDetails, Error>) {
        detailsResultsQueue.append(result)
    }

    func autocomplete(query: String, session: PlacesAutocompleteSession?) async throws -> PlacesAutocompleteResponse {
        receivedSessions.append(session)
        if autocompleteResultsQueue.isEmpty == false {
            let result = autocompleteResultsQueue.removeFirst()
            return try result.get()
        }
        guard let result = autocompleteResult else {
            fatalError("autocompleteResult が設定されていません")
        }
        return try result.get()
    }

    func fetchPlaceDetails(placeId: String, session: PlacesAutocompleteSession) async throws -> PlaceDetails {
        if detailsResultsQueue.isEmpty == false {
            let result = detailsResultsQueue.removeFirst()
            return try result.get()
        }
        guard let result = detailsResult else {
            fatalError("detailsResult が設定されていません")
        }
        return try result.get()
    }

    func fetchPlaceDetails(placeId: String) async throws -> PlaceDetails {
        if detailsResultsQueue.isEmpty == false {
            let result = detailsResultsQueue.removeFirst()
            return try result.get()
        }
        guard let result = detailsResult else {
            fatalError("detailsResult が設定されていません")
        }
        return try result.get()
    }
}
