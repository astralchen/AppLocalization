#if canImport(UIKit)
import UIKit

/// 重建无法原地更新的已呈现内容的接口。
///
/// 用于应用拥有且需要关闭或重建的呈现边界，例如警告框或第三方界面的包装控制器。
@MainActor
public protocol PresentedLocalizationBoundaryRebuilding: AnyObject {
    /// 重建已呈现内容或应用适当的回退方案。
    ///
    /// 协调器调用此方法后，不再遍历该呈现子树。
    /// 实现方负责更新或替换其中的内容。
    ///
    /// - Parameter update: 要应用的本地化状态和刷新原因。
    func rebuildPresentedBoundary(for update: UIKitLocalizationUpdate)
}

/// 窗口内容无法原地更新时采用的恢复操作。
public enum UIWindowLocalizationRecoveryAction: Equatable, Sendable {
    /// 保留现有根视图层级，并原地应用更新。
    case none

    /// 分离并重新挂载现有根视图控制器。
    case reattachExistingRoot

    /// 使用已注册的工厂替换根视图控制器。
    ///
    /// 此操作要求已注册工厂，并会丢弃现有根视图层级。
    case recreateRoot
}

/// 向应用拥有的窗口分发本地化更新的对象。
///
/// 注册应用拥有的每个窗口，在场景断开连接时取消注册，在场景激活时同步状态。
/// 调用方需将控制器的变更通知转发给协调器；协调器自身不监听通知。
///
/// 协调器遍历公开容器和已呈现控制器的层级。仅已加载的视图接收准备和应用回调。
/// 对于无法原地更新的内容，可显式选择根视图恢复操作作为回退方案。
@MainActor
public final class UIWindowSceneLocalizationCoordinator {
    /// 根据本地化快照创建根视图控制器的闭包。
    ///
    /// 协调器在窗口注册信息中持有此闭包，仅在请求重新创建根控制器时调用。
    public typealias RootViewControllerFactory = @MainActor (
        LocalizationSnapshot
    ) -> UIViewController
    /// 窗口接收更新后选择恢复操作的闭包。
    ///
    /// 参数依次为正在更新的窗口和已应用的本地化状态。
    public typealias RecoveryActionProvider = @MainActor (
        UIWindow,
        UIKitLocalizationUpdate
    ) -> UIWindowLocalizationRecoveryAction
    /// 返回是否应向已发现窗口分发更新的闭包。
    public typealias WindowSelection = @MainActor (UIWindow) -> Bool

    private final class WindowRegistration {
        weak var window: UIWindow?
        let rootViewControllerFactory: RootViewControllerFactory?

        init(
            window: UIWindow,
            rootViewControllerFactory: RootViewControllerFactory?
        ) {
            self.window = window
            self.rootViewControllerFactory = rootViewControllerFactory
        }
    }

    private let localizationController: LocalizationController
    private let presentedBoundaryHandler: ((UIViewController, UIKitLocalizationUpdate) -> Bool)?
    private var registrations: [ObjectIdentifier: WindowRegistration] = [:]

    /// 为指定本地化控制器创建窗口协调器。
    ///
    /// - Parameters:
    ///   - localizationController: 提供当前本地化状态的控制器。
    ///   - presentedBoundaryHandler: 处理已呈现控制器的可选闭包。返回 `true` 时，
    ///     协调器以无动画方式关闭该控制器并跳过其子树；返回 `false` 时继续常规处理。
    public init(
        localizationController: LocalizationController,
        presentedBoundaryHandler: ((UIViewController, UIKitLocalizationUpdate) -> Bool)? = nil
    ) {
        self.localizationController = localizationController
        self.presentedBoundaryHandler = presentedBoundaryHandler
    }

    /// 注册应用拥有的窗口，并立即应用当前状态。
    ///
    /// 协调器弱引用窗口。再次注册同一窗口会替换其工厂，并重新应用初始更新。
    ///
    /// - Parameters:
    ///   - window: 要管理的应用窗口。
    ///   - rootViewControllerFactory: 执行 `.recreateRoot` 恢复时使用并持有的工厂。
    ///     默认值为 `nil`；重新创建根控制器要求提供工厂。
    public func register(
        window: UIWindow,
        rootViewControllerFactory: RootViewControllerFactory? = nil
    ) {
        registrations[ObjectIdentifier(window)] = WindowRegistration(
            window: window,
            rootViewControllerFactory: rootViewControllerFactory
        )
        apply(
            .initial(snapshot: localizationController.currentSnapshot),
            to: registrations[ObjectIdentifier(window)]!
        )
    }

    /// 停止管理指定窗口。
    ///
    /// 在窗口所属场景断开连接时调用。
    ///
    /// - Parameter window: 要取消注册的窗口。
    public func unregister(window: UIWindow) {
        registrations.removeValue(forKey: ObjectIdentifier(window))
    }

    /// 使用当前本地化状态同步已注册窗口的方向。
    ///
    /// 在场景激活时调用。此方法发送挂载更新，请求方向刷新，但不请求本地化内容刷新。
    /// 未注册的窗口会被忽略。
    ///
    /// - Parameter window: 要同步的已注册窗口。
    public func synchronize(window: UIWindow) {
        guard let registration = registrations[ObjectIdentifier(window)] else {
            return
        }
        apply(
            .attachment(snapshot: localizationController.currentSnapshot),
            to: registration
        )
    }

    /// 向所有已注册窗口应用本地化变更。
    ///
    /// 变更的当前版本与控制器版本不一致时，忽略此次变更。
    /// 默认原地更新已加载内容。恢复策略闭包可请求在更新后重新挂载或创建根控制器。
    ///
    /// - Parameters:
    ///   - change: 要应用的本地化变更。
    ///   - animated: 指示根视图恢复是否使用快照淡出过渡的布尔值。默认值为 `true`。
    ///   - recoveryAction: 为每个窗口选择恢复操作的可选闭包。
    ///     为 `nil` 时不执行根视图恢复。
    public func apply(
        _ change: LocalizationChange,
        animated: Bool = true,
        recoveryAction: RecoveryActionProvider? = nil
    ) {
        guard change.current.revision == localizationController.currentSnapshot.revision else {
            return
        }

        let update = UIKitLocalizationUpdate.change(change)
        registrations = registrations.filter { $0.value.window != nil }
        for registration in registrations.values {
            apply(update, to: registration)
            guard let window = registration.window else { continue }
            recover(
                window,
                registration: registration,
                update: update,
                action: recoveryAction?(window, update) ?? .none,
                animated: animated
            )
        }
    }

    /// 向所有已连接窗口场景中选中的窗口应用变更。
    ///
    /// 常规更新应优先使用显式窗口注册。此方法仅为本次调用发现已连接场景的窗口，
    /// 不会注册这些窗口。应提供筛选闭包，仅选择应用拥有的窗口，排除系统或第三方窗口。
    /// 版本过期的变更会被忽略。
    ///
    /// - Parameters:
    ///   - change: 要应用的本地化变更。
    ///   - animated: 指示根视图恢复是否使用快照淡出过渡的布尔值。默认值为 `true`。
    ///   - shouldIncludeWindow: 为需要更新的窗口返回 `true` 的闭包。
    ///     默认包含所有发现的窗口。
    ///   - recoveryAction: 可选的恢复策略闭包。重新创建根控制器要求已为所选窗口注册工厂。
    public func reloadAllScenes(
        for change: LocalizationChange,
        animated: Bool = true,
        including shouldIncludeWindow: WindowSelection = { _ in true },
        recoveryAction: RecoveryActionProvider? = nil
    ) {
        let connectedWindows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        reload(
            change,
            windows: connectedWindows,
            animated: animated,
            including: shouldIncludeWindow,
            recoveryAction: recoveryAction
        )
    }

    func reload(
        _ change: LocalizationChange,
        windows: [UIWindow],
        animated: Bool = true,
        including shouldIncludeWindow: WindowSelection = { _ in true },
        recoveryAction: RecoveryActionProvider? = nil
    ) {
        guard change.current.revision
            == localizationController.currentSnapshot.revision else {
            return
        }

        let update = UIKitLocalizationUpdate.change(change)
        registrations = registrations.filter { $0.value.window != nil }

        for window in windows where shouldIncludeWindow(window) {
            let registration = registrations[ObjectIdentifier(window)]
                ?? WindowRegistration(
                    window: window,
                    rootViewControllerFactory: nil
                )
            apply(update, to: registration)
            recover(
                window,
                registration: registration,
                update: update,
                action: recoveryAction?(window, update) ?? .none,
                animated: animated
            )
        }
    }

    private func apply(
        _ update: UIKitLocalizationUpdate,
        to registration: WindowRegistration
    ) {
        guard let window = registration.window else { return }
        var prepared = Set<ObjectIdentifier>()
        prepare(update, from: window.rootViewController, visited: &prepared)
        if update.requiresLayoutDirectionRefresh {
            window.semanticContentAttribute = update.semanticContentAttribute
        }
        var visited = Set<ObjectIdentifier>()
        apply(
            update,
            from: window.rootViewController,
            visited: &visited
        )
    }

    private func recover(
        _ window: UIWindow,
        registration: WindowRegistration,
        update: UIKitLocalizationUpdate,
        action: UIWindowLocalizationRecoveryAction,
        animated: Bool
    ) {
        guard action != .none else { return }
        let snapshot = animated ? window.snapshotView(afterScreenUpdates: false) : nil

        switch action {
        case .none:
            break
        case .reattachExistingRoot:
            let currentRootViewController = window.rootViewController
            window.rootViewController = nil
            window.rootViewController = currentRootViewController
        case .recreateRoot:
            guard let factory = registration.rootViewControllerFactory else {
                assertionFailure("recreateRoot requires a registered root factory")
                return
            }
            window.rootViewController = factory(update.snapshot)
        }

        // 根视图恢复后重新解析方向。保留原始更新原因，
        // 使恢复后的层级同时接收所需的内容刷新请求。
        apply(
            UIKitLocalizationUpdate(
                snapshot: update.snapshot,
                reasons: update.reasons.union(.attachment)
            ),
            to: registration
        )

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

    /// 沿公开容器和已呈现控制器层级应用更新。
    ///
    /// 跟踪控制器身份，避免重叠层级导致重复回调。
    private func apply(
        _ update: UIKitLocalizationUpdate,
        from viewController: UIViewController?,
        visited: inout Set<ObjectIdentifier>
    ) {
        guard let viewController else { return }

        let identifier = ObjectIdentifier(viewController)
        guard visited.insert(identifier).inserted else { return }

        if viewController.isViewLoaded {
            if update.requiresLayoutDirectionRefresh {
                viewController.viewIfLoaded?.semanticContentAttribute = update
                    .semanticContentAttribute
                applyContainerDirection(update, to: viewController)
            }
            (viewController as? UIKitLocalizationApplying)?
                .applyLocalization(update)
        }

        for child in containedControllers(of: viewController) {
            apply(update, from: child, visited: &visited)
        }

        if let presented = viewController.presentedViewController {
            if presentedBoundaryHandler?(presented, update) == true {
                presented.dismiss(animated: false)
            } else if let rebuildable = presented as? PresentedLocalizationBoundaryRebuilding {
                rebuildable.rebuildPresentedBoundary(for: update)
            } else {
                apply(update, from: presented, visited: &visited)
            }
        }
    }

    private func prepare(
        _ update: UIKitLocalizationUpdate,
        from viewController: UIViewController?,
        visited: inout Set<ObjectIdentifier>
    ) {
        guard let viewController,
              visited.insert(ObjectIdentifier(viewController)).inserted else { return }
        if viewController.isViewLoaded {
            (viewController as? UIKitLocalizationPreparing)?.prepareForLocalization(update)
        }
        for child in containedControllers(of: viewController) {
            prepare(update, from: child, visited: &visited)
        }
        prepare(update, from: viewController.presentedViewController, visited: &visited)
    }

    /// 返回准备阶段和应用阶段共同使用的容器成员。
    private func containedControllers(of controller: UIViewController) -> [UIViewController] {
        var children = controller.children
        if let navigation = controller as? UINavigationController {
            children += navigation.viewControllers
        }
        if let tabs = controller as? UITabBarController {
            children += tabs.viewControllers ?? []
        }
        return children
    }

    private func applyContainerDirection(
        _ update: UIKitLocalizationUpdate,
        to viewController: UIViewController
    ) {
        if let navigationController = viewController as? UINavigationController {
            // 在子控制器回调前更新容器特征，使导航标题采用应用方向。
            if #available(iOS 17.0, *) {
                navigationController.traitOverrides.layoutDirection =
                    update.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
            }
            navigationController.view.semanticContentAttribute = update.semanticContentAttribute
            navigationController.navigationBar.semanticContentAttribute = update.semanticContentAttribute
        }
        if let tabBarController = viewController as? UITabBarController {
            // 在子控制器回调前同步特征。仅更新语义属性不会改变方向特征，
            // 也不会重置浮动标签栏缓存的几何布局。
            if #available(iOS 17.0, *) {
                tabBarController.traitOverrides.layoutDirection =
                    update.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
            }
            tabBarController.view.semanticContentAttribute = update.semanticContentAttribute
            tabBarController.tabBar.semanticContentAttribute = update.semanticContentAttribute
        }
        if let splitViewController = viewController as? UISplitViewController {
            splitViewController.view.semanticContentAttribute = update.semanticContentAttribute
        }
        if let pageViewController = viewController as? UIPageViewController {
            pageViewController.view.semanticContentAttribute = update.semanticContentAttribute
        }
    }
}
#endif
