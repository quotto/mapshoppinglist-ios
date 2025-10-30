import XCTest
@testable import MapShoppingList

@MainActor
final class ShoppingListViewModelTests: XCTestCase {
    func testLoadSortsPendingAndPurchased() async throws {
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
        XCTAssertEqual(viewModel.pendingItems.map { $0.title }, ["牛乳"])
        XCTAssertEqual(viewModel.purchasedItems.map { $0.title }, ["パン"])
    }

    func testToggleUpdatesPurchasedState() async throws {
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
        guard let first = viewModel.pendingItems.first else {
            return XCTFail("アイテムが読み込まれていません")
        }
        await viewModel.togglePurchased(item: first)
        let updated = try await itemRepo.fetchItem(id: item.id)
        XCTAssertEqual(updated?.isPurchased, true)
    }
}
