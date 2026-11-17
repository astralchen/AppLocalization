import UIKit

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
    public var layoutDirection: UIUserInterfaceLayoutDirection {
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

/// 一次本地化刷新的当前状态与可选旧状态。
///
/// 没有旧快照表示首次配置或显式同步，内容和方向都需要刷新。
/// 语言切换携带前后快照，刷新需求由差异计算；同一个值用于窗口事务、页面回调和完成通知。
public struct LocalizationUpdate: Equatable, Sendable {
    /// 本次应显示的状态。
    public let snapshot: LocalizationSnapshot

    /// 更新前的状态；首次配置或显式同步时为 nil。
    public let previousSnapshot: LocalizationSnapshot?

    /// 创建首次刷新或前后状态之间的差异更新。
    ///
    /// - Parameters:
    ///   - snapshot: 本次应显示的状态。
    ///   - previousSnapshot: 更新前的状态；默认 nil，表示同时刷新内容和方向。
    public init(snapshot: LocalizationSnapshot, previousSnapshot: LocalizationSnapshot? = nil) {
        self.snapshot = snapshot
        self.previousSnapshot = previousSnapshot
    }

    /// 本次状态对应的 UIKit 原生布局方向。
    public var layoutDirection: UIUserInterfaceLayoutDirection { snapshot.layoutDirection }

    /// 强制采用当前应用方向的 UIKit 语义属性。
    public var semanticContentAttribute: UISemanticContentAttribute {
        layoutDirection == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
    }

    /// 首次刷新、区域设置标识符或跟随系统选择模式变化时为 true。
    /// 仅版本号变化不要求刷新内容。
    public var requiresLocalizedContentRefresh: Bool {
        guard let previousSnapshot else { return true }
        return previousSnapshot.locale.identifier != snapshot.locale.identifier
            || previousSnapshot.followsSystemLocale != snapshot.followsSystemLocale
    }

    /// 首次刷新或布局方向变化时为 true。
    /// 同方向语言之间切换，以及仅选择模式或版本号变化时为 false。
    public var requiresLayoutDirectionRefresh: Bool {
        previousSnapshot?.layoutDirection != snapshot.layoutDirection
    }
}
