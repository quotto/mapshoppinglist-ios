import Foundation

/// 通知送信可否を判定するユースケース。
///  現時点では常に通知を許可するが、将来的な抑制ロジックを切り出して定義する拡張ポイントとして維持する。
public struct ShouldSendNotificationUseCase {
    public init() {}

    public func execute(state: NotificationState?, now: Date = Date()) throws -> Bool {
        return true
    }
}
