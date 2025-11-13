import Foundation
import Combine
import CoreLocation
import UserNotifications

@MainActor
final class PermissionStatusViewModel: ObservableObject {
    @Published private(set) var locationStatus: CLAuthorizationStatus
    @Published private(set) var notificationStatus: UNAuthorizationStatus
    @Published var isRequestingLocation: Bool = false
    @Published var isRequestingNotification: Bool = false

    private let locationManager: LocationPermissionManager
    private let notificationScheduler: NotificationScheduling
    private let settingsOpener: SettingsOpening

    init(
        locationManager: LocationPermissionManager,
        notificationScheduler: NotificationScheduling,
        settingsOpener: SettingsOpening
    ) {
        self.locationManager = locationManager
        self.notificationScheduler = notificationScheduler
        self.settingsOpener = settingsOpener
        if let override = LaunchArguments.locationAuthorizationOverride {
            locationStatus = override
        } else if LaunchArguments.isUITesting {
            locationStatus = .authorizedAlways
        } else {
            locationStatus = locationManager.authorizationStatus()
        }

        if let notificationOverride = LaunchArguments.notificationAuthorizationOverride {
            notificationStatus = notificationOverride
        } else if LaunchArguments.isUITesting {
            notificationStatus = .authorized
        } else {
            notificationStatus = .authorized
        }
    }

    convenience init(environment: AppEnvironment, settingsOpener: SettingsOpening = SystemSettingsOpener()) {
        self.init(
            locationManager: environment.locationPermissionManager,
            notificationScheduler: environment.notificationScheduler,
            settingsOpener: settingsOpener
        )
    }

    func refreshStatuses() async {
        if let override = LaunchArguments.locationAuthorizationOverride {
            locationStatus = override
        } else {
            locationStatus = locationManager.authorizationStatus()
        }

        if let override = LaunchArguments.notificationAuthorizationOverride {
            notificationStatus = override
        } else {
            notificationStatus = await notificationScheduler.authorizationStatus()
        }
    }

    func requestLocationAuthorization() async {
        if let override = LaunchArguments.locationAuthorizationOverride {
            locationStatus = override
            return
        }
        isRequestingLocation = true
        locationStatus = await locationManager.requestAuthorization()
        isRequestingLocation = false
    }

    func requestNotificationAuthorization() async {
        if let override = LaunchArguments.notificationAuthorizationOverride {
            notificationStatus = override
            return
        }
        isRequestingNotification = true
        notificationStatus = await notificationScheduler.requestAuthorization()
        isRequestingNotification = false
    }

    func openSettings() {
        settingsOpener.openAppSettings()
    }

    var needsLocationPrompt: Bool {
        switch locationStatus {
        case .authorizedAlways:
            return false
        default:
            return true
        }
    }

    var needsNotificationPrompt: Bool {
        switch notificationStatus {
        case .authorized:
            return false
        default:
            return true
        }
    }

    var locationMessage: String {
        switch locationStatus {
        case .authorizedAlways:
            return ""
        default:
            return "登録したお店の付近で通知を受け取るためには位置情報の利用を「常に許可」に変更してください。"
        }
    }

    var locationPrimaryButtonTitle: String {
        switch locationStatus {
        case .notDetermined:
            return "許可をリクエスト"
        case .authorizedWhenInUse:
            return "常に許可をリクエスト"
        case .denied, .restricted:
            return "設定を開く"
        case .authorizedAlways, .authorized:
            return ""
        @unknown default:
            return "設定を開く"
        }
    }

    var notificationMessage: String {
        switch notificationStatus {
        case .notDetermined:
            return "地点付近でリマインドを受け取るため通知を許可してください。"
        case .denied:
            return "通知が無効です。設定アプリで通知を有効にしてください。"
        case .provisional:
            return "通知がサイレントでのみ送信されます。設定アプリで通常の通知を有効にしてください。"
        case .ephemeral:
            return "通知の許可が一時的です。設定アプリで通知を有効にしてください。"
        case .authorized:
            return ""
        @unknown default:
            return "通知権限の状態を確認してください。"
        }
    }

    var notificationPrimaryButtonTitle: String {
        switch notificationStatus {
        case .notDetermined:
            return "通知を許可"
        case .denied, .provisional, .ephemeral:
            return "設定を開く"
        case .authorized:
            return ""
        @unknown default:
            return "設定を開く"
        }
    }
}
