import Foundation

/// 一次应用内本地化变更。
///
/// 此类型分别描述文本变化和布局方向变化。大多数区域设置切换只需要
/// 更新文本；只有从左向右和从右向左布局相互切换时，才需要额外刷新布局、手势和
/// 导航方向。
public struct LocalizationChange: Equatable, Sendable {
    /// 切换前的区域设置。
    public let previousLocale: AppLocale

    /// 切换后的区域设置。
    public let currentLocale: AppLocale

    /// 创建本地化变更。
    ///
    /// - Parameters:
    ///   - previousLocale: 切换前的区域设置。
    ///   - currentLocale: 切换后的区域设置。
    public init(previousLocale: AppLocale, currentLocale: AppLocale) {
        self.previousLocale = previousLocale
        self.currentLocale = currentLocale
    }

    /// 文案是否需要刷新。
    public var textChanged: Bool {
        previousLocale.identifier != currentLocale.identifier
    }

    /// 指示界面布局方向是否发生变化。
    ///
    /// 仅当此值为 `true` 时，才需要使集合视图布局失效、更新语义内容属性、
    /// 重新计算手势方向，或考虑重建根视图控制器。
    public var layoutDirectionChanged: Bool {
        previousLocale.layoutDirection != currentLocale.layoutDirection
    }
}
