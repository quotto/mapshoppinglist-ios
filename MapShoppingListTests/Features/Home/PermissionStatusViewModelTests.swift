import XCTest
import CoreLocation
import UserNotifications
@testable import MapShoppingList

@MainActor
final class PermissionStatusViewModelTests: XCTestCase {
    func testRefreshStatusesUpdatesPublishedValues() async {
        let location = StubLocationPermissionManager(status: .authorizedWhenInUse, requested: .authorizedAlways)
        let notification = StubNotificationScheduler(status: .denied, requested: .authorized)
        let settings = StubSettingsOpener()
        let viewModel = PermissionStatusViewModel(
            locationManager: location,
            notificationScheduler: notification,
            settingsOpener: settings
        )

        await viewModel.refreshStatuses()

        XCTAssertEqual(viewModel.locationStatus, .authorizedWhenInUse)
        XCTAssertEqual(viewModel.notificationStatus, .denied)
    }

    func testNeedsLocationPromptIsFalseWhenAuthorizedAlways() async {
        let location = StubLocationPermissionManager(status: .authorizedAlways, requested: .authorizedAlways)
        let notification = StubNotificationScheduler(status: .authorized, requested: .authorized)
        let settings = StubSettingsOpener()
        let viewModel = PermissionStatusViewModel(
            locationManager: location,
            notificationScheduler: notification,
            settingsOpener: settings
        )

        await viewModel.refreshStatuses()

        XCTAssertFalse(viewModel.needsLocationPrompt)
        XCTAssertFalse(viewModel.needsNotificationPrompt)
    }

    func testOpenSettingsInvokesOpener() {
        let location = StubLocationPermissionManager(status: .denied, requested: .denied)
        let notification = StubNotificationScheduler(status: .denied, requested: .denied)
        let settings = StubSettingsOpener()
        let viewModel = PermissionStatusViewModel(
            locationManager: location,
            notificationScheduler: notification,
            settingsOpener: settings
        )

        viewModel.openSettings()

        XCTAssertEqual(settings.openCount, 1)
    }
}

// MARK: - Stubs

@MainActor
private final class StubLocationPermissionManager: LocationPermissionManager {
    var status: CLAuthorizationStatus
    private let requestedStatus: CLAuthorizationStatus
    private(set) var requestCallCount = 0

    init(status: CLAuthorizationStatus, requested: CLAuthorizationStatus) {
        self.status = status
        self.requestedStatus = requested
    }

    func authorizationStatus() -> CLAuthorizationStatus {
        status
    }

    func requestAuthorization() async -> CLAuthorizationStatus {
        requestCallCount += 1
        status = requestedStatus
        return requestedStatus
    }
}

@MainActor
private final class StubNotificationScheduler: NotificationScheduling {
    var status: UNAuthorizationStatus
    private let requestedStatus: UNAuthorizationStatus
    private(set) var requestCallCount = 0

    init(status: UNAuthorizationStatus, requested: UNAuthorizationStatus) {
        self.status = status
        self.requestedStatus = requested
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    @discardableResult
    func requestAuthorization() async -> UNAuthorizationStatus {
        requestCallCount += 1
        status = requestedStatus
        return requestedStatus
    }

    func requestAuthorizationIfNeeded() async {
        _ = await requestAuthorization()
    }

    func schedule(place: Place, items: [ShoppingItem]) async {}
}

@MainActor
private final class StubSettingsOpener: SettingsOpening {
    private(set) var openCount = 0

    func openAppSettings() {
        openCount += 1
    }
}
