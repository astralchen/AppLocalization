import Foundation

/// 应用本地化状态的不可变快照。
public struct LocalizationSnapshot: Equatable, Sendable {
    /// 当前生效的应用区域设置。
    public let locale: AppLocale

    /// 指示应用是否跟随系统语言偏好的布尔值。
    public let followsSystemLocale: Bool

    /// 本地化状态的版本号。
    ///
    /// 区域设置或选择模式变化时，控制器递增此值。
    /// 应用异步结果前，应将此值与当前版本号比较。
    public let revision: UInt64

    /// 当前生效区域设置的界面布局方向。
    public var layoutDirection: AppUserInterfaceLayoutDirection {
        locale.layoutDirection
    }

    /// 使用指定本地化状态创建快照。
    ///
    /// - Parameters:
    ///   - locale: 当前生效的应用区域设置。
    ///   - followsSystemLocale: 指示是否根据系统语言偏好确定区域设置的布尔值。
    ///   - revision: 此状态对应的版本号。
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

/// 两个应用本地化快照之间的变更。
///
/// 使用各变更标志区分区域设置、选择模式和布局方向的变化。
public struct LocalizationChange: Equatable, Sendable {
    /// 变更前的本地化状态。
    public let previous: LocalizationSnapshot

    /// 变更后的本地化状态。
    public let current: LocalizationSnapshot

    /// 使用指定快照创建本地化变更。
    ///
    /// - Parameters:
    ///   - previous: 变更前的本地化状态。
    ///   - current: 变更后的本地化状态。
    public init(
        previous: LocalizationSnapshot,
        current: LocalizationSnapshot
    ) {
        self.previous = previous
        self.current = current
    }

    /// 指示区域设置标识符是否变化的布尔值。
    public var localeChanged: Bool {
        previous.locale.identifier != current.locale.identifier
    }

    /// 指示跟随系统语言的选择模式是否变化的布尔值。
    public var selectionChanged: Bool {
        previous.followsSystemLocale != current.followsSystemLocale
    }

    /// 指示界面布局方向是否变化的布尔值。
    ///
    /// 使用此值判断是否需要刷新依赖方向的布局、导航项和手势。
    public var layoutDirectionChanged: Bool {
        previous.layoutDirection != current.layoutDirection
    }
}
