import CoreLocation
import CoreMotion
import Foundation

@MainActor
protocol ActivityPermissionManaging: AnyObject {
    func authorizationStatus() -> CMAuthorizationStatus
    func requestAuthorization() async -> CMAuthorizationStatus
}

@MainActor
protocol ActivityMonitoring: AnyObject {
    func start() async
    func stop()
}

@MainActor
protocol NearbySuggestionTriggerHandling: AnyObject {
    func handleStopDetected(
        coordinate: CLLocationCoordinate2D,
        detectedAt: Date
    ) async
}

@MainActor
final class DefaultActivityPermissionManager: ActivityPermissionManaging {
    private let manager: CMMotionActivityManager

    init(manager: CMMotionActivityManager = CMMotionActivityManager()) {
        self.manager = manager
    }

    func authorizationStatus() -> CMAuthorizationStatus {
        CMMotionActivityManager.authorizationStatus()
    }

    func requestAuthorization() async -> CMAuthorizationStatus {
        guard CMMotionActivityManager.isActivityAvailable() else {
            NearbyDebugLogger.log(.activity, "activity unavailable")
            return .restricted
        }
        guard authorizationStatus() == .notDetermined else {
            let status = authorizationStatus()
            NearbyDebugLogger.log(.activity, "authorization already resolved", metadata: [
                "status": String(describing: status)
            ])
            return status
        }

        let end = Date()
        let start = end.addingTimeInterval(-60)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            manager.queryActivityStarting(from: start, to: end, to: .main) { _, _ in
                continuation.resume()
            }
        }
        let status = authorizationStatus()
        NearbyDebugLogger.log(.activity, "authorization requested", metadata: [
            "status": String(describing: status)
        ])
        return status
    }
}

@MainActor
final class MotionActivityMonitor: ActivityMonitoring {
    private let activityManager: CMMotionActivityManager
    private let permissionManager: ActivityPermissionManaging
    private let currentLocationProvider: CurrentLocationProviding
    private let triggerHandler: NearbySuggestionTriggerHandling
    private var isRunning = false
    private var lastWasMoving = false

    init(
        activityManager: CMMotionActivityManager = CMMotionActivityManager(),
        permissionManager: ActivityPermissionManaging,
        currentLocationProvider: CurrentLocationProviding,
        triggerHandler: NearbySuggestionTriggerHandling
    ) {
        self.activityManager = activityManager
        self.permissionManager = permissionManager
        self.currentLocationProvider = currentLocationProvider
        self.triggerHandler = triggerHandler
    }

    func start() async {
        guard isRunning == false else { return }
        guard CMMotionActivityManager.isActivityAvailable() else {
            NearbyDebugLogger.log(.activity, "start skipped because activity is unavailable")
            return
        }

        let status = await permissionManager.requestAuthorization()
        guard status == .authorized else {
            NearbyDebugLogger.log(.activity, "start skipped because authorization failed", metadata: [
                "status": String(describing: status)
            ])
            return
        }

        isRunning = true
        NearbyDebugLogger.log(.activity, "activity updates started")
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            Task { @MainActor in
                await self.handle(activity: activity)
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        activityManager.stopActivityUpdates()
        isRunning = false
        lastWasMoving = false
        NearbyDebugLogger.log(.activity, "activity updates stopped")
    }
}

@MainActor
private extension MotionActivityMonitor {
    func handle(activity: CMMotionActivity) async {
        let isMoving = activity.walking || activity.running || activity.automotive || activity.cycling
        let isStopped = activity.stationary && activity.unknown == false
        NearbyDebugLogger.log(.activity, "activity update received", metadata: [
            "walking": String(activity.walking),
            "running": String(activity.running),
            "automotive": String(activity.automotive),
            "cycling": String(activity.cycling),
            "stationary": String(activity.stationary),
            "unknown": String(activity.unknown)
        ])

        if isMoving {
            lastWasMoving = true
            NearbyDebugLogger.log(.activity, "movement detected")
            return
        }

        guard isStopped, lastWasMoving else {
            NearbyDebugLogger.log(.activity, "stop ignored", metadata: [
                "isStopped": String(isStopped),
                "lastWasMoving": String(lastWasMoving)
            ])
            return
        }
        lastWasMoving = false

        do {
            let coordinate = try await currentLocationProvider.currentLocation()
            NearbyDebugLogger.log(.activity, "stop detected", metadata: [
                "latitude": String(coordinate.latitude),
                "longitude": String(coordinate.longitude)
            ])
            await triggerHandler.handleStopDetected(
                coordinate: coordinate,
                detectedAt: Date()
            )
        } catch {
            NearbyDebugLogger.log(.activity, "current location failed after stop", metadata: [
                "error": error.localizedDescription
            ])
            // 権限不足や取得失敗時は次回トリガーへ委ねる
        }
    }
}

@MainActor
final class NoopActivityPermissionManager: ActivityPermissionManaging {
    private let status: CMAuthorizationStatus

    init(status: CMAuthorizationStatus = .authorized) {
        self.status = status
    }

    func authorizationStatus() -> CMAuthorizationStatus { status }

    func requestAuthorization() async -> CMAuthorizationStatus { status }
}

@MainActor
final class NoopActivityMonitor: ActivityMonitoring {
    func start() async {}
    func stop() {}
}

@MainActor
final class NoopNearbySuggestionTriggerHandler: NearbySuggestionTriggerHandling {
    func handleStopDetected(
        coordinate: CLLocationCoordinate2D,
        detectedAt: Date
    ) async {}
}

@MainActor
final class NearbySuggestionTriggerProcessor: NearbySuggestionTriggerHandling {
    private let findNearbyStoreSuggestionsUseCase: FindNearbyStoreSuggestionsUseCase
    private let nearbySuggestionStateRepository: NearbySuggestionStateRepository
    private let notificationScheduler: NotificationScheduling

    init(
        findNearbyStoreSuggestionsUseCase: FindNearbyStoreSuggestionsUseCase,
        nearbySuggestionStateRepository: NearbySuggestionStateRepository,
        notificationScheduler: NotificationScheduling
    ) {
        self.findNearbyStoreSuggestionsUseCase = findNearbyStoreSuggestionsUseCase
        self.nearbySuggestionStateRepository = nearbySuggestionStateRepository
        self.notificationScheduler = notificationScheduler
    }

    func handleStopDetected(
        coordinate: CLLocationCoordinate2D,
        detectedAt: Date
    ) async {
        do {
            NearbyDebugLogger.log(.nearbyDecision, "nearby suggestion processing started", metadata: [
                "latitude": String(coordinate.latitude),
                "longitude": String(coordinate.longitude),
                "detectedAt": detectedAt.ISO8601Format()
            ])
            let suggestions = try await findNearbyStoreSuggestionsUseCase.execute(
                currentCoordinate: coordinate,
                now: detectedAt
            )
            NearbyDebugLogger.log(.nearbyDecision, "nearby suggestion processing finished", metadata: [
                "suggestionCount": String(suggestions.count)
            ])

            for suggestion in suggestions {
                let placeCoordinate = CLLocationCoordinate2D(
                    latitude: suggestion.place.latitude,
                    longitude: suggestion.place.longitude
                )
                NearbyDebugLogger.log(.nearbyDecision, "scheduling suggestion notification", metadata: [
                    "itemId": suggestion.item.id.uuidString,
                    "itemTitle": suggestion.item.title,
                    "placeId": suggestion.place.id,
                    "placeName": suggestion.place.name,
                    "distanceMeters": String(Int(suggestion.distanceMeters.rounded()))
                ])
                await notificationScheduler.scheduleNearbySuggestion(
                    item: suggestion.item,
                    placeName: suggestion.place.name,
                    coordinate: placeCoordinate,
                    distanceMeters: suggestion.distanceMeters
                )
                try await nearbySuggestionStateRepository.upsert(
                    state: NearbySuggestionState(
                        itemId: suggestion.item.id,
                        lastNotifiedAt: detectedAt,
                        lastNotifiedLatitudeE6: coordinate.latitude.toLatitudeE6(),
                        lastNotifiedLongitudeE6: coordinate.longitude.toLongitudeE6(),
                        lastSuggestedPlaceID: suggestion.place.id,
                        lastSuggestedPlaceName: suggestion.place.name
                    )
                )
            }
        } catch {
            NearbyDebugLogger.log(.nearbyDecision, "nearby suggestion processing failed", metadata: [
                "error": error.localizedDescription
            ])
            // 停止トリガーの失敗は UI へ出さず、次回トリガーへ委ねる
        }
    }
}

@MainActor
final class NearbySuggestionEventPoster: NearbySuggestionTriggerHandling {
    func handleStopDetected(
        coordinate: CLLocationCoordinate2D,
        detectedAt: Date
    ) async {
        NotificationCenter.default.post(
            name: .nearbySuggestionTriggerDetected,
            object: nil,
            userInfo: [
                AppNotificationUserInfoKey.latitude: coordinate.latitude,
                AppNotificationUserInfoKey.longitude: coordinate.longitude,
                AppNotificationUserInfoKey.detectedAt: detectedAt
            ]
        )
    }
}

private extension Double {
    func toLatitudeE6() -> Int {
        Int((self * 1_000_000).rounded())
    }

    func toLongitudeE6() -> Int {
        Int((self * 1_000_000).rounded())
    }
}
