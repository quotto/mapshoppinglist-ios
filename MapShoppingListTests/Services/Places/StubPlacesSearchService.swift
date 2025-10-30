import Foundation
@testable import MapShoppingList

final class StubPlacesSearchService: PlacesSearchService {
    var autocompleteResult: Result<PlacesAutocompleteResponse, Error>?
    var detailsResult: Result<PlaceDetails, Error>?

    func autocomplete(query: String) async throws -> PlacesAutocompleteResponse {
        guard let result = autocompleteResult else {
            fatalError("autocompleteResult が設定されていません")
        }
        return try result.get()
    }

    func fetchPlaceDetails(placeId: String, session: PlacesAutocompleteSession) async throws -> PlaceDetails {
        guard let result = detailsResult else {
            fatalError("detailsResult が設定されていません")
        }
        return try result.get()
    }
}

