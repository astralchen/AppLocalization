import UIKit

/// 在语义水平方向与物理水平方向之间转换的工具。
public enum DirectionalLayout {
    /// 返回水平位移对应的语义方向。
    ///
    /// 正值表示向物理右侧移动。零值与负值使用相同的判断分支。
    /// 需要最小移动距离或校验非有限值时，使用带 `minimumDistance` 的重载。
    ///
    /// - Parameters:
    ///   - translationX: 视图坐标系中的水平位移。
    ///   - layoutDirection: 界面布局方向。
    /// - Returns: 单一 `.leading` 或 `.trailing`，不返回多边缘组合。
    public static func semanticHorizontalDirection(
        translationX: CGFloat,
        layoutDirection: UIUserInterfaceLayoutDirection
    ) -> NSDirectionalRectEdge {
        let isPhysicalRight = translationX > 0

        if layoutDirection == .rightToLeft {
            return isPhysicalRight ? .leading : .trailing
        }
        return isPhysicalRight ? .trailing : .leading
    }

    /// 返回超过最小距离的位移所对应的语义方向。
    ///
    /// 负的最小距离按零处理。位移或最小距离为非有限值时返回 `nil`。
    ///
    /// - Parameters:
    ///   - translationX: 视图坐标系中的水平位移。
    ///   - layoutDirection: 界面布局方向。
    ///   - minimumDistance: 位移绝对值必须超过的距离。
    /// - Returns: 单一 `.leading` 或 `.trailing`；位移不满足条件时返回 `nil`。
    public static func semanticHorizontalDirection(
        translationX: CGFloat,
        layoutDirection: UIUserInterfaceLayoutDirection,
        minimumDistance: CGFloat
    ) -> NSDirectionalRectEdge? {
        guard translationX.isFinite,
              minimumDistance.isFinite,
              abs(translationX) > max(0, minimumDistance)
        else {
            return nil
        }

        return semanticHorizontalDirection(
            translationX: translationX,
            layoutDirection: layoutDirection
        )
    }

    /// 将单一水平语义边缘转换为 UIKit 物理边缘。
    ///
    /// - Parameters:
    ///   - semanticEdge: 单一 `.leading` 或 `.trailing`。
    ///   - layoutDirection: 界面布局方向。
    /// - Returns: 单一 `.left` 或 `.right`；空集合、垂直边缘、组合或未知值返回 nil。
    public static func physicalEdge(
        for semanticEdge: NSDirectionalRectEdge,
        layoutDirection: UIUserInterfaceLayoutDirection
    ) -> UIRectEdge? {
        guard semanticEdge == .leading || semanticEdge == .trailing else { return nil }
        let leadingIsLeft = layoutDirection != .rightToLeft
        let isLeft = semanticEdge == .leading ? leadingIsLeft : !leadingIsLeft
        return isLeft ? .left : .right
    }

    /// 返回自定义返回手势的原生矩形边缘。
    /// LTR 使用左边缘，RTL 使用右边缘。
    public static func backSwipeRectEdge(layoutDirection: UIUserInterfaceLayoutDirection) -> UIRectEdge {
        layoutDirection == .rightToLeft ? .right : .left
    }

    /// 返回自定义返回箭头的系统符号名称。
    public static func backChevronSystemName(layoutDirection: UIUserInterfaceLayoutDirection) -> String {
        layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left"
    }

    /// 返回指示位移是否表示返回手势的布尔值。
    ///
    /// 零位移和非有限位移不表示返回手势。
    ///
    /// - Parameters:
    ///   - translationX: 视图坐标系中的水平位移。
    ///   - layoutDirection: 界面布局方向。
    /// - Returns: 位移朝向语义后缘时返回 `true`。
    public static func isBackSwipe(
        translationX: CGFloat,
        layoutDirection: UIUserInterfaceLayoutDirection
    ) -> Bool {
        isBackSwipe(
            translationX: translationX,
            layoutDirection: layoutDirection,
            minimumDistance: 0
        )
    }

    /// 返回指示返回手势是否超过最小距离的布尔值。
    ///
    /// 负的最小距离按零处理。位移或最小距离为非有限值时返回 `false`。
    ///
    /// - Parameters:
    ///   - translationX: 视图坐标系中的水平位移。
    ///   - layoutDirection: 界面布局方向。
    ///   - minimumDistance: 位移绝对值必须超过的距离。
    /// - Returns: 位移朝向语义后缘且超过阈值时返回 `true`。
    public static func isBackSwipe(
        translationX: CGFloat,
        layoutDirection: UIUserInterfaceLayoutDirection,
        minimumDistance: CGFloat
    ) -> Bool {
        semanticHorizontalDirection(
            translationX: translationX,
            layoutDirection: layoutDirection,
            minimumDistance: minimumDistance
        ) == .trailing
    }

    /// 返回自定义入栈转场的起始水平偏移量。
    ///
    /// - Parameters:
    ///   - width: 转场容器的宽度，使用其绝对值。
    ///   - layoutDirection: 界面布局方向。
    /// - Returns: 朝向语义后缘的有符号偏移量。
    public static func pushStartOffset(
        width: CGFloat,
        layoutDirection: UIUserInterfaceLayoutDirection
    ) -> CGFloat {
        signedHorizontalOffset(
            distance: width,
            layoutDirection: layoutDirection
        )
    }

    /// 返回自定义出栈转场的结束水平偏移量。
    ///
    /// - Parameters:
    ///   - width: 转场容器的宽度，使用其绝对值。
    ///   - layoutDirection: 界面布局方向。
    /// - Returns: 朝向语义后缘的有符号偏移量。
    public static func popEndOffset(
        width: CGFloat,
        layoutDirection: UIUserInterfaceLayoutDirection
    ) -> CGFloat {
        signedHorizontalOffset(
            distance: width,
            layoutDirection: layoutDirection
        )
    }

    private static func signedHorizontalOffset(
        distance: CGFloat,
        layoutDirection: UIUserInterfaceLayoutDirection
    ) -> CGFloat {
        let magnitude = abs(distance)

        return layoutDirection == .rightToLeft ? -magnitude : magnitude
    }
}
