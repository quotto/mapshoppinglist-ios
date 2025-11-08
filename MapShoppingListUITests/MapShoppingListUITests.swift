import XCTest

final class MapShoppingListUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFloatingActionButtonOpensEditor() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITests")
        app.launch()

        let addButton = app.buttons["アイテムを追加"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        let editorNavigationBar = app.navigationBars["アイテム追加"]
        XCTAssertTrue(editorNavigationBar.waitForExistence(timeout: 3))

        app.buttons["キャンセル"].tap()
    }

    func testHamburgerMenuOpensPrivacyPolicy() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITests")
        app.launch()

        let menuButton = app.buttons["メニュー"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 3))
        menuButton.tap()

        let privacyButton = app.buttons["プライバシーポリシー"]
        XCTAssertTrue(privacyButton.waitForExistence(timeout: 3))
        privacyButton.tap()

        let privacyNavigationBar = app.navigationBars["プライバシーポリシー"]
        XCTAssertTrue(privacyNavigationBar.waitForExistence(timeout: 3))
    }
}
