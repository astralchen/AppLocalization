import Foundation

/// 应用内本地化状态在某一时刻的不可变快照。
public struct LocalizationSnapshot: Equatable, Sendable {
    /// 当前应用区域设置。
    public let locale: AppLocale

    /// 当前是否跟随系统首选语言。
    public let followsSystemLocale: Bool

    /// 每次有效选择状态变化时单调递增的版本号。
    public let revision: UInt64

    /// 当前应用界面布局方向。
    public var layoutDirection: AppUserInterfaceLayoutDirection {
        locale.layoutDirection
    }

    /// 创建本地化状态快照。
    public init(
        locale: AppLocale,
        followsSystemLocale: Bool,
        revision: UInt64
    ) {
        self.locale = locale
        self.followsSystemLocale = followsSystemLocale
        self.revision = revision
    }
}

/// 一次应用内本地化变更。
///
/// 此类型分别描述文本变化和布局方向变化。大多数区域设置切换只需要
/// 更新文本；只有从左向右和从右向左布局相互切换时，才需要额外刷新布局、手势和
/// 导航方向。
public struct LocalizationChange: Equatable, Sendable {
    /// 切换前的本地化状态。
    public let previous: LocalizationSnapshot

    /// 切换后的本地化状态。
    public let current: LocalizationSnapshot

    /// 创建本地化变更。
    ///
    /// - Parameters:
    ///   - previous: 切换前的本地化状态。
    ///   - current: 切换后的本地化状态。
    public init(
        previous: LocalizationSnapshot,
        current: LocalizationSnapshot
    ) {
        self.previous = previous
        self.current = current
    }

    /// 区域设置是否变化。
    public var localeChanged: Bool {
        previous.locale.identifier != current.locale.identifier
    }

    /// “跟随系统”与手动选择状态是否变化。
    public var selectionChanged: Bool {
        previous.followsSystemLocale != current.followsSystemLocale
    }

    /// 指示界面布局方向是否发生变化。
    ///
    /// 仅当此值为 `true` 时，才需要刷新表格可见视图的方向布局、使集合视图布局失效、
    /// 更新语义内容属性、重新计算手势方向，或考虑重建根视图控制器。
    public var layoutDirectionChanged: Bool {
        previous.layoutDirection != current.layoutDirection
    }
}
