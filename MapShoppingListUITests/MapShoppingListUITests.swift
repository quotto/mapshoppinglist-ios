import XCTest

class BaseUITestCase: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @discardableResult
    func launchApp(
        scenario: String? = nil,
        locationStatus: String? = nil,
        notificationStatus: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        if app.launchArguments.contains("UITests") == false {
            app.launchArguments.append("UITests")
        }
        if let scenario {
            app.launchEnvironment[UITestEnvironmentKeys.scenario] = scenario
        }
        if let locationStatus {
            app.launchEnvironment[UITestEnvironmentKeys.locationStatus] = locationStatus
        }
        if let notificationStatus {
            app.launchEnvironment[UITestEnvironmentKeys.notificationStatus] = notificationStatus
        }
        app.launch()
        return app
    }

    func assertExists(
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

    func addItem(app: XCUIApplication, title: String) {
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

    func openMenu(app: XCUIApplication) {
        let menuButton = app.buttons[UITestIdentifiers.Home.menuButton]
        assertExists(menuButton, in: app)
        menuButton.tap()
    }
}

final class HomeScreenUITests: BaseUITestCase {
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

    func testPermissionPromptAppearsWhenLocationNotAlways() {
        let app = launchApp(
            scenario: UITestScenariosShared.permissionPrompt,
            locationStatus: UITestLocationStatusValue.whenInUse
        )
        let locationCardTitle = app.staticTexts["位置情報の許可設定"]
        assertExists(locationCardTitle, in: app)
    }
}

final class MenuNavigationUITests: BaseUITestCase {
    func testHamburgerMenuOpensPlaceManagement() {
        let app = launchApp(scenario: UITestScenariosShared.placeManagementSeed)
        openMenu(app: app)

        let placeButton = app.buttons[UITestIdentifiers.Menu.placeManagement]
        assertExists(placeButton, in: app)
        placeButton.tap()

        let navBar = app.navigationBars["地点管理"]
        assertExists(navBar, in: app)
    }

    func testHamburgerMenuOpensPrivacyPolicy() {
        let app = launchApp()
        openMenu(app: app)

        let privacyButton = app.buttons[UITestIdentifiers.Menu.privacyPolicy]
        assertExists(privacyButton, in: app)
        privacyButton.tap()

        let privacyNavigationBar = app.navigationBars["プライバシーポリシー"]
        assertExists(privacyNavigationBar, in: app)
    }

    func testHamburgerMenuOpensOssLicenses() {
        let app = launchApp()
        openMenu(app: app)

        let ossButton = app.buttons[UITestIdentifiers.Menu.ossLicenses]
        assertExists(ossButton, in: app)
        ossButton.tap()

        let ossNavigationBar = app.navigationBars["OSSライセンス"]
        assertExists(ossNavigationBar, in: app)
    }
}

final class PlaceManagementUITests: BaseUITestCase {
    func testRenamePlaceFromList() {
        let app = launchApp(scenario: UITestScenariosShared.placeManagementSeed)
        openMenu(app: app)
        app.buttons[UITestIdentifiers.Menu.placeManagement].tap()
        let targetCell = app.cells.element(boundBy: 1)
        assertExists(targetCell, in: app)
        targetCell.tap()

        let renameField = app.textFields[UITestIdentifiers.PlaceManagement.renameTextField]
        assertExists(renameField, in: app)
        renameField.tap()
        renameField.typeText(" リニューアル")

        let saveButton = app.navigationBars["名称変更"].buttons["保存"]
        assertExists(saveButton, in: app)
        saveButton.tap()

        let reopenCell = app.cells.element(boundBy: 1)
        assertExists(reopenCell, in: app)
        reopenCell.tap()

        let reopenedRenameField = app.textFields[UITestIdentifiers.PlaceManagement.renameTextField]
        assertExists(reopenedRenameField, in: app)
        let currentValue = reopenedRenameField.value as? String
        XCTExpectFailure("S6の名称変更結果がUIに反映されない既知の問題") {
            XCTAssertEqual(currentValue, "テストスーパーA リニューアル")
        }

        app.buttons["キャンセル"].tap()
    }

    func testDeletePlaceFromList() {
        let app = launchApp(scenario: UITestScenariosShared.placeManagementSeed)
        openMenu(app: app)
        app.buttons[UITestIdentifiers.Menu.placeManagement].tap()

        let deleteButton = app.buttons["ドラッグBを削除"]
        assertExists(deleteButton, in: app)
        deleteButton.tap()

        let deleteConfirm = app.alerts["削除確認"].buttons["削除"]
        assertExists(deleteConfirm, in: app)
        deleteConfirm.tap()

        XCTAssertFalse(app.staticTexts["ドラッグB"].waitForExistence(timeout: 2))
    }
}

final class ItemEditorUITests: BaseUITestCase {
    func testCanAttachRecentPlaceToNewItem() {
        let app = launchApp(scenario: UITestScenariosShared.placeManagementSeed)
        let title = "タオル"
        addItem(app: app, title: title)
        // item added once; reopen to attach place
        let cell = app.otherElements[UITestIdentifiers.Home.itemRowPrefix + title]
        assertExists(cell, in: app)
        cell.tap()

        let recentButton = app.buttons[UITestIdentifiers.ItemEditor.recentPlacesButton]
        assertExists(recentButton, in: app)
        recentButton.tap()

        let placeOption = app.staticTexts["テストスーパーA"].firstMatch
        assertExists(placeOption, in: app)
        placeOption.tap()

        let addButton = app.buttons[UITestIdentifiers.RecentPlaces.addButton]
        assertExists(addButton, in: app)
        addButton.tap()

        let selectedPlaceLabel = app.staticTexts["テストスーパーA"].firstMatch
        assertExists(selectedPlaceLabel, in: app)

        let saveButton = app.buttons[UITestIdentifiers.ItemEditor.saveButton]
        assertExists(saveButton, in: app)
        saveButton.tap()

        let placeCountLabel = app.staticTexts["紐付くお店: 1件"]
        assertExists(placeCountLabel, in: app)
    }
}
