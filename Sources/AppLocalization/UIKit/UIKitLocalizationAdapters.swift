#if canImport(UIKit)
import UIKit

/// UIKit 页面实现此协议后，可以在 locale 变化时重设所有可见文案。
///
/// UIKit 的 `UILabel.text`、`UIButton` title、`navigationItem.title` 等都是
/// 命令式赋值，不会像 SwiftUI 一样自动跟随环境重算，因此需要显式 reload。
@MainActor
public protocol LocalizedContentUpdating: AnyObject {
    /// 重设页面内所有本地化文案。
    func reloadLocalizedContent()
}

/// 方向敏感的 UIKit 页面实现此协议。
///
/// 只有 LTR/RTL 发生变化时才会调用，用于更新 `semanticContentAttribute`、
/// collection layout、手势边缘、自定义动画方向等。
@MainActor
public protocol UserInterfaceLayoutDirectionUpdating: AnyObject {
    /// 按新的 UIKit layout direction 刷新方向相关 UI。
    func reloadLayoutDirection(_ direction: UIUserInterfaceLayoutDirection)
}

/// 对无法原地刷新的 presented 内容提供重建钩子。
///
/// `UIAlertController`、菜单、context menu、第三方 SDK 弹窗等通常不能可靠地
/// 原地替换文案，可以实现该协议或通过 coordinator 的 handler 选择 dismiss
/// 后重建，或约定下次展示时生效。
@MainActor
public protocol PresentedLocalizationBoundaryRebuilding: AnyObject {
    /// 处理 presented 边界的重建或降级策略。
    func rebuildPresentedBoundary(for change: LocalizationChange)
}

public extension AppUserInterfaceLayoutDirection {
    /// 转成 UIKit 的 `UIUserInterfaceLayoutDirection`。
    var uiLayoutDirection: UIUserInterfaceLayoutDirection {
        self == .rightToLeft ? .rightToLeft : .leftToRight
    }

    /// 转成 UIKit 的强制 semantic content attribute。
    ///
    /// 使用 `.forceLeftToRight` / `.forceRightToLeft` 是为了让 App 内选择的方向
    /// 明确覆盖系统语言方向。
    var semanticContentAttribute: UISemanticContentAttribute {
        self == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
    }
}

public extension UIUserInterfaceLayoutDirection {
    /// 从 UIKit layout direction 转回框架内部方向类型。
    var appLayoutDirection: AppUserInterfaceLayoutDirection {
        self == .rightToLeft ? .rightToLeft : .leftToRight
    }
}

/// 负责把一次本地化变化分发到所有 `UIWindowScene`。
///
/// 不使用 `keyWindow`，因为 iPad 多窗口、外接显示器、Stage Manager 等场景
/// 可能同时存在多个 scene/window。coordinator 会遍历 root、children、
/// navigation stack、tab stack 和 presented chain。
@MainActor
public final class UIWindowSceneLocalizationCoordinator {
    private let application: UIApplication
    private let presentedBoundaryHandler: ((UIViewController, LocalizationChange) -> Bool)?

    /// 创建 coordinator。
    ///
    /// - Parameters:
    ///   - application: 默认使用 `.shared`，测试或特殊宿主可注入。
    ///   - presentedBoundaryHandler: 返回 `true` 时表示该 presented VC 已由
    ///     handler 处理，coordinator 会 dismiss 它并停止递归。
    public init(
        application: UIApplication,
        presentedBoundaryHandler: ((UIViewController, LocalizationChange) -> Bool)? = nil
    ) {
        self.application = application
        self.presentedBoundaryHandler = presentedBoundaryHandler
    }

    /// 使用 `UIApplication.shared` 创建 coordinator。
    public convenience init(
        presentedBoundaryHandler: ((UIViewController, LocalizationChange) -> Bool)? = nil
    ) {
        self.init(
            application: .shared,
            presentedBoundaryHandler: presentedBoundaryHandler
        )
    }

    /// 刷新所有 connected `UIWindowScene` 中的可见 window。
    ///
    /// 通常在 `LocalizationController.localizationDidChangeNotification` 的监听中调用。
    /// 默认路径是原地 reload；当系统 UI 或 RTL/LTR 切换需要更强刷新时，可以打开
    /// root-window rebuild。rebuild 会用快照淡出减少闪烁。
    ///
    /// `updateAppearanceProxies` 默认为 `false`：运行时切语言优先更新 window/root/页面，
    /// 不默认改 `UIView.appearance()` 这个全局默认值，避免 SwiftUI-root App 的懒创建
    /// UIKit 宿主 view 混入旧方向。UIKit-only App 确认需要时可显式打开。
    ///
    /// ```swift
    /// UIWindowSceneLocalizationCoordinator().reloadAllScenes(
    ///     for: change,
    ///     rebuildRootWindows: change.layoutDirectionChanged,
    ///     animateRootRebuild: true,
    ///     updateAppearanceProxies: false
    /// )
    /// ```
    public func reloadAllScenes(
        for change: LocalizationChange,
        rebuildRootWindows: Bool = false,
        animateRootRebuild: Bool = true,
        updateAppearanceProxies: Bool = false
    ) {
        let direction = change.currentLocale.layoutDirection.uiLayoutDirection
        let scenes = application.connectedScenes.compactMap { $0 as? UIWindowScene }

        // appearance proxy 是全局“默认值”，只影响之后创建的 UIKit view。
        // SwiftUI-root App 在运行时切语言时不建议默认更新它：List/NavigationView
        // 会懒创建 UIKit 宿主 view，多次随机切换可能把旧 proxy、SwiftUI environment
        // 和 window semantic 混进同一棵树。UIKit-only App 如需让后续新建 view
        // 继承方向，可以显式传 updateAppearanceProxies: true。
        if change.layoutDirectionChanged && updateAppearanceProxies {
            applyGlobalLayoutDirection(change.currentLocale)
        }

        for scene in scenes {
            for window in scene.windows where !window.isHidden {
                window.semanticContentAttribute = change.currentLocale.layoutDirection.semanticContentAttribute
                reloadTree(
                    from: window.rootViewController,
                    change: change,
                    direction: direction,
                    visited: []
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

    /// 更新 UIKit 全局 appearance 的 semantic 方向。
    ///
    /// 这只影响之后创建的 view。已经存在的页面仍需要实现
    /// `UserInterfaceLayoutDirectionUpdating`，或在必要时执行 root-window rebuild。
    ///
    /// 注意：它是全局默认值，不是一次局部刷新动作。SwiftUI 混合栈在运行时切换
    /// LTR/RTL 时，如果同时更新 appearance、window semantic 和 SwiftUI environment，
    /// SwiftUI 内部懒创建的 UIKit 宿主 view 可能拿到不同批次的方向状态。
    /// 因此示例 App 默认不在运行时调用它，只在 UIKit-only 或启动阶段需要统一默认值时使用。
    ///
    /// ```swift
    /// UIWindowSceneLocalizationCoordinator().applyGlobalLayoutDirection(
    ///     localizationController.currentLocale
    /// )
    /// ```
    public func applyGlobalLayoutDirection(_ locale: AppLocale) {
        UIView.appearance().semanticContentAttribute = locale.layoutDirection.semanticContentAttribute
    }

    /// 通过重设 rootViewController 触发系统容器 UI 重新读取方向和 appearance。
    ///
    /// 这是 fallback 手段，适合 NavigationBar、TabBar 或复杂 UIKit 容器无法原地
    /// 刷新的场景。快照淡出用于减少 root 置空再恢复时的闪烁。
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

    /// 递归刷新 view controller 树。
    ///
    /// `visited` 防止自定义容器或异常层级形成循环。递归顺序覆盖普通 children、
    /// `UINavigationController` 栈、`UITabBarController` 子控制器以及 presented 链。
    private func reloadTree(
        from viewController: UIViewController?,
        change: LocalizationChange,
        direction: UIUserInterfaceLayoutDirection,
        visited: Set<ObjectIdentifier>
    ) {
        guard let viewController else { return }

        let identifier = ObjectIdentifier(viewController)
        guard !visited.contains(identifier) else { return }
        var visited = visited
        visited.insert(identifier)

        (viewController as? LocalizedContentUpdating)?.reloadLocalizedContent()
        if change.layoutDirectionChanged {
            viewController.view.semanticContentAttribute = change.currentLocale.layoutDirection.semanticContentAttribute
            (viewController as? UserInterfaceLayoutDirectionUpdating)?.reloadLayoutDirection(direction)
        }

        if let navigationController = viewController as? UINavigationController {
            navigationController.viewControllers.forEach {
                reloadTree(from: $0, change: change, direction: direction, visited: visited)
            }
        }

        if let tabBarController = viewController as? UITabBarController {
            tabBarController.viewControllers?.forEach {
                reloadTree(from: $0, change: change, direction: direction, visited: visited)
            }
        }

        viewController.children.forEach {
            reloadTree(from: $0, change: change, direction: direction, visited: visited)
        }

        if let presented = viewController.presentedViewController {
            if presentedBoundaryHandler?(presented, change) == true {
                presented.dismiss(animated: false)
            } else if let rebuildable = presented as? PresentedLocalizationBoundaryRebuilding {
                rebuildable.rebuildPresentedBoundary(for: change)
            } else {
                reloadTree(from: presented, change: change, direction: direction, visited: visited)
            }
        }
    }
}

/// 导航按钮的语义位置。
///
/// 使用 leading/trailing 表达意图，再根据 LTR/RTL 映射到 UIKit 的 left/right。
public enum NavigationItemPlacement: Equatable, Sendable {
    case leading
    case trailing
}

public extension UINavigationItem {
    /// 按语义位置设置导航按钮，而不是直接写 left/right。
    ///
    /// 自定义导航栏按钮如果需要 RTL 镜像，建议统一使用这个方法。
    ///
    /// ```swift
    /// navigationItem.setBarButtonItem(
    ///     closeItem,
    ///     side: .trailing,
    ///     layoutDirection: view.effectiveUserInterfaceLayoutDirection
    /// )
    /// ```
    func setBarButtonItem(
        _ item: UIBarButtonItem?,
        side: NavigationItemPlacement,
        layoutDirection: UIUserInterfaceLayoutDirection
    ) {
        switch (side, layoutDirection) {
        case (.leading, .leftToRight), (.trailing, .rightToLeft):
            leftBarButtonItem = item
        case (.trailing, .leftToRight), (.leading, .rightToLeft):
            rightBarButtonItem = item
        @unknown default:
            leftBarButtonItem = item
        }
    }
}

public extension DirectionalLayout {
    /// 返回自定义 interactive pop 手势应该监听的 `UIRectEdge`。
    ///
    /// ```swift
    /// edgePan.edges = DirectionalLayout.backSwipeRectEdge(
    ///     layoutDirection: localizationController.layoutDirection
    /// )
    /// ```
    static func backSwipeRectEdge(layoutDirection: AppUserInterfaceLayoutDirection) -> UIRectEdge {
        layoutDirection == .rightToLeft ? .right : .left
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
    static func backChevronSystemName(layoutDirection: AppUserInterfaceLayoutDirection) -> String {
        layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left"
    }
}

public extension UICollectionView {
    /// 应用 LTR/RTL 方向并 invalidate layout，同时尽量保留当前逻辑 item。
    ///
    /// 横向列表、分页 carousel、依赖 leading/trailing 几何的布局，都应在
    /// `reloadLayoutDirection(_:)` 中调用。切方向时不要直接复用旧 `contentOffset`，
    /// 因为物理偏移在 RTL/LTR 下含义不同；保留 indexPath 更接近用户意图。
    ///
    /// ```swift
    /// func reloadLayoutDirection(_ direction: UIUserInterfaceLayoutDirection) {
    ///     collectionView.applyUserInterfaceLayoutDirection(
    ///         direction.appLayoutDirection,
    ///         preservingVisibleItem: true
    ///     )
    /// }
    /// ```
    func applyUserInterfaceLayoutDirection(
        _ layoutDirection: AppUserInterfaceLayoutDirection,
        preservingVisibleItem shouldPreserveVisibleItem: Bool = true
    ) {
        let visibleIndexPath = shouldPreserveVisibleItem
            ? indexPathsForVisibleItems.sorted().first
            : nil
        // 修复点：切换 RTL/LTR 时不能复用旧 contentOffset。
        // 旧偏移是物理坐标，方向切换后含义会反转；这里保留逻辑 indexPath。
        // 如果首次布局还没有 visible item，就定位到第一个逻辑 item，避免 RTL 下停在物理左端。
        let targetIndexPath = visibleIndexPath ?? (shouldPreserveVisibleItem ? firstItemIndexPathForDirectionReset() : nil)

        semanticContentAttribute = layoutDirection.semanticContentAttribute
        collectionViewLayout.invalidateLayout()
        // invalidate 后先强制 layout，确保 scrollToItem 使用的是新方向下的布局属性。
        layoutIfNeeded()

        if let targetIndexPath {
            scrollToItem(
                at: targetIndexPath,
                // RTL 的逻辑起点在右侧，LTR 的逻辑起点在左侧。
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
