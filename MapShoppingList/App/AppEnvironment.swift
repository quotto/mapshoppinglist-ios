import Foundation
import SwiftUI

/// アプリ全体で利用する依存関係を束ねるコンテナ。
final class AppEnvironment {
    private static var sharedInstance: AppEnvironment?

    static var shared: AppEnvironment {
        if let environment = sharedInstance {
            return environment
        }
        let environment = AppEnvironment(isSharedInstance: true)
        sharedInstance = environment
        return environment
    }

    static func configureShared(
        stack: CoreDataStack = .shared,
        placesSearchService: PlacesSearchService,
        geocodingService: GeocodingService
    ) {
        sharedInstance = AppEnvironment(
            stack: stack,
            placesSearchService: placesSearchService,
            geocodingService: geocodingService,
            isSharedInstance: true
        )
    }

    // MARK: - Core Data / Repository
    let coreDataStack: CoreDataStack
    let shoppingListRepository: ShoppingListRepository
    let placesRepository: PlacesRepository
    let linkRepository: ItemPlaceLinkRepository
    let notificationRepository: NotificationStateRepository
    let geofenceRegistryRepository: GeofenceRegistryRepository

    // MARK: - Services
    let placesSearchService: PlacesSearchService
    let geocodingService: GeocodingService
    let locationPermissionManager: DefaultLocationPermissionManager
    let notificationScheduler: NotificationScheduler
    let geofenceCoordinator: GeofenceCoordinator
    let networkMonitor: NetworkMonitor

    // MARK: - UseCases
    let addItemUseCase: AddShoppingItemUseCase
    let updateItemUseCase: UpdateItemUseCase
    let deleteItemUseCase: DeleteShoppingItemUseCase
    let updatePurchasedUseCase: UpdatePurchasedStateUseCase
    let markPlacePurchasedUseCase: MarkPlaceItemsPurchasedUseCase
    let createPlaceUseCase: CreatePlaceUseCase
    let updatePlaceNameUseCase: UpdatePlaceNameUseCase
    let deletePlaceUseCase: DeletePlaceUseCase
    let linkItemToPlaceUseCase: LinkItemToPlaceUseCase
    let unlinkItemFromPlaceUseCase: UnlinkItemFromPlaceUseCase
    let getRecentPlacesUseCase: GetRecentPlacesUseCase
    let loadAllPlacesUseCase: LoadAllPlacesUseCase
    let loadShoppingItemsUseCase: LoadShoppingItemsUseCase
    let getShoppingItemUseCase: GetShoppingItemUseCase
    let buildGeofenceSyncPlanUseCase: BuildGeofenceSyncPlanUseCase
    let shouldSendNotificationUseCase: ShouldSendNotificationUseCase

    init(
        stack: CoreDataStack = .shared,
        placesSearchService: PlacesSearchService = UnavailablePlacesSearchService(
            reason: "Google Maps/Places APIキーが設定されていません。"
        ),
        geocodingService: GeocodingService = UnavailableGeocodingService(
            reason: "Google Maps/Places APIキーが設定されていません。"
        ),
        isSharedInstance: Bool = false
    ) {
        coreDataStack = stack

        let shoppingRepo = CoreDataShoppingListRepository(stack: stack)
        let placeRepo = CoreDataPlacesRepository(stack: stack)
        let linkRepo = CoreDataItemPlaceLinkRepository(stack: stack)
        let notifyRepo = CoreDataNotificationStateRepository(stack: stack)
        // CoreLocation ベースのジオフェンス登録を利用。
        let geofenceRepo = CoreLocationGeofenceRegistryRepository()

        shoppingListRepository = shoppingRepo
        placesRepository = placeRepo
        linkRepository = linkRepo
        notificationRepository = notifyRepo
        geofenceRegistryRepository = geofenceRepo

        self.placesSearchService = placesSearchService
        self.geocodingService = geocodingService

        addItemUseCase = AddShoppingItemUseCase(itemRepository: shoppingRepo, linkRepository: linkRepo)
        updateItemUseCase = UpdateItemUseCase(itemRepository: shoppingRepo, linkRepository: linkRepo)
        deleteItemUseCase = DeleteShoppingItemUseCase(itemRepository: shoppingRepo, linkRepository: linkRepo)
        updatePurchasedUseCase = UpdatePurchasedStateUseCase(itemRepository: shoppingRepo)
        markPlacePurchasedUseCase = MarkPlaceItemsPurchasedUseCase(itemRepository: shoppingRepo, placesRepository: placeRepo)
        createPlaceUseCase = CreatePlaceUseCase(placesRepository: placeRepo)
        updatePlaceNameUseCase = UpdatePlaceNameUseCase(placesRepository: placeRepo)
        deletePlaceUseCase = DeletePlaceUseCase(placesRepository: placeRepo)
        linkItemToPlaceUseCase = LinkItemToPlaceUseCase(itemRepository: shoppingRepo, placesRepository: placeRepo, linkRepository: linkRepo)
        unlinkItemFromPlaceUseCase = UnlinkItemFromPlaceUseCase(itemRepository: shoppingRepo, linkRepository: linkRepo)
        getRecentPlacesUseCase = GetRecentPlacesUseCase(placesRepository: placeRepo)
        loadAllPlacesUseCase = LoadAllPlacesUseCase(placesRepository: placeRepo)
        loadShoppingItemsUseCase = LoadShoppingItemsUseCase(repository: shoppingRepo)
        getShoppingItemUseCase = GetShoppingItemUseCase(repository: shoppingRepo)
        buildGeofenceSyncPlanUseCase = BuildGeofenceSyncPlanUseCase(registryRepository: geofenceRepo)
        shouldSendNotificationUseCase = ShouldSendNotificationUseCase()

        networkMonitor = NetworkMonitor()
        networkMonitor.start()

        locationPermissionManager = DefaultLocationPermissionManager()
        notificationScheduler = NotificationScheduler()
        geofenceCoordinator = GeofenceCoordinator(
            placesRepository: placeRepo,
            loadAllPlacesUseCase: loadAllPlacesUseCase,
            loadShoppingItemsUseCase: loadShoppingItemsUseCase,
            notificationStateRepository: notifyRepo,
            shouldSendNotificationUseCase: shouldSendNotificationUseCase,
            buildGeofenceSyncPlanUseCase: buildGeofenceSyncPlanUseCase,
            geofenceRepository: geofenceRepo,
            notificationScheduler: notificationScheduler
        )
        geofenceRepo.onRegionEntered = { [weak geofenceCoordinator] placeId in
            guard let coordinator = geofenceCoordinator else { return }
            Task { await coordinator.handleRegionEntry(placeId: placeId) }
        }
    }
}

private struct AppEnvironmentKey: EnvironmentKey {
    static var defaultValue: AppEnvironment { AppEnvironment.shared }
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
