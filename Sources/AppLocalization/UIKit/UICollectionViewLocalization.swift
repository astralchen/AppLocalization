#if canImport(UIKit)
import UIKit

/// 集合视图中条目的索引路径及其在可见区域中的位置。
///
/// 偏移量相对于扣除调整后内容边距的可见区域。水平偏移以语义前缘为基准，
/// 可在方向变化后恢复。恢复锚点时，索引路径必须仍指向同一条目。
public struct UICollectionViewLocalizationAnchor: Equatable {
    /// 作为锚点的条目索引路径。
    public let indexPath: IndexPath

    /// 从可见区域顶部到条目顶部的有符号距离。
    public let offsetFromViewportTop: CGFloat

    /// 从可见区域前缘到条目前缘的有符号距离。
    public let offsetFromViewportLeading: CGFloat

    /// 使用条目及其相对于可见区域的位置创建锚点。
    ///
    /// - Parameters:
    ///   - indexPath: 要保留位置的条目索引路径。
    ///   - offsetFromViewportTop: 相对于可见区域顶部的有符号垂直距离。
    ///   - offsetFromViewportLeading: 从可见区域语义前缘向内测量的有符号水平距离。
    public init(
        indexPath: IndexPath,
        offsetFromViewportTop: CGFloat,
        offsetFromViewportLeading: CGFloat
    ) {
        self.indexPath = indexPath
        self.offsetFromViewportTop = offsetFromViewportTop
        self.offsetFromViewportLeading = offsetFromViewportLeading
    }
}

public extension UICollectionView {
    /// 捕获首个可见条目相对于可见区域的位置。
    ///
    /// 先按从上到下、再按从前缘到后缘的顺序排列可见条目。
    /// 可见区域不包含调整后的内容边距。
    ///
    /// - Returns: 条目的索引路径和偏移量；没有可见条目的布局属性与可见区域相交时返回 `nil`。
    func captureLocalizationAnchor()
        -> UICollectionViewLocalizationAnchor? {
        layoutIfNeeded()
        let visibleViewport = CGRect(
            x: contentOffset.x + adjustedContentInset.left,
            y: contentOffset.y + adjustedContentInset.top,
            width: max(
                0,
                bounds.width
                    - adjustedContentInset.left
                    - adjustedContentInset.right
            ),
            height: max(
                0,
                bounds.height
                    - adjustedContentInset.top
                    - adjustedContentInset.bottom
            )
        )
        let visibleAttributes = indexPathsForVisibleItems
            .compactMap { layoutAttributesForItem(at: $0) }
            .filter { $0.frame.intersects(visibleViewport) }
        let attributes = visibleAttributes.min { lhs, rhs in
            if abs(lhs.frame.minY - rhs.frame.minY) > 0.5 {
                return lhs.frame.minY < rhs.frame.minY
            }
            if effectiveUserInterfaceLayoutDirection == .rightToLeft {
                return lhs.frame.maxX > rhs.frame.maxX
            }
            return lhs.frame.minX < rhs.frame.minX
        }
        guard let attributes else {
            return nil
        }

        let indexPath = attributes.indexPath
        let frame = attributes.frame
        let viewportTop = contentOffset.y + adjustedContentInset.top
        let offsetFromViewportLeading: CGFloat
        if effectiveUserInterfaceLayoutDirection == .rightToLeft {
            let viewportRight = contentOffset.x
                + bounds.width
                - adjustedContentInset.right
            offsetFromViewportLeading = viewportRight - frame.maxX
        } else {
            let viewportLeft = contentOffset.x + adjustedContentInset.left
            offsetFromViewportLeading = frame.minX - viewportLeft
        }

        return UICollectionViewLocalizationAnchor(
            indexPath: indexPath,
            offsetFromViewportTop: frame.minY - viewportTop,
            offsetFromViewportLeading: offsetFromViewportLeading
        )
    }

    /// 使用已捕获的锚点恢复条目位置。
    ///
    /// 读取条目几何信息前先完成集合视图布局。将结果偏移限制在可滚动内容边界内，
    /// 并以无动画方式应用。
    ///
    /// - Parameter anchor: 索引路径仍指向目标条目的锚点。
    /// - Returns: 条目具有有效索引路径和布局属性时返回 `true`，否则返回 `false`。
    ///   内容边界限制可能导致位置无法完全恢复。
    @discardableResult
    func restoreLocalizationAnchor(
        _ anchor: UICollectionViewLocalizationAnchor
    ) -> Bool {
        guard containsItem(at: anchor.indexPath) else { return false }
        layoutIfNeeded()
        guard let attributes = layoutAttributesForItem(
            at: anchor.indexPath
        ) else {
            return false
        }

        let frame = attributes.frame
        let minimumOffsetX = -adjustedContentInset.left
        let maximumOffsetX = max(
            minimumOffsetX,
            contentSize.width - bounds.width + adjustedContentInset.right
        )
        let minimumOffsetY = -adjustedContentInset.top
        let maximumOffsetY = max(
            minimumOffsetY,
            contentSize.height - bounds.height + adjustedContentInset.bottom
        )

        let proposedOffsetX: CGFloat
        if effectiveUserInterfaceLayoutDirection == .rightToLeft {
            proposedOffsetX = frame.maxX
                + anchor.offsetFromViewportLeading
                - bounds.width
                + adjustedContentInset.right
        } else {
            proposedOffsetX = frame.minX
                - anchor.offsetFromViewportLeading
                - adjustedContentInset.left
        }
        let proposedOffsetY = frame.minY
            - anchor.offsetFromViewportTop
            - adjustedContentInset.top

        setContentOffset(
            CGPoint(
                x: min(max(proposedOffsetX, minimumOffsetX), maximumOffsetX),
                y: min(max(proposedOffsetY, minimumOffsetY), maximumOffsetY)
            ),
            animated: false
        )
        return true
    }

    /// 更新集合视图方向和布局，并按需保留可见条目的位置。
    ///
    /// 仅在更新请求方向刷新时执行。刷新可见复用内容并使当前布局失效；
    /// 如果语义属性变化且提供了布局工厂，则替换布局。
    ///
    /// 保留位置时，恢复首个可见条目的索引路径及其相对于语义可见区域的偏移。
    /// 没有可用锚点时，将首个条目对齐到前缘。更新期间应保持索引路径稳定；
    /// 锚点不跟踪数据源标识符。
    ///
    /// - Parameters:
    ///   - update: 要应用的本地化状态和刷新原因。
    ///   - shouldPreserveVisibleItem: 指示是否保留可见条目及其偏移的布尔值。默认值为 `true`。
    ///   - makeLayout: 语义属性变化时创建布局的闭包，适用于失效后仍保留方向缓存的布局。
    ///     为 `nil` 时，使当前布局失效。
    func applyLocalization(
        _ update: UIKitLocalizationUpdate,
        preservingVisibleItem shouldPreserveVisibleItem: Bool = true,
        rebuildingLayoutWith makeLayout: (() -> UICollectionViewLayout)? = nil
    ) {
        guard update.requiresLayoutDirectionRefresh else { return }
        let layoutDirection = update.snapshot.layoutDirection
        let visibleAnchor = shouldPreserveVisibleItem
            ? captureLocalizationAnchor()
            : nil
        // 保留索引路径和语义偏移，避免沿用物理偏移。
        // 尚无可见条目时，从首个条目的语义前缘开始。
        let targetIndexPath = visibleAnchor?.indexPath
            ?? (shouldPreserveVisibleItem
                ? firstItemIndexPathForDirectionReset()
                : nil)

        let semanticContentAttribute = layoutDirection.semanticContentAttribute
        let directionChanged = self.semanticContentAttribute
            != semanticContentAttribute
        self.semanticContentAttribute = semanticContentAttribute

        if directionChanged, let makeLayout {
            // 替换在失效后仍保留方向缓存的布局。
            setCollectionViewLayout(makeLayout(), animated: false)
        } else {
            collectionViewLayout.invalidateLayout()
        }
        refreshVisibleContent(for: update)
        // 使用新方向下的几何信息前先完成布局。
        layoutIfNeeded()

        if let visibleAnchor {
            restoreLocalizationAnchor(visibleAnchor)
        } else if let targetIndexPath {
            scrollToItem(
                at: targetIndexPath,
                // 将初始条目对齐到语义前缘。
                at: layoutDirection == .rightToLeft ? .right : .left,
                animated: false
            )
        }
    }

    private func refreshVisibleContent(for update: UIKitLocalizationUpdate) {
        for cell in visibleCells {
            UIKitReusableLocalizationDispatcher.apply(update, to: cell)
        }

        let supplementaryKinds = Set(
            (collectionViewLayout.layoutAttributesForElements(in: bounds) ?? [])
                .compactMap(\.representedElementKind)
        )
        for kind in supplementaryKinds {
            for view in visibleSupplementaryViews(ofKind: kind) {
                UIKitReusableLocalizationDispatcher.apply(update, to: view)
            }
        }
    }

    private func firstItemIndexPathForDirectionReset() -> IndexPath? {
        for section in 0..<numberOfSections {
            if numberOfItems(inSection: section) > 0 {
                return IndexPath(item: 0, section: section)
            }
        }

        return nil
    }

    private func containsItem(at indexPath: IndexPath) -> Bool {
        indexPath.section >= 0
            && indexPath.section < numberOfSections
            && indexPath.item >= 0
            && indexPath.item < numberOfItems(inSection: indexPath.section)
    }
}
#endif
