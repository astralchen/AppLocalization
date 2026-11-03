#if canImport(UIKit)
import UIKit

/// 触发 UIKit 本地化状态更新的原因。
public struct UIKitLocalizationUpdateReason: OptionSet, Sendable {
    /// 更新原因的原始位掩码。
    public let rawValue: UInt8

    /// 使用原始位掩码创建更新原因。
    ///
    /// - Parameter rawValue: 更新原因的位掩码。
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// 对象首次接收本地化状态。
    public static let initial = Self(rawValue: 1 << 0)

    /// 选择模式在跟随系统偏好与明确选择区域设置之间变化。
    public static let selection = Self(rawValue: 1 << 1)

    /// 当前生效的区域设置标识符发生变化。
    public static let locale = Self(rawValue: 1 << 2)

    /// 界面布局方向需要更新。
    public static let layoutDirection = Self(rawValue: 1 << 3)

    /// 对象正在挂载到视图层级或与当前层级同步。
    public static let attachment = Self(rawValue: 1 << 4)

    /// 对象正在准备内容配置。
    public static let configuration = Self(rawValue: 1 << 5)
}

/// 不可变的本地化快照及其更新原因。
///
/// 方向和内容回调应使用同一次更新，使两者读取相同版本的状态。
/// 配置和挂载更新会请求方向刷新，但自身不会请求本地化内容刷新。
public struct UIKitLocalizationUpdate: Equatable, Sendable {
    /// 要应用的本地化状态。
    public let snapshot: LocalizationSnapshot

    /// 应用此次更新的原因。
    public let reasons: UIKitLocalizationUpdateReason

    /// 使用指定快照和原因创建更新。
    ///
    /// - Parameters:
    ///   - snapshot: 要应用的本地化状态。
    ///   - reasons: 决定所需刷新操作的更新原因。
    public init(
        snapshot: LocalizationSnapshot,
        reasons: UIKitLocalizationUpdateReason
    ) {
        self.snapshot = snapshot
        self.reasons = reasons
    }

    /// 创建请求初始内容刷新和方向刷新的更新。
    ///
    /// - Parameter snapshot: 当前本地化状态。
    /// - Returns: 包含初始、选择、区域设置和布局方向原因的更新。
    public static func initial(
        snapshot: LocalizationSnapshot
    ) -> Self {
        Self(
            snapshot: snapshot,
            reasons: [.initial, .selection, .locale, .layoutDirection]
        )
    }

    /// 根据本地化快照之间的差异创建更新。
    ///
    /// - Parameter change: 变更前后的本地化状态。
    /// - Returns: 包含当前快照及其变更原因的更新。
    public static func change(_ change: LocalizationChange) -> Self {
        var reasons: UIKitLocalizationUpdateReason = []
        if change.selectionChanged {
            reasons.insert(.selection)
        }
        if change.localeChanged {
            reasons.insert(.locale)
        }
        if change.layoutDirectionChanged {
            reasons.insert(.layoutDirection)
        }
        return Self(snapshot: change.current, reasons: reasons)
    }

    /// 为挂载或重新挂载的内容创建方向更新。
    ///
    /// - Parameter snapshot: 当前本地化状态。
    /// - Returns: 包含挂载和布局方向原因的更新。
    public static func attachment(
        snapshot: LocalizationSnapshot
    ) -> Self {
        Self(snapshot: snapshot, reasons: [.attachment, .layoutDirection])
    }

    /// 为内容配置创建方向更新。
    ///
    /// - Parameter snapshot: 当前本地化状态。
    /// - Returns: 包含配置和布局方向原因的更新。
    public static func configuration(
        snapshot: LocalizationSnapshot
    ) -> Self {
        Self(snapshot: snapshot, reasons: [.configuration, .layoutDirection])
    }

    /// 指示是否需要刷新本地化内容的布尔值。
    ///
    /// 更新原因包含初始、选择或区域设置时，此值为 `true`。
    public var requiresLocalizedContentRefresh: Bool {
        !reasons.intersection([.initial, .selection, .locale]).isEmpty
    }

    /// 指示是否需要刷新依赖方向的状态的布尔值。
    ///
    /// 更新原因包含初始、布局方向、挂载或配置时，此值为 `true`。
    public var requiresLayoutDirectionRefresh: Bool {
        !reasons.intersection([
            .initial,
            .layoutDirection,
            .attachment,
            .configuration
        ]).isEmpty
    }

    /// 与快照对应的 UIKit 布局方向。
    public var layoutDirection: UIUserInterfaceLayoutDirection {
        snapshot.layoutDirection.uiLayoutDirection
    }

    /// 用于强制采用快照布局方向的语义内容属性。
    public var semanticContentAttribute: UISemanticContentAttribute {
        snapshot.layoutDirection.semanticContentAttribute
    }
}

/// 向 UIKit 对象应用本地化状态的接口。
@MainActor
public protocol UIKitLocalizationApplying: AnyObject {
    /// 应用指定的本地化更新。
    ///
    /// 先应用组件拥有的方向目标，再更新文本、菜单、配置和缓存的布局状态。
    /// 使用更新标志判断需要执行的操作。
    ///
    /// - Parameter update: 要应用的本地化状态和刷新原因。
    func applyLocalization(_ update: UIKitLocalizationUpdate)
}

/// 在本地化更新前保存局部界面状态的接口。
///
/// 窗口协调器先为所有已加载的控制器执行准备阶段，再改变窗口或容器方向。
/// 在此阶段捕获状态，在 ``UIKitLocalizationApplying/applyLocalization(_:)`` 中修改视图。
/// 准备阶段不会加载离屏控制器的视图。
@MainActor
public protocol UIKitLocalizationPreparing: AnyObject {
    /// 在协调器应用更新前捕获局部界面状态。
    ///
    /// 使用此方法捕获滚动锚点或其他受方向影响的状态，将视图修改留到应用阶段。
    ///
    /// - Parameter update: 即将应用的本地化更新。
    func prepareForLocalization(_ update: UIKitLocalizationUpdate)
}
#endif
