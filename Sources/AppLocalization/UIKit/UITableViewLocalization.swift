#if canImport(UIKit)
import UIKit

public extension UITableView {
    /// 取出可复用单元格，并在返回前应用当前本地化方向。
    ///
    /// 此方法返回后，再设置文本和内容配置。
    ///
    /// - Parameters:
    ///   - identifier: 注册单元格时使用的复用标识符。
    ///   - indexPath: 单元格在表格视图中的索引路径。
    ///   - context: 提供最新本地化快照的上下文。
    ///   - policy: 单元格的方向策略。默认值为 `.followApplication`。
    ///   - cellType: 预期的单元格类型；省略时由返回类型推断。
    /// - Returns: 已完成内容配置准备的单元格。
    /// - Precondition: 标识符已注册，且对应单元格与 `Cell` 类型兼容。
    func dequeueLocalizedReusableCell<Cell: UITableViewCell>(
        withIdentifier identifier: String,
        for indexPath: IndexPath,
        using context: UIKitLocalizationContext,
        policy: UIViewLayoutDirectionPolicy = .followApplication,
        as cellType: Cell.Type = Cell.self
    ) -> Cell {
        let dequeuedCell = dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        guard let cell = dequeuedCell as? Cell else {
            preconditionFailure(
                "Registered cell for \(identifier) is not \(String(reflecting: cellType))"
            )
        }
        context.prepareForConfiguration(cell, policy: policy)
        return cell
    }

    /// 取出可复用页眉或页脚视图，并应用当前本地化方向。
    ///
    /// 此方法返回后，再设置文本和内容配置。
    ///
    /// - Parameters:
    ///   - identifier: 页眉或页脚视图的复用标识符。
    ///   - context: 提供最新本地化快照的上下文。
    ///   - policy: 视图的方向策略。默认值为 `.followApplication`。
    ///   - viewType: 预期的视图类型；省略时由返回类型推断。
    /// - Returns: 已准备好的视图；表格无法取出视图时返回 `nil`。
    /// - Precondition: 取出的视图与 `View` 类型兼容。
    func dequeueLocalizedReusableHeaderFooterView<View: UITableViewHeaderFooterView>(
        withIdentifier identifier: String,
        using context: UIKitLocalizationContext,
        policy: UIViewLayoutDirectionPolicy = .followApplication,
        as viewType: View.Type = View.self
    ) -> View? {
        guard let dequeuedView = dequeueReusableHeaderFooterView(withIdentifier: identifier) else {
            return nil
        }
        guard let view = dequeuedView as? View else {
            preconditionFailure(
                "Registered header/footer for \(identifier) is not \(String(reflecting: viewType))"
            )
        }
        context.prepareForConfiguration(view, policy: policy)
        return view
    }

    /// 更新表格方向和可见内容，并按需保留可见行的位置。
    ///
    /// 仅在更新请求方向刷新时执行。更新可见单元格、分区页眉和页脚，以及表格自身的
    /// 页眉和页脚，然后执行布局，不调用 `reloadData()`。
    ///
    /// 启用位置保留时，在内容边界允许的范围内保留首个可见索引路径及其垂直偏移。
    /// 锚点使用索引路径，不跟踪数据源标识符。本地化数据应通过数据源刷新。
    /// 异步快照改变行的几何布局时，应结合其完成回调安排此次更新。
    ///
    /// 具有自定义方向状态的复用视图应实现 ``UIKitLocalizationApplying``，更新自身拥有的内容。
    ///
    /// - Parameters:
    ///   - update: 要应用的本地化状态和刷新原因。
    ///   - shouldPreserveVisibleRow: 指示是否保留首个可见行及其垂直偏移的布尔值。
    ///     默认值为 `true`。
    func applyLocalization(
        _ update: UIKitLocalizationUpdate,
        preservingVisibleRow shouldPreserveVisibleRow: Bool = true
    ) {
        guard update.requiresLayoutDirectionRefresh else { return }
        let visibleRowAnchor: (indexPath: IndexPath, offsetFromViewportTop: CGFloat)? = {
            guard shouldPreserveVisibleRow,
                  let indexPath = indexPathsForVisibleRows?.sorted().first else {
                return nil
            }

            return (
                indexPath: indexPath,
                offsetFromViewportTop: rectForRow(at: indexPath).minY - contentOffset.y
            )
        }()

        semanticContentAttribute = update.semanticContentAttribute
        refreshVisibleContent(for: update)
        setNeedsLayout()
        layoutIfNeeded()

        guard let visibleRowAnchor,
              containsRow(at: visibleRowAnchor.indexPath) else {
            return
        }

        let proposedOffsetY = rectForRow(at: visibleRowAnchor.indexPath).minY
            - visibleRowAnchor.offsetFromViewportTop
        let minimumOffsetY = -adjustedContentInset.top
        let maximumOffsetY = max(
            minimumOffsetY,
            contentSize.height - bounds.height + adjustedContentInset.bottom
        )
        var restoredContentOffset = contentOffset
        restoredContentOffset.y = min(max(proposedOffsetY, minimumOffsetY), maximumOffsetY)
        setContentOffset(restoredContentOffset, animated: false)
    }

    private func refreshVisibleContent(for update: UIKitLocalizationUpdate) {
        for cell in visibleCells {
            UIKitReusableLocalizationDispatcher.apply(update, to: cell)
        }

        for section in 0..<numberOfSections {
            let visibleSupplementaryViews = [
                headerView(forSection: section),
                footerView(forSection: section)
            ]

            for view in visibleSupplementaryViews.compactMap({ $0 }) {
                UIKitReusableLocalizationDispatcher.apply(update, to: view)
            }
        }

        for view in [tableHeaderView, tableFooterView].compactMap({ $0 }) {
            UIViewLayoutDirectionUpdater.apply(
                update,
                to: UIViewLayoutDirectionTarget(view, policy: .followApplication)
            )
            (view as? UIKitLocalizationApplying)?.applyLocalization(update)
        }
    }

    private func containsRow(at indexPath: IndexPath) -> Bool {
        indexPath.section >= 0
            && indexPath.section < numberOfSections
            && indexPath.row >= 0
            && indexPath.row < numberOfRows(inSection: indexPath.section)
    }
}
#endif
