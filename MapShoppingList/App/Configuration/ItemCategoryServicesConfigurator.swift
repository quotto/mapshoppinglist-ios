import Foundation

struct ItemCategoryServicesConfigurator {
    struct Result {
        let classifier: ItemCategoryClassifying
        let warningMessage: String?
    }

    static func configure(session: URLSession = .shared) -> Result {
        let endpoint = AppConfigurationValues.itemCategoryAPIEndpoint
        let apiKey = AppConfigurationValues.itemCategoryAPIKey

        guard let endpoint, endpoint.isEmpty == false else {
            let message = """
            カテゴリ判定APIのエンドポイントが設定されていません。User-Defined build setting の
            ITEM_CATEGORY_API_ENDPOINT を確認してください。
            """
            return Result(classifier: UnavailableItemCategoryClassifier(reason: message), warningMessage: message)
        }
        guard let url = URL(string: endpoint) else {
            let message = "カテゴリ判定APIのエンドポイントが不正です。ITEM_CATEGORY_API_ENDPOINT を確認してください。"
            return Result(classifier: UnavailableItemCategoryClassifier(reason: message), warningMessage: message)
        }
        guard let apiKey, apiKey.isEmpty == false else {
            let message = """
            カテゴリ判定APIのAPI Keyが設定されていません。User-Defined build setting の
            ITEM_CATEGORY_API_KEY を確認してください。
            """
            return Result(classifier: UnavailableItemCategoryClassifier(reason: message), warningMessage: message)
        }

        return Result(
            classifier: HTTPItemCategoryClassifier(endpoint: url, apiKey: apiKey, session: session),
            warningMessage: nil
        )
    }
}
