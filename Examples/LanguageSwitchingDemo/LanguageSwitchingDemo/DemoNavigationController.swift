import AppLocalization
import SwiftUI
import UIKit

/// 示例直接拥有导航栈，SwiftUI 页面只负责内容和用户操作。
final class DemoNavigationController: UINavigationController, UIKitLocalizationApplying {
    private let services: DemoServices
    private weak var sheet: UIViewController?

    init(services: DemoServices) {
        self.services = services
        super.init(nibName: nil, bundle: nil)
        let root = UIHostingController(rootView: DemoRootView(
            localizationController: services.localizationController,
            resolver: services.resolver,
            showSheet: { [weak self] in self?.showSheet() },
            showPushPage: { [weak self] in self?.showPushPage() }
        ).appLocalizationEnvironment(services.localizationController))
        setViewControllers([root], animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        // 页面标题由 SwiftUI 的 navigationTitle 提供，保持单一更新来源。
        navigationBar.prefersLargeTitles = true
        applyLocalization(LocalizationUpdate(snapshot: services.localizationController.currentSnapshot))
    }

    func applyLocalization(_ update: LocalizationUpdate) {
        if update.requiresLayoutDirectionRefresh {
            // 与参考项目一致，在系统导航容器上设置语义方向，保留原生返回手势及代理。
            view.semanticContentAttribute = update.semanticContentAttribute
            navigationBar.semanticContentAttribute = update.semanticContentAttribute
            toolbar.semanticContentAttribute = update.semanticContentAttribute
            for host in viewControllers { applyDirection(update, to: host) }
            if let sheet { applyDirection(update, to: sheet) }
        }
        guard update.requiresLocalizedContentRefresh else { return }
        sheet?.navigationItem.leftBarButtonItem?.title = services.resolver.string("close", bundle: .main)
    }

    private func showPushPage() {
        let page = UIHostingController(rootView: PushPopGestureDemoView(
            localizationController: services.localizationController,
            resolver: services.resolver
        ).appLocalizationEnvironment(services.localizationController))
        // 编辑页使用原生紧凑标题，避免大标题与独立输入区的滚动边界不一致。
        page.navigationItem.largeTitleDisplayMode = .never
        // 入栈前配置新宿主；后续语言切换只刷新现有实例，不重建页面或编辑状态。
        applyDirection(LocalizationUpdate(snapshot: services.localizationController.currentSnapshot), to: page)
        pushViewController(page, animated: true)
    }

    private func showSheet() {
        let page = UIHostingController(rootView: DemoSheetView(
            localizationController: services.localizationController,
            resolver: services.resolver
        ).appLocalizationEnvironment(services.localizationController))
        let close = UIBarButtonItem(title: services.resolver.string("close", bundle: .main),
                                    style: .plain, target: self, action: #selector(closeSheet))
        close.accessibilityIdentifier = "demo.sheet.close"
        page.navigationItem.leftBarButtonItem = close
        sheet = page
        let navigation = UINavigationController(rootViewController: page)
        navigation.navigationBar.prefersLargeTitles = true
        applyLocalization(LocalizationUpdate(snapshot: services.localizationController.currentSnapshot))
        present(navigation, animated: true)
    }

    @objc private func closeSheet() {
        sheet?.navigationController?.dismiss(animated: true)
    }

    private func applyDirection(_ update: LocalizationUpdate, to host: UIViewController) {
        // 此处仅同步本示例拥有的 SwiftUI 宿主，避免环境和 UIKit traits 不一致时留下 List 镜像。
        if #available(iOS 17.0, *) {
            host.traitOverrides.layoutDirection = update.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
            host.updateTraitsIfNeeded()
        }
        host.view.semanticContentAttribute = update.semanticContentAttribute
        if let navigation = host.navigationController, navigation !== self {
            navigation.view.semanticContentAttribute = update.semanticContentAttribute
            navigation.navigationBar.semanticContentAttribute = update.semanticContentAttribute
            navigation.toolbar.semanticContentAttribute = update.semanticContentAttribute
        }
    }
}
