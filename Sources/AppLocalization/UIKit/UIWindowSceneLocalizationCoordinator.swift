import UIKit

/// 自动参与控制器事务，向显式注册且由应用拥有的窗口刷新内容。
/// iOS 17+ 的方向属于 Scene，同一 Scene 内的其他窗口也会继承。
/// 窗口与协调器注册均使用弱引用。
@MainActor
public final class UIWindowSceneLocalizationCoordinator {
    private struct Delivery {
        let windows: [UIWindow]
        let controllers: [UIViewController]
        let components: [any UIKitLocalizationApplying]
    }

    private let controller: LocalizationController
    // 原生弱集合按实例身份管理窗口，不延长窗口生命周期。
    private let windows = NSHashTable<UIWindow>(options: [.weakMemory, .objectPointerPersonality])
    private var delivery: Delivery?

    public init(
        localizationController: LocalizationController
    ) {
        controller = localizationController
        controller.register(self)
    }

    public func register(window: UIWindow) {
        windows.add(window)
        refresh([window])
    }

    public func unregister(window: UIWindow) {
        windows.remove(window)
    }

    /// 重新解析系统选择，同时刷新内容和方向。
    /// 同时修复上次切换后才创建的页面内容。
    public func synchronize(window: UIWindow) {
        guard windows.contains(window) else { return }
        controller.refreshSystemLocaleIfNeeded()
        refresh([window])
    }

    /// 场景激活时同步已注册窗口，不发现或枚举其他窗口。
    public func synchronize() {
        controller.refreshSystemLocaleIfNeeded()
        refresh(windows.allObjects)
    }

    func prepareLocalization(_ update: LocalizationUpdate) {
        delivery = capture(windows.allObjects)
    }

    func applyLocalization(_ update: LocalizationUpdate) {
        guard let delivery, update.snapshot.revision == controller.currentSnapshot.revision else { return }
        apply(delivery, update: update)
    }

    func applyLocalizationDirection(_ update: LocalizationUpdate) {
        guard let delivery, update.snapshot.revision == controller.currentSnapshot.revision else { return }
        applyDirection(delivery, update: update)
    }

    func finishLocalization(_ update: LocalizationUpdate) {
        guard let delivery, update.snapshot.revision == controller.currentSnapshot.revision else { return }
        finish(delivery)
        self.delivery = nil
    }

    private func refresh(_ windows: [UIWindow]) {
        controller.synchronize { [weak self] snapshot in
            guard let self else { return }
            let windows = windows.filter { self.windows.contains($0) }
            let update = LocalizationUpdate(snapshot: snapshot)
            let delivery = self.capture(windows)
            self.applyDirection(delivery, update: update)
            self.apply(delivery, update: update)
            self.finish(delivery)
        }
    }

    private func capture(_ windows: [UIWindow]) -> Delivery {
        var controllers: [UIViewController] = []
        var components: [any UIKitLocalizationApplying] = []
        var visited = Set<ObjectIdentifier>()
        func visit(_ viewController: UIViewController) {
            guard visited.insert(ObjectIdentifier(viewController)).inserted else { return }
            controllers.append(viewController)
            if viewController.isViewLoaded, let component = viewController as? UIKitLocalizationApplying {
                components.append(component)
            }
            var children = viewController.children
            if let navigation = viewController as? UINavigationController {
                children += navigation.viewControllers
            }
            if let tabs = viewController as? UITabBarController { children += tabs.viewControllers ?? [] }
            if let split = viewController as? UISplitViewController { children += split.viewControllers }
            if let pages = viewController as? UIPageViewController { children += pages.viewControllers ?? [] }
            for child in children { visit(child) }
            if let presented = viewController.presentedViewController {
                visit(presented)
            }
        }
        for window in windows { if let root = window.rootViewController { visit(root) } }
        return Delivery(
            windows: windows, controllers: controllers, components: components)
    }

    private func applyDirection(_ delivery: Delivery, update: LocalizationUpdate) {
        guard update.requiresLayoutDirectionRefresh else { return }
        UIView.performWithoutAnimation {
            var updatedScenes = Set<ObjectIdentifier>()
            for window in delivery.windows {
                if #available(iOS 17.0, *) {
                    let direction: UITraitEnvironmentLayoutDirection =
                        update.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
                    // Scene 同时覆盖后续创建的窗口及呈现内容，不逐页覆盖 traits。
                    if let scene = window.windowScene {
                        // 已注册窗口由 Scene 管理方向，清除无 Scene 阶段留下的窗口级覆盖。
                        window.traitOverrides.remove(UITraitLayoutDirection.self)
                        if updatedScenes.insert(ObjectIdentifier(scene)).inserted {
                            scene.traitOverrides.layoutDirection = direction
                        }
                    } else {
                        window.traitOverrides.layoutDirection = direction
                    }
                    // traits 默认延后传播；事务配置内容前需要完成公开层级的同步更新。
                    window.updateTraitsIfNeeded()
                } else {
                    window.semanticContentAttribute = update.semanticContentAttribute
                }
            }
            for viewController in delivery.controllers {
                if #available(iOS 17.0, *) {
                    viewController.updateTraitsIfNeeded()
                } else {
                    Self.applyLegacyDirection(update, to: viewController)
                }
                // 导航转场和返回手势仍读取导航容器的语义方向，所有版本都要同步。
                if let navigation = viewController as? UINavigationController, navigation.isViewLoaded {
                    navigation.view.semanticContentAttribute = update.semanticContentAttribute
                    navigation.navigationBar.semanticContentAttribute = update.semanticContentAttribute
                    navigation.toolbar.semanticContentAttribute = update.semanticContentAttribute
                    // customView 的实际位置可能仍沿用旧方向的尺寸布局。
                    // 只使公开导航项的自定义视图尺寸失效，让 UIKit 重新解析位置；
                    // 不重新安装 item、不替换视图，也不覆盖自定义内容的语义方向。
                    for item in navigation.navigationBar.items ?? [] {
                        let buttons = (item.leftBarButtonItems ?? []) + (item.rightBarButtonItems ?? [])
                        for button in buttons { button.customView?.invalidateIntrinsicContentSize() }
                    }
                    navigation.navigationBar.setNeedsLayout()
                    navigation.view.setNeedsLayout()
                }
            }
        }
    }

    /// iOS 15/16 的公开边界适配，不创建宿主、不加载离屏页面或遍历私有子视图。
    /// 独立保留此内部实现，以便在新系统验证旧 API 的合并与投递行为。
    static func applyLegacyDirection(_ update: LocalizationUpdate, to viewController: UIViewController) {
        let direction = UITraitCollection(layoutDirection:
            update.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight)
        if let parent = viewController.parent {
            let traits = UITraitCollection(traitsFrom: [
                parent.overrideTraitCollection(forChild: viewController) ?? UITraitCollection(), direction
            ])
            parent.setOverrideTraitCollection(traits, forChild: viewController)
        } else if viewController.presentingViewController != nil,
                  let presentation = viewController.presentationController {
            presentation.overrideTraitCollection = UITraitCollection(traitsFrom: [
                presentation.overrideTraitCollection ?? UITraitCollection(), direction
            ])
        }
        viewController.viewIfLoaded?.semanticContentAttribute = update.semanticContentAttribute
        if let tabs = viewController as? UITabBarController, tabs.isViewLoaded {
            tabs.tabBar.semanticContentAttribute = update.semanticContentAttribute
        }
    }

    private func apply(_ delivery: Delivery, update: LocalizationUpdate) {
        UIView.performWithoutAnimation {
            for component in delivery.components { component.applyLocalization(update) }
        }
    }

    private func finish(_ delivery: Delivery) {
        for window in delivery.windows {
            window.setNeedsLayout()
            window.layoutIfNeeded()
        }
    }
}
