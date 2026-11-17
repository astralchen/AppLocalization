# 不兼容迁移

最低工具链改为 Swift 6.3，语言模式保持 Swift 6；框架只支持 iOS 15+。移除 macOS 平台声明及 UIKit／SwiftUI 的 canImport 包裹。命令行宿主 `swift test` 不再适用，应使用 iOS 模拟器上的 Xcode 包测试。

| 原用法 | 新用法 |
| --- | --- |
| LocalizedCollectionViewFlowLayout | 删除；应用直接提供原生或业务自定义布局，镜像排列策略由业务布局拥有 |
| UIKitLocalizationContext | 删除；普通列表和输入无需上下文或绑定 |
| dequeueLocalizedReusableCell／HeaderFooterView | 原生 UITableView dequeue，然后执行原有业务配置 |
| makeCellRegistration／makeSupplementaryRegistration | 原生 UIKit registration，闭包只执行业务配置 |
| prepareForConfiguration／restoreOnAttachment | 删除；原生列表管理复用方向，willDisplay 重用业务配置以读取最新语言 |
| tableView／collectionView.applyLocalization | 删除；列表继承容器方向，页面更新业务内容 |
| cell.applyLocalizationDirection | 普通外壳交给 UIKit；特殊业务节点直接设置原生 semanticContentAttribute |
| update.attachment／configuration 及对应 reason | 删除；首次配置使用 LocalizationUpdate(snapshot:)；后续更新从前后快照推导 |
| UIViewLayoutDirectionTargetProviding | 删除未被消费的协议；需要的组件直接设置原生 semanticContentAttribute |
| 订阅 `$currentLocale`／`$followsSystemLocale` | 订阅 `$currentSnapshot`，从同一个值读取所有字段；普通属性读取不变 |
| 应用接收通知后调用 `coordinator.apply(change)` | 创建并持有协调器后自动参与事务；删除通知转发 |
| `reloadAllScenes`／隐式发现系统窗口 | 为每个应用拥有的窗口显式 `register(window:)`，断开时 unregister |
| `apply(change,recoveryAction:)` | 普通更新自动执行；根替换／恢复由应用直接使用 UIKit，再 synchronize(window:) |
| `UIKitLocalizationPreparing` | 删除；页面只实现 UIKitLocalizationApplying.applyLocalization(_:) |
| 每个页面自行拼接列表捕获／刷新／恢复 | 删除额外列表恢复机制，采用 UIKit 原生行为 |
| `preservingVisibleRow`／`preservingVisibleItem` | 删除；不再承诺精确阅读锚点恢复 |
| 公共 `UICollectionViewLocalizationAnchor`／捕获恢复索引路径 | 全部删除，使用原生滚动行为 |
| `systemLocaleIdentifierProvider` 单值重载 | 使用 `systemLocaleIdentifiersProvider` 数组提供器 |
| 默认跟随 `Locale.preferredLanguages` | 默认跟随 `resourceBundle.preferredLocalizations`；其他策略显式注入 |
| 自定义 contentConfiguration 在方向切换时自动重建 | 保留实例；自定义组件按需设置原生方向属性，输入控件保持原生行为 |
| 自定义 presented handler 闭包 | 删除框架边界协议；特殊界面的关闭／重建由业务拥有者处理 |

原来的 `setLocale`、`setFollowsSystemLocale`、resolver.string 和方向语义工具继续使用。没有增加旧 API 的别名或双轨兼容层。

## 页面迁移

```swift
final class ItemsViewController: UIViewController, UIKitLocalizationApplying {
    override func viewDidLoad() {
        super.viewDidLoad()
        // 按原生 UIKit 方式创建布局、注册 cell 和配置数据源。
        applyLocalization(LocalizationUpdate(snapshot: localizationController.currentSnapshot))
    }

    func applyLocalization(_ update: LocalizationUpdate) {
        guard update.requiresLocalizedContentRefresh else { return }
        // 由页面更新标题、文本和数据源，无需列表本地化对象。
        updateLocalizedContent()
    }
}
```

删除仅用于列表恢复的 revision 捕获和 complete(revision:) completion；普通 snapshot 直接使用 dataSource.apply(snapshot, animatingDifferences: false)。真正的异步业务结果若依赖语言版本，仍应验证 revision。首次页面渲染直接调用 applyLocalization(LocalizationUpdate(snapshot: ...))。

## 选择持久化

不改变原有 UserDefaults key 或值格式。原有具体语言标识符与 `system` 均继续读取；不支持的旧标识符仍降级到资源包回退语言，不擅自改成跟随系统。选择模式变化但生效语言相同时仍递增 revision 并通知观察者。

## 仓库内示例

- LanguageSwitchingDemo 删除手动通知转发，保持 SwiftUI 根身份稳定，场景激活时同步窗口。列表原地更新可见内容，系统返回手势对象和代理保留。
- Today 删除 AppDelegate 的异步通知转发；列表采用原生 diffable 数据源和滚动行为。
- Today 详情的 Row 不再包含翻译文案、草稿字符串或 Date 值。编辑行使用固定业务身份，从 workingReminder 读取内容，避免热切换替换输入单元格。
- SwiftUI/UIKit 桥接仍读取环境的 locale 和 layoutDirection；SwiftUI 环境更新与已注册窗口的 UIKit 更新各有明确责任。

Today 保持原工程 iOS 18 的部署目标；主示例和框架保持 iOS 15。没有为了重构降低 Today 原有系统 API 要求。

## 移除组件树接线

删除所有 localizationChildren 声明。列表与输入都采用原生 UIKit 行为，不持有额外的本地化对象。仅用于转发输入绑定的 UIContentView 可同时移除 UIKitLocalizationApplying conformance 和空的 applyLocalization 方法；页面无需扫描 cell.contentView 或其子视图。

## 移除输入绑定

删除 UIKitTextInputLocalizationBinding、UIKitTextInputAlignmentPolicy、inputBinding 属性、相关 refresh 调用及仅用于刷新的 didMoveToWindow。普通输入内容视图不再导入 AppLocalization 或依赖语言服务。改用 UIKit 的语义继承和 natural 对齐；这是明确的行为调整，不再统一强制对齐到应用前缘，也不再自动修补业务改写后的 typingAttributes。固定策略直接设置原生 semanticContentAttribute／textAlignment。

## 移除列表协调器

删除 UIKitListLocalizationCoordinator、UIKitListLocalizationState、listLocalization 属性、初始化 ID 映射和 complete(revision:)。同时删除仅服务它们的内部自动订阅和集合视图锚点工具。滚动、选择、布局更新交给 UIKit；框架不再承诺数据重排／高度变化后的业务 ID 精确锚点、相对偏移或正交分页位置恢复。

## 收敛公开接入 API

| 删除的抽象／包装 | 当前方式 |
| --- | --- |
| prepareForLocalization／finishLocalization | 页面仅实现 applyLocalization(_:) |
| update.apply(to:)、initial(snapshot:)／change(_:) 工厂 | 页面直接接收 LocalizationUpdate(snapshot:) 或 LocalizationUpdate(snapshot:previousSnapshot:) |
| UIKitLocalizationUpdateReason／reasons | 从 snapshot 与 previousSnapshot 推导刷新需求 |
| LocalizationTransactionParticipant、WeakLocalizationParticipant、通用参与者注册 | 删除协议和弱引用包装；内部直接调度具体窗口协调器，以原生有序弱容器保存。业务仍只注册应用窗口 |
| LocalizationTransactionDirectionApplying | 合并为内部事务的方向阶段，不再动态查找第二个协议 |
| LocalizationEnvironmentView／resetContentOnLayoutDirectionChange | 仅使用 appLocalizationEnvironment；业务自行管理局部身份 |
| NavigationBarItemBuilder／闭包式按钮 DSL | 使用普通 UIBarButtonItem 数组，语义 side 不变 |
| UIWindowLocalizationRecoveryAction／根工厂／recover | 应用按自己的状态模型替换根控制器，再 synchronize(window:) |
| PresentedLocalizationBoundaryRebuilding | 普通 presented 链正常刷新；特殊系统／第三方界面的重建由业务处理 |

LocalePreferenceStore、LocalizedStringResolver、快照／变更值类型和语义方向工具仍保留，它们分别承担可替换持久化、资源回退、原子状态与布局语义，没有为了减少类型数量合并不同职责。

## 移除视图方向包装

删除 UIViewLayoutDirection.swift 及 UIViewLayoutDirectionTarget、UIViewLayoutDirectionUpdater、UIViewLayoutDirectionPolicy；同时删除未被使用的 DirectionalContentSemantics。特殊内容直接采用 UIKit 的 UISemanticContentAttribute。

| 原策略／调用 | 原生方式 |
| --- | --- |
| 普通视图的 inherited／followContainer | 保持默认 `.unspecified`，由 UIKit 继承；不再把父视图的当前方向复制为长期强制值 |
| followApplication | 普通视图无需代码；仅在明确需要独立强制方向时设置 `view.semanticContentAttribute = update.semanticContentAttribute` |
| fixed(.forceLeftToRight／.spatial／.playback) | 直接设置相应的 `view.semanticContentAttribute` |
| updater 自动重建配置、重设附件及使布局失效 | 删除；业务内容变化通过原生配置 API 更新，自定义布局按实际需要失效 |

原 inherited 策略不会清除既有属性；迁移时同样保留原有业务例外。只有需要撤销业务自己设置的强制方向时才写回 `.unspecified`。框架不遍历子视图统一重置这些属性，也不接管 cell 外壳的方向。主示例的两个普通按钮已删除方向更新代码，直接继承容器方向。

配置式按钮若热切换后图标位置未更新，在其业务配置处比较按钮的旧 semanticContentAttribute 与新方向；仅不同时设置 configuration = nil，随后设置新方向并赋回业务配置，最后 setNeedsLayout。参照 UIKitLanguageDemo/Screens/LanguagePickerView.swift。该方式已通过严格回归，保留按钮实例、状态与 action；框架不恢复批量配置重建机制，其他普通控件保持原生继承。

## iOS 17+ 与 iOS 15/16 的方向传播

窗口注册 API 不变，但 iOS 17+ 的方向作用域改为所属 UIWindowScene；没有 Scene 才回退窗口 trait override。同 Scene 的未注册窗口同样继承方向，注销仅停止内容投递，不恢复 Scene 方向。不同语言方向的独立场景应使用不同 Scene，不再依赖同 Scene 窗口注册隔离方向。

普通控制器不再被框架逐个设置 traitOverrides 和强制语义方向；它们通过原生层级继承，业务显式方向例外保留。导航容器的 view、navigationBar、toolbar 仍在所有版本同步语义方向。iOS 15/16 则使用窗口／视图语义边界，以及已有父容器、呈现控制器的 trait override，保留其他 traits，不插入额外宿主。

未挂载页面的实际方向应在挂载后检查；首次文案与配置使用 update.snapshot。iOS 15/16 运行时目前未安装，现有证据为部署目标编译及在新系统调用旧版公开 API 的测试，不等于旧系统运行验收。

## 示例改为原生导航所有权

LanguageSwitchingDemo 删除 NavigationPopGestureConfigurator、WindowLocalizationRegistrationView 和 WindowRegistrationView。SceneDelegate 创建并注册窗口，DemoNavigationController 直接使用 UINavigationController 的 push、present、dismiss；SwiftUI 页面通过操作闭包请求导航，不再内嵌 NavigationView、隐藏 NavigationLink 或导航探测背景。

语言切换只更新现有宿主的标题、环境和方向，不替换 rootView、不重建导航栈、不接管 interactivePopGestureRecognizer 的代理。SwiftUI 根仍注入 appLocalizationEnvironment；编辑页保持稳定输入框和局部 List 身份方案。此调整仅属于示例组合方式，没有新增框架容器或通用导航包装。

## 导航项改用 UIKit 原生属性

删除 UINavigationItemLocalization.swift、NavigationItemPlacement 及 setBarButtonItem(_:side:animated:)、setBarButtonItems(_:side:animated:) 扩展，不保留兼容别名。

```swift
// UIKit 根据导航栏方向解析前缘与后缘，RTL 下不要手动交换。
navigationItem.leftBarButtonItem = closeButton
navigationItem.rightBarButtonItems = [saveButton, moreButton]
// 需要动画时使用原生 setLeftBarButtonItems／setRightBarButtonItems。
```

原包装附带的数组去重和跨侧迁移行为一并移除。若业务要移动同一按钮，应显式从原槽位移除，再安装到目标槽位；这与语言切换无关。示例静态按钮只安装一次，语言变化刷新标题，编辑状态改变时再调整按钮组合。

此前诊断的 customView 热切换位置问题已修复：现有窗口协调器在首次／方向刷新时，对 UINavigationBar.items 的左右导航项 customView 调用原生 invalidateIntrinsicContentSize。业务继续使用 UIBarButtonItem(customView:)，无需增加新类型或手动重新安装按钮。原有 item、view、action、状态及 fixed LTR／playback 语义保持不变；不重建导航栏、不延迟调度。同方向语言变化不触发此失效。

窗口协调器内部改用 Foundation 原生弱集合，显式注册、注销、Scene 方向作用域和投递顺序保持不变。DemoServices 不再声明 ObservableObject；页面继续观察 LocalizationController。Today 的系统语言刷新由场景激活同步负责。

## 统一本地化更新值

删除 LocalizationChange 和 UIKitLocalizationUpdate，统一使用 LocalizationUpdate，不保留兼容 typealias 或中间转换构造器。

| 原接口 | 当前接口 |
| --- | --- |
| UIKitLocalizationUpdate(snapshot:) | LocalizationUpdate(snapshot:)；首次／显式同步，完整刷新 |
| LocalizationChange(previous:current:) 后再 UIKitLocalizationUpdate(change:) | LocalizationUpdate(snapshot:previousSnapshot:)；实际状态变化，差异刷新 |
| change.current／change.previous | update.snapshot／update.previousSnapshot；旧快照现在可选 |
| change.localeChanged 或 change.selectionChanged 决定内容刷新 | update.requiresLocalizedContentRefresh |
| change.layoutDirectionChanged 决定方向刷新 | update.requiresLayoutDirectionRefresh；首次刷新也为 true |
| UIKitLocalizationApplying.applyLocalization(_ update: UIKitLocalizationUpdate) | 参数改为 LocalizationUpdate |

通知名称及 LocalizationController.localizationChangeUserInfoKey 不变，通知值转换为 LocalizationUpdate。若业务需要单独判断语言或选择模式，比较 previousSnapshot 与 snapshot 的对应属性；刷新入口使用统一的 requires 属性，不再维护两套变化标志。控制器发出的通知始终有旧快照，首次配置和同步不发通知。

## 使用 UIKit 原生方向类型

删除 AppUserInterfaceLayoutDirection 和 UIKitLayoutDirectionConversions.swift；公开方向属性及 DirectionalLayout 参数统一为 UIUserInterfaceLayoutDirection，不保留兼容别名。需要显式书写类型名时导入 UIKit。

- 删除 `.uiLayoutDirection` 和 `.appLayoutDirection`：直接使用 `controller.layoutDirection` 或 `view.effectiveUserInterfaceLayoutDirection`。
- 删除 `.swiftUILayoutDirection`：在 SwiftUI 边界使用 `direction == .rightToLeft ? .rightToLeft : .leftToRight` 注入环境。根视图仍调用 `.appLocalizationEnvironment(controller)`，不需要额外配置。
- 方向值不再提供 `.semanticContentAttribute` 扩展：页面接收更新时可以使用 `update.semanticContentAttribute`；具体业务边界直接选择 `.forceRightToLeft`／`.forceLeftToRight`。
- Scene 的 `traitOverrides.layoutDirection` 属于另一原生枚举类型，原有显式映射保留；不要将两种 UIKit 方向类型当成同一个类型。
- 自定义 `backSwipeRectEdge`、`backChevronSystemName` 和语义手势函数仍在 DirectionalLayout 中，直接接受原生方向；系统返回手势不替换对象或代理。

## 使用原生语义与物理边缘

删除 SemanticHorizontalDirection 和 PhysicalHorizontalEdge，不保留 typealias。

| 原接口 | 当前接口 |
| --- | --- |
| SemanticHorizontalDirection | NSDirectionalRectEdge；手势函数仅返回单一 leading／trailing |
| PhysicalHorizontalEdge | UIRectEdge；水平映射仅返回单一 left／right |
| physicalEdge(for:layoutDirection:) | 参数改为 NSDirectionalRectEdge，返回 UIRectEdge?；非单一水平边缘返回 nil |
| backSwipeEdge(layoutDirection:) | 删除重复入口，使用 backSwipeRectEdge(layoutDirection:) |

原生边缘类型是 OptionSet，不能再用只有两个分支的穷尽 switch 处理所有可能值。展示手势结果时对 leading／trailing 分别处理，其余情况回到未识别状态。映射输入使用精确单边缘校验，不用 contains 静默接受组合。

```swift
let edge = DirectionalLayout.backSwipeRectEdge(
    layoutDirection: view.effectiveUserInterfaceLayoutDirection
)
edgePanGesture.edges = edge
```

示例的 lastDirection 改为 NSDirectionalRectEdge?；系统 UINavigationController 的返回手势仍由 UIKit 管理，不以此代码替换系统手势。位移阈值、RTL 的前缘／后缘语义与返回方向保持不变。

## 资源包与 Foundation 原生语言策略

删除 LocalizationController 的 supportedLocales／fallbackLocale 初始化参数；不增加新的 supportedLocalizations／fallbackLocalization 初始化参数。改用 `LocalizationController(resourceBundle: .main, preferenceStore: store)`。可选语言直接声明在 String Catalog／Bundle 中；只读 `supportedLocalizations: [String]` 用于语言选择器，按需构造 `AppLocale(identifier:)` 获取名称及方向。

解析器不再提供默认英语 fallback，调用方显式传入 `AppLocale(identifier: controller.fallbackLocalization)`。核心的 `.englishUS`、`.simplifiedChinese`、`.arabic` 删除，不提供兼容别名。示例英语语言项与自动化标识符从 en-US 改为实际资源的 en；旧持久化选择会按语言族匹配，显式选择当前 en 会修正存储且不发伪更新。

方向推导不再维护 rightToLeftScripts。iOS 16+ 使用 Locale.Language.characterDirection，iOS 15 使用旧 Locale.characterDirection API。显式脚本测试改为验证与系统结果一致；不再强制 az-Arab 必须返回 RTL。此项是采用系统策略的行为契约变更，不是预期失败。

格式化仍采用当前内容语言对应的 Locale；没有新增地区偏好策略。事务顺序、快照发布、原生输入实例及返回手势保持原有接入方式。
