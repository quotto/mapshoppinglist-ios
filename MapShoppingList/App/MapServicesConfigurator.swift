import Foundation
import GoogleMaps
import GooglePlaces

/// Google Maps / Places SDK の初期化を担当するユーティリティ。
struct MapServicesConfigurator {
    /// 設定結果。サービス実装と、警告表示用のメッセージを返す。
    struct Result {
        let placesService: PlacesSearchService
        let geocodingService: GeocodingService
        let warningMessage: String?
    }

    /// 環境変数 `GOOGLE_MAPS_API_KEY` からAPIキーを読み込み、SDKを初期化する。
    /// - Returns: Places検索サービス実装と、警告表示が必要な場合のメッセージ。
    static func configure() -> Result {
        let environment = ProcessInfo.processInfo.environment
        guard let apiKey = environment["GOOGLE_MAPS_API_KEY"], apiKey.isEmpty == false else {
            let message = "Google Maps/Places APIキーが設定されていません。ビルド環境の環境変数 GOOGLE_MAPS_API_KEY を設定してください。"
            return Result(
                placesService: UnavailablePlacesSearchService(reason: message),
                geocodingService: UnavailableGeocodingService(reason: message),
                warningMessage: message
            )
        }

        GMSServices.provideAPIKey(apiKey)
        GMSPlacesClient.provideAPIKey(apiKey)

        let client = GMSPlacesClient.shared()
        let service = GooglePlacesSearchService(client: client)
        let geocodingService = GoogleGeocodingService()
        return Result(placesService: service, geocodingService: geocodingService, warningMessage: nil)
    }
}
