import Foundation
import CoreLocation
import GooglePlaces

/// Google Places SDK を利用した検索サービス実装。
final class GooglePlacesSearchService: PlacesSearchService {
    private static let maxSearchResults = 10
    private let client: GMSPlacesClient

    init(client: GMSPlacesClient) {
        self.client = client
    }

    func search(
        query: String,
        session: PlacesSearchSession?,
        origin: CLLocationCoordinate2D?
    ) async throws -> PlacesSearchResponse {
        _ = session // Text Searchではセッションを利用しない
        let places: [PlaceDetails] = try await withCheckedThrowingContinuation { continuation in
            let myProperties = [
                GMSPlaceProperty.name,
                GMSPlaceProperty.placeID,
                GMSPlaceProperty.coordinate,
                GMSPlaceProperty.formattedAddress
            ].map { $0.rawValue }
            let request = GMSPlaceSearchByTextRequest(textQuery: query, placeProperties: myProperties)
            request.isOpenNow = false
            request.rankPreference = .distance
            request.maxResultCount = Int32(Self.maxSearchResults)
            if let origin {
                request.locationBias = GMSPlaceCircularLocationOption(
                    CLLocationCoordinate2DMake(origin.latitude, origin.longitude),
                    5000.0
                )
            }
            client.searchByText(with: request) { results, error in
                if let error = error as NSError? {
                    continuation.resume(throwing: self.mapPlacesError(error))
                    return
                }
                let mapped = results?.map { result in
                    PlaceDetails(
                        id: result.placeID ?? "",
                        name: result.name ?? "",
                        latitude: result.coordinate.latitude,
                        longitude: result.coordinate.longitude,
                        formattedAddress: result.formattedAddress
                    )
                }
                continuation.resume(returning: mapped ?? [])
            }
        }
        return PlacesSearchResponse(
            session: PlacesSearchSession(identifier: NSObject()),
            places: places
        )
    }

    func fetchPlaceDetails(placeId: String, session: PlacesSearchSession) async throws -> PlaceDetails {
        _ = session // Text Searchではセッションを利用しない
        return try await fetchPlaceDetails(placeId: placeId)
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
