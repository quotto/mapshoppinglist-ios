import Foundation

enum AppConfigurationValues {
    static var nearbyDebugLoggingEnabled: Bool {
        bool(for: "NEARBY_DEBUG_LOGGING_ENABLED")
    }

    static var itemCategoryAPIEndpoint: String? {
        string(for: "ITEM_CATEGORY_API_ENDPOINT")
    }

    static var itemCategoryAPIKey: String? {
        string(for: "ITEM_CATEGORY_API_KEY")
    }

    static var googleMapsAPIKey: String? {
        string(for: "GOOGLE_MAPS_API_KEY")
    }

    private static func string(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let normalized = value.normalizedBuildSettingValue
        return normalized.isEmpty ? nil : normalized
    }

    private static func bool(for key: String) -> Bool {
        guard let value = string(for: key)?.lowercased() else {
            return false
        }

        switch value {
        case "1", "yes", "true":
            return true
        default:
            return false
        }
    }
}

extension String {
    var normalizedBuildSettingValue: String {
        var trimmed = trimmingCharacters(in: .whitespacesAndNewlines)

        while trimmed.count >= 2, trimmed.hasPrefix("\""), trimmed.hasSuffix("\"") {
            trimmed = String(trimmed.dropFirst().dropLast())
        }

        return trimmed
    }
}
