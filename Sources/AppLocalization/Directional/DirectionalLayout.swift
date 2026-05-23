import Foundation

/// 语义水平方向。
///
/// `leading`/`trailing` 表达用户意图，不绑定物理左/右。LTR 中 leading 是左，
/// RTL 中 leading 是右。
public enum SemanticHorizontalDirection: Equatable, Sendable {
    case leading
    case trailing
}

/// 物理水平边缘。
///
/// 与 `SemanticHorizontalDirection` 不同，它永远表示屏幕上的实际左/右。
public enum PhysicalHorizontalEdge: Equatable, Sendable {
    case left
    case right
}

/// 内容的方向语义。
///
/// 大多数 UI chrome 可以镜像；但地图、播放器、时间线、图表、游戏场景等
/// 可能需要保持空间或播放语义，不应简单按 RTL/LTR 镜像。
public enum DirectionalContentSemantics: Equatable, Sendable {
    /// 跟随界面方向镜像。
    case mirrored

    /// 空间语义内容，例如地图、平面图、游戏世界。
    case spatial

    /// 播放语义内容，例如视频进度条或音频波形。
    case playback
}

/// 与 LTR/RTL 相关的方向计算工具。
///
/// 这里集中处理 physical 与 semantic 的转换，避免业务代码散落
/// `translation.x > 0` 这类只适用于 LTR 的判断。
public enum DirectionalLayout {
    /// 将物理拖拽距离转换成语义方向。
    ///
    /// 不要直接把 `translation.x > 0` 当成固定业务动作。RTL 下，同一个物理
    /// 滑动方向会映射到相反的 semantic side。
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

    /// 把 semantic leading/trailing 转成物理左/右。
    ///
    /// ```swift
    /// let physicalEdge = DirectionalLayout.physicalEdge(
    ///     for: .leading,
    ///     layoutDirection: localizationController.layoutDirection
    /// )
    /// ```
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
    public static func backSwipeEdge(layoutDirection: AppUserInterfaceLayoutDirection) -> PhysicalHorizontalEdge {
        physicalEdge(for: .leading, layoutDirection: layoutDirection)
    }

    /// 判断一次物理 pan 是否应该被当成返回手势。
    ///
    /// ```swift
    /// if DirectionalLayout.isBackSwipe(
    ///     translationX: pan.translation(in: view).x,
    ///     layoutDirection: localizationController.layoutDirection
    /// ) {
    ///     navigationController?.popViewController(animated: true)
    /// }
    /// ```
    public static func isBackSwipe(
        translationX: CGFloat,
        layoutDirection: AppUserInterfaceLayoutDirection
    ) -> Bool {
        semanticHorizontalDirection(
            translationX: translationX,
            layoutDirection: layoutDirection
        ) == .trailing
    }

    /// 自定义 push 转场的起始 x 偏移。
    ///
    /// ```swift
    /// incomingView.frame.origin.x = DirectionalLayout.pushStartOffset(
    ///     width: container.bounds.width,
    ///     layoutDirection: localizationController.layoutDirection
    /// )
    /// ```
    public static func pushStartOffset(
        width: CGFloat,
        layoutDirection: AppUserInterfaceLayoutDirection
    ) -> CGFloat {
        layoutDirection == .rightToLeft ? -width : width
    }

    /// 自定义 pop 转场的结束 x 偏移。
    ///
    /// ```swift
    /// outgoingView.frame.origin.x = DirectionalLayout.popEndOffset(
    ///     width: container.bounds.width,
    ///     layoutDirection: localizationController.layoutDirection
    /// )
    /// ```
    public static func popEndOffset(
        width: CGFloat,
        layoutDirection: AppUserInterfaceLayoutDirection
    ) -> CGFloat {
        layoutDirection == .rightToLeft ? width : -width
    }
}
