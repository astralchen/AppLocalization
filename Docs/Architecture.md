# 架构与取舍

本轮面向 iOS 15+、Swift 工具链 6.3+，使用 Swift 6 语言模式。保留单个 `AppLocalization` target；代码直接导入 UIKit 和 SwiftUI，不提供 macOS 构建分支。

## 状态与依赖

```text
LocalePreferenceStore + 系统 App 语言来源
                 ↓
        LocalizationController ──→ LocalizationSnapshot
                 │                       │
                 │                       ├─→ SwiftUI 环境
                 │                       └─→ LocalizedStringResolver 的 localeProvider
                 ↓
  内部窗口事务
                 ↓
 UIWindowSceneLocalizationCoordinator
                 ↓
 UIKitLocalizationApplying
                 ↓
 页面文案与业务配置 / 原生 UIKit 列表及输入
```

本包仅支持 iOS；LocalizationController 在内部直接引用具体的 UIWindowSceneLocalizationCoordinator，不再为平台隔离保留只有一个生产实现的协议。控制器不持有窗口或页面，也不强持有协调器。一个应用通常持有一个控制器、一个解析器、一个窗口协调器；框架不要求全局单例。应用可以创建相互独立的控制器用于隔离场景或测试。

`currentSnapshot` 是唯一的 `@Published` 状态，包含生效语言、跟随系统状态和 revision。`currentLocale`、`locale`、`layoutDirection`、`followsSystemLocale` 都从它计算，避免多个 Published 属性逐个赋值时出现半更新状态。

## 切换事务

1. 主 actor 接受请求，校验支持语言。
2. 固定本轮窗口与已加载页面，避免语言切换过程中对象增删造成混合投递。
3. 持久化选择，一次发布新快照。
4. 先由框架内部方向阶段更新全部窗口／容器，随后由协调器执行 `applyLocalization` 配置业务内容。此顺序不依赖对象创建顺序。
5. 完成窗口布局；不调用额外的页面完成回调。
6. 发布原有 `localizationDidChangeNotification`，供外部集成观察结果。
7. 处理重入请求和挂载同步。重入选择合并为最后一个请求，不递归执行切换。

窗口注册与激活同步也进入控制器的同步队列。首次渲染回调中再次切换语言，不会让剩余页面收到覆盖新状态的旧更新。协调器与窗口均为弱引用；事务执行期间暂时强持有本轮投递成员，保证同一轮处理相同的窗口集合。

各阶段均同步执行，不在阶段中等待异步任务。异步 diffable、网络或资源结果落地前必须检查 revision。后来的版本不会等待旧异步工作完成。`@Published` 保留 Combine 的 willSet 语义：订阅者应使用收到的快照值；需要读取提交后的状态及 UIKit 结果时使用事务完成通知。

业务首次渲染直接调用 `applyLocalization(LocalizationUpdate(snapshot: ...))`。此普通页面方法不提供重入保护；窗口注册、同步和语言选择的重入由控制器串行处理。

## 组件边界

`UIKitLocalizationApplying` 只有 `applyLocalization(_:)`，不再有页面准备／完成回调或子组件枚举。`LocalizationUpdate` 保存当前快照和可选旧快照，从差异计算内容／方向刷新需求，不暴露可与状态矛盾的 reason 位掩码。控制器创建一次更新值，事务、页面回调和完成通知直接使用该值；删除 LocalizationChange 与 UIKitLocalizationUpdate 之间的转换，也不保留旧类型别名。

首次配置和显式同步使用 `LocalizationUpdate(snapshot:)`，旧快照为 nil，内容与方向均刷新；实际切换使用 `LocalizationUpdate(snapshot:previousSnapshot:)`。同方向语言切换及仅跟随系统模式变化只刷新内容；仅 revision 变化不刷新。首次／同步不会增加 revision 或发送变更通知。通知名称和 localizationChangeUserInfoKey 保持不变，userInfo 中的值改为 LocalizationUpdate；LocalizationUpdate 直接提供 UIKit 原生布局方向及当前应用的强制语义属性，不再经过自定义方向枚举。

删除 `LocalizationTransactionParticipant`、默认空阶段实现和 `WeakLocalizationParticipant`，控制器直接调用具体窗口协调器的 prepare／direction／apply／finish。阶段仍在控制器中分批执行，确保全部方向完成后才配置任何页面内容，不改为每个协调器自行完成整轮更新。

控制器使用 Foundation 的 `NSPointerArray.weakObjects()` 保存有序弱引用；注册／注销按对象指针身份比较，重复注册不改变顺序，注销后重新注册追加到末尾。每轮先清理失效条目，再通过 allObjects 创建强引用投递快照，固定本轮成员。NSHashTable 虽然也支持弱引用，但没有顺序保证，因此不用于这里。Unmanaged 仅在内部将对象身份桥接给原生弱容器，不手动 retain／release，不增加注册令牌、闭包包装或第二个事务接口。

窗口协调器只遍历公开控制器包含关系、导航栈、Tab、Split、Page 和 presented 链。不会为了刷新加载尚未创建的页面视图；新页面在 `viewDidLoad` 中通过最新快照初始化。系统导航项的业务文案由页面／应用容器负责提供。Page 容器的数据源邻接关系和当前业务页 ID 也由应用负责，框架不接管其 delegate 或路由。

所有普通 presented 控制器都沿公开层级参与刷新。没有额外呈现边界协议、根控制器工厂或恢复动作枚举；无法原地更新的警告框、菜单、第三方界面由应用拥有者关闭／重建。应用若自行替换 rootViewController，再调用 synchronize(window:) 同步新页面即可。

SwiftUI 仅公开 appLocalizationEnvironment 修饰符，由私有 ViewModifier 观察状态并注入环境；没有第二个公开包装视图或整棵子树身份重置开关。导航项直接使用 UINavigationItem 的原生单项和数组属性；删除位置枚举、数组去重和跨侧迁移包装。

## 原生方向类型

AppLocale、LocalizationSnapshot、LocalizationController、LocalizationUpdate 及 DirectionalLayout 直接使用 UIUserInterfaceLayoutDirection。删除 AppUserInterfaceLayoutDirection、UIKitLayoutDirectionConversions.swift、uiLayoutDirection／appLayoutDirection 双向转换和公开 swiftUILayoutDirection 属性，不保留 typealias。

必要映射按实际职责保留：SwiftUI 环境修饰符和候选语言标题在注入 LayoutDirection 时直接映射；Scene 的 UITraitEnvironmentLayoutDirection 在已有方向分支中映射；LocalizationUpdate.semanticContentAttribute 明确表达当前应用的 forceLeftToRight／forceRightToLeft。具体语言行的书写语义、对齐和原生日期／导航边界直接使用 UIKit 属性。没有建立新的通用转换对象或方向策略层。

区域设置的方向遵循 Foundation：iOS 16+ 使用 Locale.Language(identifier:).characterDirection，iOS 15 使用 Locale.characterDirection(forLanguage:)。删除手工 rightToLeftScripts，不再保证显式脚本优先；特殊脚本的结果取决于系统语言数据。不读取系统当前界面方向代替应用选择。自定义返回边缘、箭头和转场工具移回 DirectionalLayout，参数接受 UIKit 原生方向；系统 UINavigationController 返回手势仍由 UIKit 管理。

语义水平边缘使用原生 NSDirectionalRectEdge，物理边缘使用 UIRectEdge，删除 SemanticHorizontalDirection 和 PhysicalHorizontalEdge。semanticHorizontalDirection 只返回单一 leading／trailing，带阈值的重载保持可选结果。physicalEdge 只接受单一水平边缘；原生 OptionSet 的空集合、垂直值、组合及未知位返回 nil，不将其他值默认为 trailing。删除重复 backSwipeEdge，统一使用 backSwipeRectEdge，可直接赋给 UIScreenEdgePanGestureRecognizer.edges。无阈值重载的零位移兼容规则、返回判断排除零位移、非有限值检查与转场偏移保持不变。

## 分版本方向适配

参考 UIKitLanguageDemo 的 LayoutDirection.swift 与 LocalizedControllers.swift，并采用用户确认的 Scene 作用域：

- iOS 17+：注册窗口存在 windowScene 时，设置 scene.traitOverrides.layoutDirection；无 Scene 时才设置 window.traitOverrides.layoutDirection。每轮去重 Scene，随后通过 updateTraitsIfNeeded 完成原生传播，保证内容回调读取已更新的环境。普通控制器不再单独写 traitOverrides 或强制语义属性，显式固定方向的业务子控制器仍可覆盖继承值。
- iOS 15/16：窗口和已加载控制器的根视图同步 semanticContentAttribute，Tab 栏也同步；已有父容器通过 setOverrideTraitCollection 更新子控制器，呈现根通过 UIPresentationController.overrideTraitCollection 更新。合并已有 override 中的其他 traits，不强制加载未创建视图。没有父容器的普通根采用语义边界，不引入参考项目的额外 Host 包装。
- 所有版本：导航容器 view、navigationBar、toolbar 保持明确的语义方向。仅 traits 不替代原生导航转场和返回边缘所需的语义配置。

Scene 方向是共享环境，不等同于窗口内容注册范围。同 Scene 未注册窗口及后续呈现内容继承方向；仅注册窗口的已加载页面接收文案刷新。注销不会恢复 Scene 方向，避免干扰仍在使用同一 Scene 的窗口。每个 Scene 应由同一语言状态控制，不承诺同 Scene 不同控制器之间的方向隔离。隐藏窗口的内容仍读取最新快照，未挂载页面在 UIKit 挂载后才具备有效继承环境。

已注册窗口加入 Scene 后会清除窗口级的 layoutDirection override，避免无 Scene 阶段留下的值遮蔽共享方向；业务子控制器的显式方向例外仍保留。混合导航示例由 SceneDelegate 创建窗口，DemoNavigationController 直接持有原生导航栈和 UIHostingController；在创建页面及本地化事务中同步自己拥有的 SwiftUI 宿主语义属性和 iOS 17+ trait override，防止编辑页列表出现字形镜像。页面不再安装隐藏的导航或窗口探测视图。这项示例兼容处理不扩展到框架的普通页面。

保留原有列表、输入和配置式按钮决策：不移入参考项目的滚动恢复、输入绑定或基类；具体需要配置重建的按钮仍在业务边界使用原生 configuration 属性处理。

## 列表与输入

Table 和 Collection 使用原生 UIKit 方向继承、布局、数据源和滚动行为。框架不建立独立的列表状态机，不捕获业务 ID 锚点、相对偏移、选择集或正交分页位置，不提供恢复 completion，也不按语言变化重建布局。数据插入、删除、行高变化和滚动中的行为由 UIKit 与应用数据更新决定。

页面仍负责可见文案和 diffable 数据内容。稳定业务 ID 是数据源的设计要求，但不再是本地化框架的接口。选择保留只按 UIKit 原生语义处理，不承诺任意数据重排后的精确阅读位置。

复用直接使用原生 dequeue 和 registration。没有 UIKitLocalizationContext、复用工厂或独立 prepare/attachment 操作。页面的业务配置读取当前语言，willDisplay 调用相同配置入口；切换时由页面重配置可见内容或提交 diffable reconfigure。普通复用外壳的方向交给列表和 UIKit，框架不额外保存强制方向。UIKit 可能主动设置 cell、contentView 和 header 的 semanticContentAttribute，正确性应检查实际方向和布局，而非要求这些属性始终 unspecified。

业务的 fixed LTR、playback、spatial 节点位于自己拥有的内容边界。需要特殊方向的复用根外壳必须在其业务配置／更新回调中重申该策略，因为 UIKit 管理外壳。脱离层级的内容不能假设尚未继承到的方向有效；挂载后读取容器 traits，或由自定义组件直接设置自己的 semanticContentAttribute。

不再提供 UIViewLayoutDirectionTarget、UIViewLayoutDirectionUpdater 或策略枚举。普通视图保持默认 unspecified 并继承 UIKit 方向；固定 LTR、spatial、playback 直接设置原生 semanticContentAttribute。框架不清空再恢复按钮／列表配置、不重设附件、不统一触发布局与固有尺寸失效。业务按内容变化使用原生配置和布局 API，自定义配置中的编辑实例保持不变。配置式按钮的图文位置问题由具体页面局部处理：比较按钮自身的 semanticContentAttribute，变化时清空 configuration，再设置新方向并赋回业务配置；保留按钮、状态及 action。同方向更新不重置配置。此做法参照 UIKitLanguageDemo 的 LanguagePickerView，不引入框架包装或子视图扫描。输入控件不接入单独的语言绑定。默认语义继承与 natural 对齐交给 UIKit，语言事务不改写文本、段落、typingAttributes 或选区，不替换代理或主动恢复焦点。内容配置应避免相同值重复赋值以及覆盖 markedTextRange；这属于输入组件的数据更新规则。固定方向、固定对齐等特殊业务策略直接使用原生 UIKit 属性。Today 标题输入框参考 UIKitLanguageDemo.applyTextField，在具体 UIContentConfiguration 中传递原生 UIUserInterfaceLayoutDirection，配置时设置 semanticContentAttribute 与左右 textAlignment，保证空光标也跟随应用前缘；备注仍使用 natural。

## 系统语言与资源

默认来源为注入资源包的 `preferredLocalizations`，尊重系统为当前 App 匹配的语言。支持语言先按完整标识符匹配，再由 Foundation 在同语言族内匹配地区／脚本；不支持的第一偏好不会遮蔽后续可用偏好。找不到时使用资源包推导的 fallbackLocalization。

语言选择和资源覆盖是两个问题：支持语言列表由应用声明，解析器独立处理缺失资源或缺失键，按现有回退链查找。不会扫描所有资源后静默修改应用支持语言。

解析器继续支持运行时 key、格式参数、指定 bundle/table 以及源码 String Catalog 的简单 stringUnit。这次没有加入框架级 AppText 枚举或假设所有应用使用相同的 Xcode 生成符号。应用可以在业务层包装类型化 key；生成的 LocalizedStringResource 若直接交给 Foundation 解析，应显式设置当前 locale，且不自动继承本解析器的回退链。iOS 15 不具备该现代资源 API，普通 String(format:) 也不等价于完整的复数／变体解释器。

## 参考项目的采用边界

参考 UIKitLanguageDemo 的语言事务、系统 App 语言来源和导航状态保留。后续按用户选择移除列表精确恢复与输入绑定，采用原生 UIKit 行为。没有移入其 LanguageService.shared、固定语言枚举、AppText 业务文案、Scene 路由 DTO、检查点文件、窗口切换菜单或外观服务。

跨进程恢复仍由应用根据业务路由实现。应用名、权限提示、通知、Widget 和扩展不属于进程内热切换保证。

## 剩余抽象审查

再次对照 UIKitLanguageDemo 后，Today 删除了 cell 上的三种输入配置工厂、全局 UIContentConfiguration 默认实现，以及 prepareForEditing／prepareForViewing 转发。具体输入组件直接实现原生配置协议；业务层直接构造配置。查看／编辑模式共用一个快照提交入口，分区通过 dataSource.sectionIdentifier(for:) 获取，删除 Section 的整数映射；列表首次加载不重复提交快照或再次设置数据源。不同内容类型各用一个原生 CellRegistration，避免 UIKit 在模式切换时复用不兼容的内容视图。

未移入参考项目的页面基类、LocalizationHostController、输入快照或滚动恢复协调器。现有窗口协调器、事务快照、资源解析及 SwiftUI 环境有独立职责，继续保留；DirectionalLayout 表达自定义手势的语义意图，不介入 UINavigationController 的系统返回手势。原生 UIContentView 和业务配置方法负责实际编辑行为，也不应作为无用包装删除。

窗口注册使用 NSHashTable<UIWindow> 的 weakMemory 和 objectPointerPersonality，保留按实例去重及弱引用语义，删除 Registration 盒子和 ObjectIdentifier 字典。Delivery 仍强持有本轮窗口和页面，以冻结投递集合、完成方向与内容阶段。

导航 customView 的尺寸失效集中在已有方向处理分支：更新原生导航容器语义后，通过 navigationBar.items 访问左右导航项，对其公开 customView 调用 invalidateIntrinsicContentSize，最后由原有窗口布局完成阶段更新位置。这是针对已复现问题的原生导航边界处理，不是子视图树刷新；不重新安装导航项、不覆盖内容语义，也不增加 Target／Updater／Policy 或业务修复调用。

UIKit 已提供导航项槽位和方向解析，框架不再包装按钮位置、数组去重或跨侧迁移。示例在页面创建及编辑状态改变时安装按钮，切换语言更新文案。主示例服务由 AppDelegate 持有，移除无订阅者的 ObservableObject；Today 通过场景激活同步系统语言，删除前台回调中的重复刷新。

保留 LocalizationSnapshot 表达原子状态与版本；LocalizationChange 与 UIKitLocalizationUpdate 合并为 LocalizationUpdate，统一表达首次／差异更新；控制器直接调度具体协调器的分阶段方法，保证所有窗口方向先于页面内容并处理重入。LocalePreferenceStore、LocaleMatcher、LocalizedStringResolver 分别承担可替换持久化、语言匹配和资源回退。SwiftUI 环境修饰符、UIKitDemoRepresentable 和业务导航容器具有实际桥接或生命周期职责，不继续合并成通用包装。

### SwiftUI 草稿对齐

主示例的具体草稿 TextField 在 iOS 26+ 使用原生 `.multilineTextAlignment(strategy: .layoutBased)` 配合 `.leading`，将对齐绑定到布局环境；旧系统保留 `.leading` 分支。输入框继续位于 List 重建边界之外，不通过重建输入框、重新聚焦、私有视图遍历或全局输入策略修复对齐。核心库的 SwiftUI 环境注入不变。

## Bundle 驱动的语言配置

LocalizationController 的构造器只接收资源包、存储、通知中心和可选系统偏好来源，不接收支持语言与 fallback。localizations 提供全部资源语言，过滤 Base、空值和 system 并去重；preferredLocalizations 负责跟随系统；developmentLocalization 优先决定 fallback。仅 Base 包可用开发语言表达源内容；无任何语言声明属于配置错误。只读 supportedLocalizations／fallbackLocalization 供 UI 和解析器使用，不重复储存业务语言配置。

AppLocale 继续用于不可变快照、显示名称和字符串解析，不再提供三个示例语言常量；也不以显示名称作为控制器语言列表的数据。示例语言由自己的 String Catalog 声明。两个示例的英语资源为 en，历史 en-US 偏好按同语言族匹配到 en。生产 UI 不枚举 Locale.availableIdentifiers，也不把系统偏好结果当成完整选项。

Request 只保存目标区域设置和选择模式，持久化标识符由二者推导。状态未变但存储为失效语言、旧标识符或尚未保存 system 时，更新存储而不生成新快照；该写入仍受串行重入保护。实际语言变更仍保持全部准备 → 持久化 → 单次发布 → 全部方向 → 全部内容 → 全部完成 → 通知的顺序。
