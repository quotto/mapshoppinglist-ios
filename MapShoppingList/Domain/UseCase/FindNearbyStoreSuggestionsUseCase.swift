import CoreLocation
import Foundation

struct FindNearbyStoreSuggestionsUseCase {
    private static let searchRadiusMeters: CLLocationDistance = 300
    private static let maxCategories = 3
    private static let fallbackPlaceTypes: Set<String> = ["store"]

    private let loadShoppingItemsUseCase: LoadShoppingItemsUseCase
    private let nearbySuggestionStateRepository: NearbySuggestionStateRepository
    private let shouldSuggestNearbyStoreUseCase: ShouldSuggestNearbyStoreUseCase
    private let placesSearchService: PlacesSearchService
    private let itemCategoryClassifier: ItemCategoryClassifying

    init(
        loadShoppingItemsUseCase: LoadShoppingItemsUseCase,
        nearbySuggestionStateRepository: NearbySuggestionStateRepository,
        shouldSuggestNearbyStoreUseCase: ShouldSuggestNearbyStoreUseCase,
        placesSearchService: PlacesSearchService,
        itemCategoryClassifier: ItemCategoryClassifying
    ) {
        self.loadShoppingItemsUseCase = loadShoppingItemsUseCase
        self.nearbySuggestionStateRepository = nearbySuggestionStateRepository
        self.shouldSuggestNearbyStoreUseCase = shouldSuggestNearbyStoreUseCase
        self.placesSearchService = placesSearchService
        self.itemCategoryClassifier = itemCategoryClassifier
    }

    func execute(
        currentCoordinate: CLLocationCoordinate2D,
        now: Date = Date(),
        locale: String = "ja-JP",
        country: String = "JP"
    ) async throws -> [NearbyStoreSuggestion] {
        let items = try await loadShoppingItemsUseCase.execute()
        let targetItems = items.filter { $0.isPurchased == false && $0.placeIds.isEmpty }
        var suggestions: [NearbyStoreSuggestion] = []
        NearbyDebugLogger.log(.nearbyDecision, "evaluating nearby suggestions", metadata: [
            "allItemCount": String(items.count),
            "targetItemCount": String(targetItems.count)
        ])

        for item in targetItems {
            let state = try await nearbySuggestionStateRepository.fetchState(forItem: item.id)
            let shouldSuggest = shouldSuggestNearbyStoreUseCase.execute(
                state: state,
                currentCoordinate: currentCoordinate,
                now: now
            )
            guard shouldSuggest else {
                NearbyDebugLogger.log(.nearbyDecision, "item suppressed by cooldown", metadata: [
                    "itemId": item.id.uuidString,
                    "itemTitle": item.title,
                    "lastNotifiedAt": state?.lastNotifiedAt?.ISO8601Format() ?? "nil"
                ])
                continue
            }
            NearbyDebugLogger.log(.nearbyDecision, "item passed cooldown", metadata: [
                "itemId": item.id.uuidString,
                "itemTitle": item.title
            ])

            if let suggestion = try await resolveSuggestion(
                for: item,
                currentCoordinate: currentCoordinate,
                locale: locale,
                country: country
            ) {
                NearbyDebugLogger.log(.nearbyDecision, "item resolved suggestion ", metadata: [
                    "itemId": item.id.uuidString,
                    "itemTitle": item.title,
                    "placeId": suggestion.place.id,
                    "placeName": suggestion.place.name,
                    "strategy": strategyLabel(suggestion.strategy),
                    "distanceMeters": String(Int(suggestion.distanceMeters.rounded()))
                ])
                suggestions.append(suggestion)
            } else {
                NearbyDebugLogger.log(.nearbyDecision, "item had no nearby suggestion", metadata: [
                    "itemId": item.id.uuidString,
                    "itemTitle": item.title
                ])
            }
        }

        return suggestions
    }
}

private extension FindNearbyStoreSuggestionsUseCase {
    func resolveSuggestion(
        for item: ShoppingItem,
        currentCoordinate: CLLocationCoordinate2D,
        locale: String,
        country: String
    ) async throws -> NearbyStoreSuggestion? {
        if let validCategories = await classifyValidCategories(item: item, locale: locale, country: country) {
            for category in validCategories {
                if let suggestion = try await searchNearby(
                    includedType: category.placeType,
                    item: item,
                    currentCoordinate: currentCoordinate
                ) {
                    return suggestion
                }
            }

            if validCategories.isEmpty == false {
                NearbyDebugLogger.log(
                    .nearbyDecision,
                    "category search had no suggestion; text fallback skipped",
                    metadata: [
                        "itemId": item.id.uuidString,
                        "itemTitle": item.title,
                        "validCategoryCount": String(validCategories.count)
                    ]
                )
                return nil
            }
        }
        NearbyDebugLogger.log(.nearbyDecision, "falling back to text search", metadata: [
            "itemId": item.id.uuidString,
            "itemTitle": item.title
        ])

        return try await search(
            query: item.title,
            includedType: nil,
            strategy: .text,
            item: item,
            currentCoordinate: currentCoordinate
        )
    }

    func classifyValidCategories(
        item: ShoppingItem,
        locale: String,
        country: String
    ) async -> [ItemPlaceCategory]? {
        guard let classification = try? await itemCategoryClassifier.classify(
            itemName: item.title,
            locale: locale,
            country: country,
            maxCategories: Self.maxCategories
        ) else {
            return nil
        }
        NearbyDebugLogger.log(.nearbyDecision, "category classification available", metadata: [
            "itemId": item.id.uuidString,
            "itemTitle": item.title,
            "categoryCount": String(classification.categories.count)
        ])
        let validCategories = classification.categories.filter { category in
            category.placeType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
                category.confidence > 0 &&
                Self.fallbackPlaceTypes.contains(category.placeType) == false
        }
        NearbyDebugLogger.log(.nearbyDecision, "filtered category candidates", metadata: [
            "itemId": item.id.uuidString,
            "itemTitle": item.title,
            "validCategoryCount": String(validCategories.count)
        ])
        return validCategories
    }

    func searchNearby(
        includedType: String,
        item: ShoppingItem,
        currentCoordinate: CLLocationCoordinate2D
    ) async throws -> NearbyStoreSuggestion? {
        NearbyDebugLogger.log(.nearbyDecision, "place category search started", metadata: [
            "itemId": item.id.uuidString,
            "itemTitle": item.title,
            "includedType": includedType,
            "strategy": strategyLabel(.category(placeType: includedType))
        ])
        let response = try await placesSearchService.searchNearby(
            includedType: includedType,
            options: PlacesSearchOptions(
                origin: currentCoordinate,
                includedType: includedType,
                radiusMeters: Self.searchRadiusMeters,
                strictTypeFiltering: true
            )
        )
        guard let nearest = nearestPlace(in: response.places, currentCoordinate: currentCoordinate) else {
            NearbyDebugLogger.log(.nearbyDecision, "place category search had no candidate within radius", metadata: [
                "itemId": item.id.uuidString,
                "itemTitle": item.title,
                "includedType": includedType
            ])
            return nil
        }
        return NearbyStoreSuggestion(
            item: item,
            place: nearest.place,
            distanceMeters: nearest.distance,
            strategy: .category(placeType: includedType)
        )
    }

    func search(
        query: String,
        includedType: String?,
        strategy: NearbyStoreSuggestion.SearchStrategy,
        item: ShoppingItem,
        currentCoordinate: CLLocationCoordinate2D
    ) async throws -> NearbyStoreSuggestion? {
        NearbyDebugLogger.log(.nearbyDecision, "place search started", metadata: [
            "itemId": item.id.uuidString,
            "itemTitle": item.title,
            "query": query,
            "includedType": includedType ?? "nil",
            "strategy": strategyLabel(strategy)
        ])
        let response = try await placesSearchService.search(
            query: query,
            options: PlacesSearchOptions(
                origin: currentCoordinate,
                includedType: includedType,
                radiusMeters: Self.searchRadiusMeters,
                strictTypeFiltering: includedType != nil
            )
        )
        guard let nearest = nearestPlace(in: response.places, currentCoordinate: currentCoordinate) else {
            NearbyDebugLogger.log(.nearbyDecision, "place search had no candidate within radius", metadata: [
                "itemId": item.id.uuidString,
                "itemTitle": item.title,
                "query": query
            ])
            return nil
        }
        return NearbyStoreSuggestion(
            item: item,
            place: nearest.place,
            distanceMeters: nearest.distance,
            strategy: strategy
        )
    }

    func nearestPlace(
        in places: [PlaceDetails],
        currentCoordinate: CLLocationCoordinate2D
    ) -> (place: PlaceDetails, distance: CLLocationDistance)? {
        let current = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
        return places.compactMap { place in
            let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
            let distance = current.distance(from: location)
            guard distance <= Self.searchRadiusMeters else { return nil }
            return (place, distance)
        }
        .min(by: { $0.distance < $1.distance })
    }

    func strategyLabel(_ strategy: NearbyStoreSuggestion.SearchStrategy) -> String {
        switch strategy {
        case let .category(placeType):
            return "category:\(placeType)"
        case .text:
            return "text"
        }
    }
}
