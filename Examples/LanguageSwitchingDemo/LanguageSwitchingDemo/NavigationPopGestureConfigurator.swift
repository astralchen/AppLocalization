import SwiftUI
import UIKit
import AppLocalization

/// 将 SwiftUI `NavigationView` 的 `UINavigationController` 同步到应用布局方向。
///
/// SwiftUI 的 `.environment(\.layoutDirection, ...)` 会影响文本和很多布局，
/// 但不保证同步修改底层 `UINavigationController` 的转场语义，也不保证修改
/// `interactivePopGestureRecognizer` 的物理边缘。在阿拉伯文布局中，如果只修改
/// SwiftUI 环境，页面可能显示右侧返回按钮，但出栈动画仍可能从左向右移动。
struct NavigationPopGestureConfigurator: UIViewControllerRepresentable {
    let layoutDirection: AppUserInterfaceLayoutDirection

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ viewController: Controller, context: Context) {
        viewController.layoutDirection = layoutDirection
        viewController.configureNavigationControllerWhenAvailable()
    }

    final class Controller: UIViewController {
        var layoutDirection: AppUserInterfaceLayoutDirection = .leftToRight

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            configureNavigationControllerWhenAvailable()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            configureNavigationControllerWhenAvailable()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            configureNavigationControllerWhenAvailable()
        }

        func configureNavigationControllerWhenAvailable() {
            // SwiftUI 先创建桥接对象，再将宿主控制器放入导航栈，因此延迟到下一次
            // 主队列调度，等待 `navigationController` 可用后再配置。
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      let navigationController = self.navigationController
                else { return }

                self.configure(navigationController)
            }
        }

        private func configure(_ navigationController: UINavigationController) {
            let semanticAttribute = layoutDirection.semanticContentAttribute

            // 系统入栈和出栈转场读取 UIKit 导航容器的语义方向，而不是 SwiftUI 视图的
            // `layoutDirection`。从右向左布局必须在入栈前设置导航控制器视图的语义属性。
            navigationController.view.semanticContentAttribute = semanticAttribute
            navigationController.navigationBar.semanticContentAttribute = semanticAttribute
            navigationController.toolbar.semanticContentAttribute = semanticAttribute
            navigationController.viewControllers.forEach {
                $0.viewIfLoaded?.semanticContentAttribute = semanticAttribute
            }

            if let edgePan = navigationController.interactivePopGestureRecognizer as? UIScreenEdgePanGestureRecognizer {
                // 系统交互式出栈操作使用物理边缘手势，不会自动读取应用内语言状态。
                // 手势边缘应与返回按钮所在的语义前缘保持一致。
                edgePan.edges = DirectionalLayout.backSwipeRectEdge(layoutDirection: layoutDirection)
                edgePan.isEnabled = navigationController.viewControllers.count > 1
            }
        }
    }
}
