#if canImport(SwiftUI)
import SwiftUI

public extension AppUserInterfaceLayoutDirection {
    /// 对应的 SwiftUI 布局方向。
    var swiftUILayoutDirection: LayoutDirection {
        self == .rightToLeft ? .rightToLeft : .leftToRight
    }
}

/// 向内容提供应用本地化状态的视图。
///
/// 包装每个场景的根视图，将控制器作为环境对象注入，
/// 并使区域设置和布局方向与控制器状态保持同步。
public struct LocalizationEnvironmentView<Content: View>: View {
    // 观察选择变化，使环境值随控制器状态更新。
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

    /// 创建向内容提供本地化环境值的视图。
    ///
    /// 仅在容器无法原地更新方向时启用内容重置。重置会改变内容标识，
    /// 丢弃子树状态，包括导航和呈现状态。
    ///
    /// - Parameters:
    ///   - localizationController: 提供本地化状态的控制器。
    ///   - resetContentOnLayoutDirectionChange: 指示是否在方向变化时重置内容标识的布尔值。
    ///     默认值为 `false`。
    ///   - content: 创建内容的视图构建闭包。
    public init(
        localizationController: LocalizationController,
        resetContentOnLayoutDirectionChange: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.localizationController = localizationController
        self.resetContentOnLayoutDirectionChange = resetContentOnLayoutDirectionChange
        self.content = content()
    }

    /// 已在环境中注入控制器、区域设置和布局方向的内容。
    public var body: some View {
        content
            .environmentObject(localizationController)
            .environment(\.locale, localizationController.locale)
            .environment(\.layoutDirection, localizationController.layoutDirection.swiftUILayoutDirection)
            // 保持内容标识稳定，除非调用方明确选择在方向变化时丢弃子树状态。
            .id(layoutDirectionIdentity)
    }
}

public extension View {
    /// 向视图提供应用的本地化控制器、区域设置和布局方向。
    ///
    /// 将此修饰符应用于每个场景的根视图。UIKit 桥接类型应在更新方法中读取
    /// `context.environment.locale` 和 `context.environment.layoutDirection`，
    /// 并刷新通过命令式接口设置的内容。
    ///
    /// - Parameters:
    ///   - localizationController: 提供本地化状态的控制器。
    ///   - resetContentOnLayoutDirectionChange: 指示是否在方向变化时重置内容标识的布尔值。
    ///     默认值为 `false`。启用后，方向变化会丢弃内容的局部状态。
    /// - Returns: 注入指定本地化环境的视图。
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
