#if canImport(UIKit)
import UIKit

@MainActor
enum UIKitReusableLocalizationDispatcher {
    static func apply(
        _ update: UIKitLocalizationUpdate,
        to cell: UITableViewCell,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        apply(
            update,
            targets: [
                UIViewLayoutDirectionTarget(cell, policy: policy),
                UIViewLayoutDirectionTarget(cell.contentView, policy: policy)
            ],
            component: cell
        )
    }

    static func apply(
        _ update: UIKitLocalizationUpdate,
        to cell: UICollectionViewCell,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        apply(
            update,
            targets: [
                UIViewLayoutDirectionTarget(cell, policy: policy),
                UIViewLayoutDirectionTarget(cell.contentView, policy: policy)
            ],
            component: cell
        )
    }

    static func apply(
        _ update: UIKitLocalizationUpdate,
        to view: UITableViewHeaderFooterView,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        apply(
            update,
            targets: [UIViewLayoutDirectionTarget(view, policy: policy)],
            component: view
        )
    }

    static func apply(
        _ update: UIKitLocalizationUpdate,
        to view: UICollectionReusableView,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        if let cell = view as? UICollectionViewCell {
            apply(update, to: cell, policy: policy)
            return
        }

        apply(
            update,
            targets: [UIViewLayoutDirectionTarget(view, policy: policy)],
            component: view
        )
    }

    private static func apply(
        _ update: UIKitLocalizationUpdate,
        targets: [UIViewLayoutDirectionTarget],
        component: UIView
    ) {
        UIViewLayoutDirectionUpdater.apply(update, to: targets)
        (component as? UIKitLocalizationApplying)?.applyLocalization(update)
    }
}

@MainActor
public extension UITableViewCell {
    /// 向单元格及其内容视图应用本地化方向。
    ///
    /// 此方法更新公开视图边界，不调用单元格的本地化回调。
    /// 组件独立拥有的其他方向目标应在该回调中更新。
    ///
    /// - Parameters:
    ///   - update: 要应用的本地化状态和刷新原因。
    ///   - policy: 两个视图采用的方向策略。默认值为 `.followApplication`。
    func applyLocalizationDirection(
        _ update: UIKitLocalizationUpdate,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIViewLayoutDirectionUpdater.apply(
            update,
            to: [
                UIViewLayoutDirectionTarget(self, policy: policy),
                UIViewLayoutDirectionTarget(contentView, policy: policy)
            ]
        )
    }

}

@MainActor
public extension UICollectionViewCell {
    /// 向单元格及其内容视图应用本地化方向。
    ///
    /// 此方法更新公开视图边界，不调用单元格的本地化回调。
    /// 组件独立拥有的其他方向目标应在该回调中更新。
    ///
    /// - Parameters:
    ///   - update: 要应用的本地化状态和刷新原因。
    ///   - policy: 两个视图采用的方向策略。默认值为 `.followApplication`。
    func applyLocalizationDirection(
        _ update: UIKitLocalizationUpdate,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIViewLayoutDirectionUpdater.apply(
            update,
            to: [
                UIViewLayoutDirectionTarget(self, policy: policy),
                UIViewLayoutDirectionTarget(contentView, policy: policy)
            ]
        )
    }

}
#endif
