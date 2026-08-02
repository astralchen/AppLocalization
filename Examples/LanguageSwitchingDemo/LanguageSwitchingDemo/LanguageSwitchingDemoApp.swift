import SwiftUI
import AppLocalization

@main
struct LanguageSwitchingDemoApp: App {
    @StateObject private var services = DemoServices()

    var body: some Scene {
        WindowGroup {
            DemoRootView(
                localizationController: services.localizationController,
                resolver: services.resolver
            )
            // `NavigationView` 和 `List` 原地切换布局方向后可能保留 UIKit 镜像变换。
            // 仅在布局方向变化时重建内容；同方向的语言切换保留现有视图状态。
            .appLocalizationEnvironment(
                services.localizationController,
                resetContentOnLayoutDirectionChange: true
            )
            .onReceive(
                NotificationCenter.default.publisher(
                    for: LocalizationController.localizationDidChangeNotification,
                    object: services.localizationController
                )
            ) { notification in
                guard let change = notification.userInfo?[LocalizationController.localizationChangeUserInfoKey] as? LocalizationChange else {
                    return
                }
                UIWindowSceneLocalizationCoordinator().reloadAllScenes(
                    for: change,
                    // SwiftUI 环境会按需重建内容，无需同时重设窗口的根视图控制器。
                    rebuildRootWindows: false,
                    animateRootRebuild: true,
                    updateAppearanceProxies: false
                )
            }
        }
    }
}
