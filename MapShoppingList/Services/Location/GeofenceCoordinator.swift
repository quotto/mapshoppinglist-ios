import Foundation

@MainActor
final class GeofenceCoordinator {
    private let placesRepository: PlacesRepository
    private let loadAllPlacesUseCase: LoadAllPlacesUseCase
    private let loadShoppingItemsUseCase: LoadShoppingItemsUseCase
    private let notificationStateRepository: NotificationStateRepository
    private let shouldSendNotificationUseCase: ShouldSendNotificationUseCase
    private let buildGeofenceSyncPlanUseCase: BuildGeofenceSyncPlanUseCase
    private let geofenceRepository: GeofenceRegistryRepository
    private let notificationScheduler: NotificationScheduler
    private var eventSequence: Int = 0

    init(
        placesRepository: PlacesRepository,
        loadAllPlacesUseCase: LoadAllPlacesUseCase,
        loadShoppingItemsUseCase: LoadShoppingItemsUseCase,
        notificationStateRepository: NotificationStateRepository,
        shouldSendNotificationUseCase: ShouldSendNotificationUseCase,
        buildGeofenceSyncPlanUseCase: BuildGeofenceSyncPlanUseCase,
        geofenceRepository: GeofenceRegistryRepository,
        notificationScheduler: NotificationScheduler
    ) {
        self.placesRepository = placesRepository
        self.loadAllPlacesUseCase = loadAllPlacesUseCase
        self.loadShoppingItemsUseCase = loadShoppingItemsUseCase
        self.notificationStateRepository = notificationStateRepository
        self.shouldSendNotificationUseCase = shouldSendNotificationUseCase
        self.buildGeofenceSyncPlanUseCase = buildGeofenceSyncPlanUseCase
        self.geofenceRepository = geofenceRepository
        self.notificationScheduler = notificationScheduler
    }

    func syncActiveGeofences() async {
        do {
            let places = try await loadAllPlacesUseCase.execute()
            let activePlaces = places.filter { $0.isActive }
            let plan = try await buildGeofenceSyncPlanUseCase.execute(activePlaces: activePlaces)
            try await geofenceRepository.registerGeofences(plan.toRegister)
            try await geofenceRepository.unregisterGeofences(plan.toUnregister)
        } catch {
            // TODO: ログ収集などの実装を検討
        }
    }

    func handleRegionEntry(placeId: UUID) async {
        do {
            eventSequence += 1
            let sequence = eventSequence
            let now = Date()
            debugPrint("[Geofence] handle start seq=\(sequence) place=\(placeId) time=\(now)")
            defer { debugPrint("[Geofence] handle end seq=\(sequence) place=\(placeId) time=\(Date())") }
            guard let place = try await placesRepository.fetchPlace(id: placeId), place.isActive else { return }
            let items = try await loadShoppingItemsUseCase.execute()
            debugPrint("[Geofence] seq=\(sequence) fetched \(items.count) items")
            let pendingItems = items.filter { $0.placeIds.contains(placeId) && $0.isPurchased == false }
            guard pendingItems.isEmpty == false else { return }

            let state = try await notificationStateRepository.fetchState(forPlace: placeId)
            debugPrint("[Geofence] seq=\(sequence) state=\(String(describing: state))")
            guard (try? shouldSendNotificationUseCase.execute(state: state, now: now)) == true else { return }

            do {
                debugPrint("[Geofence] seq=\(sequence) scheduling notification")
                await notificationScheduler.schedule(place: place, items: pendingItems)
            } catch {
                throw error
            }
            let newState = NotificationState(placeId: placeId, lastNotifiedAt: now, snoozeUntil: state?.snoozeUntil)
            try await notificationStateRepository.upsert(state: newState)
        } catch {
            // TODO: ログ収集などの実装を検討
            debugPrint("[Geofence] seq=\(eventSequence) error=\(error)")
        }
    }
}
