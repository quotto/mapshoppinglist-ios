# UIテスト計画

## 1. 方針
- SwiftUIビューおよびCoreDataStackに依存するテストはUIテストで網羅し、ユースケース単位で検証する。
- UIテストでは `UITEST_SCENARIO` / `UITEST_LOCATION_STATUS` / `UITEST_NOTIFICATION_STATUS` の環境変数を用いて状態を切り替える。
- シードデータは `UITestScenarioSeeder` で投入し、Android版 (`/Volumes/extend/mapshoppinglist/app/src/androidTest/java/com/mapshoppinglist/ui/PermissionsUiTest.kt`) のテスト観点を踏襲する。

| Screen | ユースケース | iOS UIテスト (クラス.メソッド) | Android参考 | 備考 |
| --- | --- | --- | --- | --- |
| S1 買い物リスト | 空状態の表示 | `HomeScreenUITests.testEmptyStateVisibleOnLaunch` | - | 既存テスト継続 |
| S1 買い物リスト | アイテム追加〜表示 | `HomeScreenUITests.testCanAddItemWithoutPlace` | - | CoreDataへの書き込み確認を兼ねる |
| S1 買い物リスト | バリデーション（空タイトル） | `HomeScreenUITests.testShowsValidationErrorWhenTitleEmpty` | - | | 
| S1 買い物リスト | 購入済みトグル | `HomeScreenUITests.testTogglePurchasedState` | - | | 
| S1 権限カード | 位置情報カード表示 | `HomeScreenUITests.testPermissionPromptAppearsWhenLocationNotAlways` | `PermissionsUiTest.shoppingList_showsPermissionPromptAndInvokesAction` | `UITEST_LOCATION_STATUS=when_in_use` |
| S1 メニュー | 地点管理遷移 | `MenuNavigationUITests.testHamburgerMenuOpensPlaceManagement` | - | | 
| S1 メニュー | プライバシーポリシー遷移 | `MenuNavigationUITests.testHamburgerMenuOpensPrivacyPolicy` | - | | 
| S1 メニュー | OSSライセンス遷移 | `MenuNavigationUITests.testHamburgerMenuOpensOssLicenses` | - | | 
| S6 地点管理 | 名称変更 | `PlaceManagementUITests.testRenamePlaceFromList` | - | `UITEST_SCENARIO=place_management` でシード |
| S6 地点管理 | 削除 | `PlaceManagementUITests.testDeletePlaceFromList` | - | 同上 |
| S2/S4 アイテム編集 | 最近地点の紐付け | `ItemEditorUITests.testCanAttachRecentPlaceToNewItem` | `PermissionsUiTest.placePicker_showsPermissionPlaceholderWhenDenied` (シナリオ流用) | 最近地点の複数選択挙動を確認 |

## 2. 環境変数とシナリオ
- `UITEST_SCENARIO=place_management` : 地点3件を事前投入し、S6/S4/S2で利用可能にする。
- `UITEST_SCENARIO=permission_prompt` + `UITEST_LOCATION_STATUS=when_in_use` : S1で位置情報カードを強制表示。
- `UITEST_LOCATION_STATUS` : `always` / `when_in_use` / `denied`。
- `UITEST_NOTIFICATION_STATUS` : `authorized` / `denied` （将来の通知カード検証用）。

## 3. CoreData/Viewテストの移行
- `ContentViewTests` と `CoreDataStackTests` は UIテストへ検証を移管したため `XCTSkip` 化。
- CoreDataの保存・更新は `HomeScreenUITests`・`ItemEditorUITests` で実際のユーザー操作としてカバーする。
