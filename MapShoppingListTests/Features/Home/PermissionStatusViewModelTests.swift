import CoreLocation
import CoreMotion
import Foundation
import Testing
import UserNotifications
@testable import MapShoppingList

@Suite("PermissionStatusViewModelTests")
@MainActor
struct PermissionStatusViewModelTests {
    @Test("shows activity prompt when motion access is not determined")
    func showsActivityPromptWhenMotionAccessIsNotDetermined() async {
        let viewModel = PermissionStatusViewModel(
            locationManager: NoopLocationPermissionManager(status: .authorizedAlways),
            activityPermissionManager: NoopActivityPermissionManager(status: .notDetermined),
            notificationScheduler: NoopNotificationScheduler(status: .authorized),
            settingsOpener: StubSettingsOpener()
        )

        await viewModel.refreshStatuses()

        #expect(viewModel.needsActivityPrompt)
        #expect(viewModel.activityPrimaryButtonTitle == "許可をリクエスト")
    }

    @Test("requestActivityAuthorization updates status")
    func requestActivityAuthorizationUpdatesStatus() async {
        let manager = NoopActivityPermissionManager(status: .authorized)
        let viewModel = PermissionStatusViewModel(
            locationManager: NoopLocationPermissionManager(status: .authorizedAlways),
            activityPermissionManager: manager,
            notificationScheduler: NoopNotificationScheduler(status: .authorized),
            settingsOpener: StubSettingsOpener()
        )

        await viewModel.requestActivityAuthorization()

        #expect(viewModel.activityStatus == .authorized)
        #expect(viewModel.needsActivityPrompt == false)
    }

    @Test("nearby trigger handler posts notification")
    func nearbyTriggerHandlerPostsNotification() async throws {
        let handler = NearbySuggestionEventPoster()
        let coordinate = CLLocationCoordinate2D(latitude: 35.1, longitude: 139.2)

        var token: NSObjectProtocol?
        let notification = await withCheckedContinuation { (continuation: CheckedContinuation<Notification, Never>) in
            token = NotificationCenter.default.addObserver(
                forName: .nearbySuggestionTriggerDetected,
                object: nil,
                queue: nil
            ) { notification in
                continuation.resume(returning: notification)
            }

            Task {
                await handler.handleStopDetected(coordinate: coordinate, detectedAt: Date(timeIntervalSince1970: 123))
            }
        }
        if let token {
            NotificationCenter.default.removeObserver(token)
        }

        #expect(notification.userInfo?[AppNotificationUserInfoKey.latitude] as? Double == 35.1)
        #expect(notification.userInfo?[AppNotificationUserInfoKey.longitude] as? Double == 139.2)
        #expect(
            notification.userInfo?[AppNotificationUserInfoKey.detectedAt] as? Date
                == Date(timeIntervalSince1970: 123)
        )
    }
}

private struct StubSettingsOpener: SettingsOpening {
    func openAppSettings() {}
}
