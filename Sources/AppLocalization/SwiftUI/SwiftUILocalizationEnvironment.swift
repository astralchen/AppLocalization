import SwiftUI

/// 观察控制器并更新环境，保持内容身份由业务视图自身管理。
private struct AppLocalizationEnvironmentModifier: ViewModifier {
    @ObservedObject var localizationController: LocalizationController

    func body(content: Content) -> some View {
        content
            .environmentObject(localizationController)
            .environment(\.locale, localizationController.locale)
            .environment(\.layoutDirection, localizationController.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight)
    }
}

public extension View {
    /// 向场景根视图注入本地化控制器、区域设置和布局方向。
    /// 不改变内容身份；局部恢复需求由业务视图在自己的边界处理。
    /// UIKit 桥接类型应在 update 方法读取环境 locale 和 layoutDirection。
    func appLocalizationEnvironment(_ localizationController: LocalizationController) -> some View {
        modifier(AppLocalizationEnvironmentModifier(localizationController: localizationController))
    }
}
