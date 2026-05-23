#if canImport(SwiftUI)
import SwiftUI

public extension AppUserInterfaceLayoutDirection {
    /// 转成 SwiftUI 的 `LayoutDirection`。
    var swiftUILayoutDirection: LayoutDirection {
        self == .rightToLeft ? .rightToLeft : .leftToRight
    }
}

/// 给 SwiftUI 内容注入 App 内 locale 环境。
///
/// 每个 scene root 都应该包一层，让 SwiftUI 在 `currentLocale` 变化时同步拿到
/// 最新的 `Locale` 和 `LayoutDirection`。不要只在单个窗口里注入，否则 iPad
/// 多窗口场景会出现某些窗口不刷新的问题。
///
/// ```swift
/// WindowGroup {
///     RootView()
///         .appLocalizationEnvironment(localizationController)
/// }
/// ```
public struct LocalizationEnvironmentView<Content: View>: View {
    /// 使用 `@ObservedObject` 让 locale 变化触发 SwiftUI body 重算。
    @ObservedObject private var localizationController: LocalizationController
    private let resetContentOnLayoutDirectionChange: Bool
    private let content: Content

    /// 创建环境包装视图。
    public init(
        localizationController: LocalizationController,
        resetContentOnLayoutDirectionChange: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.localizationController = localizationController
        self.resetContentOnLayoutDirectionChange = resetContentOnLayoutDirectionChange
        self.content = content()
    }

    /// 注入 `EnvironmentObject`、`Locale` 和 `LayoutDirection`。
    public var body: some View {
        content
            .environmentObject(localizationController)
            .environment(\.locale, localizationController.locale)
            .environment(\.layoutDirection, localizationController.layoutDirection.swiftUILayoutDirection)
            // 修复点：SwiftUI 的 List、NavigationView、toolbar 等容器会复用内部宿主 view。
            // 多次随机在 LTR/RTL 间切换时，如果只改 environment，旧方向下创建的 cell
            // 可能和新语言文案混在同一棵树里，表现为文字反排、按钮位置错乱。
            // 因此只在“布局方向”变化时切换 identity，让 SwiftUI 丢弃方向敏感子树；
            // 同方向语言切换（例如 en <-> zh-Hans）仍走普通 body 重算，避免无谓重建。
            .id(layoutDirectionIdentity)
    }

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
}

public extension View {
    /// 注入 `LocalizationController`、`Locale` 和 SwiftUI `LayoutDirection`。
    ///
    /// SwiftUI 的 `Text(LocalizedStringKey)` 会读取环境中的 `locale`；自定义
    /// UIKit bridge 则应在 `updateUIView` / `updateUIViewController` 里读取
    /// `context.environment.locale` 和 `context.environment.layoutDirection`。
    ///
    /// ```swift
    /// RootView()
    ///     .appLocalizationEnvironment(localizationController)
    /// ```
    func appLocalizationEnvironment(
        _ localizationController: LocalizationController,
        resetContentOnLayoutDirectionChange: Bool = true
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
