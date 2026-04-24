import Foundation

extension Notification.Name {
    static let geofenceNeedsSync = Notification.Name("GeofenceNeedsSyncNotification")
    static let nearbySuggestionTriggerDetected = Notification.Name("NearbySuggestionTriggerDetected")
    static let openShoppingItemFromNotification = Notification.Name("OpenShoppingItemFromNotification")
}

enum AppNotificationUserInfoKey {
    static let latitude = "latitude"
    static let longitude = "longitude"
    static let detectedAt = "detectedAt"
    static let itemId = "itemId"
    static let placeName = "placeName"
    static let placeLatitude = "placeLatitude"
    static let placeLongitude = "placeLongitude"
}
