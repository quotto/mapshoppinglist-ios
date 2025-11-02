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

    private let locationManager: LocationPermissionManaging
    private let notificationScheduler: NotificationScheduling
    private let settingsOpener: SettingsOpening

    init(
        locationManager: LocationPermissionManaging,
        notificationScheduler: NotificationScheduling,
        settingsOpener: SettingsOpening
    ) {
        self.locationManager = locationManager
        self.notificationScheduler = notificationScheduler
        self.settingsOpener = settingsOpener
        locationStatus = locationManager.authorizationStatus()
        notificationStatus = .authorized
    }

    convenience init(environment: AppEnvironment, settingsOpener: SettingsOpening = SystemSettingsOpener()) {
        self.init(
            locationManager: environment.locationPermissionManager,
            notificationScheduler: environment.notificationScheduler,
            settingsOpener: settingsOpener
        )
    }

    func refreshStatuses() async {
        locationStatus = locationManager.authorizationStatus()
        notificationStatus = await notificationScheduler.authorizationStatus()
    }

    func requestInitialPermissionsIfNeeded() async {
        if needsLocationPrompt {
            isRequestingLocation = true
            locationStatus = await locationManager.requestAlwaysAuthorizationIfNeeded()
            isRequestingLocation = false
        }
        if needsNotificationPrompt {
            isRequestingNotification = true
            notificationStatus = await notificationScheduler.requestAuthorization()
            isRequestingNotification = false
        }
    }

    func requestLocationAuthorization() async {
        isRequestingLocation = true
        locationStatus = await locationManager.requestAlwaysAuthorizationIfNeeded()
        isRequestingLocation = false
    }

    func requestNotificationAuthorization() async {
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
        case .authorized:
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
        case .notDetermined:
            return "ジオフェンス通知を利用するため、位置情報の常に許可が必要です。"
        case .authorizedWhenInUse:
            return "現在は「使用中のみ許可」です。常に許可へ切り替えると地点付近で通知できます。"
        case .denied, .restricted:
            return "設定アプリで位置情報の常に許可を有効にしてください。"
        case .authorized:
            return "位置情報の許可状態を確認してください。"
        case .authorizedAlways:
            return ""
        @unknown default:
            return "位置情報の権限状態を確認できません。"
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

    var locationSecondaryButtonTitle: String? {
        switch locationStatus {
        case .authorizedWhenInUse:
            return "設定を開く"
        default:
            return nil
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
