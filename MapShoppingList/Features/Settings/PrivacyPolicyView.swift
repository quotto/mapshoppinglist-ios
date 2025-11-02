import SwiftUI

struct PrivacyPolicyView: View {
    private let sections: [PolicySection] = [
        .init(
            title: "1. アプリが取得する情報",
            bulletPoints: [
                "端末の位置情報（緯度・経度）: 登録地点への出入りを検知するためにのみ利用します。外部への送信は行いません。",
                "アプリ内で登録した買い物アイテム、地点の名称・座標・メモ: 端末内データベースに保存します。",
                "通知設定やアプリ動作ログ（障害発生時のみ）: 利便性向上や不具合修正のため、端末内で一時的に保持することがあります（外部送信なし）。"
            ]
        ),
        .init(
            title: "2. 位置情報の取り扱い",
            bulletPoints: [
                "利用目的: 登録済み地点（半径100m）への出入りを検知し、リマインド通知を行うために使用します。",
                "取得タイミング: アプリがバックグラウンド状態または終了している場合でも、OSのGeofencing機能により検知が行われます。",
                "保存期間: 位置情報の履歴は保存せず、通知制御に必要な最小限の情報のみ保持します。",
                "権限設定: 位置情報（常に許可またはアプリ使用中のみ）および通知権限を必要に応じてリクエストします。端末設定からいつでも変更・削除できます。"
            ]
        ),
        .init(
            title: "3. データの第三者提供",
            body: "本アプリは、位置情報・買い物アイテム・メモなどのユーザーデータを第三者へ提供・共有しません。広告SDKや解析SDK、外部サーバー通信も行っていません。\nただし、以下の場合に限り、法令に基づき情報を開示することがあります。",
            bulletPoints: [
                "法令に基づく要請がある場合",
                "犯罪捜査・裁判手続など、公的機関からの正当な照会があった場合",
                "人の生命・身体・財産の保護のために必要であり、ユーザーの同意を得ることが困難な場合"
            ]
        ),
        .init(
            title: "4. データの管理",
            body: "すべてのデータは端末内に保存され、アンインストール時に自動的に削除されます。クラウド同期やバックアップ機能は提供していません。端末のセキュリティ設定を適切に管理することをおすすめします。"
        ),
        .init(
            title: "5. ユーザーの権利",
            body: "登録したアイテムや地点情報はいつでも編集・削除できます。位置情報や通知権限を拒否した場合、一部機能（地点付近での通知など）が利用できなくなることがあります。"
        ),
        .init(
            title: "6. お問い合わせ窓口",
            body: "本アプリのプライバシーに関するお問い合わせ、または個人情報の取扱いに関するご意見・ご要望は、以下のメールアドレスまでご連絡ください。\nmap.shoppinglist@gmail.com"
        ),
        .init(
            title: "7. ポリシーの変更",
            body: "本ポリシーの内容を変更する場合は、アプリ内のお知らせまたはリリースノートで告知します。変更後もアプリを継続して利用する場合、改定後の内容に同意したものとみなします。"
        )
    ]

    var body: some View {
        NavigationView {
            List(sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.headline)
                    if let body = section.body {
                        Text(body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    if let bulletPoints = section.bulletPoints {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(bulletPoints, id: \.self) { item in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                    Text(item)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("プライバシーポリシー")
        }
    }

    private struct PolicySection: Identifiable {
        let id = UUID()
        let title: String
        let body: String?
        let bulletPoints: [String]?

        init(title: String, body: String? = nil, bulletPoints: [String]? = nil) {
            self.title = title
            self.body = body
            self.bulletPoints = bulletPoints
        }
    }
}
