import Foundation
import CoreLocation
import GoogleMaps
import GooglePlaces

/// Google Places SDK のジオコーダーを利用した実装。
final class GoogleGeocodingService: GeocodingService {
    private let geocoder: GMSGeocoder

    init(geocoder: GMSGeocoder = GMSGeocoder()) {
        self.geocoder = geocoder
    }

    func reverseGeocode(latitude: Double, longitude: Double) async -> Result<GeocodeResult, Error> {
        await withCheckedContinuation { continuation in
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            geocoder.reverseGeocodeCoordinate(coordinate) { response, error in
                if let error = error {
                    continuation.resume(returning: .failure(error))
                    return
                }
                let address = response?.firstResult()
                let primary = address?.thoroughfare ?? address?.locality
                let secondary = address?.lines?.joined(separator: ", ")
                let result = GeocodeResult(
                    primaryText: primary,
                    secondaryText: secondary
                )
                continuation.resume(returning: .success(result))
            }
        }
    }
}
