import Foundation

/// APIキー未設定時などに利用するダミー逆ジオコーディング実装。
struct UnavailableGeocodingService: GeocodingService {
    private let reason: String

    init(reason: String) {
        self.reason = reason
    }

    func reverseGeocode(latitude: Double, longitude: Double) async -> Result<GeocodeResult, Error> {
        .failure(PlacesSearchError.serviceUnavailable(reason))
    }
}
