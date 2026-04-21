import Foundation
import UIKit
import UserNotifications

struct NearbySuggestionNotificationContext: Equatable {
    static let categoryIdentifier = "nearby-store-suggestion"
    static let purchasedActionIdentifier = "nearby-store-purchased"
    static let deleteActionIdentifier = "nearby-store-delete"
    static let mapActionIdentifier = "nearby-store-map"

    let itemId: UUID
    let placeName: String
    let placeLatitude: Double
    let placeLongitude: Double

    var userInfo: [AnyHashable: Any] {
        [
            AppNotificationUserInfoKey.itemId: itemId.uuidString,
            AppNotificationUserInfoKey.placeName: placeName,
            AppNotificationUserInfoKey.placeLatitude: placeLatitude,
            AppNotificationUserInfoKey.placeLongitude: placeLongitude
        ]
    }

    init(itemId: UUID, placeName: String, placeLatitude: Double, placeLongitude: Double) {
        self.itemId = itemId
        self.placeName = placeName
        self.placeLatitude = placeLatitude
        self.placeLongitude = placeLongitude
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard
            let itemIdString = userInfo[AppNotificationUserInfoKey.itemId] as? String,
            let itemId = UUID(uuidString: itemIdString),
            let placeName = userInfo[AppNotificationUserInfoKey.placeName] as? String
        else {
            return nil
        }

        let latitude = userInfo[AppNotificationUserInfoKey.placeLatitude] as? Double
        let longitude = userInfo[AppNotificationUserInfoKey.placeLongitude] as? Double

        self.init(
            itemId: itemId,
            placeName: placeName,
            placeLatitude: latitude ?? .zero,
            placeLongitude: longitude ?? .zero
        )
    }
}

@MainActor
protocol NotificationItemRouting {
    func openItemDetail(itemId: UUID)
}

@MainActor
struct NotificationCenterItemRouter: NotificationItemRouting {
    func openItemDetail(itemId: UUID) {
        NotificationCenter.default.post(
            name: .openShoppingItemFromNotification,
            object: nil,
            userInfo: [AppNotificationUserInfoKey.itemId: itemId.uuidString]
        )
    }
}

@MainActor
protocol NotificationMapRouting {
    func openMap(for context: NearbySuggestionNotificationContext) async -> Bool
}

@MainActor
protocol ApplicationOpening {
    func open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any]) async -> Bool
}

extension UIApplication: ApplicationOpening {
    func open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any] = [:]) async -> Bool {
        await withCheckedContinuation { continuation in
            open(url, options: options) { success in
                continuation.resume(returning: success)
            }
        }
    }
}

@MainActor
final class DefaultNotificationMapRouter: NotificationMapRouting {
    private let application: ApplicationOpening

    init(application: ApplicationOpening) {
        self.application = application
    }

    convenience init() {
        self.init(application: UIApplication.shared)
    }

    func openMap(for context: NearbySuggestionNotificationContext) async -> Bool {
        if let googleMapsURL = googleMapsURL(for: context) {
            let didOpenGoogleMaps = await application.open(googleMapsURL, options: [:])
            if didOpenGoogleMaps {
                return true
            }
        }

        guard let appleMapsURL = appleMapsURL(for: context) else {
            return false
        }
        return await application.open(appleMapsURL, options: [:])
    }
}

private extension DefaultNotificationMapRouter {
    func googleMapsURL(for context: NearbySuggestionNotificationContext) -> URL? {
        var components = URLComponents()
        components.scheme = "comgooglemaps"
        components.host = ""
        components.queryItems = [
            URLQueryItem(name: "q", value: context.placeName),
            URLQueryItem(name: "center", value: "\(context.placeLatitude),\(context.placeLongitude)")
        ]
        return components.url
    }

    func appleMapsURL(for context: NearbySuggestionNotificationContext) -> URL? {
        var components = URLComponents(string: "http://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: context.placeName),
            URLQueryItem(name: "ll", value: "\(context.placeLatitude),\(context.placeLongitude)")
        ]
        return components?.url
    }
}

@MainActor
protocol NotificationActionHandling {
    func handle(response: UNNotificationResponse) async
}

@MainActor
final class NotificationActionHandler: NotificationActionHandling {
    private let updatePurchasedUseCase: UpdatePurchasedStateUseCase
    private let deleteShoppingItemUseCase: DeleteShoppingItemUseCase
    private let itemRouter: NotificationItemRouting
    private let mapRouter: NotificationMapRouting

    init(
        updatePurchasedUseCase: UpdatePurchasedStateUseCase,
        deleteShoppingItemUseCase: DeleteShoppingItemUseCase,
        itemRouter: NotificationItemRouting,
        mapRouter: NotificationMapRouting
    ) {
        self.updatePurchasedUseCase = updatePurchasedUseCase
        self.deleteShoppingItemUseCase = deleteShoppingItemUseCase
        self.itemRouter = itemRouter
        self.mapRouter = mapRouter
    }

    convenience init(
        updatePurchasedUseCase: UpdatePurchasedStateUseCase,
        deleteShoppingItemUseCase: DeleteShoppingItemUseCase
    ) {
        self.init(
            updatePurchasedUseCase: updatePurchasedUseCase,
            deleteShoppingItemUseCase: deleteShoppingItemUseCase,
            itemRouter: NotificationCenterItemRouter(),
            mapRouter: DefaultNotificationMapRouter()
        )
    }

    func handle(response: UNNotificationResponse) async {
        guard let context = NearbySuggestionNotificationContext(
            userInfo: response.notification.request.content.userInfo
        ) else {
            return
        }

        await handle(actionIdentifier: response.actionIdentifier, context: context)
    }

    func handle(actionIdentifier: String, context: NearbySuggestionNotificationContext) async {
        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            itemRouter.openItemDetail(itemId: context.itemId)
        case NearbySuggestionNotificationContext.purchasedActionIdentifier:
            try? await updatePurchasedUseCase.execute(itemId: context.itemId, isPurchased: true)
            NotificationCenter.default.post(name: .geofenceNeedsSync, object: nil)
        case NearbySuggestionNotificationContext.deleteActionIdentifier:
            try? await deleteShoppingItemUseCase.execute(itemId: context.itemId)
            NotificationCenter.default.post(name: .geofenceNeedsSync, object: nil)
        case NearbySuggestionNotificationContext.mapActionIdentifier:
            let didOpenMap = await mapRouter.openMap(for: context)
            if didOpenMap == false {
                itemRouter.openItemDetail(itemId: context.itemId)
            }
        default:
            break
        }
    }
}
