import Foundation
@testable import MapShoppingList

final class StubGeocodingService: GeocodingService {
    var result: Result<GeocodeResult, Error> = .success(GeocodeResult(primaryText: nil, secondaryText: nil))

    func reverseGeocode(latitude: Double, longitude: Double) async -> Result<GeocodeResult, Error> {
        result
    }
}

