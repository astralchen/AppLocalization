#if canImport(SwiftUI)
import SwiftUI

public extension AppUserInterfaceLayoutDirection {
    /// 对应的 SwiftUI `LayoutDirection`。
    var swiftUILayoutDirection: LayoutDirection {
        self == .rightToLeft ? .rightToLeft : .leftToRight
    }
}

/// 向 SwiftUI 内容注入应用内本地化环境的容器视图。
///
/// 每个场景的根视图都应使用此类型，使 SwiftUI 在 ``LocalizationController/currentLocale``
/// 变化时获取最新的 `Locale` 和 `LayoutDirection`。
///
/// ```swift
/// WindowGroup {
///     RootView()
///         .appLocalizationEnvironment(localizationController)
/// }
/// ```
public struct LocalizationEnvironmentView<Content: View>: View {
    // 观察控制器，使区域设置变化触发 SwiftUI 重新计算 `body`。
    @ObservedObject private var localizationController: LocalizationController
    private let resetContentOnLayoutDirectionChange: Bool
    private let content: Content

    private var layoutDirectionIdentity: String {
        guard resetContentOnLayoutDirectionChange else {
            return "AppLocalization.stable"
        }

        switch localizationController.layoutDirection {
        case .leftToRight:
            return "AppLocalization.leftToRight"
        case .rightToLeft:
            return "AppLocalization.rightToLeft"
        }
    }

    /// 创建本地化环境容器视图。
///
    /// `resetContentOnLayoutDirectionChange` 默认关闭，以保留内容树中的 `@State`、
    /// 工作表和导航状态。仅当系统容器无法原地响应布局方向变化时才应启用该选项；
    /// 启用后，方向变化会重建内容子树。
    ///
    /// - Parameters:
    ///   - localizationController: 要注入内容树的本地化控制器。
    ///   - resetContentOnLayoutDirectionChange: 是否在布局方向变化时重建内容子树。
    ///   - content: 创建容器内容的视图构建闭包。
    public init(
        localizationController: LocalizationController,
        resetContentOnLayoutDirectionChange: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.localizationController = localizationController
        self.resetContentOnLayoutDirectionChange = resetContentOnLayoutDirectionChange
        self.content = content()
    }

    /// 注入本地化环境值后的内容视图。
    public var body: some View {
        content
            .environmentObject(localizationController)
            .environment(\.locale, localizationController.locale)
            .environment(\.layoutDirection, localizationController.layoutDirection.swiftUILayoutDirection)
            // 某些旧系统容器无法原地刷新方向时，调用方可显式切换视图标识。
            // 此回退方案会丢弃子树状态，因此不作为默认刷新路径。
            .id(layoutDirectionIdentity)
    }
}

public extension View {
    /// 将 `LocalizationController`、`Locale` 和 SwiftUI `LayoutDirection` 注入视图层级。
    ///
    /// SwiftUI 的 `Text(LocalizedStringKey)` 会读取环境中的 `locale`。自定义
    /// UIKit 桥接类型应在 `updateUIView` 或 `updateUIViewController` 中读取
    /// `context.environment.locale` 和 `context.environment.layoutDirection`。
    ///
    /// ```swift
    /// RootView()
    ///     .appLocalizationEnvironment(localizationController)
    /// ```
    ///
    /// - Parameters:
    ///   - localizationController: 要注入视图层级的本地化控制器。
    ///   - resetContentOnLayoutDirectionChange: 是否在布局方向变化时重建接收者。
    /// - Returns: 注入本地化环境值的视图。
    func appLocalizationEnvironment(
        _ localizationController: LocalizationController,
        resetContentOnLayoutDirectionChange: Bool = false
    ) -> some View {
        LocalizationEnvironmentView(
            localizationController: localizationController,
            resetContentOnLayoutDirectionChange: resetContentOnLayoutDirectionChange
        ) {
            self
        }
    }
}
#endif
