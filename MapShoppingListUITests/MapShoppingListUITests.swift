import XCTest
@testable import MapShoppingList

final class MapShoppingListUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        if app.launchArguments.contains("UITests") == false {
            app.launchArguments.append("UITests")
        }
        app.launch()
        return app
    }

    private func addItem(app: XCUIApplication, title: String) {
        let addButton = app.buttons[UITestIdentifiers.Home.fabAddItem]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        let titleField = app.textFields[UITestIdentifiers.ItemEditor.titleField]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText(title)

        app.buttons[UITestIdentifiers.ItemEditor.saveButton].tap()
    }

    func testEmptyStateVisibleOnLaunch() {
        let app = launchApp()
        XCTAssertTrue(app.otherElements[UITestIdentifiers.Home.emptyState].waitForExistence(timeout: 3))
    }

    func testCanAddItemWithoutPlace() {
        let app = launchApp()
        let title = "りんご"
        addItem(app: app, title: title)

        XCTAssertTrue(app.otherElements[UITestIdentifiers.Home.itemRowPrefix + title].waitForExistence(timeout: 3))
    }

    func testShowsValidationErrorWhenTitleEmpty() {
        let app = launchApp()
        let addButton = app.buttons[UITestIdentifiers.Home.fabAddItem]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        app.buttons[UITestIdentifiers.ItemEditor.saveButton].tap()

        XCTAssertTrue(app.staticTexts["タイトルを入力してください"].waitForExistence(timeout: 3))
    }

    func testTogglePurchasedState() {
        let app = launchApp()
        let title = "牛乳"
        addItem(app: app, title: title)

        let checkbox = app.buttons[UITestIdentifiers.Home.checkboxPrefix + title]
        XCTAssertTrue(checkbox.waitForExistence(timeout: 3))
        checkbox.tap()

        XCTAssertTrue(app.staticTexts["購入済み"].waitForExistence(timeout: 3))
    }

    func testHamburgerMenuOpensPrivacyPolicy() {
        let app = launchApp()
        let menuButton = app.buttons[UITestIdentifiers.Home.menuButton]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 3))
        menuButton.tap()

        let privacyButton = app.buttons["プライバシーポリシー"]
        XCTAssertTrue(privacyButton.waitForExistence(timeout: 3))
        privacyButton.tap()

        let privacyNavigationBar = app.navigationBars["プライバシーポリシー"]
        XCTAssertTrue(privacyNavigationBar.waitForExistence(timeout: 3))
    }
}
