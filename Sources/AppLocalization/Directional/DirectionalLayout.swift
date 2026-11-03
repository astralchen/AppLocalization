import Foundation

/// 相对于界面布局方向的水平方向。
///
/// 从左向右布局时，前缘位于左侧；从右向左布局时，前缘位于右侧。
public enum SemanticHorizontalDirection: Equatable, Sendable {
    /// 朝向界面前缘的方向。
    case leading

    /// 朝向界面后缘的方向。
    case trailing
}

/// 物理坐标中的水平边缘，不受布局方向影响。
public enum PhysicalHorizontalEdge: Equatable, Sendable {
    /// 物理左边缘。
    case left

    /// 物理右边缘。
    case right
}

/// 内容的方向语义。
///
/// 对于含义不应随界面布局方向变化的内容，使用空间语义或播放语义。
public enum DirectionalContentSemantics: Equatable, Sendable {
    /// 随界面布局方向镜像的内容。
    case mirrored

    /// 具有空间含义的内容，例如地图或游戏世界。
    case spatial

    /// 具有播放含义的内容，例如进度指示器或波形。
    case playback
}

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
    /// - Returns: 与位移对应的前缘或后缘方向。
    public static func semanticHorizontalDirection(
        translationX: CGFloat,
        layoutDirection: AppUserInterfaceLayoutDirection
    ) -> SemanticHorizontalDirection {
        let isPhysicalRight = translationX > 0

        switch layoutDirection {
        case .leftToRight:
            return isPhysicalRight ? .trailing : .leading
        case .rightToLeft:
            return isPhysicalRight ? .leading : .trailing
        }
    }

    /// 返回超过最小距离的位移所对应的语义方向。
    ///
    /// 负的最小距离按零处理。位移或最小距离为非有限值时返回 `nil`。
    ///
    /// - Parameters:
    ///   - translationX: 视图坐标系中的水平位移。
    ///   - layoutDirection: 界面布局方向。
    ///   - minimumDistance: 位移绝对值必须超过的距离。
    /// - Returns: 对应的语义方向；位移不满足条件时返回 `nil`。
    public static func semanticHorizontalDirection(
        translationX: CGFloat,
        layoutDirection: AppUserInterfaceLayoutDirection,
        minimumDistance: CGFloat
    ) -> SemanticHorizontalDirection? {
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

    /// 返回语义方向对应的物理边缘。
    ///
    /// - Parameters:
    ///   - semanticEdge: 要转换的语义方向。
    ///   - layoutDirection: 界面布局方向。
    /// - Returns: 对应的物理左边缘或右边缘。
    public static func physicalEdge(
        for semanticEdge: SemanticHorizontalDirection,
        layoutDirection: AppUserInterfaceLayoutDirection
    ) -> PhysicalHorizontalEdge {
        switch (semanticEdge, layoutDirection) {
        case (.leading, .leftToRight), (.trailing, .rightToLeft):
            return .left
        case (.trailing, .leftToRight), (.leading, .rightToLeft):
            return .right
        }
    }

    /// 返回用于返回手势的物理起始边缘。
    ///
    /// - Parameter layoutDirection: 界面布局方向。
    /// - Returns: 语义前缘对应的物理边缘。
    public static func backSwipeEdge(layoutDirection: AppUserInterfaceLayoutDirection) -> PhysicalHorizontalEdge {
        physicalEdge(for: .leading, layoutDirection: layoutDirection)
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
        layoutDirection: AppUserInterfaceLayoutDirection
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
        layoutDirection: AppUserInterfaceLayoutDirection,
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
        layoutDirection: AppUserInterfaceLayoutDirection
    ) -> CGFloat {
        signedHorizontalOffset(
            distance: width,
            toward: .trailing,
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
        layoutDirection: AppUserInterfaceLayoutDirection
    ) -> CGFloat {
        signedHorizontalOffset(
            distance: width,
            toward: .trailing,
            layoutDirection: layoutDirection
        )
    }

    private static func signedHorizontalOffset(
        distance: CGFloat,
        toward semanticDirection: SemanticHorizontalDirection,
        layoutDirection: AppUserInterfaceLayoutDirection
    ) -> CGFloat {
        let magnitude = abs(distance)

        switch physicalEdge(for: semanticDirection, layoutDirection: layoutDirection) {
        case .left:
            return -magnitude
        case .right:
            return magnitude
        }
    }
}
