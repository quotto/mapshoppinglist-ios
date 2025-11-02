import Foundation
import Combine

@MainActor
final class ShoppingListViewModel: ObservableObject {
    struct ItemRow: Identifiable, Equatable {
        let id: UUID
        let title: String
        let isPurchased: Bool
        let placeCount: Int
        let updatedAt: Date
    }

    @Published private(set) var pendingItems: [ItemRow] = []
    @Published private(set) var purchasedItems: [ItemRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let loadItemsUseCase: LoadShoppingItemsUseCase
    private let updatePurchasedUseCase: UpdatePurchasedStateUseCase
    private let deleteItemUseCase: DeleteShoppingItemUseCase

    init(
        loadItemsUseCase: LoadShoppingItemsUseCase,
        updatePurchasedUseCase: UpdatePurchasedStateUseCase,
        deleteItemUseCase: DeleteShoppingItemUseCase
    ) {
        self.loadItemsUseCase = loadItemsUseCase
        self.updatePurchasedUseCase = updatePurchasedUseCase
        self.deleteItemUseCase = deleteItemUseCase
    }

    convenience init(environment: AppEnvironment) {
        self.init(
            loadItemsUseCase: environment.loadShoppingItemsUseCase,
            updatePurchasedUseCase: environment.updatePurchasedUseCase,
            deleteItemUseCase: environment.deleteItemUseCase
        )
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let items = try await loadItemsUseCase.execute()
            apply(items: items)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func togglePurchased(item: ItemRow) async {
        do {
            try await updatePurchasedUseCase.execute(itemId: item.id, isPurchased: !item.isPurchased)
            await load()
            NotificationCenter.default.post(name: .geofenceNeedsSync, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(item: ItemRow) async {
        do {
            try await deleteItemUseCase.execute(itemId: item.id)
            await load()
            NotificationCenter.default.post(name: .geofenceNeedsSync, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(items: [ShoppingItem]) {
        let rows = items.map { item in
            ItemRow(
                id: item.id,
                title: item.title,
                isPurchased: item.isPurchased,
                placeCount: item.placeIds.count,
                updatedAt: item.updatedAt
            )
        }
        pendingItems = rows.filter { $0.isPurchased == false }.sorted { $0.updatedAt > $1.updatedAt }
        purchasedItems = rows.filter { $0.isPurchased }.sorted { $0.updatedAt > $1.updatedAt }
    }
}
