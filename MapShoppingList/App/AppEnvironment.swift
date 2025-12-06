import Foundation
import SwiftUI
import CoreLocation

/// アプリ全体で利用する依存関係を束ねるコンテナ。
@MainActor
final class AppEnvironment {
    private static var sharedInstance: AppEnvironment?

    @MainActor static var shared: AppEnvironment {
        if let environment = sharedInstance {
            return environment
        }
        let environment = AppEnvironment(isSharedInstance: true)
        sharedInstance = environment
        return environment
    }

    @MainActor static func configureShared(
        stack: CoreDataStack = .shared,
        placesSearchService: PlacesSearchService,
        geocodingService: GeocodingService,
        geofenceRegistryRepository: GeofenceRegistryRepository? = nil,
        notificationScheduler: NotificationScheduling? = nil,
        locationPermissionManager: LocationPermissionManager? = nil,
        currentLocationProvider: CurrentLocationProviding? = nil,
        networkMonitor: NetworkMonitor? = nil
    ) {
        sharedInstance = AppEnvironment(
            stack: stack,
            placesSearchService: placesSearchService,
            geocodingService: geocodingService,
            geofenceRegistryRepository: geofenceRegistryRepository,
            notificationScheduler: notificationScheduler,
            locationPermissionManager: locationPermissionManager,
            currentLocationProvider: currentLocationProvider,
            networkMonitor: networkMonitor,
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
    let locationPermissionManager: LocationPermissionManager
    let currentLocationProvider: CurrentLocationProviding
    let notificationScheduler: NotificationScheduling
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

    // 依存性注入のため初期化処理が長いことを許容
    // swiftlint:disable:next function_body_length
    init(
        stack: CoreDataStack = .shared,
        placesSearchService: PlacesSearchService = UnavailablePlacesSearchService(
            reason: "Google Maps/Places APIキーが設定されていません。"
        ),
        geocodingService: GeocodingService = UnavailableGeocodingService(
            reason: "Google Maps/Places APIキーが設定されていません。"
        ),
        geofenceRegistryRepository: GeofenceRegistryRepository? = nil,
        notificationScheduler: NotificationScheduling? = nil,
        locationPermissionManager: LocationPermissionManager? = nil,
        currentLocationProvider: CurrentLocationProviding? = nil,
        networkMonitor: NetworkMonitor? = nil,
        isSharedInstance: Bool = false
    ) {
        coreDataStack = stack

        let shoppingRepo = CoreDataShoppingListRepository(stack: stack)
        let placeRepo = CoreDataPlacesRepository(stack: stack)
        let linkRepo = CoreDataItemPlaceLinkRepository(stack: stack)
        let notifyRepo = CoreDataNotificationStateRepository(stack: stack)
        // CoreLocation ベースのジオフェンス登録を利用。
        var geofenceRepo: GeofenceRegistryRepository = geofenceRegistryRepository ?? Self.defaultGeofenceRepository()

        shoppingListRepository = shoppingRepo
        placesRepository = placeRepo
        linkRepository = linkRepo
        notificationRepository = notifyRepo
        self.geofenceRegistryRepository = geofenceRepo

        self.placesSearchService = placesSearchService
        self.geocodingService = geocodingService

        addItemUseCase = AddShoppingItemUseCase(itemRepository: shoppingRepo, linkRepository: linkRepo)
        updateItemUseCase = UpdateItemUseCase(itemRepository: shoppingRepo, linkRepository: linkRepo)
        deleteItemUseCase = DeleteShoppingItemUseCase(itemRepository: shoppingRepo, linkRepository: linkRepo)
        updatePurchasedUseCase = UpdatePurchasedStateUseCase(itemRepository: shoppingRepo)
        markPlacePurchasedUseCase = MarkPlaceItemsPurchasedUseCase(
            itemRepository: shoppingRepo,
            placesRepository: placeRepo
        )
        createPlaceUseCase = CreatePlaceUseCase(placesRepository: placeRepo)
        updatePlaceNameUseCase = UpdatePlaceNameUseCase(placesRepository: placeRepo)
        deletePlaceUseCase = DeletePlaceUseCase(placesRepository: placeRepo)
        linkItemToPlaceUseCase = LinkItemToPlaceUseCase(
            itemRepository: shoppingRepo,
            placesRepository: placeRepo,
            linkRepository: linkRepo
        )
        unlinkItemFromPlaceUseCase = UnlinkItemFromPlaceUseCase(itemRepository: shoppingRepo, linkRepository: linkRepo)
        getRecentPlacesUseCase = GetRecentPlacesUseCase(placesRepository: placeRepo)
        loadAllPlacesUseCase = LoadAllPlacesUseCase(placesRepository: placeRepo)
        loadShoppingItemsUseCase = LoadShoppingItemsUseCase(repository: shoppingRepo)
        getShoppingItemUseCase = GetShoppingItemUseCase(repository: shoppingRepo)
        buildGeofenceSyncPlanUseCase = BuildGeofenceSyncPlanUseCase(registryRepository: geofenceRepo)
        shouldSendNotificationUseCase = ShouldSendNotificationUseCase()

        self.networkMonitor = networkMonitor ?? NetworkMonitor()
        self.networkMonitor.start()

        self.locationPermissionManager = locationPermissionManager ?? Self.defaultLocationPermissionManager()
        self.currentLocationProvider = currentLocationProvider ?? Self.defaultCurrentLocationProvider()
        let resolvedScheduler: NotificationScheduling = notificationScheduler ?? Self.defaultNotificationScheduler()
        self.notificationScheduler = resolvedScheduler
        geofenceCoordinator = GeofenceCoordinator(
            placesRepository: placeRepo,
            loadAllPlacesUseCase: loadAllPlacesUseCase,
            loadShoppingItemsUseCase: loadShoppingItemsUseCase,
            notificationStateRepository: notifyRepo,
            shouldSendNotificationUseCase: shouldSendNotificationUseCase,
            buildGeofenceSyncPlanUseCase: buildGeofenceSyncPlanUseCase,
            geofenceRepository: geofenceRepo,
            notificationScheduler: resolvedScheduler
        )
        geofenceRepo.onRegionEntered = { [weak geofenceCoordinator] placeId in
            guard let coordinator = geofenceCoordinator else { return }
            Task { await coordinator.handleRegionEntry(placeId: placeId) }
        }
    }
}

private extension AppEnvironment {
    static func defaultGeofenceRepository() -> GeofenceRegistryRepository {
        if LaunchArguments.isRunningTests {
            return NoopGeofenceRegistryRepository()
        }
        return CoreLocationGeofenceRegistryRepository()
    }

    static func defaultNotificationScheduler() -> NotificationScheduling {
        if LaunchArguments.isRunningTests {
            return NoopNotificationScheduler()
        }
        return NotificationScheduler()
    }

    static func defaultLocationPermissionManager() -> LocationPermissionManager {
        if LaunchArguments.isRunningTests {
            return NoopLocationPermissionManager()
        }
        return DefaultLocationPermissionManager()
    }

    static func defaultCurrentLocationProvider() -> CurrentLocationProviding {
        if LaunchArguments.isRunningTests {
            return FixedCurrentLocationProvider(
                coordinate: CLLocationCoordinate2D(latitude: 35.6813, longitude: 139.767066)
            )
        }
        return DefaultCurrentLocationProvider()
    }
}

@MainActor
private struct AppEnvironmentKey: EnvironmentKey {
    static var defaultValue: AppEnvironment { AppEnvironment.shared }
}

extension EnvironmentValues {
    @MainActor var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
