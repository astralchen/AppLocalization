import SwiftUI
import UIKit

/// 把 SwiftUI NavigationView 背后的 `UINavigationController` 同步到 App 当前方向。
///
/// SwiftUI 的 `.environment(\.layoutDirection, ...)` 会影响文本和很多布局，
/// 但不保证同步修改底层 `UINavigationController` 的转场语义，也不保证修改
/// `interactivePopGestureRecognizer` 的物理边缘。阿语 RTL 下如果只改 SwiftUI
/// 环境，页面可能显示右侧返回按钮，但 push/pop 动画仍按 LTR，从左向右返回。
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
            // SwiftUI 会先创建 representable，再把宿主控制器放进导航栈；
            // 因此这里延后一轮到主队列，等 navigationController 可用后再配置。
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      let navigationController = self.navigationController
                else { return }

                self.configure(navigationController)
            }
        }

        private func configure(_ navigationController: UINavigationController) {
            let semanticAttribute = layoutDirection.semanticContentAttribute

            // 关键修复：系统 push/pop 转场读取的是 UIKit 导航容器的语义方向，
            // 不是 SwiftUI view 的 layoutDirection。RTL 下必须在 push 发生前把
            // UINavigationController.view 设为 forceRightToLeft，否则返回动画仍会
            // 按 LTR 从左向右移动。
            navigationController.view.semanticContentAttribute = semanticAttribute
            navigationController.navigationBar.semanticContentAttribute = semanticAttribute
            navigationController.toolbar.semanticContentAttribute = semanticAttribute
            navigationController.viewControllers.forEach {
                $0.view.semanticContentAttribute = semanticAttribute
            }

            if let edgePan = navigationController.interactivePopGestureRecognizer as? UIScreenEdgePanGestureRecognizer {
                // 系统 interactive pop 是物理边缘手势，不会自动理解 App 内语言状态。
                // LTR 使用左边缘；RTL 使用右边缘，和返回按钮所在的 semantic leading 对齐。
                edgePan.edges = DirectionalLayout.backSwipeRectEdge(layoutDirection: layoutDirection)
                edgePan.isEnabled = navigationController.viewControllers.count > 1
            }
        }
    }
}
