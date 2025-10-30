import Foundation

/// ドメイン層で発生するエラー。
public enum DomainError: Error, Equatable {
    /// 重複する地点が存在する。
    case duplicatePlace
    /// 登録可能な地点数を超えた。
    case placeLimitExceeded(max: Int)
    /// 指定した地点が見つからない。
    case placeNotFound
    /// 指定したアイテムが見つからない。
    case itemNotFound
    /// アイテムが地点と紐付いていない。
    case linkNotFound
    /// ジオフェンス登録可能件数を超えた。
    case geofenceLimitExceeded(max: Int)
    /// 通知がクールダウン中である。
    case notificationCooldown
}
