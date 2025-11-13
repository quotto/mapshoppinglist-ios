/// UIテスト用のアクセシビリティ識別子。
/// `MapShoppingList/Utilities/UITestIdentifiers.swift` と同一内容である点に注意。
enum UITestIdentifiers {
    enum Home {
        static let emptyState = "home.empty_state"
        static let fabAddItem = "home.fab_add_item"
        static let menuButton = "home.menu_button"
        static let itemRowPrefix = "home.item_row."
        static let checkboxPrefix = "home.checkbox."
        static let permissionLocationCard = "home.permission.location"
        static let permissionNotificationCard = "home.permission.notification"
    }

    enum ItemEditor {
        static let titleField = "item_editor.title"
        static let noteField = "item_editor.note"
        static let saveButton = "item_editor.save"
        static let recentPlacesButton = "item_editor.recent_places_button"
        static let selectedPlacePrefix = "item_editor.selected_place."
    }

    enum Menu {
        static let placeManagement = "menu.place_management"
        static let privacyPolicy = "menu.privacy_policy"
        static let ossLicenses = "menu.oss_licenses"
    }

    enum PlaceManagement {
        static let rowPrefix = "place_management.row."
        static let deleteButtonPrefix = "place_management.delete."
        static let renameTextField = "place_management.rename.textfield"
    }

    enum RecentPlaces {
        static let rowPrefix = "recent_places.row."
        static let addButton = "recent_places.add_button"
    }

    enum PermissionPrompt {
        static let locationCard = Home.permissionLocationCard
        static let notificationCard = Home.permissionNotificationCard
    }
}
