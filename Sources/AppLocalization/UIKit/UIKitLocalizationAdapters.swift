#if canImport(UIKit)
import UIKit

/// 为需要在区域设置变化时刷新可见文本的 UIKit 视图控制器提供接口。
///
/// UIKit 的 `UILabel.text`、按钮标题和导航标题等值不会像 SwiftUI 一样自动根据
/// 环境重新计算，因此实现者必须显式更新这些值。
@MainActor
public protocol LocalizedContentUpdating: AnyObject {
    /// 重新加载接收者显示的所有本地化文本。
    func reloadLocalizedContent()
}

/// 为需要响应布局方向变化的 UIKit 对象提供接口。
///
/// 视图控制器可更新列表/集合视图布局、手势边缘和自定义动画方向；自定义 cell、
/// header 和 footer 可用它刷新显式设置的 `semanticContentAttribute` 和内部布局。
@MainActor
public protocol UserInterfaceLayoutDirectionUpdating: AnyObject {
    /// 使用指定的 UIKit 布局方向刷新接收者。
    ///
    /// - Parameter direction: 要应用的界面布局方向。
    func reloadLayoutDirection(_ direction: UIUserInterfaceLayoutDirection)
}

/// 为无法原地刷新的已呈现内容提供重建接口。
///
/// `UIAlertController`、菜单、上下文菜单和第三方 SDK 弹窗等内容通常无法可靠地
/// 原地替换文本。此类视图控制器可实现该协议以提供重建或降级策略。
@MainActor
public protocol PresentedLocalizationBoundaryRebuilding: AnyObject {
    /// 根据本地化变更重建已呈现内容，或应用降级策略。
    ///
    /// - Parameter change: 触发重建的本地化变更。
    func rebuildPresentedBoundary(for change: LocalizationChange)
}

public extension AppUserInterfaceLayoutDirection {
    /// 对应的 UIKit `UIUserInterfaceLayoutDirection`。
    var uiLayoutDirection: UIUserInterfaceLayoutDirection {
        self == .rightToLeft ? .rightToLeft : .leftToRight
    }

    /// 对应的 UIKit 强制语义内容属性。
    ///
    /// 使用 `.forceLeftToRight` 或 `.forceRightToLeft` 可使应用内选择的方向
    /// 明确覆盖系统语言方向。
    var semanticContentAttribute: UISemanticContentAttribute {
        self == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
    }
}

public extension UIUserInterfaceLayoutDirection {
    /// 对应的应用布局方向。
    var appLayoutDirection: AppUserInterfaceLayoutDirection {
        self == .rightToLeft ? .rightToLeft : .leftToRight
    }
}

/// 将本地化变更分发到所有已连接窗口场景的协调器。
///
/// 协调器会遍历每个窗口的根视图控制器、子视图控制器、导航栈、标签页和
/// 已呈现层级。
/// 此类型不依赖单一关键窗口，因此支持 iPad 多窗口、外接显示器和台前调度。
@MainActor
public final class UIWindowSceneLocalizationCoordinator {
    private let application: UIApplication
    private let presentedBoundaryHandler: ((UIViewController, LocalizationChange) -> Bool)?

    /// 使用指定应用实例创建协调器。
    ///
    /// - Parameters:
    ///   - application: 默认使用 `.shared`，测试或特殊宿主可注入。
    ///   - presentedBoundaryHandler: 处理已呈现视图控制器的可选闭包。返回 `true` 时，
    ///     协调器会关闭该视图控制器并停止遍历其层级。
    public init(
        application: UIApplication,
        presentedBoundaryHandler: ((UIViewController, LocalizationChange) -> Bool)? = nil
    ) {
        self.application = application
        self.presentedBoundaryHandler = presentedBoundaryHandler
    }

    /// 使用 `UIApplication.shared` 创建协调器。
    ///
    /// - Parameter presentedBoundaryHandler: 处理已呈现视图控制器的可选闭包。
    public convenience init(
        presentedBoundaryHandler: ((UIViewController, LocalizationChange) -> Bool)? = nil
    ) {
        self.init(
            application: .shared,
            presentedBoundaryHandler: presentedBoundaryHandler
        )
    }

    /// 刷新所有已连接窗口场景中的可见窗口。
///
    /// 通常在监听 `LocalizationController.localizationDidChangeNotification` 时调用此方法。
    /// 默认行为是原地刷新。当系统界面或布局方向变化需要完整刷新时，可选择重建
    /// 根视图控制器。重建过程使用淡出快照减少闪烁。
///
    /// `updateAppearanceProxies` 默认为 `false`。运行时切换语言时，协调器优先更新窗口、
    /// 根视图控制器和已加载界面，不修改 `UIView.appearance()` 的全局默认值。
    ///
    /// ```swift
    /// UIWindowSceneLocalizationCoordinator().reloadAllScenes(
    ///     for: change,
    ///     rebuildRootWindows: change.layoutDirectionChanged,
    ///     animateRootRebuild: true,
    ///     updateAppearanceProxies: false
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - change: 要分发的本地化变更。
    ///   - rebuildRootWindows: 是否重建每个窗口的根视图控制器。
    ///   - animateRootRebuild: 是否使用淡出快照过渡根视图控制器重建。
    ///   - updateAppearanceProxies: 是否更新 UIKit 外观代理的全局布局方向。
    public func reloadAllScenes(
        for change: LocalizationChange,
        rebuildRootWindows: Bool = false,
        animateRootRebuild: Bool = true,
        updateAppearanceProxies: Bool = false
    ) {
        let direction = change.currentLocale.layoutDirection.uiLayoutDirection
        let scenes = application.connectedScenes.compactMap { $0 as? UIWindowScene }

        // 外观代理是全局默认值，只影响之后创建的 UIKit 视图。SwiftUI 根视图可能延迟
        // 创建 UIKit 宿主视图；运行时更新代理会使不同批次的方向状态混入同一视图树。
        // 纯 UIKit 应用如需让后续视图继承方向，可显式启用 `updateAppearanceProxies`。
        if change.layoutDirectionChanged && updateAppearanceProxies {
            applyGlobalLayoutDirection(change.currentLocale)
        }

        for scene in scenes {
            for window in scene.windows where !window.isHidden {
                window.semanticContentAttribute = change.currentLocale.layoutDirection.semanticContentAttribute
                var visited = Set<ObjectIdentifier>()
                reloadTree(
                    from: window.rootViewController,
                    change: change,
                    direction: direction,
                    visited: &visited
                )

                if rebuildRootWindows {
                    rebuildRootWindow(
                        window,
                        animated: animateRootRebuild && scene.activationState == .foregroundActive
                    )
                }
            }
        }
    }

    /// 更新 UIKit 外观代理的全局语义方向。
///
    /// 此方法只影响之后创建的视图。已存在的界面仍需实现
    /// `UserInterfaceLayoutDirectionUpdating`，或在必要时重建根视图控制器。
///
    /// - Important: 此方法修改全局默认值，而非执行局部刷新。在 SwiftUI 混合层级中，
    ///   同时更新外观代理、窗口语义方向和 SwiftUI 环境，可能使延迟创建的 UIKit 宿主视图
    ///   获得不同批次的方向状态。建议仅在纯 UIKit 应用或启动阶段使用。
    ///
    /// ```swift
    /// UIWindowSceneLocalizationCoordinator().applyGlobalLayoutDirection(
    ///     localizationController.currentLocale
    /// )
    /// ```
    ///
    /// - Parameter locale: 用于确定全局布局方向的区域设置。
    public func applyGlobalLayoutDirection(_ locale: AppLocale) {
        UIView.appearance().semanticContentAttribute = locale.layoutDirection.semanticContentAttribute
    }

    /// 通过重设根视图控制器，使系统容器重新读取布局方向和外观。
    ///
    /// 此回退方案适用于导航栏、标签栏或复杂 UIKit 容器无法原地刷新的场景。
    /// 快照淡出用于减少重设根视图控制器时的闪烁。
    private func rebuildRootWindow(_ window: UIWindow, animated: Bool) {
        let snapshot = animated ? window.snapshotView(afterScreenUpdates: false) : nil
        let currentRootViewController = window.rootViewController

        window.rootViewController = nil
        window.rootViewController = currentRootViewController

        guard let snapshot else { return }

        window.addSubview(snapshot)
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState],
            animations: {
                snapshot.alpha = 0
            },
            completion: { _ in
                snapshot.removeFromSuperview()
            }
        )
    }

    /// 递归刷新视图控制器树。
    ///
    /// `visited` 防止自定义容器或异常层级形成循环。遍历范围包括普通子视图控制器、
    /// `UINavigationController` 栈、`UITabBarController` 子控制器和已呈现层级。
    private func reloadTree(
        from viewController: UIViewController?,
        change: LocalizationChange,
        direction: UIUserInterfaceLayoutDirection,
        visited: inout Set<ObjectIdentifier>
    ) {
        guard let viewController else { return }

        let identifier = ObjectIdentifier(viewController)
        guard visited.insert(identifier).inserted else { return }

        // 导航栈可能包含尚未加载视图的离屏界面。不要为了语言刷新主动加载它们：
        // 它们应在自己的 `viewDidLoad` 中读取当前区域设置，而已经加载的离屏界面
        // 仍需要在返回前刷新。
        if viewController.isViewLoaded {
            (viewController as? LocalizedContentUpdating)?.reloadLocalizedContent()
            if change.layoutDirectionChanged {
                viewController.viewIfLoaded?.semanticContentAttribute = change.currentLocale
                    .layoutDirection
                    .semanticContentAttribute
                (viewController as? UserInterfaceLayoutDirectionUpdating)?.reloadLayoutDirection(direction)
            }
        }

        if let navigationController = viewController as? UINavigationController {
            for child in navigationController.viewControllers {
                reloadTree(from: child, change: change, direction: direction, visited: &visited)
            }
        }

        if let tabBarController = viewController as? UITabBarController {
            for child in tabBarController.viewControllers ?? [] {
                reloadTree(from: child, change: change, direction: direction, visited: &visited)
            }
        }

        for child in viewController.children {
            reloadTree(from: child, change: change, direction: direction, visited: &visited)
        }

        if let presented = viewController.presentedViewController {
            if presentedBoundaryHandler?(presented, change) == true {
                presented.dismiss(animated: false)
            } else if let rebuildable = presented as? PresentedLocalizationBoundaryRebuilding {
                rebuildable.rebuildPresentedBoundary(for: change)
            } else {
                reloadTree(from: presented, change: change, direction: direction, visited: &visited)
            }
        }
    }
}

/// 导航按钮的语义位置。
///
/// 使用前缘和后缘表达意图，再根据布局方向映射到 UIKit 的物理左侧或右侧。
public enum NavigationItemPlacement: Equatable, Sendable {
    /// 导航栏的语义前缘。
    case leading

    /// 导航栏的语义后缘。
    case trailing
}

public extension UINavigationItem {
    /// 在指定的语义位置设置导航栏按钮。
    ///
    /// 自定义导航栏按钮需要随布局方向镜像时，建议统一使用此方法。
    ///
    /// ```swift
    /// navigationItem.setBarButtonItem(
    ///     closeItem,
    ///     side: .trailing,
    ///     layoutDirection: view.effectiveUserInterfaceLayoutDirection
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - item: 要设置的导航栏按钮。传入 `nil` 可清除对应位置的按钮。
    ///   - side: 按钮的语义位置。
    ///   - layoutDirection: 当前 UIKit 布局方向。
    func setBarButtonItem(
        _ item: UIBarButtonItem?,
        side: NavigationItemPlacement,
        layoutDirection: UIUserInterfaceLayoutDirection
    ) {
        let physicalEdge = DirectionalLayout.physicalEdge(
            for: side.semanticDirection,
            layoutDirection: layoutDirection.appLayoutDirection
        )

        switch physicalEdge {
        case .left:
            if let item, rightBarButtonItem === item {
                rightBarButtonItem = nil
            }
            leftBarButtonItem = item
        case .right:
            if let item, leftBarButtonItem === item {
                leftBarButtonItem = nil
            }
            rightBarButtonItem = item
        }
    }
}

private extension NavigationItemPlacement {
    var semanticDirection: SemanticHorizontalDirection {
        switch self {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        }
    }
}

public extension DirectionalLayout {
    /// 返回自定义交互式出栈手势应监听的 `UIRectEdge`。
    ///
    /// ```swift
    /// edgePan.edges = DirectionalLayout.backSwipeRectEdge(
    ///     layoutDirection: localizationController.layoutDirection
    /// )
    /// ```
    ///
    /// - Parameter layoutDirection: 当前应用布局方向。
    /// - Returns: 返回手势应监听的物理矩形边缘。
    static func backSwipeRectEdge(layoutDirection: AppUserInterfaceLayoutDirection) -> UIRectEdge {
        switch backSwipeEdge(layoutDirection: layoutDirection) {
        case .left:
            return .left
        case .right:
            return .right
        }
    }

    /// 返回自定义返回按钮应该使用的 SF Symbol 名称。
    ///
    /// ```swift
    /// backButton.image = UIImage(
    ///     systemName: DirectionalLayout.backChevronSystemName(
    ///         layoutDirection: localizationController.layoutDirection
    ///     )
    /// )
    /// ```
    ///
    /// - Parameter layoutDirection: 当前应用布局方向。
    /// - Returns: 与返回方向匹配的 SF Symbol 名称。
    static func backChevronSystemName(layoutDirection: AppUserInterfaceLayoutDirection) -> String {
        switch backSwipeEdge(layoutDirection: layoutDirection) {
        case .left:
            return "chevron.left"
        case .right:
            return "chevron.right"
        }
    }
}

public extension UITableView {
    /// 应用布局方向、刷新表格布局，并按需保留当前逻辑行。
    ///
    /// 表格视图通常沿垂直方向滚动，因此 LTR/RTL 切换不需要像横向集合视图一样
    /// 反转滚动位置。如果布局变化影响行的位置，此方法会使用最上方可见行及其
    /// 相对位置作为锚点。
    ///
    /// ```swift
    /// func reloadLayoutDirection(_ direction: UIUserInterfaceLayoutDirection) {
    ///     tableView.applyUserInterfaceLayoutDirection(
    ///         direction.appLayoutDirection,
    ///         preservingVisibleRow: true
    ///     )
    /// }
    /// ```
    ///
    /// 此方法不会调用 `reloadData()`，因此可以与 `UITableViewDiffableDataSource` 一起
    /// 使用。当前可见的 cell 和 section header/footer 会刷新方向回调、configuration、
    /// 约束和布局；`tableHeaderView` 与 `tableFooterView` 也会刷新方向回调、约束和布局。
    /// 需要替换本地化内容时，仍应由调用方通过当前 data source 刷新。对于 diffable
    /// data source，优先在 snapshot 中使用 `reconfigureItems(_:)`。如果 snapshot 异步
    /// 应用、使用动画或改变行顺序/高度，请在 snapshot completion 中再次调用此方法。
    ///
    /// cell 不必实现 `UserInterfaceLayoutDirectionUpdating`：使用 `.unspecified` semantic、
    /// leading/trailing 约束或在布局时读取 `effectiveUserInterfaceLayoutDirection` 的 cell
    /// 会自动响应。只有显式强制子视图方向、缓存方向或维护自定义左右状态的 reusable
    /// view，才需要实现该协议。
    ///
    /// - Parameters:
    ///   - layoutDirection: 要应用的布局方向。
    ///   - shouldPreserveVisibleRow: 是否在布局刷新后保持最上方可见的逻辑行及其相对位置。
    func applyUserInterfaceLayoutDirection(
        _ layoutDirection: AppUserInterfaceLayoutDirection,
        preservingVisibleRow shouldPreserveVisibleRow: Bool = true
    ) {
        let visibleRowAnchor: (indexPath: IndexPath, offsetFromViewportTop: CGFloat)? = {
            guard shouldPreserveVisibleRow,
                  let indexPath = indexPathsForVisibleRows?.sorted().first else {
                return nil
            }

            return (
                indexPath: indexPath,
                offsetFromViewportTop: rectForRow(at: indexPath).minY - contentOffset.y
            )
        }()

        semanticContentAttribute = layoutDirection.semanticContentAttribute
        refreshVisibleContent(for: layoutDirection.uiLayoutDirection)
        setNeedsLayout()
        layoutIfNeeded()

        guard let visibleRowAnchor,
              containsRow(at: visibleRowAnchor.indexPath) else {
            return
        }

        let proposedOffsetY = rectForRow(at: visibleRowAnchor.indexPath).minY
            - visibleRowAnchor.offsetFromViewportTop
        let minimumOffsetY = -adjustedContentInset.top
        let maximumOffsetY = max(
            minimumOffsetY,
            contentSize.height - bounds.height + adjustedContentInset.bottom
        )
        var restoredContentOffset = contentOffset
        restoredContentOffset.y = min(max(proposedOffsetY, minimumOffsetY), maximumOffsetY)
        setContentOffset(restoredContentOffset, animated: false)
    }

    private func refreshVisibleContent(for layoutDirection: UIUserInterfaceLayoutDirection) {
        for cell in visibleCells {
            (cell as? UserInterfaceLayoutDirectionUpdating)?.reloadLayoutDirection(layoutDirection)
            cell.setNeedsUpdateConfiguration()
            cell.setNeedsUpdateConstraints()
            cell.contentView.setNeedsUpdateConstraints()
            cell.setNeedsLayout()
            cell.contentView.setNeedsLayout()
        }

        for section in 0..<numberOfSections {
            let visibleSupplementaryViews = [
                headerView(forSection: section),
                footerView(forSection: section)
            ]

            for view in visibleSupplementaryViews.compactMap({ $0 }) {
                (view as? UserInterfaceLayoutDirectionUpdating)?.reloadLayoutDirection(layoutDirection)
                view.setNeedsUpdateConfiguration()
                view.setNeedsUpdateConstraints()
                view.setNeedsLayout()
            }
        }

        for view in [tableHeaderView, tableFooterView].compactMap({ $0 }) {
            (view as? UserInterfaceLayoutDirectionUpdating)?.reloadLayoutDirection(layoutDirection)
            view.setNeedsUpdateConstraints()
            view.setNeedsLayout()
        }
    }

    private func containsRow(at indexPath: IndexPath) -> Bool {
        indexPath.section >= 0
            && indexPath.section < numberOfSections
            && indexPath.row >= 0
            && indexPath.row < numberOfRows(inSection: indexPath.section)
    }
}

public extension UICollectionView {
    /// 应用布局方向、使集合视图布局失效，并按需保留当前逻辑项目。
    ///
    /// 横向列表、分页轮播和依赖语义边缘的布局，均可在 `reloadLayoutDirection(_:)`
    /// 中调用此方法。切换方向时不应直接复用旧 `contentOffset`，因为物理偏移在不同
    /// 布局方向下含义不同；保留 `IndexPath` 更符合用户意图。
    ///
    /// ```swift
    /// func reloadLayoutDirection(_ direction: UIUserInterfaceLayoutDirection) {
    ///     collectionView.applyUserInterfaceLayoutDirection(
    ///         direction.appLayoutDirection,
    ///         preservingVisibleItem: true
    ///     )
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - layoutDirection: 要应用的布局方向。
    ///   - shouldPreserveVisibleItem: 是否在布局失效后保持当前可见的逻辑项目。
    func applyUserInterfaceLayoutDirection(
        _ layoutDirection: AppUserInterfaceLayoutDirection,
        preservingVisibleItem shouldPreserveVisibleItem: Bool = true
    ) {
        let visibleIndexPath = shouldPreserveVisibleItem
            ? indexPathsForVisibleItems.sorted().first
            : nil
        // 旧偏移使用物理坐标，切换方向后含义会反转，因此这里保留逻辑 `IndexPath`。
        // 首次布局没有可见项目时，定位到第一个逻辑项目，避免从右向左布局
        // 停在物理左端。
        let targetIndexPath = visibleIndexPath ?? (shouldPreserveVisibleItem ? firstItemIndexPathForDirectionReset() : nil)

        semanticContentAttribute = layoutDirection.semanticContentAttribute
        collectionViewLayout.invalidateLayout()
        // 布局失效后立即执行布局，确保滚动操作使用新方向下的布局属性。
        layoutIfNeeded()

        if let targetIndexPath {
            scrollToItem(
                at: targetIndexPath,
                // 从右向左布局的逻辑起点在右侧，从左向右布局的逻辑起点在左侧。
                at: layoutDirection == .rightToLeft ? .right : .left,
                animated: false
            )
        }
    }

    private func firstItemIndexPathForDirectionReset() -> IndexPath? {
        for section in 0..<numberOfSections {
            if numberOfItems(inSection: section) > 0 {
                return IndexPath(item: 0, section: section)
            }
        }

        return nil
    }
}
#endif
