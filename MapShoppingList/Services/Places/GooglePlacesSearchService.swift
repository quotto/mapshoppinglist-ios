import Foundation
import GooglePlaces

/// Google Places SDK を利用した検索サービス実装。
final class GooglePlacesSearchService: PlacesSearchService {
    private let client: GMSPlacesClient

    init(client: GMSPlacesClient) {
        self.client = client
    }

    func autocomplete(query: String, session: PlacesAutocompleteSession?) async throws -> PlacesAutocompleteResponse {
        let token: GMSAutocompleteSessionToken
        if let existingToken = session?.identifier as? GMSAutocompleteSessionToken {
            token = existingToken
        } else {
            token = GMSAutocompleteSessionToken()
        }

        let predictions: [PlaceAutocompletePrediction] = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[PlaceAutocompletePrediction], Error>) in
            let filter = GMSAutocompleteFilter()
            filter.type = .establishment

            client.findAutocompletePredictions(fromQuery: query, filter: filter, sessionToken: token) { results, error in
                if let error = error as NSError? {
                    continuation.resume(throwing: self.mapPlacesError(error))
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
                if let error = error as NSError? {
                    continuation.resume(throwing: self.mapPlacesError(error))
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

    func fetchPlaceDetails(placeId: String) async throws -> PlaceDetails {
        let properties = [
            GMSPlaceProperty.name.rawValue,
            GMSPlaceProperty.coordinate.rawValue,
            GMSPlaceProperty.formattedAddress.rawValue,
            GMSPlaceProperty.placeID.rawValue
        ]
        let request = GMSFetchPlaceRequest(placeID: placeId, placeProperties: properties, sessionToken: nil)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PlaceDetails, Error>) in
            client.fetchPlace(with: request) { place, error in
                if let error = error as NSError? {
                    continuation.resume(throwing: self.mapPlacesError(error))
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

private extension GooglePlacesSearchService {
    func mapPlacesError(_ error: NSError) -> PlacesSearchError {
        if error.domain == kGMSPlacesErrorDomain,
           let code = GMSPlacesErrorCode(rawValue: error.code) {
            switch code {
            case .networkError, .serverError, .internalError:
                return .serviceUnavailable("通信エラーが発生しました。時間をおいて再度お試しください。")
            case .rateLimitExceeded, .usageLimitExceeded, .deviceRateLimitExceeded:
                return .quotaExceeded("Google Places APIの利用上限に達しました。しばらく経ってから再度お試しください。")
            case .keyInvalid, .keyExpired:
                return .configuration("Google Places APIキーの設定に問題があります。アプリの設定を確認してください。")
            case .accessNotConfigured, .incorrectBundleIdentifier:
                return .configuration("Google Places APIキーの設定に問題があります。アプリの設定を確認してください。")
            case .locationError:
                return .locationPermission("位置情報が取得できませんでした。端末の設定を確認してください。")
            case .invalidRequest:
                return .serviceUnavailable("検索条件を変更して再度お試しください。")
            default:
                return .serviceUnavailable("地点検索に失敗しました。(code: \(code.rawValue))")
            }
        }

        if error.domain == NSURLErrorDomain {
            return .serviceUnavailable("通信エラーが発生しました。ネットワーク接続を確認してください。")
        }

        return .underlying(error)
    }
}
