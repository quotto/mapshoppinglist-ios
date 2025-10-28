# 買い忘れ防止リスト（Android）基本設計書（MVP / v1.2）

最終更新: 2025-09-27（Asia/Tokyo）

---

## 1. 目的・スコープ

- **目的**: 位置情報（ジオフェンス）を用いて、ユーザーが指定した「お店（地点）」の近くに来たとき、そのお店で買える未購入アイテムを通知し、買い忘れを防止する。
- **対象プラットフォーム**: Android（MVP）。iOSは将来対応（本書では設計上の考慮のみ）。
- **本MVPでの前提/制約**
    - **アイテム数に上限なし**。
    - **紐づけ可能なお店（地点）は最大100種類**（緯度経度単位、アプリ全体で合計）。  
      ※AndroidのGeofencing APIの登録上限に合わせる。
    - ジオフェンス半径は固定 **100m**。
    - **アプリ未起動時・端末再起動後も通知**されること。
- **スコープ外（将来検討）**: iOS対応、ユーザー管理/同期、Web版、端末変更時のクラウド永続化/共有、営業時間連動、高度な学習等。

---

## 2. 全体アーキテクチャ（MVP）

- **言語/主要技術**: Kotlin、Jetpack（Compose推奨/RecyclerViewでも可）、Room、WorkManager、Google Play services Location（Geofencing API）、Maps/Places（検索&地図ピッカー）
- **アーキテクチャ**: MVVM + UseCase + Repository（Clean Architecture寄り）
    - Presentation: View/Compose + ViewModel（StateFlow/SharedFlow）
    - Domain: UseCase（アプリケーションルール、上限/重複制御、通知文構築）
    - Data: Repository（Room + Geofence登録/解除 + Map/Places検索）
- **主なコンポーネント**
    - **GeofenceRegistrar**（Repository配下）: Places⇄GeofencingClient の橋渡し
    - **GeofenceReceiver**（BroadcastReceiver）: 近接イベント受信→通知生成
    - **BootCompletedReceiver**: 端末再起動時にジオフェンス再登録を起動
    - **ReconcileGeofenceWorker**（WorkManager）: 再登録/整合性の定期・遅延実行
    - **NotificationManagerFacade**: 通知チャンネル/グルーピング/アクション

---

## 3. 画面定義

### 3.1 画面一覧

| 画面ID | 画面名 | 目的 | 主な要素 |
|---|---|---|---|
| S1 | 買い物リスト一覧 | 未購入/購入済みの一覧と操作 | 検索/フィルタ、アイテム行（タイトル・紐づくお店数・未購入バッジ）、追加FAB |
| S2 | アイテム編集 | アイテムの追加/変更/削除 | タイトル（常時編集可）、メモ、紐づくお店リスト、[お店を追加]ボタン |
| S3 | お店検索&選択 | 地図/検索で地点を登録 | 検索バー（チェーン名等）、候補リスト、地図（ピン&半径100m表示）、[この地点を追加] |
| S4 | 最近使ったお店 | クイック選択 | 最近追加/更新の地点のリスト（距離順/更新日順切替） |
| S5 | 通知一覧（任意） | 過去通知の確認（MVPは省略可） | 通知履歴/クールダウン状態表示 |
| S6 | 地点管理 | 登録済み地点の名称編集・削除 | 地点リスト（名称/状態/座標）、編集ダイアログ、削除確認ダイアログ |
| S7 | プライバシーポリシー | データの取得・利用目的を明示 | プライバシーポリシー本文（固定テキスト） |
| S8 | OSSライセンス | 利用ライブラリのライセンス確認 | ライセンス説明文、OSS Licenses 標準画面起動ボタン |

※ S4はS2内のモーダル/シートとして表示しても良い。

### 3.2 主要UI振る舞い

- **S1（一覧）**
    - アプリ起動時は**S1**が表示される。
    - デフォルトは**未購入タブ**。購入済みは折りたたみ/別タブ。
    - 行スワイプ: 右→購入済みにする、左→削除（確認ダイアログ）。
    - FAB: S2へ遷移（新規）。
    - 新規追加ダイアログでは、冒頭に **「検索・地図で探す」「最近使ったお店から選ぶ」** の2アクションを提示し、必要に応じて地点を追加できる。紐づけ予定のお店はリスト表示し、削除が可能。
    - トップバー右上メニューから **地点管理（S6）／プライバシーポリシー（S7）／OSSライセンス（S8）** に遷移できる。
- **S2（編集）**
    - お店リスト（紐づき）: 削除/並べ替え。
    - [お店を追加] → S3（検索&地図） or S4（最近）を選択できるアクション。
    - 画面初期表示時からタイトル・メモは編集可能で、戻る操作時に自動保存（空タイトルの場合は保存せず従前の値を保持）。
    - 保存時に **上限100地点を超える場合はバリデーションでブロック**。
- **S3（検索&地図）**
    - 検索候補（Places API等）タップで地図にピン。
    - 地図を長押しして任意地点にピンを立てることも可能（逆ジオコーディングで名称候補を取得し、ユーザーが編集可能）。
    - マップ上の POI（Point of Interest）をシングルタップすると、その地点の名称を自動入力して選択状態にする。
    - 地図初期表示は端末の現在地（位置情報未取得時はデフォルト: 東京駅付近）。
    - 半径は固定表示（100m）。[この地点を追加]で登録。
- **通知（システムUI）**
    - 同一お店に紐づく未購入アイテムが複数ある場合、**InboxStyleで複数行**表示。
    - アクション: **「購入済みにする」**, **「削除」**, **「詳細」**（詳細で該当アイテムのS2を開く）。

### 3.3 画面遷移（設計書内に記載）

#### 3.3.1 遷移一覧（テキスト）
- **アプリ起動** → **S1**（買い物リスト一覧）
- **S1 → S2**: FAB［+］押下、またはアイテム行タップ（編集）
- **S2 → S3**: ［お店を追加］→［検索&地図で探す］
- **S2 → S4**: ［お店を追加］→［最近使ったお店から選ぶ］
- **S3 → S2**: ［この地点を追加］でS2に戻り、紐づきリストへ反映
- **S4 → S2**: 任意の地点を選択するとS2に戻り、紐づきリストへ反映
- **S1 → S6**: トップバーのメニュー［地点を管理］
- **S6 → S1**: トップバーの戻る操作
- **S1 → S7**: トップバーのメニュー［プライバシーポリシー］
- **S1 → S8**: トップバーのメニュー［オープンソースライセンス］
- **S7/S8 → S1**: トップバーの戻る操作
- **S2 → S1**: 戻る操作時に現在の入力内容を保存（タイトル空の場合は更新せずに遷移）
- **通知（開く） → S1**: 既定はS1へ遷移し、対象お店に紐づく未購入アイテムを強調表示（フィルタ適用可）  
  将来: 深いリンクで**対象アイテムのS2**へ直接遷移するオプションも検討
- **戻るキー**: S3/S4→S2、S2→S1、S1→アプリ終了

#### 3.3.2 画面遷移図（Mermaid）
> Mermaid対応ビューアで表示してください。

```mermaid
flowchart LR
    Start[アプリ起動/通知(開く)] --> S1[S1: 買い物リスト一覧]
    S1 -- FAB/行タップ --> S2[S2: アイテム編集]
    S2 -- お店を追加→検索 --> S3[S3: お店検索&地図]
    S2 -- お店を追加→最近 --> S4[S4: 最近使ったお店]
    S3 -- この地点を追加 --> S2
    S4 -- 地点選択 --> S2
    S2 -- 保存/戻る --> S1
```
> ※ Mermaid未対応環境のための**テキスト版**は 3.3.1 を参照。

---

### 3.4 ビジュアルガイドライン（MVP）

- **ブランドパレット**  
  - プライマリ: #1B70A0（ヘッダー/主要ボタン）  
  - バリエーション: #1B7CB0（グラデーション上部）、#1B6491（カード強調）  
  - アクセント: #EA5F52（主要アクション/FAB）、ホワイトハイライト: #F6F4F3  
  - ベース背景: #F6FAFD（ライトテーマ） / #0F1C2B（ダークテーマ）
- **タイポグラフィ**: DM Sans（Regular/Medium/SemiBold/Bold）を基本フォントとし、本文16sp、セクションタイトル18sp、画面タイトル22spを基準とする。
- **トップバー**: 深い青 (#1B70A0) の塗り潰し＋白字を既定とし、ナビゲーションアイコンは白塗りで揃える。
- **FAB/主要ボタン**: アクセントレッド (#EA5F52) を背景に使用し、丸みを帯びた形状（24dp）とElevation 6dpを付与する。
- **カード/リスト**: 角丸16dp、表面色は #F6FAFD（未完了）/ #E2F1FA（完了）を基準にし、左側アクセントやバッジで状態を示す。
- **権限・空状態**: ブランドカラーを使ったピクトグラムとカード型案内で統一し、テキストのみにならないようにする。

---

## 4. 機能仕様

### 4.1 買い物リスト一覧（S1）

- **表示**: 未購入アイテム（作成日時降順/任意で並び替え）、購入済みは別表示。
- **操作**
    - 追加（FAB） / 編集（タップ） / 削除（スワイプ or メニュー）
    - ステータス変更（チェックボックス or クイックアクション）
- **副作用**
    - ステータス変更・削除に応じて、**紐づくお店のアクティブ状態**を再評価 → ジオフェンス再登録。

### 4.2 アイテム編集（追加・削除・変更）（S2）

- **入力項目**
    - タイトル（必須）、メモ（任意）、ステータス（初期は未購入）
    - 紐づくお店（0..N）※0可
- **バリデーション**
    - タイトル必須
    - 追加時点で**アプリ全体の一意な地点数 ≤ 100**を保証
        - 一意性判定: 緯度/経度を**小数第6位で丸め**た値で重複判定（~0.11m）
- **削除**
    - アイテム削除時、**当該アイテムのみが参照するお店**に対しては**ジオフェンス解除**（ただし他アイテムが参照していれば保持）
- **保存時の副作用**
    - 紐づき/ステータスに応じて**アクティブなお店集合**を再計算 → ジオフェンスを**差分更新**

### 4.3 地点検索・選択（S3/S4）

- **検索**
    - Places API（または代替）でテキスト検索。候補→地図にピン。
    - 直接地図長押しでピンも可（名称はユーザー入力/逆ジオコーディングで初期化）。
- **登録**
    - 緯度/経度（正規化済み）、名称、メモ（任意）
    - **最近使ったお店**: last_used_at を更新。S4では上位10件程度を即参照。
    - **制約**
        - 追加前に**100上限の見込みチェック**（重複なら上限カウントしない）
    - ピンの決定方法
        1. プレイス検索結果を選択
        2. 地図を長押し（逆ジオコーディング、名称未取得の場合はユーザー入力）

### 4.4 通知機能

- **トリガー**: Geofencing API の **ENTER**
- **条件**:
    - そのお店に紐づく**未購入アイテムが1件以上**あること
    - **クールダウン中でない**こと（MVP既定: 同一点で**2時間**再通知しない）
- **内容**:
    - タイトル: 「近くに **{お店名}**」
    - 本文: `買えるもの: A, B, C…（最大N行; 以降は「ほかX件」）`
    - アクション:
    - 「購入済みにする」→ 対象お店紐づきの**未購入全件**を購入済みに更新
    - 「削除」→ 対象アイテムを削除
    - 「詳細」→ アプリ起動（該当アイテムのS2へディープリンク）
- **再起動時**:
    - **BootCompletedReceiver**がWorkを起動→DBを読み、**有効なお店**に対して**再登録**
- **チャンネル**:
    - `shopping_reminders`（重要度: Default/High検討）
- **重複抑制**:
    - 同一お店に対し、**連続ENTER検知を間引き**（固定5分）

### 4.5 地点管理（S6）

- **表示**: `is_active DESC`, `last_used_at DESC` の順でソートした地点の一覧を示す。名称・座標・アクティブ状態バッジを表示する。
- **名称編集**: ダイアログで入力。空または空白のみの場合は保存不可。保存成功時は `places.name` を更新し、`last_used_at` も現在時刻に更新する。
- **削除**: 確認ダイアログから実行。`places` レコード削除時に `item_place`・`notify_state` は外部キーで連鎖削除。削除後は `DeletePlaceUseCase` によりジオフェンス差分同期を即時スケジュールする。
- **エラーハンドリング**: 失敗時はダイアログを閉じずに再入力を促し、Snackbar で結果を通知する。

### 4.6 プライバシーポリシー（S7）

- **内容**: 位置情報の取得目的・保存方式・第三者提供なし・問い合わせ先・変更手順を静的テキストで掲載する。
- **更新日表示**: 画面上部に「最終更新日: 2025年10月4日」を表示し、将来の改定に備えて文言をリソース化する。
- **遷移**: S1 のメニューから遷移し、トップバーの戻る操作で復帰するのみ。

### 4.7 オープンソースライセンス（S8）

- **ライブラリ**: AboutLibraries（`com.mikepenz:aboutlibraries-*`）を利用し、依存関係から自動生成されたライセンス一覧を表示する。
- **UI**: Compose Material3 の `LibrariesContainer` を用いた一覧画面。トップバーのみアプリ側で提供し、一覧は AboutLibraries が生成したデータをそのまま表示する。
- **遷移**: S1 のメニューから遷移し、トップバーの戻る操作で復帰する。

---

## 5. 非機能要件（抜粋）

- **対応OS**: minSdk 29+, targetSdk 最新
- **電池**: バックグラウンドポーリング禁止。Geofence + WorkManagerのみ。
- **パフォーマンス**: 一覧1000件規模で快適表示（Room + Paging推奨は任意）
- **信頼性**: 再起動時/アプリ更新時の**ジオフェンス自動再登録**を保証
- **プライバシー**: 位置情報は**端末内DBのみ**（MVP）。外部送信なし。

---

## 6. 権限とポリシー

- **必須権限**
    - `ACCESS_FINE_LOCATION`（前景）
    - `ACCESS_BACKGROUND_LOCATION`（バックグラウンド; Android 10+）
    - `RECEIVE_BOOT_COMPLETED`（再起動時再登録）
    - `POST_NOTIFICATIONS`（Android 13+）
- **取得タイミング**
    - PlacePicker 起動前に `ACCESS_FINE_LOCATION` をリクエスト。未許可の場合は現在地取得をスキップし東京都内の既定座標へフォールバック。
    - 背景位置 (`ACCESS_BACKGROUND_LOCATION`) はジオフェンス通知を有効化したいタイミングで追加説明→設定画面へ誘導。
    - `POST_NOTIFICATIONS` は初回通知送信前に説明を挟んだうえでリクエスト。
- **Play審査注記**
    - 背景位置は**中核機能**に必須である旨を、オンボーディング画面/ヘルプで明示

---

## 7. データベース設計（Room / SQLite）

### 7.1 エンティティ

**items**
- `id` INTEGER PK
- `title` TEXT NOT NULL
- `note` TEXT NULL
- `is_purchased` INTEGER NOT NULL (0/1)
- `created_at` INTEGER (epoch ms)
- `updated_at` INTEGER (epoch ms)

**places**
- `id` INTEGER PK
- `name` TEXT NOT NULL
- `lat_e6` INTEGER NOT NULL
- `lng_e6` INTEGER NOT NULL
- `note` TEXT NULL
- `last_used_at` INTEGER NULL
- `is_active` INTEGER NOT NULL DEFAULT 0
- **UNIQUE(`lat_e6`,`lng_e6`)**

**item_place**（多対多）
- `item_id` INTEGER NOT NULL FK→items(id) ON DELETE CASCADE
- `place_id` INTEGER NOT NULL FK→places(id) ON DELETE CASCADE
- **PK(`item_id`,`place_id`)**

**notify_state**（通知制御）
- `place_id` INTEGER PK FK→places(id) ON DELETE CASCADE
- `last_notified_at` INTEGER NULL
- `snooze_until` INTEGER NULL（現在は未使用・常にNULL）

**app_settings**（将来拡張）
- `key` TEXT PK
- `value` TEXT

### 7.2 インデックス

- `items(is_purchased, updated_at DESC)`
- `places(is_active DESC, last_used_at DESC)`
- `item_place(place_id, item_id)`

### 7.3 ドメイン制約（UseCaseで担保）

- **上限**: `SELECT COUNT(*) FROM places` ≤ 100
- **アクティブ判定**:  
  `places.is_active = EXISTS(SELECT 1 FROM item_place ip JOIN items i ON i.id=ip.item_id WHERE ip.place_id=places.id AND i.is_purchased=0)`

---

## 8. ジオフェンス運用仕様

- **登録対象**: `places.is_active=1` の地点**すべて**（上限100の内数）
- **半径**: 100m（固定）
- **トランジション**: `ENTER`
- **PendingIntent**: `GeofenceReceiver`（BroadcastReceiver）にブロードキャスト
- **再登録トリガ**
    1. アプリ起動/更新時
    2. 端末再起動時（BootCompletedReceiver→Work）
    3. アイテム追加/変更/削除（UseCase→差分更新）
- **差分更新アルゴリズム（擬似）**
  ```
  target = ActivePlaces()                       // DB
  current = GeofencingClient.registeredIds()   // キャッシュ/同期テーブル
  toAdd = target - current
  toRemove = current - target
  GeofencingClient.add(toAdd); GeofencingClient.remove(toRemove)
  updateSyncTable()
  ```
- **クールダウン**
    - `last_notified_at + 5min > now` の場合は通知をスキップ（固定5分）

---

## 9. 通知仕様（詳細）

- **チャンネルID**: `shopping_reminders`
- **ID命名**: `place_{placeId}`
- **スタイル**: `NotificationCompat.InboxStyle`
- **アクション**
    - **購入済みにする**: 該当お店×未購入アイテムを一括更新
    - **削除**: 対象アイテムを削除
    - **詳細**: `MainActivity` に DeepLink しアイテム詳細画面を開く

---

## 10. ユースケース/シーケンス（代表）

- 「お店を紐づけて保存」: S2→S3/S4→S2→差分更新
- 「境界に入る→通知→購入済み」: 受信→通知→アクション→差分更新
- 「再起動後の復旧」: Boot→Work→Geofence再登録

---

## 11. CI/CD 運用方針

- **CI/CD 基盤**: GitHub Actions。コンポジットアクション `./.github/actions/android-gradle` を介して JDK 21・Secrets 注入・Gradle 実行を統一化し、既定では GitHub ホストランナーにプリインストール済みの Android SDK を利用する。追加コンポーネントが必要なジョブのみ `ensure-android-components=true` として `sdkmanager` を実行する。
- **ブランチ別ワークフロー**
    - `push`（`main`/`release` 以外）: `android-ci.yml` でユニットテスト（`testDebugUnitTest`+`assembleDebug`）と `lintDebug` を並列実行し、ユニットテスト結果は GitHub Actions Test Report に連携、Lint レポートは Job Summary と 1 日保持の Artifact に出力する。
    - `pull_request`（base=`release`）: `android-release.yml` でユニットテスト→API 29 & 35 の計装テスト→`bundleRelease`+`publishReleaseBundle` を実行し、内部テストトラックへ自動アップロードする。Firebase Test Lab 実行はサービスアカウント Secret 設定時のみ行う。
    - `push`（`release`）: `android-promote.yml` が `promoteReleaseArtifact` を起動し、内部テストから製品版トラックへプロモートする（審査提出は手動）。
- **キャッシュ方針**: すべてのワークフローで `actions/cache@v4` を活用し、`/usr/local/lib/android/sdk/{build-tools,platforms,platform-tools}` と `~/.android` をキー `android-sdk-${ runner.os }-${ hashFiles('gradle/libs.versions.toml') }` で再利用する。キャッシュミス時は `ensure-android-components` 有効化ジョブが不足分を取得する。
- **バージョン採番**
    - `gradle/version.properties` に格納したメジャー番号を手動更新。
    - マイナー番号は Pull Request 番号を CI 環境変数で注入しストーリー単位で採番。
    - パッチ番号は `github.run_number` を利用しビルド単位で採番。`versionCode = major*1_000_000 + minor*10_000 + patch`、`versionName = "major.minor.patch"`。
- **Secrets 管理**
    - GitHub Secrets を使用し、`MAPS_API_KEY`、`PLAY_SERVICE_ACCOUNT_JSON`、`ANDROID_KEYSTORE_*`、`FIREBASE_TEST_LAB_SA_JSON` を登録。
    - ワークフロー内で一時ファイルとして `local.properties`、`gradle/keystore.jks`、`gradle/play-service-account.json` を生成し、ジョブ終了時に削除する。
    - Keystore・Play 資格情報が存在しない場合でもビルドを継続し、必要時のみ署名・配信処理を有効にする。
