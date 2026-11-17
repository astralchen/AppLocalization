import UIKit

@main
@MainActor
final class LanguageSwitchingDemoApp: UIResponder, UIApplicationDelegate {
    let services = DemoServices()

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = DemoSceneDelegate.self
        return configuration
    }
}

@MainActor
final class DemoSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var services: DemoServices?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene,
              let app = UIApplication.shared.delegate as? LanguageSwitchingDemoApp else { return }
        let services = app.services
        self.services = services
        let window = UIWindow(windowScene: scene)
        window.rootViewController = DemoNavigationController(services: services)
        self.window = window
        // 窗口由 Scene 创建和注册，无需在 SwiftUI 中放置隐藏视图查找窗口。
        window.rootViewController?.loadViewIfNeeded()
        services.localizationCoordinator.register(window: window)
        window.makeKeyAndVisible()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard let window else { return }
        services?.localizationCoordinator.synchronize(window: window)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        guard let window else { return }
        services?.localizationCoordinator.unregister(window: window)
    }
}
