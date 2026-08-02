import Foundation

/// 语义水平方向。
///
/// 语义方向表达用户意图，不绑定物理左侧或右侧。在从左向右布局中，前缘位于左侧；
/// 在从右向左布局中，前缘位于右侧。
public enum SemanticHorizontalDirection: Equatable, Sendable {
    /// 界面的前缘方向。
    case leading

    /// 界面的后缘方向。
    case trailing
}

/// 物理水平边缘。
///
/// 与 `SemanticHorizontalDirection` 不同，它永远表示屏幕上的实际左/右。
public enum PhysicalHorizontalEdge: Equatable, Sendable {
    /// 屏幕的物理左边缘。
    case left

    /// 屏幕的物理右边缘。
    case right
}

/// 内容的方向语义。
///
/// 大多数界面控件可以镜像；但地图、播放器、时间线、图表和游戏场景等
/// 可能需要保持空间或播放语义，不应简单随布局方向镜像。
public enum DirectionalContentSemantics: Equatable, Sendable {
    /// 跟随界面方向镜像。
    case mirrored

    /// 空间语义内容，例如地图、平面图、游戏世界。
    case spatial

    /// 播放语义内容，例如视频进度条或音频波形。
    case playback
}

/// 与从左向右和从右向左布局相关的方向计算工具。
///
/// 此类型集中处理物理方向与语义方向的转换，避免业务代码依赖仅适用于
/// 从左向右布局的判断。
public enum DirectionalLayout {
    /// 将物理拖拽距离转换成语义方向。
    ///
    /// 不应将 `translation.x > 0` 直接映射为固定业务动作。在从右向左布局中，
    /// 同一物理滑动方向会映射到相反的语义方向。
    ///
    /// ```swift
    /// let direction = DirectionalLayout.semanticHorizontalDirection(
    ///     translationX: pan.translation(in: view).x,
    ///     layoutDirection: view.effectiveUserInterfaceLayoutDirection.appLayoutDirection
    /// )
    ///
    /// switch direction {
    /// case .leading:
    ///     revealLeadingActions()
    /// case .trailing:
    ///     revealTrailingActions()
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - translationX: 手势在水平方向上的物理位移。
    ///   - layoutDirection: 当前界面布局方向。
    /// - Returns: 与物理位移对应的语义方向。
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

    /// 在物理拖拽距离超过阈值后，将它转换为语义方向。
    ///
    /// 与只返回两个方向的重载不同，此方法可用 `nil` 表示静止或幅度不足的手势。
    /// 负阈值按零处理，非有限数值会被拒绝。
    ///
    /// - Parameters:
    ///   - translationX: 手势在水平方向上的物理位移。
    ///   - layoutDirection: 当前界面布局方向。
    ///   - minimumDistance: 识别方向所需超过的最小位移。
    /// - Returns: 位移有效且超过阈值时返回语义方向；否则返回 `nil`。
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

    /// 将语义水平方向转换为物理边缘。
    ///
    /// ```swift
    /// let physicalEdge = DirectionalLayout.physicalEdge(
    ///     for: .leading,
    ///     layoutDirection: localizationController.layoutDirection
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - semanticEdge: 要转换的语义方向。
    ///   - layoutDirection: 当前界面布局方向。
    /// - Returns: 与语义方向对应的物理边缘。
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

    /// 返回自定义返回手势应该监听的物理边缘。
    ///
    /// ```swift
    /// edgePan.edges = DirectionalLayout.backSwipeEdge(
    ///     layoutDirection: localizationController.layoutDirection
    /// ) == .right ? .right : .left
    /// ```
    ///
    /// - Parameter layoutDirection: 当前界面布局方向。
    /// - Returns: 返回手势应监听的物理边缘。
    public static func backSwipeEdge(layoutDirection: AppUserInterfaceLayoutDirection) -> PhysicalHorizontalEdge {
        physicalEdge(for: .leading, layoutDirection: layoutDirection)
    }

    /// 返回物理平移手势是否表示返回操作。
    ///
    /// ```swift
    /// if DirectionalLayout.isBackSwipe(
    ///     translationX: pan.translation(in: view).x,
    ///     layoutDirection: localizationController.layoutDirection
    /// ) {
    ///     navigationController?.popViewController(animated: true)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - translationX: 手势在水平方向上的物理位移。
    ///   - layoutDirection: 当前界面布局方向。
    /// - Returns: 手势朝语义后缘移动时为 `true`；否则为 `false`。
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

    /// 返回超过移动阈值的平移手势是否表示返回操作。
    ///
    /// 使用阈值可避免将静止触摸或轻微抖动误判为导航手势。
    ///
    /// - Parameters:
    ///   - translationX: 手势在水平方向上的物理位移。
    ///   - layoutDirection: 当前界面布局方向。
    ///   - minimumDistance: 识别返回操作所需超过的最小位移。
    /// - Returns: 位移超过阈值并朝语义后缘移动时为 `true`；否则为 `false`。
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
    /// ```swift
    /// incomingView.frame.origin.x = DirectionalLayout.pushStartOffset(
    ///     width: container.bounds.width,
    ///     layoutDirection: localizationController.layoutDirection
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - width: 转场容器的宽度。
    ///   - layoutDirection: 当前界面布局方向。
    /// - Returns: 指向语义后缘的有符号水平偏移量。
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
    /// ```swift
    /// outgoingView.frame.origin.x = DirectionalLayout.popEndOffset(
    ///     width: container.bounds.width,
    ///     layoutDirection: localizationController.layoutDirection
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - width: 转场容器的宽度。
    ///   - layoutDirection: 当前界面布局方向。
    /// - Returns: 指向语义后缘的有符号水平偏移量。
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
