import Foundation

/// Place検索APIの共通インタフェース。
protocol PlacesSearchService {
    /// オートコンプリート検索を実行する。
    func autocomplete(query: String) async throws -> PlacesAutocompleteResponse

    /// 指定したプレイスIDの詳細を取得する。
    func fetchPlaceDetails(placeId: String, session: PlacesAutocompleteSession) async throws -> PlaceDetails
}

/// オートコンプリート検索の結果。
struct PlacesAutocompleteResponse {
    let session: PlacesAutocompleteSession
    let predictions: [PlaceAutocompletePrediction]
}

/// オートコンプリート用のセッション。
struct PlacesAutocompleteSession {
    let identifier: AnyObject
}

/// オートコンプリート候補。
struct PlaceAutocompletePrediction: Identifiable, Equatable {
    let id: String
    let primaryText: String
    let secondaryText: String?
    let distanceMeters: Double?
}

/// プレイス詳細。
struct PlaceDetails: Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let formattedAddress: String?
}

/// Place検索関連のエラー。
enum PlacesSearchError: LocalizedError {
    case serviceUnavailable(String)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case let .serviceUnavailable(reason):
            return reason
        case let .underlying(error):
            return error.localizedDescription
        }
    }
}
