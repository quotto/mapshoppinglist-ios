# CI/CD セットアップメモ

このプロジェクトでは GitHub Actions と Xcode Cloud を併用します。GUI 操作が前提となる設定項目もあるため、コードで管理できる部分とそうでない部分を切り分けておきます。

## 1. GitHub Actions（コード化済み）
- ワークフロー: `.github/workflows/ios-ci.yml`
- 実行内容: `Scripts/run-tests.sh` を呼び出し、MapShoppingList スキームの **ユニットテスト + UIテスト** を iPhone 15 Pro Max (iOS 17.5) で実行。
- 環境変数: `GOOGLE_MAPS_API_KEY` はダミー値を設定済み。実キーは GitHub Secrets から上書きする。
- 追加で必要になった場合は、`Scripts/run-tests.sh` を編集することでテスト対象やデバイスを一元管理できる。

## 2. Xcode Cloud（GUI での設定が必要）
Xcode Cloud のパイプラインは App Store Connect での GUI 設定が必須。以下の手順で手動設定を行い、必要に応じて補助スクリプトをリポジトリに配置する。

1. **App Store Connect → Xcode Cloud** で新しいワークフローを作成し、リポジトリ `MapShoppingList` を連携する。
2. ワークフロー設定
   - ビルドトリガー: `main` への push / PR を登録。
   - Scheme: `MapShoppingList` を選択（UI Test ターゲットを含む）。
   - デバイス: iPhone 15 Pro Max (iOS 17.5) など GitHub Actions と揃えたシミュレーターを指定。
3. 環境変数 / Secrets
   - `GOOGLE_MAPS_API_KEY` を **Environment Secret** に登録。
   - 必要に応じてテスト用の Launch Argument（`UITests`）は `xcodebuild` 側で自動付与されるため追加不要。
4. 追加処理が必要な場合は `ci_scripts/ci_post_clone.sh` などをこのリポジトリに追加すると Xcode Cloud から呼び出せる（現状は不要）。

> **補足:** Xcode Cloud 側の設定は GUI でしか保存できないため、本リポジトリでは手順書の形で管理しています。Secrets やビルドトリガーの変更は上記手順を参照して行ってください。
