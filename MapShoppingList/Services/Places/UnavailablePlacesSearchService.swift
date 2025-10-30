import Foundation

/// APIキー未設定時などに利用するダミー実装。
struct UnavailablePlacesSearchService: PlacesSearchService {
    private let reason: String

    init(reason: String) {
        self.reason = reason
    }

    func autocomplete(query: String) async throws -> PlacesAutocompleteResponse {
        throw PlacesSearchError.serviceUnavailable(reason)
    }

    func fetchPlaceDetails(placeId: String, session: PlacesAutocompleteSession) async throws -> PlaceDetails {
        throw PlacesSearchError.serviceUnavailable(reason)
    }
}

