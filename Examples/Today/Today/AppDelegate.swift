/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import UIKit
import AppLocalization

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

  private var localizationObserver: NSObjectProtocol?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 配置应用级外观，并开始监听本地化变更。
    UINavigationBar.appearance().tintColor = .todayPrimaryTint
    UINavigationBar.appearance().backgroundColor = .todayNavigationBackground
    let navBarAppearance = UINavigationBarAppearance()
    navBarAppearance.configureWithOpaqueBackground()
    UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

    let services = TodayLocalizationServices.shared
    localizationObserver = NotificationCenter.default.addObserver(
      forName: LocalizationController.localizationDidChangeNotification,
      object: services.localizationController,
      queue: .main
    ) { [weak self] notification in
      guard let change = notification.userInfo?[LocalizationController.localizationChangeUserInfoKey]
        as? LocalizationChange
      else {
        return
      }

      Task { @MainActor [weak self] in
        guard change.current.revision
            == TodayLocalizationServices.shared.localizationController.currentSnapshot.revision
        else {
          return
        }
        self?.applyLocalizationChange(change)
      }
    }
    return true
  }

  func applicationWillTerminate(_ application: UIApplication) {
    if let localizationObserver {
      NotificationCenter.default.removeObserver(localizationObserver)
    }
  }

  // MARK: - 场景会话生命周期

  func application(
    _ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    // 为新场景会话返回对应的配置。
    return UISceneConfiguration(
      name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  func application(
    _ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>
  ) {
    // 在此释放被用户丢弃场景所独占的资源。
  }

  private func applyLocalizationChange(_ change: LocalizationChange) {
    TodayLocalizationServices.shared.localizationCoordinator.apply(change)
  }

}
