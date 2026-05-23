import SwiftUI

@main
struct LanguageSwitchingDemoApp: App {
    @StateObject private var services = DemoServices()

    var body: some Scene {
        WindowGroup {
            DemoRootView(
                localizationController: services.localizationController,
                resolver: services.resolver
            )
            .appLocalizationEnvironment(services.localizationController)
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
                    // 修复点：SwiftUI root 已由 appLocalizationEnvironment 在方向变化时换 identity。
                    // 如果这里再执行 UIKit rootViewController 重挂，SwiftUI List/NavigationView
                    // 的内部复用状态可能和新环境交错，随机多次切换后会出现整体镜像或反排。
                    // UIKit-root App 可继续对方向变化传 true；SwiftUI-root App 保持 false。
                    rebuildRootWindows: false,
                    animateRootRebuild: true,
                    updateAppearanceProxies: false
                )
            }
        }
    }
}
