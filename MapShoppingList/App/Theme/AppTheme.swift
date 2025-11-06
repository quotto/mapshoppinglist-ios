import SwiftUI
import UIKit

// MARK: - Color Extension

extension Color {
    /// カラースキームに応じた動的カラーを生成
    /// - Parameters:
    ///   - light: ライトモード時の色
    ///   - dark: ダークモード時の色
    /// - Returns: 動的に切り替わるColor
    static func dynamicColor(light: Color, dark: Color) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - App Theme Colors

/// アプリ全体で使用する意味的なカラー定義
/// SwiftUIのViewから直接アクセス可能
extension Color {
    // MARK: - Primary Colors
    
    /// プライマリカラー（メインアクション、強調表示）
    static var appPrimary: Color {
        dynamicColor(light: AppColors.light.primary, dark: AppColors.dark.primary)
    }
    
    /// プライマリカラー上のテキスト色
    static var appOnPrimary: Color {
        dynamicColor(light: AppColors.light.onPrimary, dark: AppColors.dark.onPrimary)
    }
    
    /// プライマリコンテナ背景色
    static var appPrimaryContainer: Color {
        dynamicColor(light: AppColors.light.primaryContainer, dark: AppColors.dark.primaryContainer)
    }
    
    /// プライマリコンテナ上のテキスト色
    static var appOnPrimaryContainer: Color {
        dynamicColor(light: AppColors.light.onPrimaryContainer, dark: AppColors.dark.onPrimaryContainer)
    }
    
    // MARK: - Secondary Colors
    
    /// セカンダリカラー（補助的なアクション）
    static var appSecondary: Color {
        dynamicColor(light: AppColors.light.secondary, dark: AppColors.dark.secondary)
    }
    
    /// セカンダリカラー上のテキスト色
    static var appOnSecondary: Color {
        dynamicColor(light: AppColors.light.onSecondary, dark: AppColors.dark.onSecondary)
    }
    
    /// セカンダリコンテナ背景色
    static var appSecondaryContainer: Color {
        dynamicColor(light: AppColors.light.secondaryContainer, dark: AppColors.dark.secondaryContainer)
    }
    
    /// セカンダリコンテナ上のテキスト色
    static var appOnSecondaryContainer: Color {
        dynamicColor(light: AppColors.light.onSecondaryContainer, dark: AppColors.dark.onSecondaryContainer)
    }
    
    // MARK: - Tertiary Colors
    
    /// ターシャリカラー（アクセント、特別な強調）
    static var appTertiary: Color {
        dynamicColor(light: AppColors.light.tertiary, dark: AppColors.dark.tertiary)
    }
    
    /// ターシャリカラー上のテキスト色
    static var appOnTertiary: Color {
        dynamicColor(light: AppColors.light.onTertiary, dark: AppColors.dark.onTertiary)
    }
    
    /// ターシャリコンテナ背景色
    static var appTertiaryContainer: Color {
        dynamicColor(light: AppColors.light.tertiaryContainer, dark: AppColors.dark.tertiaryContainer)
    }
    
    /// ターシャリコンテナ上のテキスト色
    static var appOnTertiaryContainer: Color {
        dynamicColor(light: AppColors.light.onTertiaryContainer, dark: AppColors.dark.onTertiaryContainer)
    }
    
    // MARK: - Error Colors
    
    /// エラーカラー
    static var appError: Color {
        dynamicColor(light: AppColors.light.error, dark: AppColors.dark.error)
    }
    
    /// エラーカラー上のテキスト色
    static var appOnError: Color {
        dynamicColor(light: AppColors.light.onError, dark: AppColors.dark.onError)
    }
    
    /// エラーコンテナ背景色
    static var appErrorContainer: Color {
        dynamicColor(light: AppColors.light.errorContainer, dark: AppColors.dark.errorContainer)
    }
    
    /// エラーコンテナ上のテキスト色
    static var appOnErrorContainer: Color {
        dynamicColor(light: AppColors.light.onErrorContainer, dark: AppColors.dark.onErrorContainer)
    }
    
    // MARK: - Background & Surface
    
    /// 背景色
    static var appBackground: Color {
        dynamicColor(light: AppColors.light.background, dark: AppColors.dark.background)
    }
    
    /// 背景上のテキスト色
    static var appOnBackground: Color {
        dynamicColor(light: AppColors.light.onBackground, dark: AppColors.dark.onBackground)
    }
    
    /// サーフェス色（カードやダイアログの背景）
    static var appSurface: Color {
        dynamicColor(light: AppColors.light.surface, dark: AppColors.dark.surface)
    }
    
    /// サーフェス上のテキスト色
    static var appOnSurface: Color {
        dynamicColor(light: AppColors.light.onSurface, dark: AppColors.dark.onSurface)
    }
    
    /// サーフェスバリアント色
    static var appSurfaceVariant: Color {
        dynamicColor(light: AppColors.light.surfaceVariant, dark: AppColors.dark.surfaceVariant)
    }
    
    /// サーフェスバリアント上のテキスト色
    static var appOnSurfaceVariant: Color {
        dynamicColor(light: AppColors.light.onSurfaceVariant, dark: AppColors.dark.onSurfaceVariant)
    }
    
    // MARK: - Outline & Border
    
    /// アウトライン色（境界線）
    static var appOutline: Color {
        dynamicColor(light: AppColors.light.outline, dark: AppColors.dark.outline)
    }
    
    /// アウトラインバリアント色（より薄い境界線）
    static var appOutlineVariant: Color {
        dynamicColor(light: AppColors.light.outlineVariant, dark: AppColors.dark.outlineVariant)
    }
    
    // MARK: - Status Colors
    
    /// 成功カラー
    static var appSuccess: Color {
        AppColors.brandSuccess
    }
}

// MARK: - UIColor Extension

extension UIColor {
    /// プライマリカラー（UIKit用）
    static var appPrimary: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(AppColors.dark.primary)
                : UIColor(AppColors.light.primary)
        }
    }
    
    /// プライマリライトカラー（UIKit用、マップの円など）
    static var appPrimaryLight: UIColor {
        UIColor(AppColors.brandPrimaryLight)
    }
}
