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
            .background(
                WindowLocalizationRegistrationView(
                    coordinator: services.localizationCoordinator
                )
                .frame(width: 0, height: 0)
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
                // SwiftUI 环境负责根内容重算；协调器负责已经物化的 UIKit 边界。
                services.localizationCoordinator.apply(change)
            }
        }
    }
}
