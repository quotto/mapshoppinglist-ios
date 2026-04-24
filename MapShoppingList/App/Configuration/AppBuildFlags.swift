import Foundation

enum AppBuildFlags {
    static var isNearbyDebugLoggingEnabled: Bool {
        AppConfigurationValues.nearbyDebugLoggingEnabled
    }
}
