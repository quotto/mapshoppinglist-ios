import XCTest

final class MapShoppingListUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func assertExists(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let exists = element.waitForExistence(timeout: timeout)
        if exists == false {
            let screenshot = XCUIScreen.main.screenshot()
            let screenshotAttachment = XCTAttachment(screenshot: screenshot)
            screenshotAttachment.name = "Screenshot-\(UUID().uuidString)"
            screenshotAttachment.lifetime = .keepAlways
            add(screenshotAttachment)

            let treeAttachment = XCTAttachment(string: app.debugDescription)
            treeAttachment.name = "ViewTree-\(UUID().uuidString)"
            treeAttachment.lifetime = .keepAlways
            add(treeAttachment)
        }
        XCTAssertTrue(exists, file: file, line: line)
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
        assertExists(addButton, in: app)
        addButton.tap()

        let titleField = app.textFields[UITestIdentifiers.ItemEditor.titleField]
        assertExists(titleField, in: app)
        titleField.tap()
        titleField.typeText(title)

        let saveButton = app.buttons[UITestIdentifiers.ItemEditor.saveButton]
        assertExists(saveButton, in: app)
        saveButton.tap()
    }

    func testEmptyStateVisibleOnLaunch() {
        let app = launchApp()
        assertExists(app.otherElements[UITestIdentifiers.Home.emptyState], in: app)
    }

    func testCanAddItemWithoutPlace() {
        let app = launchApp()
        let title = "りんご"
        addItem(app: app, title: title)

        assertExists(app.otherElements[UITestIdentifiers.Home.itemRowPrefix + title], in: app)
    }

    func testShowsValidationErrorWhenTitleEmpty() {
        let app = launchApp()
        app.buttons[UITestIdentifiers.Home.fabAddItem].tap()

        let saveButton = app.buttons[UITestIdentifiers.ItemEditor.saveButton]
        assertExists(saveButton, in: app)
        saveButton.tap()

        assertExists(app.staticTexts["タイトルを入力してください"], in: app)
    }

    func testTogglePurchasedState() {
        let app = launchApp()
        let title = "牛乳"
        addItem(app: app, title: title)

        let checkbox = app.buttons[UITestIdentifiers.Home.checkboxPrefix + title]
        assertExists(checkbox, in: app)
        checkbox.tap()

        assertExists(app.staticTexts["購入済み"], in: app)
    }

    func testHamburgerMenuOpensPrivacyPolicy() {
        let app = launchApp()
        let menuButton = app.buttons[UITestIdentifiers.Home.menuButton]
        assertExists(menuButton, in: app)
        menuButton.tap()

        let privacyButton = app.buttons["プライバシーポリシー"]
        assertExists(privacyButton, in: app)
        privacyButton.tap()

        let privacyNavigationBar = app.navigationBars["プライバシーポリシー"]
        assertExists(privacyNavigationBar, in: app)
    }
}
