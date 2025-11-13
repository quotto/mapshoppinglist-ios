import Testing
import Foundation
@testable import MapShoppingList

@Suite("ShoppingListViewModelTests")
@MainActor
struct ShoppingListViewModelTests {
    @Test("load sorts pending and purchased")
    func loadSortsPendingAndPurchased() async throws {
        let itemRepo = InMemoryShoppingListRepository()
        let linkRepo = InMemoryItemPlaceLinkRepository()
        let now = Date()
        let itemA = ShoppingItem(id: UUID(), title: "牛乳", note: nil, isPurchased: false, createdAt: now, updatedAt: now, placeIds: [])
        let itemB = ShoppingItem(id: UUID(), title: "パン", note: nil, isPurchased: true, createdAt: now, updatedAt: now.addingTimeInterval(-60), placeIds: [])
        try await itemRepo.createItem(itemA)
        try await itemRepo.createItem(itemB)

        let viewModel = ShoppingListViewModel(
            loadItemsUseCase: LoadShoppingItemsUseCase(repository: itemRepo),
            updatePurchasedUseCase: UpdatePurchasedStateUseCase(itemRepository: itemRepo),
            deleteItemUseCase: DeleteShoppingItemUseCase(itemRepository: itemRepo, linkRepository: linkRepo)
        )

        await viewModel.load()
        #expect(viewModel.pendingItems.map(\.title) == ["牛乳"])
        #expect(viewModel.purchasedItems.map(\.title) == ["パン"])
    }

    @Test("toggle updates purchased state")
    func toggleUpdatesPurchasedState() async throws {
        let itemRepo = InMemoryShoppingListRepository()
        let linkRepo = InMemoryItemPlaceLinkRepository()
        let now = Date()
        let item = ShoppingItem(id: UUID(), title: "卵", note: nil, isPurchased: false, createdAt: now, updatedAt: now, placeIds: [])
        try await itemRepo.createItem(item)

        let viewModel = ShoppingListViewModel(
            loadItemsUseCase: LoadShoppingItemsUseCase(repository: itemRepo),
            updatePurchasedUseCase: UpdatePurchasedStateUseCase(itemRepository: itemRepo),
            deleteItemUseCase: DeleteShoppingItemUseCase(itemRepository: itemRepo, linkRepository: linkRepo)
        )

        await viewModel.load()
        let first = try #require(viewModel.pendingItems.first, "pending item not loaded")
        await viewModel.togglePurchased(item: first)
        let updated = try await itemRepo.fetchItem(id: item.id)
        #expect(updated?.isPurchased == true)
    }
}
