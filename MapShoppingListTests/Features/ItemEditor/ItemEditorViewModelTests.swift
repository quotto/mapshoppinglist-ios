import XCTest
@testable import MapShoppingList

@MainActor
final class ItemEditorViewModelTests: XCTestCase {
    func testCreateItemSavesWithSelectedPlaces() async throws {
        let itemRepo = InMemoryShoppingListRepository()
        let placeRepo = InMemoryPlacesRepository()
        let linkRepo = InMemoryItemPlaceLinkRepository()
        let placeId = UUID()
        let place = Place(id: placeId, name: "スーパー", latitudeE6: 1, longitudeE6: 1, note: nil, lastUsedAt: nil, isActive: false)
        try await placeRepo.createPlace(place)

        let viewModel = ItemEditorViewModel(
            mode: .create,
            addItemUseCase: AddShoppingItemUseCase(itemRepository: itemRepo, linkRepository: linkRepo),
            updateItemUseCase: UpdateItemUseCase(itemRepository: itemRepo, linkRepository: linkRepo),
            deleteItemUseCase: DeleteShoppingItemUseCase(itemRepository: itemRepo, linkRepository: linkRepo),
            loadItemUseCase: GetShoppingItemUseCase(repository: itemRepo),
            loadPlacesUseCase: LoadAllPlacesUseCase(placesRepository: placeRepo)
        )

        await viewModel.load()
        viewModel.title = "牛乳"
        viewModel.togglePlace(place)
        let success = await viewModel.save()
        XCTAssertTrue(success)
        let items = try await itemRepo.fetchItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.placeIds, [placeId])
    }
}
