#if canImport(UIKit)
import UIKit

/// 触发一次 UIKit 本地化刷新的原因。
public struct UIKitLocalizationUpdateReason: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let initial = Self(rawValue: 1 << 0)
    public static let selection = Self(rawValue: 1 << 1)
    public static let locale = Self(rawValue: 1 << 2)
    public static let layoutDirection = Self(rawValue: 1 << 3)
    public static let attachment = Self(rawValue: 1 << 4)
    public static let configuration = Self(rawValue: 1 << 5)
}

/// UIKit 一次原子本地化刷新的不可变输入。
public struct UIKitLocalizationUpdate: Equatable, Sendable {
    public let snapshot: LocalizationSnapshot
    public let reasons: UIKitLocalizationUpdateReason

    public init(
        snapshot: LocalizationSnapshot,
        reasons: UIKitLocalizationUpdateReason
    ) {
        self.snapshot = snapshot
        self.reasons = reasons
    }

    public static func initial(
        snapshot: LocalizationSnapshot
    ) -> Self {
        Self(
            snapshot: snapshot,
            reasons: [.initial, .selection, .locale, .layoutDirection]
        )
    }

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

    public static func attachment(
        snapshot: LocalizationSnapshot
    ) -> Self {
        Self(snapshot: snapshot, reasons: [.attachment, .layoutDirection])
    }

    public static func configuration(
        snapshot: LocalizationSnapshot
    ) -> Self {
        Self(snapshot: snapshot, reasons: [.configuration, .layoutDirection])
    }

    public var requiresLocalizedContentRefresh: Bool {
        !reasons.intersection([.initial, .selection, .locale]).isEmpty
    }

    public var requiresLayoutDirectionRefresh: Bool {
        !reasons.intersection([
            .initial,
            .layoutDirection,
            .attachment,
            .configuration
        ]).isEmpty
    }

    public var layoutDirection: UIUserInterfaceLayoutDirection {
        snapshot.layoutDirection.uiLayoutDirection
    }

    public var semanticContentAttribute: UISemanticContentAttribute {
        snapshot.layoutDirection.semanticContentAttribute
    }
}

/// 为 UIKit 对象提供一次原子的本地化状态更新。
@MainActor
public protocol UIKitLocalizationApplying: AnyObject {
    /// 方向边界应先于文案、configuration 和布局缓存更新。
    func applyLocalization(_ update: UIKitLocalizationUpdate)
}

/// 一个 UIView 在应用内方向变化时采用的语义策略。
public enum UIViewLayoutDirectionPolicy: Equatable, Sendable {
    /// 不写入 semantic，由当前 UIKit 层级自然解析。
    case inherited
    /// 显式跟随应用当前语言方向。
    case followApplication
    /// 显式跟随直接父容器当前有效方向。
    case followContainer
    /// 保留指定的局部语义方向。
    case fixed(UISemanticContentAttribute)
}

/// 一次更新中由组件明确拥有的 UIView 方向边界。
@MainActor
public struct UIViewLayoutDirectionTarget {
    public let view: UIView
    public let policy: UIViewLayoutDirectionPolicy

    public init(
        _ view: UIView,
        policy: UIViewLayoutDirectionPolicy
    ) {
        self.view = view
        self.policy = policy
    }
}

/// 声明一个组件直接拥有的 UIView 方向边界。
@MainActor
public protocol UIViewLayoutDirectionTargetProviding: AnyObject {
    var layoutDirectionTargets: [UIViewLayoutDirectionTarget] { get }
}

/// 将最新应用方向应用到显式声明的 UIView 边界。
@MainActor
public enum UIViewLayoutDirectionUpdater {
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
        // 即使 `.inherited` 不写 semantic，也要让已物化 configuration 和布局缓存
        // 在祖先方向变化后重新求值。
        refreshConfigurationIfSupported(for: target.view)
        target.view.setNeedsUpdateConstraints()
        target.view.invalidateIntrinsicContentSize()
        target.view.setNeedsLayout()
    }

    private static func refreshConfigurationIfSupported(for view: UIView) {
        switch view {
        case let button as UIButton:
            button.setNeedsUpdateConfiguration()
            // `setNeedsUpdateConfiguration()` may be coalesced until a later
            // update cycle. Runtime language switches need the already
            // materialized title/image hierarchy to observe the new semantic
            // before the caller's atomic layout pass.
            button.updateConfiguration()
            if let configuration = button.configuration {
                // UIKit may retain the old direction in the configuration's
                // already materialized private content views. Re-entering the
                // public configuration system rebuilds that local boundary;
                // this deliberately avoids walking or mutating private views.
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

@MainActor
private enum UIKitReusableLocalizationDispatcher {
    static func apply(
        _ update: UIKitLocalizationUpdate,
        to cell: UITableViewCell,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        apply(
            update,
            targets: [
                UIViewLayoutDirectionTarget(cell, policy: policy),
                UIViewLayoutDirectionTarget(cell.contentView, policy: policy)
            ],
            component: cell
        )
    }

    static func apply(
        _ update: UIKitLocalizationUpdate,
        to cell: UICollectionViewCell,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        apply(
            update,
            targets: [
                UIViewLayoutDirectionTarget(cell, policy: policy),
                UIViewLayoutDirectionTarget(cell.contentView, policy: policy)
            ],
            component: cell
        )
    }

    static func apply(
        _ update: UIKitLocalizationUpdate,
        to view: UITableViewHeaderFooterView,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        apply(
            update,
            targets: [UIViewLayoutDirectionTarget(view, policy: policy)],
            component: view
        )
    }

    static func apply(
        _ update: UIKitLocalizationUpdate,
        to view: UICollectionReusableView,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        if let cell = view as? UICollectionViewCell {
            apply(update, to: cell, policy: policy)
            return
        }

        apply(
            update,
            targets: [UIViewLayoutDirectionTarget(view, policy: policy)],
            component: view
        )
    }

    private static func apply(
        _ update: UIKitLocalizationUpdate,
        targets: [UIViewLayoutDirectionTarget],
        component: UIView
    ) {
        UIViewLayoutDirectionUpdater.apply(update, to: targets)
        (component as? UIKitLocalizationApplying)?.applyLocalization(update)
    }
}

@MainActor
public extension UITableViewCell {
    /// 把一次 UIKit 本地化更新应用到 Cell 的公开方向边界。
    func applyLocalizationDirection(
        _ update: UIKitLocalizationUpdate,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIViewLayoutDirectionUpdater.apply(
            update,
            to: [
                UIViewLayoutDirectionTarget(self, policy: policy),
                UIViewLayoutDirectionTarget(contentView, policy: policy)
            ]
        )
    }

}

@MainActor
public extension UICollectionViewCell {
    /// 把一次 UIKit 本地化更新应用到 Cell 的公开方向边界。
    func applyLocalizationDirection(
        _ update: UIKitLocalizationUpdate,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIViewLayoutDirectionUpdater.apply(
            update,
            to: [
                UIViewLayoutDirectionTarget(self, policy: policy),
                UIViewLayoutDirectionTarget(contentView, policy: policy)
            ]
        )
    }

}

/// 为 reusable UIKit 内容提供最新本地化状态，而不缓存具体 snapshot。
///
/// Collection registration 和 table dequeue 包装在业务 configuration 之前调用
/// `prepareForConfiguration`；delegate 在 `willDisplay` 中调用
/// `restoreOnAttachment`。Context 每次都会重新读取 provider，因此复用池、离层重挂和
/// 异步新物化内容不会应用创建 Context 时的旧 revision。
@MainActor
public struct UIKitLocalizationContext {
    private let snapshotProvider: @MainActor () -> LocalizationSnapshot

    public init(
        snapshotProvider: @escaping @MainActor () -> LocalizationSnapshot
    ) {
        self.snapshotProvider = snapshotProvider
    }

    public init(localizationController: LocalizationController) {
        self.init { [localizationController] in
            localizationController.currentSnapshot
        }
    }

    public func prepareForConfiguration(
        _ cell: UITableViewCell,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIKitReusableLocalizationDispatcher.apply(
            .configuration(snapshot: snapshotProvider()),
            to: cell,
            policy: policy
        )
    }

    public func prepareForConfiguration(
        _ view: UITableViewHeaderFooterView,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIKitReusableLocalizationDispatcher.apply(
            .configuration(snapshot: snapshotProvider()),
            to: view,
            policy: policy
        )
    }

    public func prepareForConfiguration(
        _ view: UICollectionReusableView,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIKitReusableLocalizationDispatcher.apply(
            .configuration(snapshot: snapshotProvider()),
            to: view,
            policy: policy
        )
    }

    public func restoreOnAttachment(
        _ cell: UITableViewCell,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIKitReusableLocalizationDispatcher.apply(
            .attachment(snapshot: snapshotProvider()),
            to: cell,
            policy: policy
        )
    }

    public func restoreOnAttachment(
        _ view: UITableViewHeaderFooterView,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIKitReusableLocalizationDispatcher.apply(
            .attachment(snapshot: snapshotProvider()),
            to: view,
            policy: policy
        )
    }

    public func restoreOnAttachment(
        _ view: UICollectionReusableView,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIKitReusableLocalizationDispatcher.apply(
            .attachment(snapshot: snapshotProvider()),
            to: view,
            policy: policy
        )
    }

    /// 创建一个在业务 handler 之前恢复最新本地化状态的 Cell registration。
    ///
    /// `Cell` 和 `Item` 通常可以从 handler 的参数类型自动推断，无需在调用处重复
    /// 声明 registration 泛型。Registration 应在 controller 初始化或 `viewDidLoad`
    /// 中创建，不要在 diffable data source 的 cell provider 内按次创建。
    public func makeCellRegistration<Cell: UICollectionViewCell, Item>(
        policy: UIViewLayoutDirectionPolicy = .followApplication,
        handler: @escaping UICollectionView.CellRegistration<Cell, Item>.Handler
    ) -> UICollectionView.CellRegistration<Cell, Item> {
        UICollectionView.CellRegistration<Cell, Item> { cell, indexPath, item in
            prepareForConfiguration(cell, policy: policy)
            handler(cell, indexPath, item)
        }
    }

    /// 创建一个基于 nib、在业务 handler 之前恢复最新本地化状态的 Cell registration。
    public func makeCellRegistration<Cell: UICollectionViewCell, Item>(
        cellNib: UINib,
        policy: UIViewLayoutDirectionPolicy = .followApplication,
        handler: @escaping UICollectionView.CellRegistration<Cell, Item>.Handler
    ) -> UICollectionView.CellRegistration<Cell, Item> {
        UICollectionView.CellRegistration<Cell, Item>(cellNib: cellNib) {
            cell,
            indexPath,
            item in
            prepareForConfiguration(cell, policy: policy)
            handler(cell, indexPath, item)
        }
    }

    /// 创建一个在业务 handler 之前恢复最新本地化状态的 supplementary registration。
    public func makeSupplementaryRegistration<Supplementary: UICollectionReusableView>(
        elementKind: String,
        policy: UIViewLayoutDirectionPolicy = .followApplication,
        handler: @escaping UICollectionView.SupplementaryRegistration<Supplementary>.Handler
    ) -> UICollectionView.SupplementaryRegistration<Supplementary> {
        UICollectionView.SupplementaryRegistration<Supplementary>(
            elementKind: elementKind
        ) { view, elementKind, indexPath in
            prepareForConfiguration(view, policy: policy)
            handler(view, elementKind, indexPath)
        }
    }

    /// 创建一个基于 nib、在业务 handler 之前恢复最新本地化状态的 registration。
    public func makeSupplementaryRegistration<Supplementary: UICollectionReusableView>(
        supplementaryNib: UINib,
        elementKind: String,
        policy: UIViewLayoutDirectionPolicy = .followApplication,
        handler: @escaping UICollectionView.SupplementaryRegistration<Supplementary>.Handler
    ) -> UICollectionView.SupplementaryRegistration<Supplementary> {
        UICollectionView.SupplementaryRegistration<Supplementary>(
            supplementaryNib: supplementaryNib,
            elementKind: elementKind
        ) {
            view,
            elementKind,
            indexPath in
            prepareForConfiguration(view, policy: policy)
            handler(view, elementKind, indexPath)
        }
    }
}

/// 为无法原地刷新的已呈现内容提供重建接口。
///
/// `UIAlertController`、菜单、上下文菜单和第三方 SDK 弹窗等内容通常无法可靠地
/// 原地替换文本。此类视图控制器可实现该协议以提供重建或降级策略。
@MainActor
public protocol PresentedLocalizationBoundaryRebuilding: AnyObject {
    /// 根据本地化变更重建已呈现内容，或应用降级策略。
    ///
    /// - Parameter update: 触发重建的最新本地化状态。
    func rebuildPresentedBoundary(for update: UIKitLocalizationUpdate)
}

/// Window 无法原地刷新时采用的恢复级别。
public enum UIWindowLocalizationRecoveryAction: Equatable, Sendable {
    case none
    case reattachExistingRoot
    case recreateRoot
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

/// 将本地化变更分发到应用 Window 的协调器。
///
/// 默认使用 `register(window:)` 明确声明应用拥有的 Window。调用方确认当前
/// 进程内所有 connected scene Window 都可安全更新时，也可以显式选择
/// `reloadAllScenes(for:)`。两条路径都会遍历根控制器、公共容器和已呈现层级。
@MainActor
public final class UIWindowSceneLocalizationCoordinator {
    public typealias RootViewControllerFactory = @MainActor (
        LocalizationSnapshot
    ) -> UIViewController
    public typealias RecoveryActionProvider = @MainActor (
        UIWindow,
        UIKitLocalizationUpdate
    ) -> UIWindowLocalizationRecoveryAction
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

    /// 使用指定应用实例创建协调器。
    ///
    /// - Parameters:
    ///   - localizationController: 应用本地化状态的单一来源。
    ///   - presentedBoundaryHandler: 处理已呈现视图控制器的可选闭包。返回 `true` 时，
    ///     协调器会关闭该视图控制器并停止遍历其层级。
    public init(
        localizationController: LocalizationController,
        presentedBoundaryHandler: ((UIViewController, UIKitLocalizationUpdate) -> Bool)? = nil
    ) {
        self.localizationController = localizationController
        self.presentedBoundaryHandler = presentedBoundaryHandler
    }

    /// 注册一个由应用拥有的 Window，并立即应用当前快照。
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

    /// 取消管理一个 Window。
    public func unregister(window: UIWindow) {
        registrations.removeValue(forKey: ObjectIdentifier(window))
    }

    /// 使用最新状态重新同步一个已注册 Window。
    public func synchronize(window: UIWindow) {
        guard let registration = registrations[ObjectIdentifier(window)] else {
            return
        }
        apply(
            .attachment(snapshot: localizationController.currentSnapshot),
            to: registration
        )
    }

    /// 将一次本地化变更应用到所有已注册 Window。
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

    /// 将一次本地化变更应用到所有已连接 Window Scene 中选中的 Window。
    ///
    /// 这是由调用方主动选择的发现模式。调用本方法即表示调用方确认 connected
    /// scenes 可以批量更新；如果其中混有第三方或系统辅助 Window，应通过
    /// `including` 缩小范围。扫描到的 Window 只参与本次分发，不会永久加入注册表。
    ///
    /// - Parameters:
    ///   - change: 要应用的最新本地化状态变化。
    ///   - animated: 执行 root recovery 时是否使用快照过渡。
    ///   - including: 返回 `true` 的 connected-scene Window 才会被更新。
    ///   - recoveryAction: 可选的 root 恢复策略。未注册 Window 没有 root
    ///     factory，因此不能选择 `.recreateRoot`。
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

        // 重新挂载或重建之后，必须再次从新层级解析容器方向。合并原更新原因，
        // 使新 root 同时获得本次文案变化，避免 factory 之外的 child 错过刷新。
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

    /// 递归刷新视图控制器树。
    ///
    /// `visited` 防止自定义容器或异常层级形成循环。遍历范围包括普通子视图控制器、
    /// `UINavigationController` 栈、`UITabBarController` 子控制器和已呈现层级。
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

        if let navigationController = viewController as? UINavigationController {
            for child in navigationController.viewControllers {
                apply(update, from: child, visited: &visited)
            }
        }

        if let tabBarController = viewController as? UITabBarController {
            for child in tabBarController.viewControllers ?? [] {
                apply(update, from: child, visited: &visited)
            }
        }

        for child in viewController.children {
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

    private func applyContainerDirection(
        _ update: UIKitLocalizationUpdate,
        to viewController: UIViewController
    ) {
        if let navigationController = viewController as? UINavigationController {
            navigationController.view.semanticContentAttribute = update.semanticContentAttribute
            navigationController.navigationBar.semanticContentAttribute = update.semanticContentAttribute
        }
        if let tabBarController = viewController as? UITabBarController {
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
    /// 从复用池取得 Cell，并在返回业务代码前恢复最新本地化状态。
    ///
    /// Cell 必须已使用同一 identifier 注册。类型不匹配表示注册配置错误，会触发
    /// precondition failure；这与 `dequeueReusableCell(withIdentifier:for:)` 的注册契约一致。
    func dequeueLocalizedReusableCell<Cell: UITableViewCell>(
        withIdentifier identifier: String,
        for indexPath: IndexPath,
        using context: UIKitLocalizationContext,
        policy: UIViewLayoutDirectionPolicy = .followApplication,
        as cellType: Cell.Type = Cell.self
    ) -> Cell {
        let dequeuedCell = dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        guard let cell = dequeuedCell as? Cell else {
            preconditionFailure(
                "Registered cell for \(identifier) is not \(String(reflecting: cellType))"
            )
        }
        context.prepareForConfiguration(cell, policy: policy)
        return cell
    }

    /// 从复用池取得 Header/Footer，并在返回业务代码前恢复最新本地化状态。
    func dequeueLocalizedReusableHeaderFooterView<View: UITableViewHeaderFooterView>(
        withIdentifier identifier: String,
        using context: UIKitLocalizationContext,
        policy: UIViewLayoutDirectionPolicy = .followApplication,
        as viewType: View.Type = View.self
    ) -> View? {
        guard let dequeuedView = dequeueReusableHeaderFooterView(withIdentifier: identifier) else {
            return nil
        }
        guard let view = dequeuedView as? View else {
            preconditionFailure(
                "Registered header/footer for \(identifier) is not \(String(reflecting: viewType))"
            )
        }
        context.prepareForConfiguration(view, policy: policy)
        return view
    }

    /// 应用布局方向、刷新表格布局，并按需保留当前逻辑行。
    ///
    /// 表格视图通常沿垂直方向滚动，因此 LTR/RTL 切换不需要像横向集合视图一样
    /// 反转滚动位置。如果布局变化影响行的位置，此方法会使用最上方可见行及其
    /// 相对位置作为锚点。
    ///
    /// ```swift
    /// func applyLocalization(_ update: UIKitLocalizationUpdate) {
    ///     tableView.applyLocalization(
    ///         update,
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
    /// cell 不必实现 `UIKitLocalizationApplying`：使用 `.unspecified` semantic、
    /// leading/trailing 约束或在布局时读取 `effectiveUserInterfaceLayoutDirection` 的 cell
    /// 会自动响应。只有显式强制子视图方向、缓存方向或维护自定义左右状态的 reusable
    /// view，才需要实现该协议。
    ///
    /// - Parameters:
    ///   - layoutDirection: 要应用的布局方向。
    ///   - shouldPreserveVisibleRow: 是否在布局刷新后保持最上方可见的逻辑行及其相对位置。
    func applyLocalization(
        _ update: UIKitLocalizationUpdate,
        preservingVisibleRow shouldPreserveVisibleRow: Bool = true
    ) {
        guard update.requiresLayoutDirectionRefresh else { return }
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

        semanticContentAttribute = update.semanticContentAttribute
        refreshVisibleContent(for: update)
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

    private func refreshVisibleContent(for update: UIKitLocalizationUpdate) {
        for cell in visibleCells {
            UIKitReusableLocalizationDispatcher.apply(update, to: cell)
        }

        for section in 0..<numberOfSections {
            let visibleSupplementaryViews = [
                headerView(forSection: section),
                footerView(forSection: section)
            ]

            for view in visibleSupplementaryViews.compactMap({ $0 }) {
                UIKitReusableLocalizationDispatcher.apply(update, to: view)
            }
        }

        for view in [tableHeaderView, tableFooterView].compactMap({ $0 }) {
            UIViewLayoutDirectionUpdater.apply(
                update,
                to: UIViewLayoutDirectionTarget(view, policy: .followApplication)
            )
            (view as? UIKitLocalizationApplying)?.applyLocalization(update)
        }
    }

    private func containsRow(at indexPath: IndexPath) -> Bool {
        indexPath.section >= 0
            && indexPath.section < numberOfSections
            && indexPath.row >= 0
            && indexPath.row < numberOfRows(inSection: indexPath.section)
    }
}

/// A logical collection item and its visual position inside the adjusted
/// scrollable viewport.
///
/// The leading distance is semantic rather than a raw physical `contentOffset.x`,
/// so the same anchor can be restored after an LTR/RTL direction change or onto
/// a replacement collection view.
public struct UICollectionViewLocalizationAnchor: Equatable {
    public let indexPath: IndexPath
    public let offsetFromViewportTop: CGFloat
    public let offsetFromViewportLeading: CGFloat

    public init(
        indexPath: IndexPath,
        offsetFromViewportTop: CGFloat,
        offsetFromViewportLeading: CGFloat
    ) {
        self.indexPath = indexPath
        self.offsetFromViewportTop = offsetFromViewportTop
        self.offsetFromViewportLeading = offsetFromViewportLeading
    }
}

public extension UICollectionView {
    /// Captures the first visible logical item and its position relative to the
    /// adjusted viewport's top and semantic leading edges.
    func captureLocalizationAnchor()
        -> UICollectionViewLocalizationAnchor? {
        layoutIfNeeded()
        let visibleViewport = CGRect(
            x: contentOffset.x + adjustedContentInset.left,
            y: contentOffset.y + adjustedContentInset.top,
            width: max(
                0,
                bounds.width
                    - adjustedContentInset.left
                    - adjustedContentInset.right
            ),
            height: max(
                0,
                bounds.height
                    - adjustedContentInset.top
                    - adjustedContentInset.bottom
            )
        )
        let visibleAttributes = indexPathsForVisibleItems
            .compactMap { layoutAttributesForItem(at: $0) }
            .filter { $0.frame.intersects(visibleViewport) }
        let attributes = visibleAttributes.min { lhs, rhs in
            if abs(lhs.frame.minY - rhs.frame.minY) > 0.5 {
                return lhs.frame.minY < rhs.frame.minY
            }
            if effectiveUserInterfaceLayoutDirection == .rightToLeft {
                return lhs.frame.maxX > rhs.frame.maxX
            }
            return lhs.frame.minX < rhs.frame.minX
        }
        guard let attributes else {
            return nil
        }

        let indexPath = attributes.indexPath
        let frame = attributes.frame
        let viewportTop = contentOffset.y + adjustedContentInset.top
        let offsetFromViewportLeading: CGFloat
        if effectiveUserInterfaceLayoutDirection == .rightToLeft {
            let viewportRight = contentOffset.x
                + bounds.width
                - adjustedContentInset.right
            offsetFromViewportLeading = viewportRight - frame.maxX
        } else {
            let viewportLeft = contentOffset.x + adjustedContentInset.left
            offsetFromViewportLeading = frame.minX - viewportLeft
        }

        return UICollectionViewLocalizationAnchor(
            indexPath: indexPath,
            offsetFromViewportTop: frame.minY - viewportTop,
            offsetFromViewportLeading: offsetFromViewportLeading
        )
    }

    /// Restores a captured logical item to the same visual position after the
    /// current layout has finished self-sizing its content.
    @discardableResult
    func restoreLocalizationAnchor(
        _ anchor: UICollectionViewLocalizationAnchor
    ) -> Bool {
        guard containsItem(at: anchor.indexPath) else { return false }
        layoutIfNeeded()
        guard let attributes = layoutAttributesForItem(
            at: anchor.indexPath
        ) else {
            return false
        }

        let frame = attributes.frame
        let minimumOffsetX = -adjustedContentInset.left
        let maximumOffsetX = max(
            minimumOffsetX,
            contentSize.width - bounds.width + adjustedContentInset.right
        )
        let minimumOffsetY = -adjustedContentInset.top
        let maximumOffsetY = max(
            minimumOffsetY,
            contentSize.height - bounds.height + adjustedContentInset.bottom
        )

        let proposedOffsetX: CGFloat
        if effectiveUserInterfaceLayoutDirection == .rightToLeft {
            proposedOffsetX = frame.maxX
                + anchor.offsetFromViewportLeading
                - bounds.width
                + adjustedContentInset.right
        } else {
            proposedOffsetX = frame.minX
                - anchor.offsetFromViewportLeading
                - adjustedContentInset.left
        }
        let proposedOffsetY = frame.minY
            - anchor.offsetFromViewportTop
            - adjustedContentInset.top

        setContentOffset(
            CGPoint(
                x: min(max(proposedOffsetX, minimumOffsetX), maximumOffsetX),
                y: min(max(proposedOffsetY, minimumOffsetY), maximumOffsetY)
            ),
            animated: false
        )
        return true
    }

    /// 应用布局方向、使集合视图布局失效，并按需保留当前逻辑项目。
    ///
    /// 横向列表、分页轮播和依赖语义边缘的布局，均可在 `applyLocalization(_:)`
    /// 中调用此方法。切换方向时不应直接复用旧 `contentOffset`，因为物理偏移在不同
    /// 布局方向下含义不同；保留 `IndexPath` 更符合用户意图。
    ///
    /// ```swift
    /// func applyLocalization(_ update: UIKitLocalizationUpdate) {
    ///     collectionView.applyLocalization(
    ///         update,
    ///         preservingVisibleItem: true,
    ///         rebuildingLayoutWith: makeCollectionViewLayout
    ///     )
    /// }
    /// ```
    ///
    /// 大多数 flow layout 只需要失效当前 layout。部分 compositional layout 会缓存
    /// 与 LTR/RTL 有关的私有坐标映射；此时可传入 `makeLayout`，方向改变时使用新
    /// layout 实例清除旧映射。方向未改变时不会调用闭包，只失效当前 layout。
    ///
    /// - Parameters:
    ///   - layoutDirection: 要应用的布局方向。
    ///   - shouldPreserveVisibleItem: 是否在布局失效后保持当前可见的逻辑项目。
    ///   - makeLayout: 方向改变时用于创建新集合布局的闭包；默认只失效当前布局。
    func applyLocalization(
        _ update: UIKitLocalizationUpdate,
        preservingVisibleItem shouldPreserveVisibleItem: Bool = true,
        rebuildingLayoutWith makeLayout: (() -> UICollectionViewLayout)? = nil
    ) {
        guard update.requiresLayoutDirectionRefresh else { return }
        let layoutDirection = update.snapshot.layoutDirection
        let visibleAnchor = shouldPreserveVisibleItem
            ? captureLocalizationAnchor()
            : nil
        // 旧偏移使用物理坐标，切换方向后含义会反转，因此这里保留逻辑 `IndexPath`。
        // 首次布局没有可见项目时，定位到第一个逻辑项目，避免从右向左布局
        // 停在物理左端。
        let targetIndexPath = visibleAnchor?.indexPath
            ?? (shouldPreserveVisibleItem
                ? firstItemIndexPathForDirectionReset()
                : nil)

        let semanticContentAttribute = layoutDirection.semanticContentAttribute
        let directionChanged = self.semanticContentAttribute
            != semanticContentAttribute
        self.semanticContentAttribute = semanticContentAttribute

        if directionChanged, let makeLayout {
            // Compositional layout 可能缓存旧方向的 counter-mirroring；只有替换
            // layout 实例才能清除这类不属于 invalidation context 的私有状态。
            setCollectionViewLayout(makeLayout(), animated: false)
        } else {
            collectionViewLayout.invalidateLayout()
        }
        refreshVisibleContent(for: update)
        // 布局失效后立即执行布局，确保滚动操作使用新方向下的布局属性。
        layoutIfNeeded()

        if let visibleAnchor {
            restoreLocalizationAnchor(visibleAnchor)
        } else if let targetIndexPath {
            scrollToItem(
                at: targetIndexPath,
                // 从右向左布局的逻辑起点在右侧，从左向右布局的逻辑起点在左侧。
                at: layoutDirection == .rightToLeft ? .right : .left,
                animated: false
            )
        }
    }

    private func refreshVisibleContent(for update: UIKitLocalizationUpdate) {
        for cell in visibleCells {
            UIKitReusableLocalizationDispatcher.apply(update, to: cell)
        }

        let supplementaryKinds = Set(
            (collectionViewLayout.layoutAttributesForElements(in: bounds) ?? [])
                .compactMap(\.representedElementKind)
        )
        for kind in supplementaryKinds {
            for view in visibleSupplementaryViews(ofKind: kind) {
                UIKitReusableLocalizationDispatcher.apply(update, to: view)
            }
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

    private func containsItem(at indexPath: IndexPath) -> Bool {
        indexPath.section >= 0
            && indexPath.section < numberOfSections
            && indexPath.item >= 0
            && indexPath.item < numberOfItems(inSection: indexPath.section)
    }
}
#endif
