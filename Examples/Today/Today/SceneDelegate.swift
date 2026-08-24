/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import UIKit
import AppLocalization

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // 故事板会自动创建窗口并将其关联到传入的窗口场景。
        guard let _ = (scene as? UIWindowScene) else { return }

        guard let window else { return }
        TodayLocalizationServices.shared.localizationCoordinator.register(window: window)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if let window {
            TodayLocalizationServices.shared.localizationCoordinator.unregister(window: window)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        if let window {
            TodayLocalizationServices.shared.localizationCoordinator.synchronize(window: window)
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // 在此暂停需要随场景进入非活跃状态而停止的任务。
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // 返回前台时，重新解析“跟随系统”的区域设置。
        TodayLocalizationServices.shared.localizationController.refreshSystemLocaleIfNeeded()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // 在此保存数据，并释放可在下次进入前台时重新创建的共享资源。
    }

}
