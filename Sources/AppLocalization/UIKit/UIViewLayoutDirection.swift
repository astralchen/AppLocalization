#if canImport(UIKit)
import UIKit

/// 向视图应用布局方向的策略。
public enum UIViewLayoutDirectionPolicy: Equatable, Sendable {
    /// 保持视图的语义内容属性不变。
    ///
    /// 未指定语义属性时，视图继承层级中的方向。此策略不会清除已有的强制方向。
    case inherited

    /// 强制视图使用当前应用布局方向。
    case followApplication

    /// 强制视图使用直接父视图的有效布局方向。
    ///
    /// 视图没有父视图时，保持语义内容属性不变。
    case followContainer

    /// 应用指定的语义内容属性。
    case fixed(UISemanticContentAttribute)
}

/// 视图及其公开组件边界所采用的方向策略。
@MainActor
public struct UIViewLayoutDirectionTarget {
    /// 需要更新方向和配置的视图。
    public let view: UIView

    /// 要应用到视图的方向策略。
    public let policy: UIViewLayoutDirectionPolicy

    /// 为组件拥有的视图创建方向目标。
    ///
    /// - Parameters:
    ///   - view: 要更新的公开视图边界。
    ///   - policy: 要应用的方向策略。
    public init(
        _ view: UIView,
        policy: UIViewLayoutDirectionPolicy
    ) {
        self.view = view
        self.policy = policy
    }
}

/// 声明组件所拥有方向目标的接口。
///
/// 返回固定方向或播放内容等特殊目标，并在组件的本地化回调中将这些目标传给更新器。
@MainActor
public protocol UIViewLayoutDirectionTargetProviding: AnyObject {
    /// 由组件明确管理方向的公开视图边界。
    var layoutDirectionTargets: [UIViewLayoutDirectionTarget] { get }
}

/// 向明确声明的视图应用本地化方向的工具。
@MainActor
public enum UIViewLayoutDirectionUpdater {
    /// 按顺序向指定视图应用方向策略。
    ///
    /// 仅在更新请求方向刷新时执行。同一视图出现多次时，只应用第一个目标的策略。
    ///
    /// - Parameters:
    ///   - update: 要应用的本地化状态和刷新原因。
    ///   - targets: 按应用顺序排列的视图目标及其方向策略。
    public static func apply(
        _ update: UIKitLocalizationUpdate,
        to targets: [UIViewLayoutDirectionTarget]
    ) {
        guard update.requiresLayoutDirectionRefresh else { return }

        var visited = Set<ObjectIdentifier>()
        for target in targets {
            guard visited.insert(ObjectIdentifier(target.view)).inserted else {
                continue
            }
            apply(update, to: target)
        }
    }

    /// 应用方向策略，并刷新目标视图的配置和布局。
    ///
    /// 仅在更新请求方向刷新时执行。只更新指定的公开边界，不遍历私有子视图。
    ///
    /// - Parameters:
    ///   - update: 要应用的本地化状态和刷新原因。
    ///   - target: 要更新的视图及其方向策略。
    public static func apply(
        _ update: UIKitLocalizationUpdate,
        to target: UIViewLayoutDirectionTarget
    ) {
        guard update.requiresLayoutDirectionRefresh else { return }

        let attribute: UISemanticContentAttribute?
        switch target.policy {
        case .inherited:
            attribute = nil
        case .followApplication:
            attribute = update.semanticContentAttribute
        case .followContainer:
            attribute = target.view.superview.map {
                $0.effectiveUserInterfaceLayoutDirection
                    .appLayoutDirection
                    .semanticContentAttribute
            }
        case let .fixed(fixedAttribute):
            attribute = fixedAttribute
        }

        if let attribute, target.view.semanticContentAttribute != attribute {
            target.view.semanticContentAttribute = attribute
        }
        // 即使语义属性继承自祖先，也需要刷新配置和布局缓存。
        refreshConfigurationIfSupported(for: target.view)
        target.view.setNeedsUpdateConstraints()
        target.view.invalidateIntrinsicContentSize()
        target.view.setNeedsLayout()
    }

    private static func refreshConfigurationIfSupported(for view: UIView) {
        switch view {
        case let button as UIButton:
            button.setNeedsUpdateConfiguration()
            // 立即应用配置，使内容在调用方执行布局之前采用新方向。
            button.updateConfiguration()
            if let configuration = button.configuration {
                // 通过公开接口重新创建配置内容，清除过期的方向状态。
                button.configuration = nil
                button.configuration = configuration
            }
        case let tableCell as UITableViewCell:
            tableCell.setNeedsUpdateConfiguration()
            tableCell.updateConfiguration(using: tableCell.configurationState)
            if let configuration = tableCell.contentConfiguration {
                tableCell.contentConfiguration = nil
                tableCell.contentConfiguration = configuration
            }
        case let listCell as UICollectionViewListCell:
            listCell.setNeedsUpdateConfiguration()
            listCell.updateConfiguration(using: listCell.configurationState)
            if let configuration = listCell.contentConfiguration {
                listCell.contentConfiguration = nil
                listCell.contentConfiguration = configuration
            }
            let accessories = listCell.accessories
            listCell.accessories = []
            listCell.accessories = accessories
        case let collectionCell as UICollectionViewCell:
            collectionCell.setNeedsUpdateConfiguration()
            collectionCell.updateConfiguration(using: collectionCell.configurationState)
        case let headerFooter as UITableViewHeaderFooterView:
            headerFooter.setNeedsUpdateConfiguration()
            headerFooter.updateConfiguration(using: headerFooter.configurationState)
            if let configuration = headerFooter.contentConfiguration {
                headerFooter.contentConfiguration = nil
                headerFooter.contentConfiguration = configuration
            }
        default:
            break
        }
    }

}
#endif
