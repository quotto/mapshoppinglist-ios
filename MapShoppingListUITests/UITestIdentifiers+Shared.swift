/// UIテスト用のアクセシビリティ識別子。
/// `MapShoppingList/Utilities/UITestIdentifiers.swift` と同一内容である点に注意。
enum UITestIdentifiers {
    enum Home {
        static let emptyState = "home.empty_state"
        static let fabAddItem = "home.fab_add_item"
        static let menuButton = "home.menu_button"
        static let itemRowPrefix = "home.item_row."
        static let checkboxPrefix = "home.checkbox."
    }

    enum ItemEditor {
        static let titleField = "item_editor.title"
        static let noteField = "item_editor.note"
        static let saveButton = "item_editor.save"
    }
}
