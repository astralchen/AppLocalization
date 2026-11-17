# AppLocalization

面向 iOS 的 Swift 本地化框架。应用内切换语言时同步文本、布局方向和语义手势，支持 UIKit、SwiftUI、混合界面及多个应用窗口。

- Swift 工具链 **6.3+**，Swift 6 语言模式。
- 框架与 LanguageSwitchingDemo 最低 **iOS 15**；Today 保留其现有 iOS 18 目标。
- 单一 Swift Package，无第三方依赖，无 macOS 适配和 canImport(UIKit) 包裹。
- 普通更新保留窗口、页面、导航栈和编辑实例；根替换或系统界面重建由应用负责。

页面更新、窗口同步与 SwiftUI 环境各保留一个入口；语言控制器在内部直接调度窗口协调器，不提供通用事务参与者接口。本轮公共 API 有不兼容调整，见 [迁移说明](Docs/Migration.md)。职责划分和采用参考项目的边界见 [架构说明](Docs/Architecture.md)，实际运行结果见 [验证记录](Docs/Validation.md)。

方向属性直接使用 UIKit 的 `UIUserInterfaceLayoutDirection`，无需应用枚举与 UIKit 之间转换。语言方向遵循 Foundation：iOS 16+ 使用 `Locale.Language(identifier:).characterDirection`，iOS 15 使用 `Locale.characterDirection(forLanguage:)`；不维护脚本表，不额外保证显式脚本优先。SwiftUI 根仍通过 `appLocalizationEnvironment` 注入语言和方向。

## 架构

| 组成 | 责任 |
| --- | --- |
| LocalizationController | 单一快照发布、选择持久化、系统匹配和同步事务 |
| LocalizationSnapshot / LocalizationUpdate | 生效状态、选择模式、revision 和差异 |
| LocalizedStringResolver | 指定资源包的字符串查找、格式化和缺失回退 |
| DirectionalLayout | 语义前后缘、返回边缘、图标及转场方向 |
| UIWindowSceneLocalizationCoordinator | 自动参与事务，向注册窗口刷新内容；iOS 17+ 在 Scene 传播方向 |
| UIKitLocalizationApplying | 页面文案、菜单和业务配置的单一刷新入口 |
| appLocalizationEnvironment | 向 SwiftUI 注入控制器、locale 和 layoutDirection |

内部顺序为：**固定本轮窗口与页面 → 发布单一新快照 → 全部窗口方向 → 页面内容 → 布局 → 完成通知**。重入语言请求在本轮结束后合并执行。调用方不需要转发本地化通知给窗口协调器。`@Published` 在 willSet 发布，订阅者应使用传入快照；该时刻不代表 UIKit 已完成刷新，完成后的布局应在完成通知中读取。

## 创建服务

```swift
import AppLocalization
import UIKit

@MainActor
final class AppLocaleServices {
    let localizationController: LocalizationController
    let resolver: LocalizedStringResolver
    let localizationCoordinator: UIWindowSceneLocalizationCoordinator

    init() {
        let controller = LocalizationController(
            resourceBundle: .main,
            preferenceStore: UserDefaultsLocalePreferenceStore(key: "app.locale.identifier")
        )
        localizationController = controller
        resolver = LocalizedStringResolver(
            localeProvider: { controller.currentLocale },
            fallbackLocale: AppLocale(identifier: controller.fallbackLocalization)
        )
        localizationCoordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
    }
}
```

服务由应用持有，不需要使用框架单例，也不重复配置支持语言与 fallback：

- `resourceBundle.localizations` 提供全部可选语言，排除 `Base` 并按大小写／分隔符等价规则去重。`supportedLocalizations` 是只读结果，顺序来自资源包。
- `resourceBundle.preferredLocalizations` 用于“跟随系统”，它不是完整语言列表。测试或其他明确的 App 偏好来源可通过 `systemLocaleIdentifiersProvider` 注入。
- `fallbackLocalization` 优先匹配 `developmentLocalization`；无法匹配时依次使用包偏好中的可用语言和首个可用语言。只有 `Base` 时使用声明的开发语言；完全没有语言声明会触发前置条件失败。
- 解析器显式使用控制器解析出的 fallback，不预设英语。开发语言与翻译在 String Catalog／Bundle 中维护；核心库没有 englishUS、simplifiedChinese、arabic 常量。

已有偏好 key 和 `system` 值继续读取。旧地区标识符会匹配到现有资源，例如 `en-US` → `en`；完全不支持的旧选择仍回退，保持显式选择模式。再次选择当前语言时会修正旧持久化值，单纯存储修正不递增 revision、不发布界面更新。当前格式化策略仍跟随所选内容语言，不修改系统 Region。

```swift
services.localizationController.setLocale(identifier: "ar")
services.localizationController.setFollowsSystemLocale()
let title = services.resolver.string("settings.title", bundle: .main)
```

资源使用 `Localizable.xcstrings`，Xcode 编译后的 `.lproj/*.strings` 同样支持。解析器也能读取源码目录中的简单 stringUnit；这不等价于完整的复数或变体解释器。不要长期缓存解析后的 String。

## UIKit 窗口与页面

每个 Scene 连接时注册应用拥有的窗口，断开时注销，激活时同步：

```swift
services.localizationCoordinator.register(window: window)
services.localizationCoordinator.unregister(window: window)
services.localizationCoordinator.synchronize(window: window)
```

方向适配按系统版本区分：

| 系统 | 原生适配方式 |
| --- | --- |
| iOS 17+ | 优先设置注册窗口所属 `UIWindowScene.traitOverrides.layoutDirection`；无 Scene 时设置 `window.traitOverrides.layoutDirection`。普通页面、Tab 和子视图继承 traits，不逐页写 override。内容投递前调用 `updateTraitsIfNeeded()` 完成同步传播。 |
| iOS 15/16 | 设置窗口及已加载页面的 `semanticContentAttribute`；已有父容器通过 `setOverrideTraitCollection(_:forChild:)` 更新子控制器，呈现根通过 `presentationController.overrideTraitCollection` 更新。合并已有 traits，保留其他设置。 |
| 所有支持版本 | 导航控制器的 view、navigationBar 和 toolbar 显式同步语义方向，保留原生转场、返回手势及代理。 |

iOS 17+ 的方向作用域是整个 Scene：同 Scene 的未注册窗口也会继承方向，但不会收到框架的内容刷新。注销窗口只停止内容投递，不撤销共享 Scene 的方向。一个 Scene 应使用同一语言状态；需要不同方向的独立窗口应放在不同 Scene，或者由业务明确设置局部例外。框架不枚举其他窗口，也不覆盖业务子控制器的显式 trait 例外。

已注册窗口加入 Scene 后会清除窗口级的 layoutDirection override，避免无 Scene 阶段留下的值遮蔽共享方向；业务子控制器的显式方向例外仍保留。混合导航示例由 SceneDelegate 创建窗口，DemoNavigationController 直接持有原生导航栈和 UIHostingController；在创建页面及本地化事务中同步自己拥有的 SwiftUI 宿主语义属性和 iOS 17+ trait override，防止编辑页列表出现字形镜像。页面不再安装隐藏的导航或窗口探测视图。这项示例兼容处理不扩展到框架的普通页面。

旧版本不额外插入宿主控制器，根视图通过窗口及自身语义边界适配，子控制器使用已有容器传播 traits。未挂载视图不能假设已继承环境方向；其内容配置读取 update.snapshot，挂载后由 UIKit 继承实际环境。

页面实现 `UIKitLocalizationApplying`。首次创建视图后使用最新快照渲染；以后由协调器更新已加载页面与 presented 链。

```swift
final class SettingsViewController: UIViewController, UIKitLocalizationApplying {
    let services: AppLocaleServices
    private let confirmButton = UIButton(type: .system)

    init(services: AppLocaleServices) {
        self.services = services
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use init(services:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(confirmButton)
        applyLocalization(LocalizationUpdate(snapshot: services.localizationController.currentSnapshot))
    }

    func applyLocalization(_ update: LocalizationUpdate) {
        // 普通控件继承窗口／容器方向，无需逐个设置。
        guard update.requiresLocalizedContentRefresh else { return }
        title = services.resolver.string("settings.title")
        confirmButton.setTitle(services.resolver.string("common.confirm"), for: .normal)
    }
}
```

不要求继承框架基类。页面仅实现 `applyLocalization(_:)`；普通列表和输入视图使用原生 UIKit 行为，无需额外的本地化协调器或绑定对象。导航、Split、Page 等业务状态仍由应用自己的容器管理。

## 列表与复用

UITableView 和 UICollectionView 继承窗口／容器方向。页面保留自己的布局、代理、数据源和业务配置，不持有列表本地化协调器，不提供 ID ↔ IndexPath 映射或本地化 completion。

布局由应用直接提供。使用原生 UICollectionViewFlowLayout、Compositional Layout 或业务自定义布局；需要镜像条目排列时，由业务布局自行覆盖 flipsHorizontallyInOppositeLayoutDirection。页面负责刷新可见文案或提交 diffable snapshot，框架不主动 reloadData、不重建列表布局。

滚动和选择采用 UIKit 原生行为。框架不再捕获／恢复业务 ID 锚点、相对偏移或正交中心页，也不承诺数据重排、行高变化后的精确阅读位置。业务数据源仍应使用稳定 ID，避免因翻译文案或草稿变化替换正在编辑的条目。

直接使用 UIKit 原生 dequeue、`UICollectionView.CellRegistration` 和 `SupplementaryRegistration`，不需要额外的配置准备调用。UIKit 同步它管理的 cell 外壳；普通 cell 不必手动固定方向。业务配置每次读取最新语言，`willDisplay` 重用同一配置入口，覆盖预取后才显示或离屏重新显示的内容：

```swift
let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Item.ID> {
    [weak self] cell, indexPath, id in
    self?.configure(cell, itemID: id)
}

func collectionView(
    _ collectionView: UICollectionView,
    willDisplay cell: UICollectionViewCell,
    forItemAt indexPath: IndexPath
) {
    guard let cell = cell as? UICollectionViewListCell,
          let id = dataSource.itemIdentifier(for: indexPath) else { return }
    configure(cell, itemID: id)
}
```

`configure` 负责业务文案、图片和配置，不调用框架的复用准备方法。Table 的 cell/header 和 Collection 的 supplementary 使用同样方式。方向敏感的自定义子组件在自身配置方法中更新其明确拥有的节点；不得把脱离层级时的方向缓存为长期状态。

## 输入、方向和手势

普通 `UITextField`、`UITextView` 和 `UISearchBar` 不需要本地化绑定对象、刷新钩子或内容视图协议。保持语义方向继承，使用原生 `.natural` 对齐，由 UIKit 和文本内容决定书写顺序及自然对齐。应用布局方向与输入文本的书写方向是不同概念，不强制把所有输入文字对齐到应用前缘。

语言切换不改写输入文本、段落属性或 typingAttributes，不替换输入代理，也不主动恢复焦点。自定义内容配置应保留输入实例；相同值不重复写回，存在 markedTextRange 时避免改写编辑内容。固定电话方向等特殊需求直接使用 UIKit 的 semanticContentAttribute 和 textAlignment。Today 示例的标题输入框也直接使用这两个原生属性，让空光标和草稿对齐当前应用前缘；配置读取最新方向，不增加输入绑定或通用更新层。

布局方向、段落对齐和文字书写顺序分别处理。特殊内容直接使用 UIKit 属性，不创建方向目标或更新器：

```swift
phoneField.semanticContentAttribute = .forceLeftToRight
mapView.semanticContentAttribute = .spatial
playbackControls.semanticContentAttribute = .playback
```

普通视图保持默认的 `.unspecified`，通过 UIKit 继承方向；需要移除自己之前设置的强制方向时，也直接恢复为 `.unspecified`。只有业务明确要求某个独立组件强制跟随应用时，才在其更新方法中设置 `view.semanticContentAttribute = update.semanticContentAttribute`。

框架不清空重建按钮／列表配置、不重设附件，也不对每个子视图统一触发约束或固有尺寸失效。业务内容变化使用原生配置 API；自定义布局确需失效时，由拥有该布局的组件调用相应 UIKit 方法。

配置式按钮热切换方向时，UIKit 可能保留旧图文布局。示例参照 UIKitLanguageDemo，在具体按钮配置处先比较语义方向，仅方向变化时清空 configuration，再设置方向并赋回业务配置；按钮实例、状态和 action 保持不变。同方向文案刷新不清空配置：

```swift
let semantic = update.semanticContentAttribute
if button.semanticContentAttribute != semantic {
    button.configuration = nil
}
button.semanticContentAttribute = semantic
var configuration = UIButton.Configuration.tinted()
configuration.title = resolver.string("close")
configuration.image = UIImage(systemName: "xmark.circle")
configuration.imagePlacement = .leading
configuration.imagePadding = 8
button.configuration = configuration
button.setNeedsLayout()
```

这是具体配置式按钮的局部处理，不是框架批量刷新机制。示例路径：主页 UIKit 区域 → 显示 UIKit Modal → 在弹窗中切换语言，观察底部关闭按钮。严格位置断言与实际 UI 证据见[验证记录](Docs/Validation.md)。

自定义手势使用 `DirectionalLayout.semanticHorizontalDirection`、`backSwipeRectEdge` 和 `backChevronSystemName`，语义结果直接为 `NSDirectionalRectEdge`，返回边缘直接为 `UIRectEdge`；系统导航容器保留原生手势及代理。导航项直接使用原生 `leftBarButtonItem(s)` 与 `rightBarButtonItem(s)`：导航栏根据语义方向解析为前缘与后缘，业务无需在 RTL 下交换数组。静态按钮在创建页面时安装，语言变化更新标题；编辑状态改变时再更新按钮组合。

`UIBarButtonItem.customView` 也使用原生创建方式。窗口协调器在首次同步或方向变化时，仅对公开左右导航项的 `customView` 调用 `invalidateIntrinsicContentSize()`，使 UIKit 更新实际位置。保持 item、customView、action 和自定义语义属性不变，页面无需额外刷新调用。同方向的语言变化不触发这项失效。

## SwiftUI

```swift
WindowGroup {
    RootView(localizationController: controller, resolver: resolver)
        .appLocalizationEnvironment(controller)
}
```

根环境观察同一快照，仅注入环境值，不主动改变视图身份。Sheet 继承相同语言环境。确需恢复局部系统组件时，由应用在局部边界明确使用 `.id(...)`，不通过框架重置整棵子树。

混合应用注册自己的 Window；Scene 激活时调用协调器 `synchronize()`。`UIViewRepresentable`／`UIViewControllerRepresentable` 的 update 方法仍读取 `context.environment.locale` 与 `layoutDirection`，新创建的 UIKit 组件使用最新快照。主示例由 SceneDelegate 直接注册、激活同步及注销窗口，不在 SwiftUI render 中触发整棵控制器树刷新。

语言选择器主标题使用候选语言的 `nativeDisplayName` 和候选语言方向；副标题按当前应用语言显示。行对齐采用应用的语义前缘。“跟随系统”是设置状态，不能当作一个真实 locale。

## 构建与测试

```sh
xcodebuild -scheme AppLocalization -destination 'generic/platform=iOS' build
xcodebuild -scheme AppLocalization -destination 'platform=iOS Simulator,id=<已安装模拟器 ID>' -parallel-testing-enabled NO test
xcodebuild -project Examples/LanguageSwitchingDemo/LanguageSwitchingDemo.xcodeproj -scheme LanguageSwitchingDemo -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Examples/Today/Today.xcodeproj -scheme Today -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

主示例的 `LocalizationValidation` 共享 Scheme 包含真实点击、草稿保留和双向边缘返回 UI 测试。框架现在直接依赖 iOS 的 UIKit，macOS 宿主 `swift test` 不再是支持的测试入口。

## App Icon

示例工程包含一套 iOS 26 风格 App Icon：

- 设计源文件在 `Design/AppIcon/AppIcon-master.svg`。
- Xcode 资源在 `Examples/LanguageSwitchingDemo/LanguageSwitchingDemo/Assets.xcassets/AppIcon.appiconset`。
- `AppIcon-Light.png` 用于默认浅色外观。
- `AppIcon-Dark.png` 用于深色外观。
- `AppIcon-Tinted.png` 是灰度主题色资源，供 iOS 26 tinted/theme color 套色。

图标主视觉是语言地球和双向切换箭头，不包含文字、国旗或国家符号，保证小尺寸和多语言场景下都稳定可识别。

## 应用名国际化

应用名属于系统读取的 bundle metadata，不走 App 内的 `LocalizedStringResolver`。示例工程使用 `InfoPlist.xcstrings` 本地化 `CFBundleDisplayName`：

- `en`: `Language Demo`
- `zh-Hans`: `语言演示`
- `ar`: `عرض اللغة`

注意：应用名不会随着应用内语言切换即时刷新。它由 iOS 系统根据安装包资源和系统语言读取，通常需要系统重新读取 bundle metadata 才会变化。

## 不能承诺即时刷新的内容

以下内容属于系统或外部进程边界，不应承诺跟随 App 内语言即时刷新：

- Launch Screen
- App 名称和系统设置里的应用名称
- 系统权限弹窗
- 已投递的通知内容
- Widget、App Extension 等独立进程
- 第三方 SDK 内部弹窗
- 已创建的 `UIAlertController`、`UIMenu`、`UIAction`、context menu

对这些内容建议采用 dismiss + recreate、下次打开生效，或明确标注为系统语言控制。
