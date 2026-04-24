import CoreLocation
import Foundation

struct ShouldSuggestNearbyStoreUseCase {
    func execute(
        state: NearbySuggestionState?,
        currentCoordinate: CLLocationCoordinate2D,
        now: Date = Date()
    ) -> Bool {
        guard let state, let lastNotifiedAt = state.lastNotifiedAt else {
            return true
        }

        if now.timeIntervalSince(lastNotifiedAt) >= 24 * 60 * 60 {
            return true
        }

        guard now.timeIntervalSince(lastNotifiedAt) >= 60 * 60,
            let latitudeE6 = state.lastNotifiedLatitudeE6,
            let longitudeE6 = state.lastNotifiedLongitudeE6 else {
            return false
        }

        let previous = CLLocation(
            latitude: CLLocationDegrees(latitudeE6) / 1_000_000,
            longitude: CLLocationDegrees(longitudeE6) / 1_000_000
        )
        let current = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
        return current.distance(from: previous) >= 300
    }
}
