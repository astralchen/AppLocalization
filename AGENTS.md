# AGENTS.md

## 项目与平台

- 通用包：`Sources/AppLocalization`，按 `Core`、`Strings`、`Directional`、`SwiftUI`、`UIKit` 分目录。
- 包测试：`Tests/AppLocalizationTests`。
- 主示例：`Examples/LanguageSwitchingDemo/LanguageSwitchingDemo.xcodeproj`。
- UIKit 业务示例：`Examples/Today/Today.xcodeproj`。
- 架构、迁移和证据：`Docs/Architecture.md`、`Docs/Migration.md`、`Docs/Validation.md`。

仅适配 iOS。包与主示例保持 iOS 15，Today 保留原有 iOS 18 部署目标。最低 Swift 工具链 6.3，使用 Swift 6 语言模式。不添加 `#if canImport(UIKit)` 或 macOS 兼容分支。新增／重写注释使用中文。

## 架构规则

- 应用语言是应用状态，不修改 AppleLanguages，不 swizzle Bundle.main。
- 方向属性和自定义手势参数直接使用 UIUserInterfaceLayoutDirection，不增加应用方向枚举、双向转换或别名。SwiftUI 环境与 Scene trait 在各自边界映射；方向完全遵循 Foundation 的 characterDirection，iOS 16+ 使用 Locale.Language，iOS 15 使用旧 Locale API；不维护 rightToLeftScripts 或另设显式脚本优先规则。
- LocalizationController 是生效语言、选择模式、方向、偏好持久化和 revision 的唯一状态所有者。一次发布一个不可变 currentSnapshot，其余属性从快照计算。
- 保持资源解析在 LocalizedStringResolver；应用业务文案枚举、生成符号、路由和跨进程状态恢复不进入核心库。
- 可选语言从 resourceBundle.localizations 读取并排除 Base；跟随系统使用 preferredLocalizations；fallback 优先开发语言。构造器不接收 supportedLocales／supportedLocalizations 或 fallbackLocale／fallbackLocalization。核心库不提供示例语言常量。
- 资源解析器显式指定 fallback；示例从控制器的只读 fallbackLocalization 构造该值。Bundle 是可选语言来源，preferredLocalizations 不能替代完整列表。
- 默认系统语言来源为注入 resourceBundle.preferredLocalizations。其他偏好来源通过 systemLocaleIdentifiersProvider 显式提供。
- @Published 是 willSet 观察，不代表 UIKit 事务完成。仅修正持久化选择时不发布快照、不递增 revision、不发送变更通知；存储回调重入仍走原队列。
- 事务顺序：全部准备 → 持久化及发布快照 → 全部应用 → 全部完成 → 完成通知。内部方向阶段先更新全部窗口／容器，再进行业务内容配置，不依赖窗口注册顺序。
- 重入选择在本轮结束后处理，最后请求生效。不要依赖 NotificationCenter 观察者顺序控制界面更新。
- 框架不要求全局单例、页面基类或外部依赖。语言控制器在内部直接调用具体窗口协调器的事务阶段，不增加通用参与者协议、空默认实现或注册令牌。协调器使用 NSPointerArray 保存有序弱引用，每轮生成强引用快照；保持重复注册去重、原注册顺序与本轮成员冻结。

## UIKit 接入

- 创建并持有 UIWindowSceneLocalizationCoordinator，协调器自动参与控制器事务，不再手动转发通知或调用 apply(change)。
- 显式注册应用拥有的窗口以刷新内容；Scene 断开时注销，激活时同步。窗口与协调器注册使用弱引用。
- iOS 17+ 优先使用注册窗口所属 Scene 的 traitOverrides.layoutDirection，无 Scene 时回退窗口 override。同 Scene 共享方向；注销窗口不撤销 Scene 方向。普通页面继承 traits，内容投递前 updateTraitsIfNeeded，不逐页覆盖业务方向例外。
- iOS 15/16 使用窗口／已加载视图语义边界、已有父容器 setOverrideTraitCollection 与呈现控制器 overrideTraitCollection；合并其他 traits，不添加 Host 包装或强制加载页面。所有版本都同步导航容器的语义方向。
- 不枚举系统窗口，不通过 UIView.appearance() 改变运行时方向，不递归访问 UIKit 私有子视图。
- 页面仅实现 UIKitLocalizationApplying.applyLocalization(_:)，不声明准备／完成回调或组件树。
- 列表与输入使用原生 UIKit 行为，不添加本地化协调器属性、绑定对象、子组件数组或私有视图扫描。首次配置直接调用 applyLocalization(LocalizationUpdate(snapshot:))；更新对象从前后快照推导刷新需求，不添加独立 reason 状态。窗口同步的重入由协调器处理。
- 保留导航栈、选中 Tab、Page 和 Split 业务状态及原生返回手势。不要替换系统手势对象或代理。
- Presented 链必须参与；无法原地更新的系统或第三方界面由业务拥有者关闭／重建，不添加框架边界协议。
- 根控制器替换由应用直接使用 UIKit 并保存业务状态，再调用 synchronize(window:)；框架不提供恢复枚举或根工厂。

## 列表与输入

- 列表使用原生布局、代理和数据源，继承窗口／容器方向；不添加列表本地化协调器、ID 映射或恢复 completion。
- 不捕获／恢复业务锚点、相对滚动偏移和正交中心页，不承诺数据重排与行高变化后的精确阅读位置；采用 UIKit 原生行为。
- 页面负责可见文案和 diffable 内容更新，框架不主动 reloadData 或重建列表布局。
- 直接使用原生 dequeue、CellRegistration 和 SupplementaryRegistration，不增加复用包装或独立 prepare 调用。配置读取当前语言，willDisplay 重用业务配置。
- 数据源继续使用稳定业务 ID，避免翻译文案或草稿值改变编辑行身份。
- 特殊 fixed LTR、playback、spatial 语义放在业务拥有的内容节点；复用根外壳由 UIKit 管理，不假设 semanticContentAttribute 始终 unspecified。
- 普通视图使用 UIKit 原生方向继承；特殊内容直接设置 semanticContentAttribute，不添加方向 Target、Updater 或 Policy 包装。不要统一清空重建按钮／列表配置、重设附件或触发子视图约束与固有尺寸失效。
- 导航项 customView 的位置缓存由现有窗口协调器在首次／方向刷新时调用 invalidateIntrinsicContentSize 处理，仅访问 UINavigationBar.items 的公开左右导航项。不重新安装 item、不替换 customView、不覆盖其语义属性、不递归扫描子视图；业务不增加修复包装或调用。
- 配置式按钮遇到热切换图标位置不更新时，在具体业务按钮配置处比较旧／新 semanticContentAttribute；仅方向变化时清空 configuration，再设置方向并生成业务配置。保留 UIButton 实例、状态和 action；不用通用包装，也不以预期失败代替修复。
- 自定义 UIContentConfiguration 保留输入实例，不清空重建编辑器。
- 不同内容类型使用独立的原生 CellRegistration；直接构造具体配置，不增加 cell 配置工厂或整个 UIContentConfiguration 协议的默认实现。详情分区从 diffable data source 读取，每次状态刷新只提交一个快照。
- 输入控件默认使用原生方向继承与 natural 对齐；需要跟随应用前缘的具体业务输入框（如 Today 标题）在内容配置中直接设置原生 semanticContentAttribute 和 textAlignment。不增加绑定属性、编辑通知订阅或刷新钩子；语言切换不改写文本、段落、选区或 typingAttributes。配置避免重复赋值和覆盖组合文本。

## SwiftUI 与语言选择器

- 每个 SwiftUI 根使用 appLocalizationEnvironment；框架仅注入环境，局部身份由业务视图管理，不添加整棵子树重置开关。
- 不在 init、static 或长期 view model 中缓存翻译后的 String。
- Representable 的 update 读取环境 locale 与 layoutDirection；新建和重新挂载时读取当前快照。
- SwiftUI Sheet 注入相同环境。主示例由 SceneDelegate 管理窗口注册，由业务 UINavigationController 持有 SwiftUI 宿主；不通过每页隐藏视图探测导航控制器或窗口，不替换原生返回手势及代理。
- 语言选项主标题使用候选语言的 nativeDisplayName 和方向，副标题使用当前应用语言；行对齐和书写方向分别处理。
- “跟随系统”是设置状态，主标题本地化，副标题显示实际生效语言，仅 followsSystemLocale 时选中。
- 自定义手势使用 DirectionalLayout 的语义映射和原生 NSDirectionalRectEdge／UIRectEdge，不增加方向或边缘枚举。水平映射拒绝非单一水平 OptionSet 输入；返回边缘统一使用 backSwipeRectEdge。导航项直接使用 UIKit 的 leftBarButtonItem(s)／rightBarButtonItem(s)，导航栏负责方向映射，不按 RTL 手动交换两侧，不增加位置枚举或导航项包装。静态按钮在创建时安装，语言更新只改标题。

## 资源与图标

- UI 字符串使用 Localizable.xcstrings；应用名 CFBundleDisplayName 使用 InfoPlist.xcstrings，不进入 UI 解析器。
- 不承诺应用名、启动屏、系统权限、已投递通知、Widget、扩展或第三方系统界面即时刷新。
- 可编辑图标源保存在 Design/AppIcon，Xcode 图标保存在 Assets.xcassets/AppIcon.appiconset，target 使用 AppIcon。
- 保留 Any/Light、Dark、Tinted 的 1024 px 资源；Tinted 为灰度，不包含可读文字、国旗或国家符号。

## 验证

核心／框架变化后运行 iOS 模拟器包测试，不再运行 macOS 宿主 swift test：

```sh
xcodebuild -scheme AppLocalization -destination 'platform=iOS Simulator,id=<可用模拟器 ID>' -parallel-testing-enabled NO test
xcodebuild -scheme AppLocalization -destination 'generic/platform=iOS' build
```

修改示例或公共 API 后构建两个示例：

```sh
xcodebuild -project Examples/LanguageSwitchingDemo/LanguageSwitchingDemo.xcodeproj -scheme LanguageSwitchingDemo -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Examples/Today/Today.xcodeproj -scheme Today -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

主示例 LocalizationValidation Scheme 提供真实 UI 测试。行为修改补充有意义的事务、重入、资源回退、稳定 ID、复用、输入及容器测试。构建、单元测试、UI 手势、模拟器和真机证据分别报告；未运行或环境阻塞不能算作通过。

编译缓存受沙盒限制时按相同命令申请所需权限，不改变源码路径或编译设置绕过限制。保持改动聚焦，不引入与本地化无关的业务或视觉修改。
