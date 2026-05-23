import Foundation

/// 一次 App 内本地化变更。
///
/// 该值把“文案变化”和“排版方向变化”分开表达。大多数 locale 切换只需要
/// 更新文案；LTR/RTL 变化才需要额外刷新布局、手势和导航方向。
public struct LocalizationChange: Equatable, Sendable {
    /// 切换前的 locale。
    public let previousLocale: AppLocale

    /// 切换后的 locale。
    public let currentLocale: AppLocale

    /// 创建变更值。通常由 `LocalizationController` 生成。
    public init(previousLocale: AppLocale, currentLocale: AppLocale) {
        self.previousLocale = previousLocale
        self.currentLocale = currentLocale
    }

    /// 文案是否需要刷新。
    public var textChanged: Bool {
        previousLocale.identifier != currentLocale.identifier
    }

    /// UI 排版方向是否发生变化。
    ///
    /// 只有这个值为 `true` 时，才需要 invalidating collection layout、
    /// 更新 semantic content attribute、重算手势方向或考虑 root rebuild。
    public var layoutDirectionChanged: Bool {
        previousLocale.layoutDirection != currentLocale.layoutDirection
    }
}
