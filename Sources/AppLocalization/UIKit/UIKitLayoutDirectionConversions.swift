#if canImport(UIKit)
import UIKit

public extension AppUserInterfaceLayoutDirection {
    /// 对应的 UIKit 布局方向。
    var uiLayoutDirection: UIUserInterfaceLayoutDirection {
        self == .rightToLeft ? .rightToLeft : .leftToRight
    }

    /// 用于强制采用此布局方向的语义内容属性。
    ///
    /// 使用此值应用当前选择的应用方向，使其不受系统语言影响。
    var semanticContentAttribute: UISemanticContentAttribute {
        self == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
    }
}

public extension UIUserInterfaceLayoutDirection {
    /// 对应的应用布局方向。
    var appLayoutDirection: AppUserInterfaceLayoutDirection {
        self == .rightToLeft ? .rightToLeft : .leftToRight
    }
}

public extension DirectionalLayout {
    /// 返回自定义返回手势使用的矩形边缘。
    ///
    /// - Parameter layoutDirection: 界面布局方向。
    /// - Returns: 从左向右布局时返回 `.left`，从右向左布局时返回 `.right`。
    static func backSwipeRectEdge(layoutDirection: AppUserInterfaceLayoutDirection) -> UIRectEdge {
        switch backSwipeEdge(layoutDirection: layoutDirection) {
        case .left:
            return .left
        case .right:
            return .right
        }
    }

    /// 返回自定义返回箭头使用的系统符号名称。
    ///
    /// - Parameter layoutDirection: 界面布局方向。
    /// - Returns: 从左向右布局时返回 `chevron.left`，从右向左布局时返回 `chevron.right`。
    static func backChevronSystemName(layoutDirection: AppUserInterfaceLayoutDirection) -> String {
        switch backSwipeEdge(layoutDirection: layoutDirection) {
        case .left:
            return "chevron.left"
        case .right:
            return "chevron.right"
        }
    }
}
#endif
