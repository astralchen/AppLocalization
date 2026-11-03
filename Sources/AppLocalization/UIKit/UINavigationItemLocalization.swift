#if canImport(UIKit)
import UIKit

/// 导航栏按钮的语义位置。
///
/// 位置随导航栏的布局方向变化。
public enum NavigationItemPlacement: Equatable, Sendable {
    /// 导航栏的语义前缘。
    case leading

    /// 导航栏的语义后缘。
    case trailing
}

/// 创建有序导航栏按钮列表的结果构建器。
///
/// 与 `setBarButtonItems(side:animated:_:)` 配合使用。设置方法保留声明顺序，
/// 并移除重复的按钮实例。构建器自身保留所有按钮，包括重复项。
@resultBuilder
public enum NavigationBarItemBuilder {
    /// 合并声明块中的按钮列表。
    ///
    /// - Parameter components: 按声明顺序排列的按钮列表。
    /// - Returns: 保持声明顺序的扁平按钮列表。
    public static func buildBlock(
        _ components: [UIBarButtonItem]...
    ) -> [UIBarButtonItem] {
        components.flatMap { $0 }
    }

    /// 将单个按钮表达式转换为按钮列表。
    ///
    /// - Parameter expression: 导航栏按钮。
    /// - Returns: 包含该按钮的列表。
    public static func buildExpression(
        _ expression: UIBarButtonItem
    ) -> [UIBarButtonItem] {
        [expression]
    }

    /// 将可选按钮表达式转换为按钮列表。
    ///
    /// - Parameter expression: 可选的导航栏按钮。
    /// - Returns: 包含该按钮的列表；为 `nil` 时返回空列表。
    public static func buildExpression(
        _ expression: UIBarButtonItem?
    ) -> [UIBarButtonItem] {
        expression.map { [$0] } ?? []
    }

    /// 接受导航栏按钮数组。
    ///
    /// - Parameter expression: 有序按钮数组。
    /// - Returns: 传入的数组。
    public static func buildExpression(
        _ expression: [UIBarButtonItem]
    ) -> [UIBarButtonItem] {
        expression
    }

    /// 构建可选条件分支中的按钮列表。
    ///
    /// - Parameter component: 条件分支产生的按钮列表，可以为空。
    /// - Returns: 分支的按钮列表；不存在时返回空列表。
    public static func buildOptional(
        _ component: [UIBarButtonItem]?
    ) -> [UIBarButtonItem] {
        component ?? []
    }

    /// 构建条件语句第一个分支中的按钮列表。
    ///
    /// - Parameter component: 第一个分支产生的按钮列表。
    /// - Returns: 传入的分支按钮列表。
    public static func buildEither(
        first component: [UIBarButtonItem]
    ) -> [UIBarButtonItem] {
        component
    }

    /// 构建条件语句第二个分支中的按钮列表。
    ///
    /// - Parameter component: 第二个分支产生的按钮列表。
    /// - Returns: 传入的分支按钮列表。
    public static func buildEither(
        second component: [UIBarButtonItem]
    ) -> [UIBarButtonItem] {
        component
    }

    /// 合并循环产生的按钮列表。
    ///
    /// - Parameter components: 按迭代顺序排列的按钮列表。
    /// - Returns: 保持迭代顺序的扁平按钮列表。
    public static func buildArray(
        _ components: [[UIBarButtonItem]]
    ) -> [UIBarButtonItem] {
        components.flatMap { $0 }
    }

    /// 构建通过可用性检查的分支中的按钮列表。
    ///
    /// - Parameter component: 可用分支产生的按钮列表。
    /// - Returns: 传入的分支按钮列表。
    public static func buildLimitedAvailability(
        _ component: [UIBarButtonItem]
    ) -> [UIBarButtonItem] {
        component
    }
}

public extension UINavigationItem {
    /// 在指定语义边缘设置导航栏按钮。
    ///
    /// 前缘使用 UIKit 的左侧按钮位置，后缘使用右侧按钮位置。
    /// 导航栏根据自身布局方向完成镜像。
    ///
    /// - Parameters:
    ///   - item: 要显示的按钮；为 `nil` 时清空指定边缘。
    ///   - side: 按钮所属的语义边缘。
    ///   - animated: 指示是否以动画方式更新的布尔值。默认值为 `false`。
    func setBarButtonItem(
        _ item: UIBarButtonItem?,
        side: NavigationItemPlacement,
        animated: Bool = false
    ) {
        setBarButtonItems(
            item.map { [$0] },
            side: side,
            animated: animated
        )
    }

    /// 在指定语义边缘设置一组有序导航栏按钮。
    ///
    /// 每个按钮实例只保留首次出现的位置，并从另一侧移除相同实例。
    /// 传入 `nil` 或空数组时清空指定边缘。此方法不修改 `leftItemsSupplementBackButton`。
    ///
    /// - Parameters:
    ///   - items: 要显示的有序按钮列表；为 `nil` 时清空指定边缘。
    ///   - side: 按钮所属的语义边缘。
    ///   - animated: 指示是否以动画方式更新的布尔值。默认值为 `false`。
    func setBarButtonItems(
        _ items: [UIBarButtonItem]?,
        side: NavigationItemPlacement,
        animated: Bool = false
    ) {
        let normalizedItems = items.normalizedByIdentity
        switch side {
        case .leading:
            removeIdenticalItems(
                normalizedItems ?? [],
                from: .trailing,
                animated: animated
            )
            guard !leftBarButtonItems.isIdentical(to: normalizedItems) else {
                return
            }
            setLeftBarButtonItems(normalizedItems, animated: animated)
        case .trailing:
            removeIdenticalItems(
                normalizedItems ?? [],
                from: .leading,
                animated: animated
            )
            guard !rightBarButtonItems.isIdentical(to: normalizedItems) else {
                return
            }
            setRightBarButtonItems(normalizedItems, animated: animated)
        }
    }

    /// 构建导航栏按钮并设置到指定语义边缘。
    ///
    /// 内容闭包支持单个按钮、可选按钮、数组和条件声明。
    /// 赋值前按对象身份移除重复按钮。
    ///
    /// - Parameters:
    ///   - side: 按钮所属的语义边缘。
    ///   - animated: 指示是否以动画方式更新的布尔值。默认值为 `false`。
    ///   - content: 按显示顺序提供按钮的结果构建闭包。
    func setBarButtonItems(
        side: NavigationItemPlacement,
        animated: Bool = false,
        @NavigationBarItemBuilder _ content: () -> [UIBarButtonItem]
    ) {
        setBarButtonItems(
            content(),
            side: side,
            animated: animated
        )
    }

    private func removeIdenticalItems(
        _ items: [UIBarButtonItem],
        from side: NavigationItemPlacement,
        animated: Bool
    ) {
        guard !items.isEmpty else { return }

        switch side {
        case .leading:
            let remainingItems = leftBarButtonItems
                .removingIdenticalItems(items)
            guard !leftBarButtonItems.isIdentical(to: remainingItems) else {
                return
            }
            setLeftBarButtonItems(remainingItems, animated: animated)
        case .trailing:
            let remainingItems = rightBarButtonItems
                .removingIdenticalItems(items)
            guard !rightBarButtonItems.isIdentical(to: remainingItems) else {
                return
            }
            setRightBarButtonItems(remainingItems, animated: animated)
        }
    }
}

private extension Optional where Wrapped == [UIBarButtonItem] {
    var normalizedByIdentity: [UIBarButtonItem]? {
        guard let items = self, !items.isEmpty else { return nil }
        var seenIdentifiers = Set<ObjectIdentifier>()
        return items.filter {
            seenIdentifiers.insert(ObjectIdentifier($0)).inserted
        }
    }

    func removingIdenticalItems(
        _ items: [UIBarButtonItem]
    ) -> [UIBarButtonItem]? {
        guard let currentItems = self else { return nil }
        let identifiers = Set(items.map(ObjectIdentifier.init))
        let remainingItems = currentItems.filter {
            !identifiers.contains(ObjectIdentifier($0))
        }
        return remainingItems.isEmpty ? nil : remainingItems
    }

    func isIdentical(to other: [UIBarButtonItem]?) -> Bool {
        switch (self, other) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            guard lhs.count == rhs.count else { return false }
            return zip(lhs, rhs).allSatisfy { $0 === $1 }
        default:
            return false
        }
    }
}
#endif
