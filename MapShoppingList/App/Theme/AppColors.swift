import SwiftUI

/// アプリケーション全体で使用するブランドカラー定義
/// Android版の配色定義（Color.kt）と統一
struct AppColors {
    // MARK: - ブランドカラー（基本）

    /// ブランドプライマリカラー (Android: BrandPrimary = 0xFF1B70A0)
    static let brandPrimary = Color(red: 0x1B / 255.0, green: 0x70 / 255.0, blue: 0xA0 / 255.0)

    /// ブランドプライマリライト (Android: BrandPrimaryLight = 0xFF1B7CB0)
    static let brandPrimaryLight = Color(red: 0x1B / 255.0, green: 0x7C / 255.0, blue: 0xB0 / 255.0)

    /// ブランドプライマリダーク (Android: BrandPrimaryDark = 0xFF1B6491)
    static let brandPrimaryDark = Color(red: 0x1B / 255.0, green: 0x64 / 255.0, blue: 0x91 / 255.0)

    /// ブランドサーフェス（ライトモード背景） (Android: BrandSurface = 0xFFF6FAFD)
    static let brandSurface = Color(red: 0xF6 / 255.0, green: 0xFA / 255.0, blue: 0xFD / 255.0)

    /// ブランドサーフェス高明度（ダークモード背景） (Android: BrandSurfaceHigh = 0xFF0F1C2B)
    static let brandSurfaceHigh = Color(red: 0x0F / 255.0, green: 0x1C / 255.0, blue: 0x2B / 255.0)

    /// ブランドセカンダリカラー (Android: BrandSecondary = 0xFF18324A)
    static let brandSecondary = Color(red: 0x18 / 255.0, green: 0x32 / 255.0, blue: 0x4A / 255.0)

    /// ブランドセカンダリコンテナ (Android: BrandSecondaryContainer = 0xFFD1E4F1)
    static let brandSecondaryContainer = Color(red: 0xD1 / 255.0, green: 0xE4 / 255.0, blue: 0xF1 / 255.0)

    /// セカンダリコンテナ上のテキスト色 (Android: BrandOnSecondaryContainer = 0xFF041420)
    static let brandOnSecondaryContainer = Color(red: 0x04 / 255.0, green: 0x14 / 255.0, blue: 0x20 / 255.0)

    // MARK: - アクセントカラー

    /// ブランドアクセントカラー (Android: BrandAccent = 0xFFEA5F52)
    static let brandAccent = Color(red: 0xEA / 255.0, green: 0x5F / 255.0, blue: 0x52 / 255.0)

    /// ブランドアクセントライト (Android: BrandAccentLight = 0xFFF6F4F3)
    static let brandAccentLight = Color(red: 0xF6 / 255.0, green: 0xF4 / 255.0, blue: 0xF3 / 255.0)

    // MARK: - ニュートラルカラー

    /// ニュートラルボーダー (Android: BrandNeutralBorder = 0xFFD5E3EE)
    static let brandNeutralBorder = Color(red: 0xD5 / 255.0, green: 0xE3 / 255.0, blue: 0xEE / 255.0)

    /// プライマリ上のテキスト色 (Android: BrandOnPrimary = 0xFFF6F4F3)
    static let brandOnPrimary = Color(red: 0xF6 / 255.0, green: 0xF4 / 255.0, blue: 0xF3 / 255.0)

    /// サーフェス上のテキスト色 (Android: BrandOnSurface = 0xFF0F1C2B)
    static let brandOnSurface = Color(red: 0x0F / 255.0, green: 0x1C / 255.0, blue: 0x2B / 255.0)

    /// サーフェスバリアント上のテキスト色 (Android: BrandOnSurfaceVariant = 0xFF4F5D6A)
    static let brandOnSurfaceVariant = Color(red: 0x4F / 255.0, green: 0x5D / 255.0, blue: 0x6A / 255.0)

    /// アウトラインカラー (Android: BrandOutline = 0xFFA9BCCC)
    static let brandOutline = Color(red: 0xA9 / 255.0, green: 0xBC / 255.0, blue: 0xCC / 255.0)

    // MARK: - ステータスカラー

    /// 成功カラー (Android: BrandSuccess = 0xFF3CB371)
    static let brandSuccess = Color(red: 0x3C / 255.0, green: 0xB3 / 255.0, blue: 0x71 / 255.0)

    /// エラーカラー (Android: BrandError = 0xFFE53935)
    static let brandError = Color(red: 0xE5 / 255.0, green: 0x39 / 255.0, blue: 0x35 / 255.0)
}

// MARK: - ライト/ダークモードカラースキーム

extension AppColors {
    /// ライトモードのカラースキーム
    struct LightScheme {
        let primary = brandPrimary
        let onPrimary = brandOnPrimary
        let primaryContainer = brandPrimaryLight
        let onPrimaryContainer = brandOnSurface

        let secondary = brandSecondary
        let onSecondary = brandOnPrimary
        let secondaryContainer = brandSecondaryContainer
        let onSecondaryContainer = brandOnSecondaryContainer

        let tertiary = brandAccent
        let onTertiary = brandOnPrimary
        let tertiaryContainer = brandAccentLight
        let onTertiaryContainer = brandSecondary

        let error = brandError
        let onError = brandOnPrimary
        let errorContainer = Color(red: 0xFF / 255.0, green: 0xDA / 255.0, blue: 0xD6 / 255.0)
        let onErrorContainer = Color(red: 0x41 / 255.0, green: 0x00 / 255.0, blue: 0x02 / 255.0)

        let background = brandSurface
        let onBackground = brandOnSurface
        let surface = brandSurface
        let onSurface = brandOnSurface
        let surfaceVariant = brandSecondaryContainer
        let onSurfaceVariant = brandOnSurfaceVariant

        let outline = brandOutline
        let outlineVariant = brandNeutralBorder
        let scrim = Color.black.opacity(0.4)

        let inversePrimary = brandPrimaryLight
        let inverseSurface = brandSurfaceHigh
        let inverseOnSurface = brandAccentLight
    }

    /// ダークモードのカラースキーム
    struct DarkScheme {
        let primary = brandPrimaryLight
        let onPrimary = brandOnPrimary
        let primaryContainer = brandPrimaryDark
        let onPrimaryContainer = brandAccentLight

        let secondary = brandSecondaryContainer
        let onSecondary = brandOnSecondaryContainer
        let secondaryContainer = brandSecondary
        let onSecondaryContainer = brandOnPrimary

        let tertiary = brandAccent
        let onTertiary = brandOnPrimary
        let tertiaryContainer = Color(red: 0x7F / 255.0, green: 0x31 / 255.0, blue: 0x27 / 255.0)
        let onTertiaryContainer = brandAccentLight

        let error = brandError
        let onError = brandOnPrimary
        let errorContainer = Color(red: 0x93 / 255.0, green: 0x00 / 255.0, blue: 0x0A / 255.0)
        let onErrorContainer = Color(red: 0xFF / 255.0, green: 0xDA / 255.0, blue: 0xD6 / 255.0)

        let background = brandSurfaceHigh
        let onBackground = brandAccentLight
        let surface = brandSurfaceHigh
        let onSurface = brandAccentLight
        let surfaceVariant = Color(red: 0x31 / 255.0, green: 0x46 / 255.0, blue: 0x59 / 255.0)
        let onSurfaceVariant = brandNeutralBorder

        let outline = brandOutline
        let outlineVariant = Color(red: 0x3E / 255.0, green: 0x4D / 255.0, blue: 0x5A / 255.0)
        let scrim = Color.black.opacity(0.6)

        let inversePrimary = brandPrimary
        let inverseSurface = brandSurface
        let inverseOnSurface = brandOnSurface
    }

    static let light = LightScheme()
    static let dark = DarkScheme()
}
