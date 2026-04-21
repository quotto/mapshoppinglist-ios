import CoreLocation
import Foundation
import Testing
@testable import MapShoppingList

@Suite("NearbySuggestionUseCaseTests")
struct NearbySuggestionUseCaseTests {
    @Test("ShouldSuggestNearbyStore allows first notification")
    func firstNotificationIsAllowed() {
        let useCase = ShouldSuggestNearbyStoreUseCase()
        #expect(
            useCase.execute(
                state: nil,
                currentCoordinate: CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0),
                now: Date()
            )
        )
    }

    @Test("ShouldSuggestNearbyStore blocks within one hour")
    func blocksWithinOneHour() {
        let useCase = ShouldSuggestNearbyStoreUseCase()
        let now = Date()
        let state = NearbySuggestionState(
            itemId: UUID(),
            lastNotifiedAt: now.addingTimeInterval(-30 * 60),
            lastNotifiedLatitudeE6: 35_000_000,
            lastNotifiedLongitudeE6: 139_000_000
        )

        #expect(
            useCase.execute(
                state: state,
                currentCoordinate: CLLocationCoordinate2D(latitude: 35.01, longitude: 139.01),
                now: now
            ) == false
        )
    }

    @Test("ShouldSuggestNearbyStore allows after one hour and moving 300m")
    func allowsAfterOneHourAndMovingThreeHundredMeters() {
        let useCase = ShouldSuggestNearbyStoreUseCase()
        let now = Date()
        let state = NearbySuggestionState(
            itemId: UUID(),
            lastNotifiedAt: now.addingTimeInterval(-61 * 60),
            lastNotifiedLatitudeE6: 35_000_000,
            lastNotifiedLongitudeE6: 139_000_000
        )

        #expect(
            useCase.execute(
                state: state,
                currentCoordinate: CLLocationCoordinate2D(latitude: 35.0035, longitude: 139.0),
                now: now
            )
        )
    }

    @Test("ShouldSuggestNearbyStore allows after twenty four hours")
    func allowsAfterTwentyFourHours() {
        let useCase = ShouldSuggestNearbyStoreUseCase()
        let now = Date()
        let state = NearbySuggestionState(
            itemId: UUID(),
            lastNotifiedAt: now.addingTimeInterval(-(25 * 60 * 60)),
            lastNotifiedLatitudeE6: 35_000_000,
            lastNotifiedLongitudeE6: 139_000_000
        )

        #expect(
            useCase.execute(
                state: state,
                currentCoordinate: CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0),
                now: now
            )
        )
    }

    @Test("FindNearbyStoreSuggestions prefers category search and returns nearest place")
    func prefersCategorySearchAndReturnsNearestPlace() async throws {
        let itemRepository = InMemoryShoppingListRepository()
        let stateRepository = InMemoryNearbySuggestionStateRepository()
        let placesService = StubPlacesSearchService()
        let classifier = makeClassifier(placeType: "supermarket", title: "牛乳")
        try await itemRepository.createItem(makeItem(title: "牛乳"))
        placesService.nearbySearchResult = .success(
            makeSearchResponse(
                places: [
                    makePlaceDetails(id: "far", name: "少し遠いスーパー", latitude: 35.0030),
                    makePlaceDetails(id: "near", name: "近いスーパー", latitude: 35.0010)
                ]
            )
        )

        let useCase = makeUseCase(
            itemRepository: itemRepository,
            stateRepository: stateRepository,
            placesService: placesService,
            classifier: classifier
        )
        let suggestions = try await execute(useCase: useCase)
        let firstPlaceId = suggestions.first?.place.id
        let isCategoryStrategy = {
            guard case .category(placeType: "supermarket") = suggestions.first?.strategy else { return false }
            return true
        }()
        let receivedIncludedTypes = placesService.receivedNearbyOptions.map { $0.includedType }
        let receivedStrictTypeFiltering = placesService.receivedNearbyOptions.map { $0.strictTypeFiltering }

        #expect(suggestions.count == 1)
        #expect(firstPlaceId == "near")
        #expect(isCategoryStrategy)
        #expect(placesService.receivedQueries.isEmpty)
        #expect(placesService.receivedNearbyTypes == ["supermarket"])
        #expect(receivedIncludedTypes == ["supermarket"])
        #expect(receivedStrictTypeFiltering == [true])
    }

    @Test("FindNearbyStoreSuggestions falls back to text search when category is too broad")
    func fallsBackToTextSearchWhenCategoryIsTooBroad() async throws {
        let itemRepository = InMemoryShoppingListRepository()
        let stateRepository = InMemoryNearbySuggestionStateRepository()
        let placesService = StubPlacesSearchService()
        let classifier = makeClassifier(placeType: "store", title: "電池")
        try await itemRepository.createItem(makeItem(title: "電池"))
        placesService.searchResult = .success(
            makeSearchResponse(
                places: [makePlaceDetails(id: "text-result", name: "ドラッグストア", latitude: 35.0008)]
            )
        )

        let useCase = makeUseCase(
            itemRepository: itemRepository,
            stateRepository: stateRepository,
            placesService: placesService,
            classifier: classifier
        )
        let suggestions = try await execute(useCase: useCase)
        let isTextStrategy = {
            guard case .text = suggestions.first?.strategy else { return false }
            return true
        }()
        let receivedIncludedTypes = placesService.receivedOptions.map { $0.includedType }
        let receivedStrictTypeFiltering = placesService.receivedOptions.map { $0.strictTypeFiltering }

        #expect(suggestions.count == 1)
        #expect(isTextStrategy)
        #expect(receivedIncludedTypes == [nil])
        #expect(receivedStrictTypeFiltering == [false])
        #expect(placesService.receivedNearbyTypes.isEmpty)
    }

    @Test("FindNearbyStoreSuggestions does not fall back to text search when category search has no results")
    func categorySearchWithoutResultsDoesNotFallBackToTextSearch() async throws {
        let itemRepository = InMemoryShoppingListRepository()
        let stateRepository = InMemoryNearbySuggestionStateRepository()
        let placesService = StubPlacesSearchService()
        let classifier = makeClassifier(placeType: "supermarket", title: "牛乳")
        try await itemRepository.createItem(makeItem(title: "牛乳"))
        placesService.nearbySearchResult = .success(makeSearchResponse(places: []))
        placesService.searchResult = .success(
            makeSearchResponse(
                places: [makePlaceDetails(id: "text-result", name: "テキスト検索結果", latitude: 35.0008)]
            )
        )

        let useCase = makeUseCase(
            itemRepository: itemRepository,
            stateRepository: stateRepository,
            placesService: placesService,
            classifier: classifier
        )
        let suggestions = try await execute(useCase: useCase)

        #expect(suggestions.isEmpty)
        #expect(placesService.receivedNearbyTypes == ["supermarket"])
        #expect(placesService.receivedQueries.isEmpty)
    }
}

private extension NearbySuggestionUseCaseTests {
    func execute(useCase: FindNearbyStoreSuggestionsUseCase) async throws -> [NearbyStoreSuggestion] {
        try await useCase.execute(
            currentCoordinate: CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0),
            now: Date()
        )
    }

    func makeUseCase(
        itemRepository: InMemoryShoppingListRepository,
        stateRepository: InMemoryNearbySuggestionStateRepository,
        placesService: StubPlacesSearchService,
        classifier: StubItemCategoryClassifier
    ) -> FindNearbyStoreSuggestionsUseCase {
        FindNearbyStoreSuggestionsUseCase(
            loadShoppingItemsUseCase: LoadShoppingItemsUseCase(repository: itemRepository),
            nearbySuggestionStateRepository: stateRepository,
            shouldSuggestNearbyStoreUseCase: ShouldSuggestNearbyStoreUseCase(),
            placesSearchService: placesService,
            itemCategoryClassifier: classifier
        )
    }

    func makeClassifier(placeType: String, title: String) -> StubItemCategoryClassifier {
        StubItemCategoryClassifier(
            result: .success(
                ItemCategoryClassification(
                    normalizedItemName: title,
                    categories: [ItemPlaceCategory(placeType: placeType, confidence: 0.9, reason: nil)],
                    cacheHit: false,
                    modelVersion: nil,
                    generatedAt: nil
                )
            )
        )
    }

    func makeItem(title: String) -> ShoppingItem {
        ShoppingItem(
            id: UUID(),
            title: title,
            note: nil,
            isPurchased: false,
            createdAt: Date(),
            updatedAt: Date(),
            placeIds: []
        )
    }

    func makeSearchResponse(places: [PlaceDetails]) -> PlacesSearchResponse {
        PlacesSearchResponse(
            session: PlacesSearchSession(identifier: NSObject()),
            places: places
        )
    }

    func makePlaceDetails(id: String, name: String, latitude: Double) -> PlaceDetails {
        PlaceDetails(
            id: id,
            name: name,
            latitude: latitude,
            longitude: 139.0,
            formattedAddress: nil
        )
    }
}
