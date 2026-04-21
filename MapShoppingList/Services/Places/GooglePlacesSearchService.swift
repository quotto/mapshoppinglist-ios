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

    func search(query: String, options: PlacesSearchOptions) async throws -> PlacesSearchResponse {
        _ = options.session // Text Searchではセッションを利用しない
        NearbyDebugLogger.log(.placesAPI, "places text search started", metadata: [
            "query": query,
            "includedType": options.includedType ?? "nil",
            "strictTypeFiltering": String(options.strictTypeFiltering),
            "radiusMeters": String(Int(options.radiusMeters)),
            "originLatitude": options.origin.map { String($0.latitude) } ?? "nil",
            "originLongitude": options.origin.map { String($0.longitude) } ?? "nil"
        ])
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
            request.includedType = options.includedType
            request.isStrictTypeFiltering = options.strictTypeFiltering
            if let origin = options.origin {
                request.locationBias = GMSPlaceCircularLocationOption(
                    CLLocationCoordinate2DMake(origin.latitude, origin.longitude),
                    options.radiusMeters
                )
            }
            client.searchByText(with: request) { results, error in
                if let error = error as NSError? {
                    NearbyDebugLogger.log(.placesAPI, "places text search failed", metadata: [
                        "query": query,
                        "error": error.localizedDescription
                    ])
                    continuation.resume(throwing: self.mapPlacesError(error))
                    return
                }
                let mapped = results?.map(Self.makePlaceDetails)
                NearbyDebugLogger.log(.placesAPI, "places text search succeeded", metadata: [
                    "query": query,
                    "resultCount": String(mapped?.count ?? 0)
                ])
                continuation.resume(returning: mapped ?? [])
            }
        }
        return PlacesSearchResponse(
            session: PlacesSearchSession(identifier: NSObject()),
            places: places
        )
    }

    func searchNearby(includedType: String, options: PlacesSearchOptions) async throws -> PlacesSearchResponse {
        NearbyDebugLogger.log(.placesAPI, "places nearby search started", metadata: [
            "includedType": includedType,
            "radiusMeters": String(Int(options.radiusMeters)),
            "originLatitude": options.origin.map { String($0.latitude) } ?? "nil",
            "originLongitude": options.origin.map { String($0.longitude) } ?? "nil"
        ])
        guard let origin = options.origin else {
            throw PlacesSearchError.locationPermission("現在地が取得できませんでした。端末の設定を確認してください。")
        }
        let places: [PlaceDetails] = try await withCheckedThrowingContinuation { continuation in
            let properties = [
                GMSPlaceProperty.name,
                GMSPlaceProperty.placeID,
                GMSPlaceProperty.coordinate,
                GMSPlaceProperty.formattedAddress
            ].map { $0.rawValue }
            let locationRestriction = GMSPlaceCircularLocationOption(
                CLLocationCoordinate2DMake(origin.latitude, origin.longitude),
                options.radiusMeters
            )
            let request = GMSPlaceSearchNearbyRequest(
                locationRestriction: locationRestriction,
                placeProperties: properties
            )
            request.rankPreference = .distance
            request.maxResultCount = Self.maxSearchResults
            request.includedTypes = [includedType]
            client.searchNearby(with: request) { results, error in
                if let error = error as NSError? {
                    NearbyDebugLogger.log(.placesAPI, "places nearby search failed", metadata: [
                        "includedType": includedType,
                        "error": error.localizedDescription
                    ])
                    continuation.resume(throwing: self.mapPlacesError(error))
                    return
                }
                let mapped = results?.map(Self.makePlaceDetails)
                NearbyDebugLogger.log(.placesAPI, "places nearby search succeeded", metadata: [
                    "includedType": includedType,
                    "resultCount": String(mapped?.count ?? 0)
                ])
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
        NearbyDebugLogger.log(.placesAPI, "place details fetch started", metadata: [
            "placeId": placeId
        ])
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
                    NearbyDebugLogger.log(.placesAPI, "place details fetch failed", metadata: [
                        "placeId": placeId,
                        "error": error.localizedDescription
                    ])
                    continuation.resume(throwing: self.mapPlacesError(error))
                    return
                }
                guard let place = place else {
                    NearbyDebugLogger.log(.placesAPI, "place details missing", metadata: [
                        "placeId": placeId
                    ])
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
                NearbyDebugLogger.log(.placesAPI, "place details fetch succeeded", metadata: [
                    "placeId": details.id,
                    "name": details.name
                ])
                continuation.resume(returning: details)
            }
        }
    }
}

private extension GooglePlacesSearchService {
    nonisolated static func makePlaceDetails(_ place: GMSPlace) -> PlaceDetails {
        PlaceDetails(
            id: place.placeID ?? "",
            name: place.name ?? "",
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            formattedAddress: place.formattedAddress
        )
    }

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
