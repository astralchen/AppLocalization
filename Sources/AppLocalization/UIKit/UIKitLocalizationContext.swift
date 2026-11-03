#if canImport(UIKit)
import UIKit

/// 向复用视图和文本输入控件提供当前本地化状态的上下文。
///
/// 上下文持有快照提供闭包，并在每次配置或挂载时重新读取状态。
/// 注册对象先恢复方向，再调用内容处理闭包。
/// 从代理的 `willDisplay` 回调调用挂载辅助方法，使复用或重新挂载的内容使用最新状态。
@MainActor
public struct UIKitLocalizationContext {
    private let snapshotProvider: @MainActor () -> LocalizationSnapshot

    /// 使用提供当前本地化状态的闭包创建上下文。
    ///
    /// 上下文持有提供闭包，不缓存其返回的快照。
    ///
    /// - Parameter snapshotProvider: 读取当前本地化快照的闭包。
    public init(
        snapshotProvider: @escaping @MainActor () -> LocalizationSnapshot
    ) {
        self.snapshotProvider = snapshotProvider
    }

    /// 创建从控制器读取本地化状态的上下文。
    ///
    /// - Parameter localizationController: 要持有的控制器，每次操作时向其读取状态。
    public init(localizationController: LocalizationController) {
        self.init { [localizationController] in
            localizationController.currentSnapshot
        }
    }

    /// 为单行文本输入框创建本地化绑定。
    ///
    /// 调用方应持有绑定，并在本地化状态变化或通过代码修改输入后刷新。
    ///
    /// - Parameters:
    ///   - textField: 要同步的单行输入框。绑定弱引用此控件。
    ///   - alignment: 文本对齐策略。默认值为 `.followLayoutDirection`。
    /// - Returns: 使用当前本地化状态初始化的绑定。
    public func makeTextInputBinding(
        to textField: UITextField,
        alignment: UIKitTextInputAlignmentPolicy = .followLayoutDirection
    ) -> UIKitTextInputLocalizationBinding {
        UIKitTextInputLocalizationBinding(
            textField: textField, alignment: alignment, snapshotProvider: snapshotProvider
        )
    }

    /// 为多行文本输入框创建本地化绑定。
    ///
    /// 调用方应持有绑定，并在本地化状态变化或通过代码修改输入后刷新。
    /// 绑定保留视图的现有代理，并原地更新段落对齐。
    ///
    /// - Parameters:
    ///   - textView: 要同步的多行输入框。绑定弱引用此控件。
    ///   - alignment: 文本对齐策略。默认值为 `.followLayoutDirection`。
    /// - Returns: 使用当前本地化状态初始化的绑定。
    public func makeTextInputBinding(
        to textView: UITextView,
        alignment: UIKitTextInputAlignmentPolicy = .followLayoutDirection
    ) -> UIKitTextInputLocalizationBinding {
        UIKitTextInputLocalizationBinding(
            textView: textView, alignment: alignment, snapshotProvider: snapshotProvider
        )
    }

    /// 为搜索栏公开的文本输入框创建本地化绑定。
    ///
    /// 调用方应持有绑定，并在本地化状态变化或通过代码修改输入后刷新。
    ///
    /// - Parameters:
    ///   - searchBar: 要同步的搜索栏。绑定弱引用此控件。
    ///   - alignment: 文本对齐策略。默认值为 `.followLayoutDirection`。
    /// - Returns: 使用当前本地化状态初始化的绑定。
    public func makeTextInputBinding(
        to searchBar: UISearchBar,
        alignment: UIKitTextInputAlignmentPolicy = .followLayoutDirection
    ) -> UIKitTextInputLocalizationBinding {
        UIKitTextInputLocalizationBinding(
            searchBar: searchBar, alignment: alignment, snapshotProvider: snapshotProvider
        )
    }

    /// 使用当前本地化方向准备表格单元格。
    ///
    /// 在设置文本或内容配置前调用。先恢复方向，再调用视图可选的本地化回调。
    /// 此次更新包含配置和布局方向原因。
    ///
    /// - Parameters:
    ///   - cell: 要准备的视图。
    ///   - policy: 要应用的方向策略。默认值为 `.followApplication`。
    public func prepareForConfiguration(
        _ cell: UITableViewCell,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIKitReusableLocalizationDispatcher.apply(
            .configuration(snapshot: snapshotProvider()),
            to: cell,
            policy: policy
        )
    }

    /// 使用当前本地化方向准备表格页眉或页脚。
    ///
    /// 在设置文本或内容配置前调用。先恢复方向，再调用视图可选的本地化回调。
    /// 此次更新包含配置和布局方向原因。
    ///
    /// - Parameters:
    ///   - view: 要准备的视图。
    ///   - policy: 要应用的方向策略。默认值为 `.followApplication`。
    public func prepareForConfiguration(
        _ view: UITableViewHeaderFooterView,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIKitReusableLocalizationDispatcher.apply(
            .configuration(snapshot: snapshotProvider()),
            to: view,
            policy: policy
        )
    }

    /// 使用当前本地化方向准备集合复用视图。
    ///
    /// 在设置文本或内容配置前调用。先恢复方向，再调用视图可选的本地化回调。
    /// 此次更新包含配置和布局方向原因。
    ///
    /// - Parameters:
    ///   - view: 要准备的视图。
    ///   - policy: 要应用的方向策略。默认值为 `.followApplication`。
    public func prepareForConfiguration(
        _ view: UICollectionReusableView,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIKitReusableLocalizationDispatcher.apply(
            .configuration(snapshot: snapshotProvider()),
            to: view,
            policy: policy
        )
    }

    /// 在表格单元格挂载时恢复当前本地化方向。
    ///
    /// 从对应代理的 `willDisplay` 回调调用此方法。
    /// 读取最新快照，先恢复方向，再调用视图可选的本地化回调。
    ///
    /// - Parameters:
    ///   - cell: 即将显示或重新挂载的视图。
    ///   - policy: 要应用的方向策略。默认值为 `.followApplication`。
    public func restoreOnAttachment(
        _ cell: UITableViewCell,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIKitReusableLocalizationDispatcher.apply(
            .attachment(snapshot: snapshotProvider()),
            to: cell,
            policy: policy
        )
    }

    /// 在表格页眉或页脚挂载时恢复当前本地化方向。
    ///
    /// 从对应代理的 `willDisplay` 回调调用此方法。
    /// 读取最新快照，先恢复方向，再调用视图可选的本地化回调。
    ///
    /// - Parameters:
    ///   - view: 即将显示或重新挂载的视图。
    ///   - policy: 要应用的方向策略。默认值为 `.followApplication`。
    public func restoreOnAttachment(
        _ view: UITableViewHeaderFooterView,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIKitReusableLocalizationDispatcher.apply(
            .attachment(snapshot: snapshotProvider()),
            to: view,
            policy: policy
        )
    }

    /// 在集合复用视图挂载时恢复当前本地化方向。
    ///
    /// 从对应代理的 `willDisplay` 回调调用此方法。
    /// 读取最新快照，先恢复方向，再调用视图可选的本地化回调。
    ///
    /// - Parameters:
    ///   - view: 即将显示或重新挂载的视图。
    ///   - policy: 要应用的方向策略。默认值为 `.followApplication`。
    public func restoreOnAttachment(
        _ view: UICollectionReusableView,
        policy: UIViewLayoutDirectionPolicy = .followApplication
    ) {
        UIKitReusableLocalizationDispatcher.apply(
            .attachment(snapshot: snapshotProvider()),
            to: view,
            policy: policy
        )
    }

    /// 创建在配置内容前恢复方向的单元格注册对象。
    ///
    /// 在数据源请求单元格之前创建并复用此注册对象。
    /// 每次配置时读取最新快照，然后调用 `handler`。
    ///
    /// - Parameters:
    ///   - policy: 单元格的方向策略。默认值为 `.followApplication`。
    ///   - handler: 恢复方向后配置单元格的闭包。
    /// - Returns: 使用此上下文快照提供闭包的单元格注册对象。
    public func makeCellRegistration<Cell: UICollectionViewCell, Item>(
        policy: UIViewLayoutDirectionPolicy = .followApplication,
        handler: @escaping UICollectionView.CellRegistration<Cell, Item>.Handler
    ) -> UICollectionView.CellRegistration<Cell, Item> {
        UICollectionView.CellRegistration<Cell, Item> { cell, indexPath, item in
            prepareForConfiguration(cell, policy: policy)
            handler(cell, indexPath, item)
        }
    }

    /// 创建基于 nib 且在配置前恢复方向的单元格注册对象。
    ///
    /// 在数据源请求单元格之前创建并复用此注册对象。
    ///
    /// - Parameters:
    ///   - cellNib: 用于创建单元格的 nib。
    ///   - policy: 单元格的方向策略。默认值为 `.followApplication`。
    ///   - handler: 恢复方向后配置单元格的闭包。
    /// - Returns: 每次配置时读取当前快照的单元格注册对象。
    public func makeCellRegistration<Cell: UICollectionViewCell, Item>(
        cellNib: UINib,
        policy: UIViewLayoutDirectionPolicy = .followApplication,
        handler: @escaping UICollectionView.CellRegistration<Cell, Item>.Handler
    ) -> UICollectionView.CellRegistration<Cell, Item> {
        UICollectionView.CellRegistration<Cell, Item>(cellNib: cellNib) {
            cell,
            indexPath,
            item in
            prepareForConfiguration(cell, policy: policy)
            handler(cell, indexPath, item)
        }
    }

    /// 创建在配置前恢复方向的补充视图注册对象。
    ///
    /// 在数据源请求补充视图之前创建并复用此注册对象。
    ///
    /// - Parameters:
    ///   - elementKind: 布局用于标识此类补充视图的标识符。
    ///   - policy: 视图的方向策略。默认值为 `.followApplication`。
    ///   - handler: 恢复方向后配置视图的闭包。
    /// - Returns: 每次配置时读取当前快照的补充视图注册对象。
    public func makeSupplementaryRegistration<Supplementary: UICollectionReusableView>(
        elementKind: String,
        policy: UIViewLayoutDirectionPolicy = .followApplication,
        handler: @escaping UICollectionView.SupplementaryRegistration<Supplementary>.Handler
    ) -> UICollectionView.SupplementaryRegistration<Supplementary> {
        UICollectionView.SupplementaryRegistration<Supplementary>(
            elementKind: elementKind
        ) { view, elementKind, indexPath in
            prepareForConfiguration(view, policy: policy)
            handler(view, elementKind, indexPath)
        }
    }

    /// 创建基于 nib 且在配置前恢复方向的补充视图注册对象。
    ///
    /// 在数据源请求补充视图之前创建并复用此注册对象。
    ///
    /// - Parameters:
    ///   - supplementaryNib: 用于创建补充视图的 nib。
    ///   - elementKind: 布局用于标识此类补充视图的标识符。
    ///   - policy: 视图的方向策略。默认值为 `.followApplication`。
    ///   - handler: 恢复方向后配置视图的闭包。
    /// - Returns: 每次配置时读取当前快照的补充视图注册对象。
    public func makeSupplementaryRegistration<Supplementary: UICollectionReusableView>(
        supplementaryNib: UINib,
        elementKind: String,
        policy: UIViewLayoutDirectionPolicy = .followApplication,
        handler: @escaping UICollectionView.SupplementaryRegistration<Supplementary>.Handler
    ) -> UICollectionView.SupplementaryRegistration<Supplementary> {
        UICollectionView.SupplementaryRegistration<Supplementary>(
            supplementaryNib: supplementaryNib,
            elementKind: elementKind
        ) {
            view,
            elementKind,
            indexPath in
            prepareForConfiguration(view, policy: policy)
            handler(view, elementKind, indexPath)
        }
    }
}
#endif
