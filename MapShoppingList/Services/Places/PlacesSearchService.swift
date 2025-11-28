import Foundation
import CoreLocation

/// Place検索APIの共通インタフェース。
protocol PlacesSearchService {
    /// テキスト検索を実行する。
    func search(
        query: String,
        session: PlacesSearchSession?,
        origin: CLLocationCoordinate2D?
    ) async throws -> PlacesSearchResponse

    /// 指定したプレイスIDの詳細を取得する。
    func fetchPlaceDetails(placeId: String, session: PlacesSearchSession) async throws -> PlaceDetails

    /// セッション不要のプレイス詳細取得。
    func fetchPlaceDetails(placeId: String) async throws -> PlaceDetails
}

/// テキスト検索の結果。
struct PlacesSearchResponse {
    let session: PlacesSearchSession
    let places: [PlaceDetails]
}

/// テキスト検索用のセッション。
struct PlacesSearchSession {
    let identifier: AnyObject
}

/// プレイス詳細。
struct PlaceDetails: Identifiable, Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let formattedAddress: String?
}

/// Place検索関連のエラー。
enum PlacesSearchError: LocalizedError {
    case serviceUnavailable(String)
    case quotaExceeded(String)
    case configuration(String)
    case locationPermission(String)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case let .serviceUnavailable(reason):
            return reason
        case let .quotaExceeded(reason):
            return reason
        case let .configuration(reason):
            return reason
        case let .locationPermission(reason):
            return reason
        case let .underlying(error):
            return error.localizedDescription
        }
    }

    /// ユーザーに再試行導線を提示すべきかどうかを返す。
    var isRetryable: Bool {
        switch self {
        case .serviceUnavailable:
            return true
        case .quotaExceeded, .configuration, .locationPermission:
            return false
        case let .underlying(error):
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                    return true
                default:
                    return false
                }
            }
            return false
        }
    }
}

extension PlacesSearchService {
    func autocomplete(query: String) async throws -> PlacesSearchResponse {
        try await search(query: query, session: nil, origin: nil)
    }
}
