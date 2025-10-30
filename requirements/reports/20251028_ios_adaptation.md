# iOS版開発向け調査メモ（2025-10-28）

## Google Maps / Places SDKのiOS 15対応状況
- 2025-05-19公開の Maps SDK for iOS v10.0.0 以降は **iOS 16以上が必須**。iOS 15をサポートするには v9.x 系を明示的に固定する必要がある。
- 2025-05-28公開の Places SDK for iOS / Places Swift SDK v10.0.0 でも同様に **iOS 16以上**が前提。iOS 15対応のため v9.x への固定が必要。
- Navigation SDKや関連Geo SDKも2025年Q2以降はiOS 16以上が前提のため、共通で9.x系を利用する想定。
- Xcode 16以降が前提となるリリースが増えているため、iOS 15対応を続ける場合はXcode 15.xラインでビルドするか、互換性に注意する。

## Core Location（ジオフェンス）仕様のiOS差異
- `CLLocationManager` によるリージョン監視は **アプリごとに最大20件**まで。Android版仕様(最大100地点)そのままの常時監視は不可。
- 背景で通知を継続するには `requestAlwaysAuthorization()` を通じて「常に許可」を取得し、かつ Info.plist に `NSLocationAlwaysAndWhenInUseUsageDescription` / `NSLocationWhenInUseUsageDescription` 等を設定する必要がある。
- ジオフェンス登録は端末側で共有リソースのため、20件を超える場合は距離や利用頻度に基づく再スケジューリングが必要。
- リージョンイベントは境界から200m程度離れるまで遅延するケースがあり、Androidの即時通知モデルとの差異をUI/文言で配慮する必要がある。

## 通知・権限まわりの考慮
- 背景位置情報を要求する場合、iOSでは初回に「アプリ使用中のみ」許可しか表示されず、追加プロンプトで「常に許可」へ誘導する導線が必要。
- iOS 13以降、背景利用を続けると定期的にシステムからリマインドが表示されるため、プライバシーポリシー画面やヘルプ文言に追記が必要。
- バックグラウンド位置取得には `UIBackgroundModes` の `location` を有効化。
- 通知権限は `UNUserNotificationCenter` でリクエストし、Androidの通知チャンネルに相当する設定（通知カテゴリ）を実装する。

## Android→iOS仕様反映での主な変更点
- 地点上限: Androidの「100地点」をCore Location制約に合わせて **「同時監視20件＋必要時差し替え」** に変更。DB上は100件保持可だが監視は動的切り替えを行う。
- ジオフェンス差分更新: iOSでは`CLLocationManager`の監視キューを管理するサービス層を用意し、監視対象リストを20件以内に収めるアルゴリズムが必要。
- 再起動後復旧: `CLLocationManager`はシステムが自動的に再起動後もリージョンイベントを復活させるが、アプリ起動時の再登録やキャッシュ整合処理を実装して補完する。
- Places検索: Google Places SDK for iOS (v9.x) を利用。iOS 15向けにSwift Package Managerを使う場合はバイナリターゲットの互換性を確認する。
- Map表示: Google Maps SDK for iOS (v9.x) をSwiftUIに組み込むため、`UIViewRepresentable` ブリッジを用意。
- データ永続化: Room→Core Data への置き換え。多対多関係を `Item`↔`Place` 中間エンティティで表現し、フェッチリクエストとID管理を設計。

