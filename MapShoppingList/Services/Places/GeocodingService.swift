import Foundation

/// 逆ジオコーディング結果。
struct GeocodeResult: Equatable {
    let primaryText: String?
    let secondaryText: String?
}

/// 逆ジオコーディングを提供するサービス。
protocol GeocodingService {
    func reverseGeocode(latitude: Double, longitude: Double) async -> Result<GeocodeResult, Error>
}
