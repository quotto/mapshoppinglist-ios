import Foundation
import Combine

@MainActor
final class ItemEditorViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var note: String = ""
    @Published var selectedPlaceIds: Set<UUID> = []
    @Published var availablePlaces: [Place] = []
    @Published var isSaving: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let mode: ItemEditorMode
    private let addItemUseCase: AddShoppingItemUseCase
    private let updateItemUseCase: UpdateItemUseCase
    private let deleteItemUseCase: DeleteShoppingItemUseCase
    private let loadItemUseCase: GetShoppingItemUseCase
    private let loadPlacesUseCase: LoadAllPlacesUseCase

    private var editingItemId: UUID? {
        if case let .edit(id) = mode { return id }
        return nil
    }

    init(
        mode: ItemEditorMode,
        addItemUseCase: AddShoppingItemUseCase,
        updateItemUseCase: UpdateItemUseCase,
        deleteItemUseCase: DeleteShoppingItemUseCase,
        loadItemUseCase: GetShoppingItemUseCase,
        loadPlacesUseCase: LoadAllPlacesUseCase
    ) {
        self.mode = mode
        self.addItemUseCase = addItemUseCase
        self.updateItemUseCase = updateItemUseCase
        self.deleteItemUseCase = deleteItemUseCase
        self.loadItemUseCase = loadItemUseCase
        self.loadPlacesUseCase = loadPlacesUseCase
    }

    convenience init(mode: ItemEditorMode, environment: AppEnvironment) {
        self.init(
            mode: mode,
            addItemUseCase: environment.addItemUseCase,
            updateItemUseCase: environment.updateItemUseCase,
            deleteItemUseCase: environment.deleteItemUseCase,
            loadItemUseCase: environment.getShoppingItemUseCase,
            loadPlacesUseCase: environment.loadAllPlacesUseCase
        )
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            availablePlaces = try await loadPlacesUseCase.execute()
            if let id = editingItemId {
                let item = try await loadItemUseCase.execute(id: id)
                title = item.title
                note = item.note ?? ""
                selectedPlaceIds = item.placeIds
            } else {
                selectedPlaceIds = []
                title = ""
                note = ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func togglePlace(_ place: Place) {
        if selectedPlaceIds.contains(place.id) {
            selectedPlaceIds.remove(place.id)
        } else {
            selectedPlaceIds.insert(place.id)
        }
    }

    func handlePlaceCreated(_ place: Place) {
        if availablePlaces.contains(where: { $0.id == place.id }) == false {
            availablePlaces.append(place)
        }
        selectedPlaceIds.insert(place.id)
    }

    func removePlace(_ place: Place) {
        selectedPlaceIds.remove(place.id)
    }

    func selectedPlaces() -> [Place] {
        availablePlaces.filter { selectedPlaceIds.contains($0.id) }
    }

    func place(for id: UUID) -> Place? {
        availablePlaces.first { $0.id == id }
    }

    func save() async -> Bool {
        guard title.isEmpty == false else {
            errorMessage = "タイトルを入力してください"
            return false
        }
        isSaving = true
        errorMessage = nil
        do {
            switch mode {
            case .create:
                let now = Date()
                let item = ShoppingItem(
                    id: UUID(),
                    title: title,
                    note: note.isEmpty ? nil : note,
                    isPurchased: false,
                    createdAt: now,
                    updatedAt: now,
                    placeIds: selectedPlaceIds
                )
                try await addItemUseCase.execute(item: item, placeIds: selectedPlaceIds)
            case let .edit(id):
                let existing = try await loadItemUseCase.execute(id: id)
                var updated = existing
                updated.title = title
                updated.note = note.isEmpty ? nil : note
                updated.updatedAt = Date()
                updated.placeIds = selectedPlaceIds
                try await updateItemUseCase.execute(item: updated, updatedPlaceIds: selectedPlaceIds)
            }
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    func deleteCurrentItem() async -> Bool {
        guard case let .edit(id) = mode else { return false }
        do {
            try await deleteItemUseCase.execute(itemId: id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
