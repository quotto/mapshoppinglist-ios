import Foundation

struct HTTPItemCategoryClassifier: ItemCategoryClassifying {
    private let endpoint: URL
    private let apiKey: String
    private let session: URLSession

    init(endpoint: URL, apiKey: String, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.session = session
    }

    func classify(
        itemName: String,
        locale: String,
        country: String,
        maxCategories: Int
    ) async throws -> ItemCategoryClassification {
        NearbyDebugLogger.log(.categoryAPI, "category classify started", metadata: [
            "itemName": itemName,
            "locale": locale,
            "country": country,
            "maxCategories": String(maxCategories)
        ])
        let request = try makeRequest(
            itemName: itemName,
            locale: locale,
            country: country,
            maxCategories: maxCategories
        )
        let (data, response) = try await send(request: request)
        try validate(response: response)
        let classification = try decodeResponse(data)
        NearbyDebugLogger.log(.categoryAPI, "category classify succeeded", metadata: [
            "normalizedItemName": classification.normalizedItemName,
            "categoryCount": String(classification.categories.count),
            "cacheHit": String(classification.cacheHit)
        ])
        return classification
    }
}

private extension HTTPItemCategoryClassifier {
    func makeRequest(
        itemName: String,
        locale: String,
        country: String,
        maxCategories: Int
    ) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.httpBody = try JSONEncoder().encode(
            ItemCategoryRequestBody(
                itemName: itemName,
                locale: locale,
                country: country,
                maxCategories: maxCategories
            )
        )
        return request
    }

    func send(request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            NearbyDebugLogger.log(.categoryAPI, "category request failed", metadata: [
                "error": error.localizedDescription
            ])
            throw ItemCategoryClassificationError.transport("カテゴリ判定APIとの通信に失敗しました。")
        }
    }

    func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            NearbyDebugLogger.log(.categoryAPI, "category response invalid", metadata: [
                "reason": "non-http-response"
            ])
            throw ItemCategoryClassificationError.invalidResponse("カテゴリ判定APIの応答形式が不正です。")
        }
        NearbyDebugLogger.log(.categoryAPI, "category response received", metadata: [
            "statusCode": String(httpResponse.statusCode)
        ])

        switch httpResponse.statusCode {
        case 200:
            return
        case 401, 403:
            throw ItemCategoryClassificationError.unauthorized("カテゴリ判定APIの認証に失敗しました。")
        case 429:
            throw ItemCategoryClassificationError.rateLimited("カテゴリ判定APIの利用上限に達しました。")
        case 500...599:
            throw ItemCategoryClassificationError.server("カテゴリ判定APIが一時的に利用できません。")
        default:
            throw ItemCategoryClassificationError.invalidResponse("カテゴリ判定APIから予期しない応答が返されました。")
        }
    }

    func decodeResponse(_ data: Data) throws -> ItemCategoryClassification {
        do {
            let decoded = try JSONDecoder.itemCategory.decode(ItemCategoryResponseBody.self, from: data)
            return ItemCategoryClassification(
                normalizedItemName: decoded.normalizedItemName,
                categories: decoded.categories.map {
                    ItemPlaceCategory(
                        placeType: $0.placeType,
                        confidence: $0.confidence,
                        reason: $0.reason
                    )
                },
                cacheHit: decoded.cacheHit,
                modelVersion: decoded.modelVersion,
                generatedAt: decoded.generatedAt
            )
        } catch {
            throw ItemCategoryClassificationError.invalidResponse("カテゴリ判定APIの応答を解釈できませんでした。")
        }
    }
}

private struct ItemCategoryRequestBody: Encodable {
    let itemName: String
    let locale: String
    let country: String
    let maxCategories: Int
}

private struct ItemCategoryResponseBody: Decodable {
    struct Category: Decodable {
        let placeType: String
        let confidence: Double
        let reason: String?
    }

    let normalizedItemName: String
    let categories: [Category]
    let cacheHit: Bool
    let modelVersion: String?
    let generatedAt: Date?
}

private extension JSONDecoder {
    static var itemCategory: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
