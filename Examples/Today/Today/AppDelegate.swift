/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import UIKit
import AppLocalization

@main
class AppDelegate: UIResponder, UIApplicationDelegate {


  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 启动时配置静态外观；语言变更由场景窗口协调器自动处理。
    UINavigationBar.appearance().tintColor = .todayPrimaryTint
    UINavigationBar.appearance().backgroundColor = .todayNavigationBackground
    let navBarAppearance = UINavigationBarAppearance()
    navBarAppearance.configureWithOpaqueBackground()
    UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

    return true
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

}
