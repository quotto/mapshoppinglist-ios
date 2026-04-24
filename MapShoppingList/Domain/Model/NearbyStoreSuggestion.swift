import CoreLocation
import Foundation

struct NearbyStoreSuggestion: Equatable {
    enum SearchStrategy: Equatable {
        case category(placeType: String)
        case text
    }

    let item: ShoppingItem
    let place: PlaceDetails
    let distanceMeters: CLLocationDistance
    let strategy: SearchStrategy
}
