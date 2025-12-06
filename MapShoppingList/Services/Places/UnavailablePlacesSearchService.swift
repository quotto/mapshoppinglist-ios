import Foundation
import CoreLocation

/// APIキー未設定時などに利用するダミー実装。
struct UnavailablePlacesSearchService: PlacesSearchService {
    private let reason: String

    init(reason: String) {
        self.reason = reason
    }

    func search(
        query: String,
        session: PlacesSearchSession?,
        origin: CLLocationCoordinate2D?
    ) async throws -> PlacesSearchResponse {
        throw PlacesSearchError.serviceUnavailable(reason)
    }

    func fetchPlaceDetails(placeId: String, session: PlacesSearchSession) async throws -> PlaceDetails {
        throw PlacesSearchError.serviceUnavailable(reason)
    }

    func fetchPlaceDetails(placeId: String) async throws -> PlaceDetails {
        throw PlacesSearchError.serviceUnavailable(reason)
    }
}
