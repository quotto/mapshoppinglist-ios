import Foundation

public enum DomainConstants {
    /// 地点の最大登録数。
    public static let placeLimit: Int = 100
    /// 同時に監視可能なジオフェンス数。
    public static let geofenceMonitorLimit: Int = 20
    /// ジオフェンス半径（メートル）。
    public static let geofenceRadius: Double = 100.0
    /// 通知クールダウン秒（Android仕様の2時間を継承）。
    public static let notificationCooldownInterval: TimeInterval = 2 * 60 * 60
}
