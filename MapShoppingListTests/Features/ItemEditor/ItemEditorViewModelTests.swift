import Testing
import Foundation
@testable import MapShoppingList

@Suite("ItemEditorViewModelTests")
@MainActor
struct ItemEditorViewModelTests {
    @Test("create item saves selected places")
    func createItemSavesWithSelectedPlaces() async throws {
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
        #expect(success)
        let items = try await itemRepo.fetchItems()
        #expect(items.count == 1)
        #expect(items.first?.placeIds == [placeId])
    }
}
