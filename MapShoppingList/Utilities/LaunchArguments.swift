import Foundation
import CoreLocation
import UserNotifications

enum LaunchArguments {
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("UITests")
    private static let hasXCTestEnv = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private static let hasXCTestClass = NSClassFromString("XCTestCase") != nil
    static let isRunningTests = hasXCTestEnv || hasXCTestClass
    static let isUnitTesting = isRunningTests && !isUITesting

    private static let scenarioKey = "UITEST_SCENARIO"
    private static let locationStatusKey = "UITEST_LOCATION_STATUS"
    private static let notificationStatusKey = "UITEST_NOTIFICATION_STATUS"

    static var uiTestScenario: String? {
        ProcessInfo.processInfo.environment[scenarioKey]
    }

    static var locationAuthorizationOverride: CLAuthorizationStatus? {
        guard let value = ProcessInfo.processInfo.environment[locationStatusKey]?.lowercased() else {
            return nil
        }
        switch value {
        case "always":
            return .authorizedAlways
        case "when_in_use":
            return .authorizedWhenInUse
        case "denied":
            return .denied
        default:
            return nil
        }
    }

    static var notificationAuthorizationOverride: UNAuthorizationStatus? {
        guard let value = ProcessInfo.processInfo.environment[notificationStatusKey]?.lowercased() else {
            return nil
        }
        switch value {
        case "authorized":
            return .authorized
        case "denied":
            return .denied
        case "provisional":
            return .provisional
        default:
            return nil
        }
    }
}
