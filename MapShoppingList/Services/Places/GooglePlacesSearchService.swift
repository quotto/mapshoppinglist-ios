import Foundation
import GooglePlaces

/// Google Places SDK を利用した検索サービス実装。
final class GooglePlacesSearchService: PlacesSearchService {
    private let client: GMSPlacesClient

    init(client: GMSPlacesClient) {
        self.client = client
    }

    func autocomplete(query: String) async throws -> PlacesAutocompleteResponse {
        let token = GMSAutocompleteSessionToken()
        let predictions: [PlaceAutocompletePrediction] = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[PlaceAutocompletePrediction], Error>) in
            let filter = GMSAutocompleteFilter()
            filter.type = .establishment

            client.findAutocompletePredictions(fromQuery: query, filter: filter, sessionToken: token) { results, error in
                if let error = error {
                    continuation.resume(throwing: PlacesSearchError.underlying(error))
                    return
                }
                let mapped = (results ?? []).map { prediction in
                    PlaceAutocompletePrediction(
                        id: prediction.placeID,
                        primaryText: prediction.attributedPrimaryText.string,
                        secondaryText: prediction.attributedSecondaryText?.string,
                        distanceMeters: prediction.distanceMeters?.doubleValue
                    )
                }
                continuation.resume(returning: mapped)
            }
        }
        return PlacesAutocompleteResponse(
            session: PlacesAutocompleteSession(identifier: token),
            predictions: predictions
        )
    }

    func fetchPlaceDetails(placeId: String, session: PlacesAutocompleteSession) async throws -> PlaceDetails {
        let token = session.identifier as? GMSAutocompleteSessionToken
        let properties = [
            GMSPlaceProperty.name.rawValue,
            GMSPlaceProperty.coordinate.rawValue,
            GMSPlaceProperty.formattedAddress.rawValue,
            GMSPlaceProperty.placeID.rawValue
        ]
        let request = GMSFetchPlaceRequest(placeID: placeId, placeProperties: properties, sessionToken: token)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PlaceDetails, Error>) in
            client.fetchPlace(with: request) { place, error in
                if let error = error {
                    continuation.resume(throwing: PlacesSearchError.underlying(error))
                    return
                }
                guard let place = place else {
                    continuation.resume(throwing: PlacesSearchError.serviceUnavailable("地点情報を取得できませんでした。"))
                    return
                }
                let details = PlaceDetails(
                    id: place.placeID ?? placeId,
                    name: place.name ?? "",
                    latitude: place.coordinate.latitude,
                    longitude: place.coordinate.longitude,
                    formattedAddress: place.formattedAddress
                )
                continuation.resume(returning: details)
            }
        }
    }
}
