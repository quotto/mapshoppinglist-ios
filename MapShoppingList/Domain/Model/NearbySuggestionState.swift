import Foundation

struct NearbySuggestionState: Equatable {
    let itemId: UUID
    var lastNotifiedAt: Date?
    var lastNotifiedLatitudeE6: Int?
    var lastNotifiedLongitudeE6: Int?
    var lastSuggestedPlaceID: String?
    var lastSuggestedPlaceName: String?

    init(
        itemId: UUID,
        lastNotifiedAt: Date?,
        lastNotifiedLatitudeE6: Int? = nil,
        lastNotifiedLongitudeE6: Int? = nil,
        lastSuggestedPlaceID: String? = nil,
        lastSuggestedPlaceName: String? = nil
    ) {
        self.itemId = itemId
        self.lastNotifiedAt = lastNotifiedAt
        self.lastNotifiedLatitudeE6 = lastNotifiedLatitudeE6
        self.lastNotifiedLongitudeE6 = lastNotifiedLongitudeE6
        self.lastSuggestedPlaceID = lastSuggestedPlaceID
        self.lastSuggestedPlaceName = lastSuggestedPlaceName
    }
}
