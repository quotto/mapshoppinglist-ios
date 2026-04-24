import Foundation

protocol ItemCategoryClassifying {
    func classify(
        itemName: String,
        locale: String,
        country: String,
        maxCategories: Int
    ) async throws -> ItemCategoryClassification
}

struct ItemCategoryClassification: Equatable {
    let normalizedItemName: String
    let categories: [ItemPlaceCategory]
    let cacheHit: Bool
    let modelVersion: String?
    let generatedAt: Date?
}

struct ItemPlaceCategory: Equatable {
    let placeType: String
    let confidence: Double
    let reason: String?
}

enum ItemCategoryClassificationError: LocalizedError, Equatable {
    case configuration(String)
    case invalidResponse(String)
    case server(String)
    case rateLimited(String)
    case unauthorized(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case let .configuration(message),
            let .invalidResponse(message),
            let .server(message),
            let .rateLimited(message),
            let .unauthorized(message),
            let .transport(message):
            return message
        }
    }
}

struct UnavailableItemCategoryClassifier: ItemCategoryClassifying {
    private let reason: String

    init(reason: String) {
        self.reason = reason
    }

    func classify(
        itemName: String,
        locale: String,
        country: String,
        maxCategories: Int
    ) async throws -> ItemCategoryClassification {
        throw ItemCategoryClassificationError.configuration(reason)
    }
}
