# 重构验证记录

## Bundle 语言配置与 Foundation 方向简化（2026-11-17）

LocalizationController 不再接收支持语言或 fallback 参数。Bundle.localizations 提供完整列表（排除 Base 并去重），preferredLocalizations 提供跟随系统的匹配结果，developmentLocalization 优先决定回退。核心语言常量与 rightToLeftScripts 删除；方向采用 iOS 16+ Locale.Language 和 iOS 15 Locale 原生 API。显式脚本测试验证系统结果，不再承诺 az-Arab 固定 RTL。

- **通过**：完整包测试 83 项，0 失败／预期失败／跳过。包括真实 Bundle 元数据、完整列表与当前偏好区分、开发语言／Base 回退、旧 en-US → en 偏好迁移、仅存储修正不发布状态，以及该修正中的重入串行处理；原有事务阶段、弱引用、成员冻结和输入回归保持通过。
- **通过**：主示例真实 UI 测试 7 项，覆盖语言往返、实际字形、空光标像素、连续草稿输入、错误边缘不返回及双向原生返回、Sheet、配置按钮、导航 customView 和语义手势。实际资源语言为 en，语言选择器显示 English，选项顺序来自 Bundle。
- **通过**：Today 真实编辑测试 4 项，草稿、输入实例、焦点、选区、组合文本、RTL 空光标、保存与取消保持。首轮通过但退出时出现 Unbalanced appearance transitions；测试清理改为等待原生 dismiss completion 后再隐藏窗口，重跑 4 项通过，本次未再出现该诊断。原始结果与日志保留。
- **通过**：核心包、主示例、Today 三项通用 iOS 构建，git diff --check。已有暂存的 SwiftUI 环境修改保留，未提交。
- **日志边界**：三个最终结果包均无 xcresult runtimeWarnings，主示例未记录 Modifying state during view update。既有包测试内容配置初始化诊断、AppIntents 元数据提示及模拟器键盘／辅助功能／系统日志保留，不宣称控制台零警告。
- **未执行**：iOS 15/16、精确 iOS 17、其他旧运行时与真机、精确 Swift 6.3 编译器、真实输入法候选交互、完整 EventKit 权限／持久化流程。运行环境为 iPhone 18 Pro／iOS 27.2，Swift 6.4.2；部署目标与最低工具链要求未抬高。

源码指纹、正式结果及截图见[验证清单](Verification/bundle-native-localization.json)。下方历史记录中的手工脚本优先、语言常量和显式支持语言配置已由本轮替代。

## SwiftUI 草稿空光标 RTL 对齐（2026-11-17）

主示例 Push 页使用 SwiftUI TextField，与 Today 的 UIKit 标题输入框不同。采用 `.leading`，并在 iOS 26+ 使用原生 `.multilineTextAlignment(strategy: .layoutBased)` 明确按布局环境对齐。输入框身份、导航及核心环境注入不变。

- **修复前失败**：真实 UI 截图中 RTL 空光标位于输入框宽度约 0.25% 处；单独添加 `.leading` 或按方向切换 leading／trailing 都没有修复。原始失败结果保留，没有预期失败或放宽断言。
- **通过**：增加 layoutBased 后，空光标截图断言覆盖 ar → en-US → ar → zh-Hans → ar，RTL 靠右、LTR 靠左；切换后无需再次点击即可输入。完整 LocalizationValidation 共 7 项通过，0 失败／预期失败／跳过，包含连续草稿输入、双向返回及错误边缘不返回、字形、Sheet、配置按钮、导航 customView 和语义手势。
- **通过**：主示例及 Today 通用 iOS 构建、git diff --check。结果包 runtimeWarnings 为空，UI 测试日志未出现 Modifying state during view update。保留已有暂存修改。
- **截图核对**：阿拉伯语占位文字和光标均靠右，英文草稿右对齐且字形未镜像。截图来自真实模拟器屏幕，无后处理。
- **未执行**：iOS 15–25 的 `.leading` 分支、精确 iOS 26、真机及精确 Swift 6.3 编译器；本轮只修改主示例，未重复包测试与 Today 编辑测试。运行环境为 iPhone 18 Pro／iOS 27.2。

见[验证清单](Verification/swiftui-draft-caret.json)、[修复前](Verification/swiftui-caret-before.png)、[RTL 修复后](Verification/swiftui-caret-rtl.png)及[LTR 修复后](Verification/swiftui-caret-ltr.png)。原生策略定义参考 [Apple 文档](https://developer.apple.com/documentation/swiftui/view/multilinetextalignment(strategy:))。

## Today 标题空光标 RTL 对齐（2026-11-17）

参考 UIKitLanguageDemo 的 LayoutDirection.applyTextField。Today 标题的原生内容配置传递当前 UIUserInterfaceLayoutDirection，直接设置 UITextField.semanticContentAttribute 与左右 textAlignment；保留输入实例及原有文本更新保护。备注仍使用 natural，核心库没有新增输入包装。

- **修复前失败**：真实新增提醒弹窗中，初始阿拉伯语及切回阿拉伯语时，338 点宽输入框的空光标中心仍在 x=1；新回归的两处 RTL 几何断言失败。首次测试准备未等待弹窗展示导致 cell 不存在，单独保留为准备失败记录，不作为根因证据。
- **通过**：修复后 TodayValidation 4 项测试，0 失败／预期失败／跳过。空光标覆盖 ar → en-US → ar → zh-Hans；同一输入实例保持焦点并能继续输入。原有草稿、选区、组合文本、取消和新增保存回归全部通过。
- **通过**：Today、主示例通用 iOS 构建，以及 git diff --check。已有暂存修改保留。
- **验证范围**：iPhone 18 Pro／iOS 27.2 模拟器，真实场景窗口与原生弹窗，使用公开 caretRect 验证位置；不是手工触摸或屏幕截图验收。xcresult 无 runtimeWarnings，控制台仍有系统键盘和 IOSurface 日志。
- **未执行**：其他 iOS 版本、真机、精确 Swift 6.3 编译器、真实输入法候选交互及完整 EventKit 流程。本轮未改核心或导航，未重复执行包测试及主示例返回手势 UI 测试。

详见[空标题光标验证记录](Verification/empty-title-caret.json)，修复前失败和修复后成功结果均保留。

## 原生语义与物理边缘（2026-11-17）

删除 SemanticHorizontalDirection 和 PhysicalHorizontalEdge，改用 NSDirectionalRectEdge／UIRectEdge；删除重复 backSwipeEdge，保留可直接赋给原生边缘手势的 backSwipeRectEdge。physicalEdge 明确返回可选值，拒绝空集合、垂直、组合或未知 OptionSet 输入。语义拖动只产生单一 leading／trailing；原有零位移兼容规则、阈值、非有限值判断及转场符号保留。

- **通过**：完整包测试 75 项，0 失败／预期失败／跳过。新增原生非法组合、四种方向／位移组合、原生边缘手势赋值、阈值与零位移回归。
- **通过**：主示例 UI 回归 6 项。新增同一应用在英／阿拉伯／英语热切换后的真实左右拖动；RTL 右拖显示 leading、左拖显示 trailing，切回 LTR 后映射恢复。原有真实双向返回、错误边缘不返回、连续输入、按钮／Sheet 和字形回归保留。
- **通过**：核心包、主示例和 Today 三个通用 iOS 构建，以及 git diff --check。已有暂存内容保留。
- **日志边界**：两个结果包均无 xcresult runtimeWarnings；既有包测试内容初始化诊断和旧 API 编译提示保留，不宣称控制台零警告。
- **未执行**：Today 编辑测试本轮未重跑，Today 源码及其使用的方向接口未改变，已完成构建；旧系统、精确 Swift 6.3 编译器及真机未运行。

[原生边缘验证清单](Verification/native-gesture-edges.json)保存源码指纹和完整结果；[RTL 真实拖动截图](Verification/native-edges-semantic-pan-rtl.png)显示左拖后的 trailing 结果。

## 直接使用 UIKit 原生方向类型（2026-11-17）

删除 AppUserInterfaceLayoutDirection、UIKitLayoutDirectionConversions.swift 及 uiLayoutDirection／appLayoutDirection／swiftUILayoutDirection 转换属性，不提供兼容别名。区域设置、快照、控制器、更新值及语义手势工具统一使用 UIUserInterfaceLayoutDirection；返回边缘与箭头函数移至 DirectionalLayout。SwiftUI 环境、Scene trait 及语义内容属性在各自实际边界映射，显式脚本优先的语言方向推导保持不变。

- **通过**：完整包测试 73 项，0 失败／预期失败／跳过。新增原生方向直接用于手势 API 的回归，以及真实 UIHostingController 环境测试：阿拉伯语初始显示后往返切换英／中／阿拉伯语，locale 与 SwiftUI.LayoutDirection 正确，底层内容视图实例保持不变。
- **通过**：主示例实际 UI 回归 5 项，覆盖字形／标题、RTL／LTR 原生返回及错误边缘不返回、连续输入、Sheet、配置式按钮和导航 customView 的位置／动作。
- **通过**：Today 实际详情回归 3 项，保留草稿、输入实例、焦点、选区、组合文本、取消与保存行为。
- **通过**：核心包、主示例、Today 三个通用 iOS 构建及 git diff --check。已有暂存修改保留。
- **日志边界**：三个结果包均无 xcresult runtimeWarnings；既有包测试自定义内容初始化诊断、旧 API 编译提示及 Today 系统键盘日志保留，不宣称控制台零警告。
- **未执行**：iOS 15/16、精确 iOS 17、真机、精确 Swift 6.3 编译器、完整 EventKit 权限／持久化及真实输入法候选交互。

源码指纹与正式结果见[原生方向类型验证清单](Verification/native-direction-type.json)，公共 API 迁移见 Migration.md“使用 UIKit 原生方向类型”。下方历史记录中的方向转换层已由本轮替代。

## 统一本地化更新值（2026-11-17）

LocalizationChange 与 UIKitLocalizationUpdate 合并为 LocalizationUpdate。统一保存 snapshot 与可选 previousSnapshot，集中计算 requiresLocalizedContentRefresh 和 requiresLayoutDirectionRefresh。语言事务创建一次更新值，协调器、页面和通知直接使用；删除中间转换与旧类型别名。首次／显式同步仍完整刷新，实际变更按差异刷新，通知时序和版本规则不变。

- **通过**：完整包测试 71 项，0 失败／预期失败／跳过。新增双向首次刷新、同状态／仅版本变化、选择模式变化、同方向语言变化、LTR／RTL 往返矩阵；实际窗口测试确认通知与页面收到相同更新值，初始和显式同步不增加 revision、不发伪变更通知。
- **通过**：主示例真实 UI 回归 5 项，语言切换、字形／标题、连续输入、原生双向返回、Sheet、配置式按钮及自定义导航按钮行为保持。
- **通过**：Today 真实编辑回归 3 项，草稿、焦点、选区、组合文本、实例身份和保存／取消行为保持。
- **通过**：核心包、主示例和 Today 通用 iOS 构建，以及 git diff --check。已有暂存内容保留。
- **日志边界**：三个结果包均无 xcresult runtimeWarnings。包测试中已有的自定义内容替换初始化诊断、旧 API 编译提示及 Today 系统键盘日志继续保留，不宣称控制台零警告。
- **未执行**：iOS 15/16、精确 iOS 17、真机、精确 Swift 6.3 编译器、完整 EventKit 权限／持久化和真实输入法候选交互。

[统一更新验证清单](Verification/unified-localization-update.json)记录源码指纹、结果包和完整日志；公共类型迁移见 Migration.md“统一本地化更新值”。下方历史记录中两个独立类型的设计已由本轮替代。

## 核心事务协议与弱引用包装清理（2026-11-17）

删除 LocalizationTransactionParticipant、默认空阶段实现及 WeakLocalizationParticipant，语言控制器直接调用 UIWindowSceneLocalizationCoordinator 的内部阶段。NSPointerArray.weakObjects 保存有序弱引用，每轮建立强引用投递快照。公开接入方式、事务循环、同步队列、导航及输入实现不变；核心现在明确依赖本包的具体 UIKit 协调器，符合仅 iOS 的范围。

- **通过**：完整包测试 69 项，0 失败／预期失败／跳过。事务测试移除协议探针，使用真实窗口与协调器验证全部准备先于持久化／发布、全部方向先于内容、全部布局先于通知、重入最后请求生效、重复注册去重、成员冻结、弱引用释放和重新注册顺序。
- **通过**：主示例真实 UI 回归 5 项，覆盖语言往返、字形／标题、连续输入、LTR／RTL 原生返回及错误边缘不返回、Sheet 与配置式／自定义导航按钮。
- **通过**：Today 真实详情回归 3 项，保留草稿、焦点、选区、组合文本、编辑实例，以及取消与新增保存行为。
- **通过**：核心包、主示例、Today 三个通用 iOS 构建，git diff --check。原有暂存修改保持不变。
- **日志边界**：三个结果包的 runtimeWarnings 均为空；包测试已有自定义内容替换测试在初始化时仍产生两条 ContentConfiguration 控制台诊断，与前一轮包基线一致。本轮不修改该测试；旧 API 弃用提示和 Today 系统键盘日志也保留，不能据此宣称控制台零警告。
- **未执行**：iOS 15/16、精确 iOS 17、真机、精确 Swift 6.3 编译器和完整 EventKit／真实输入法候选交互。

源码指纹、结果摘要和完整日志位置见[核心事务简化验证清单](Verification/direct-coordinator-transaction.json)。下方历史审查中“保留内部事务协议”的结论已由本轮替代。

## 剩余架构与 Today 原生配置清理（2026-11-17）

再次对照 UIKitLanguageDemo，保留有实际职责的窗口事务、快照、资源解析和 SwiftUI 桥接。本轮删除 Today 的三个 cell 配置工厂、全局 UIContentConfiguration 默认实现、编辑准备转发、重复快照提交、手工分区偏移及重复数据源赋值；分区直接由原生 diffable data source 提供。框架 Sources 与主示例实现未修改。

- **通过**：TodayValidation 新增 3 项真实详情页回归，0 失败、0 预期失败、0 跳过。覆盖加载前进入编辑、取消、保存回调，以及语言往返后的 cell／输入实例、草稿、焦点、选区、组合文本和原生手势对象。组合文本通过 UITextInput API 设置，不等同于真实输入法候选交互验证。
- **通过**：主示例完整 UI 回归 5 项，保留字形／标题 OCR、无需重获焦点的连续输入、LTR／RTL 正确及错误返回边缘、Sheet 和按钮位置／动作验证。
- **通过**：LanguageSwitchingDemo 与最终 Today 的通用 iOS 构建、项目格式和 git diff --check。
- **诊断已修复**：首轮 Today 测试虽通过，控制台出现不同内容配置共用复用池的替换警告；改为每种内容类型一个原生 CellRegistration 后消失。测试窗口改为挂载到 Scene 后，非 key window 输入诊断也消失。没有清空配置或新增通用包装。
- **日志边界**：两个最终结果包均无 xcresult runtimeWarnings；Today 控制台仍有系统 UIKBRenderingLog、IOSurface／文件缓存诊断，完整保留，不能称为控制台零日志。未发现内容视图替换、非 key window、约束冲突或 Modifying state 警告。
- **未执行**：本轮未改核心库，未重跑包测试／包构建；未验证 iOS 15/16、精确 iOS 17、真机、精确 Swift 6.3 编译器及完整 EventKit 权限／持久化流程。

[本轮验证清单](Verification/remaining-architecture-cleanup.json)包含源码指纹、最终结果及首轮诊断记录；[RTL 连续编辑截图](Verification/remaining-cleanup-detail-rtl.png)已检查，正文、草稿和返回按钮正常显示。

基线验证日期：2026-11-16；配置式按钮修复验证日期：2026-11-17。包最低工具链为 Swift 6.3，使用 Swift 6 语言模式，部署目标为 iOS 15。实际验证使用 Apple Swift 6.4.2，模拟器为 iPhone 18 Pro / iOS 27.2。本次没有使用 Swift 6.3 编译器，也没有验证 iOS 15 的实际运行行为。

同日后续已修复编辑详情页切换语言时的 SwiftUI 状态更新警告，见下方“SwiftUI 编辑状态警告修复”。原架构验证的日志和截图保留为基线，后续证据单独存放。

## 导航项 customView 热切换修复（2026-11-17）

此前未解决的 UIBarButtonItem.customView 位置问题已修复。复现中 Scene、导航栏和按钮方向 traits 已正确，但实际位置未重新计算；仅设置语义属性不能稳定修复。隔离验证显示 invalidateIntrinsicContentSize 单独即可通过，无须移除并重新安装导航项或 customView。

修复放在现有 UIWindowSceneLocalizationCoordinator 的方向处理分支：更新导航容器方向后，遍历 navigationBar.items 的公开左右导航项，仅对 customView 调用 invalidateIntrinsicContentSize，再由现有窗口布局完成阶段更新位置。不增加公开 API 或通用包装，不遍历私有子视图，不覆盖内容语义属性，不延迟调度。

- **通过**：完整包测试 67 项，0 失败、0 预期失败、0 跳过、0 运行期警告。新增正式 UIKitCustomNavigationItemTests 使用不变标题检查 LTR／RTL 初始状态及往返位置、实例、按钮状态、点击 action、fixed LTR／playback 语义例外和原生手势身份；另验证同方向语言变化及普通内容视图不额外失效。
- **通过**：完整 UI 回归 5 项，0 失败、0 预期失败、0 跳过、0 运行期警告。主示例导航栏关闭按钮改为真实 UIButton customView，覆盖 RTL 初始呈现和 LTR 初始呈现、英／中／阿拉伯语热切换位置、切换后实际点击关闭。原有配置式按钮、标题／字形 OCR、连续输入、双向返回及 Sheet 回归保留。
- **通过**：AppLocalization、LanguageSwitchingDemo、Today 三个通用 iOS 构建，以及 git diff --check。
- **未执行**：iOS 15/16、精确 iOS 17、真机、精确 Swift 6.3 编译器和 Today EventKit UI 流程。实际运行环境为 iOS 27.2 模拟器。

截图：[RTL customView 在右侧](Verification/custom-navigation-rtl.png)、[LTR customView 在左侧](Verification/custom-navigation-ltr.png)。源码指纹、正式结果和保留的原生方案对比见[修复验证清单](Verification/custom-navigation-fix.json)。下方“额外诊断未解决”是修复前历史记录，已由本节取代。

## 剩余包装与原生导航项清理（2026-11-17）

删除 UINavigationItemLocalization.swift、NavigationItemPlacement、单项／数组 setter 包装及附带的去重和跨侧迁移。两个示例直接使用原生导航项属性，静态按钮在创建页面时安装，语言刷新更新标题，Today 编辑状态改变时再调整按钮组合。窗口注册改用原生弱 NSHashTable，删除 Registration 盒子；移除 DemoServices 的 ObservableObject 和 Today 前台回调中的重复系统语言刷新。事务、Scene 作用域、编辑状态及原生手势职责保持不变。

- **通过**：完整包回归 65 项，0 失败、0 预期失败、0 跳过、0 运行期警告。删除两项已移除包装的规则测试，增加弱注册／重复注册和原生导航项身份回归，原有事务与输入测试保留。
- **通过**：完整主示例 UI 回归 4 项，0 失败、0 预期失败、0 跳过、0 运行期警告。新增断言在同一 Modal 内切换英／中／阿拉伯语，检查普通导航栏关闭按钮的实际物理位置；标题和字形 OCR、连续输入、原生双向返回、Sheet 关闭行为全部保留。
- **通过**：AppLocalization、LanguageSwitchingDemo、Today 通用 iOS 构建，以及 git diff --check。
- **未执行**：iOS 15/16、精确 iOS 17、真机、精确 Swift 6.3 编译器和 Today 的 EventKit／编辑页 UI 流程。
- **额外诊断未解决**：包测试宿主中，UIButton 作为 UIBarButtonItem.customView 时方向 traits 正确，但实际位置未随热切换更新。布局失效、下一轮主队列和原生 setter 尝试均失败。这两个示例不使用该场景；此诊断不包含在通过结论中，未加入预期失败标记。失败函数及结果保存在[独立诊断记录](Verification/native-navigation-customview-diagnostic.md)。

窗口释放的首轮断言未排除 NSHashTable.allObjects 自动释放快照的临时强引用；测试改为在自动释放池结束后检查，并补充协调器保持存活时窗口仍可释放的检查，两者通过。没有更改窗口的弱所有权或延长事务投递周期。

普通导航项实际截图：[LTR](Verification/native-navigation-items-ltr.png)、[RTL](Verification/native-navigation-items-rtl.png)。本轮源码指纹、完整通过结果和保留的诊断失败见[验证清单](Verification/native-surface-cleanup.json)。

## 原生导航与探测包装清理（2026-11-17）

参考 UIKitLanguageDemo 的 Scene 生命周期和 UINavigationController 所有权，删除 NavigationPopGestureConfigurator、WindowLocalizationRegistrationView、WindowRegistrationView，以及每页隐藏探测视图和 NavigationLink。SceneDelegate 直接创建和注册窗口；DemoNavigationController 使用原生 push、present、dismiss。保持现有 UIHostingController 实例、SwiftUI 环境及输入状态，系统返回手势和代理不变。框架源码及 iOS 17+ Scene／iOS 15/16 方向分支未修改。

- **通过**：完整 UI 回归 4 项，0 失败、0 预期失败、0 跳过、0 运行期警告。覆盖语言往返与字形 OCR、配置式按钮和真实 Modal、编辑连续输入及双向返回、根页无返回按钮、Sheet 标题与关闭按钮的双向位置和关闭行为。
- **通过**：随后为详情页设置原生紧凑标题，并添加英文标题像素 OCR；最终详情页定向回归 1 项通过，0 运行期警告。无须重新点击输入框，错误返回边缘不能出栈，正确边缘可出栈。该定向结果替代完整回归中详情页的早期结果，不计为第 5 项独立用例。
- **通过**：最终 LanguageSwitchingDemo 通用 iOS 构建、项目及 Info.plist 格式检查、git diff --check。
- **未执行**：本步骤未改框架，未重跑包测试；iOS 15/16、精确 iOS 17、真机、精确 Swift 6.3 编译器及多 Scene UI 操作未执行。

首次运行因空的自动生成 Scene 配置无法显示窗口，3 项 UI 用例失败；补充显式 Info.plist 配置后通过，没有卸载应用或清除数据。截图复核还发现详情页标题空白：AX 标题存在仍不能证明可见，新增 OCR 断言捕获失败。改造前同一编辑截图也有该问题；仅切换标题赋值来源不能修复，最终使用原生 largeTitleDisplayMode.never 解决，首页及 Sheet 保持大标题。

截图：[根页 RTL](Verification/native-navigation-root-rtl.png)、[详情 RTL](Verification/native-navigation-detail-rtl.png)、[详情 LTR](Verification/native-navigation-detail-ltr.png)、[Sheet RTL](Verification/native-navigation-sheet-rtl.png)。源码指纹、结果包、保留的失败及验证边界见 [原生导航清理清单](Verification/native-navigation-cleanup.json)。

## Scene 与分版本方向适配（2026-11-17）

用户选择 iOS 17+ 使用 Scene 作用域。框架设置注册窗口所属 Scene 的 layoutDirection trait，无 Scene 时使用窗口 override；加入 Scene 后清除注册窗口原有的方向 override。普通 UIKit 页面继承环境，内容投递前 updateTraitsIfNeeded；导航容器在所有版本保持语义方向。未注册窗口可继承共享方向，但不会接收内容投递，注销不会恢复 Scene 方向。

iOS 15/16 使用窗口／已加载视图的语义属性，已有父容器的 setOverrideTraitCollection 和呈现控制器的 overrideTraitCollection。合并其他 traits，不添加 Host、不加载未创建的页面。旧 API 测试在 iOS 27.2 上直接调用该内部分支，不能视为 iOS 15/16 运行验收。

- **通过**：包测试 65 项，0 失败、0 预期失败、0 跳过。覆盖 Scene 共享且不刷新未注册内容、固定方向子控制器、窗口回退到 Scene 的交接、旧版 override 的其他 traits 保留，以及既有输入／配置按钮／列表／事务回归。
- **通过**：最终实现上的 UI 用例 3 项，分两次运行：编辑与返回手势 1 项；根页字形及真实 UIKit 呈现 2 项。两个结果包均为 0 运行期警告。
- **通过**：AppLocalization、LanguageSwitchingDemo、Today 三个通用 iOS 构建。
- **未执行／环境缺少运行时**：iOS 15/16 实际运行；精确 iOS 17、真机、精确 Swift 6.3 编译器和 Today 完整业务流程也未执行。已安装运行时为 iOS 26.5、27.1、27.2，实际回归使用 iOS 27.2。

新 presented 验证从阿拉伯语启动，在 RTL 生效后创建页面；UI 断言读取页面挂载后的实际 effectiveUserInterfaceLayoutDirection 显示值，而非快照中的期望方向。[RTL 截图](Verification/scene-direction-rtl.png)与[LTR 截图](Verification/scene-direction-ltr.png)已保留。

中间失败记录保留：旧测试中的未挂载视图和局部窗口 override 不符合新的继承测试前提，已改为真实挂载并严格断言有效方向；包测试宿主的 present 未完成，因此真实呈现验证放在 App UI 中。Scene 迁移还导致 SwiftUI 编辑页切回 LTR 的字形镜像，OCR 断言捕获后，在示例已有导航桥接中同步宿主的原生语义属性与 trait override，并参与同轮内容投递修复。未恢复框架逐页覆盖、未删除 OCR／草稿／连续输入／手势断言。

源码指纹、最终结果与失败路径见 [分版本适配验证清单](Verification/scene-direction-adaptation.json)。此前“未注册窗口方向不变”的历史记录只适用于旧的窗口作用域。

## 配置式按钮方向修复（2026-11-17）

参照 UIKitLanguageDemo 的 Screens/LanguagePickerView.swift，修复位于具体按钮的业务配置处：比较按钮旧 semanticContentAttribute 与本轮语义方向，仅方向变化时将 configuration 置 nil；随后设置方向、生成业务配置并 setNeedsLayout。UIButton 实例、状态和 action 保持不变。同方向文案刷新不清空配置。框架 Sources 没有增加包装、遍历或全局补丁。

此前预期失败测试已经替换为严格回归，没有 XCTExpectFailure 或系统版本豁免。前缘／后缘图标检查实际矩形相对位置，覆盖往返切换、同方向同步、禁用／选中／高亮状态和 action 调用。完整包测试 **60 项通过、0 失败、0 预期失败**。AppLocalization、LanguageSwitchingDemo、Today 三个 iOS 构建通过。

主示例 UIKit Modal 新增原生语言分段控件和配置式关闭按钮，可在同一个呈现页面中切换英／中／阿拉伯语。原有字形及编辑返回手势 UI 测试 2 项通过；新增弹窗切换与关闭用例最终定向重跑 1 项通过，两个结果包均无运行期警告。首次完整 UI 运行中，新用例误以为关闭后离屏 UIKit 行会立即存在；失败时 AX 层级显示已返回根语言列表、滚动位置 0%。改为断言弹窗及关闭按钮消失、根语言选择器出现后通过，没有添加补偿滚动、点击或延迟恢复。首次失败证据保留。

实际截图：[RTL 图标在标题右侧](Verification/configured-button-rtl.png)、[LTR 图标在标题左侧](Verification/configured-button-ltr.png)。入口：主页 UIKit 区域 → 显示 UIKit Modal → 弹窗内切换语言。诊断中仅重新赋回原 configuration 仍失败；局部清空后配置通过，未推断 UIKit 私有实现的具体原因。

源码指纹、测试路径和边界见 [配置按钮修复清单](Verification/configured-button-fix.json)。真机、iOS 15 运行期、精确 Swift 6.3 编译器和 Today 完整业务流程未执行。下方原生包装移除阶段的预期失败属于历史记录，已由本节修复取代。

## 原生视图方向与包装移除

删除 UIViewLayoutDirection.swift，移除 UIViewLayoutDirectionTarget、UIViewLayoutDirectionUpdater、UIViewLayoutDirectionPolicy 以及未使用的 DirectionalContentSemantics。主示例两个普通文字按钮直接继承容器方向；编辑内容测试页删除仅用于转发方向更新的协议和方法。框架不再对控件统一清空并恢复配置、重设附件或触发布局／固有尺寸失效。特殊内容直接设置 UIKit 的 semanticContentAttribute。

- **通过**：AppLocalization、LanguageSwitchingDemo、Today 三个通用 iOS 构建。
- **包测试**：共 60 项，59 项通过、1 项已知预期失败、0 项未预期失败。删除 2 项包装策略测试，新增 1 项原生按钮实际布局测试；输入、列表、复用与窗口事务回归保留。
- **通过**：主示例 UI 回归 2 项、0 失败、0 运行期警告，覆盖语言字形、草稿、连续输入及原生双向返回手势。
- **未解决的原生行为限制**：iOS 27.2 模拟器中，配置式按钮的 direction 已变为 RTL，但前缘图标仍位于标题左侧。同步布局、等待下一轮主队列、显式设置 semanticContentAttribute、调用原生配置刷新均复现。当前证据确认实际位置不符合预期，未进一步归因 UIKit 内部实现。

该限制保留在 testNativeButtonsInheritDirectionWithoutRebuildingConfiguration 中，仅对 iOS 27.2 的 RTL 图文位置断言使用严格 XCTExpectFailure；两次 RTL 切换各记录一次预期断言失败，xcresult 将该测试计为 1 项预期失败。其余断言仍严格验证。系统修复后，严格预期失败会使测试失败，提示移除标记。**这不代表该图标问题已修复或全部 60 项功能均通过。** 主示例使用普通文字按钮，不依赖这项图标行为；框架未重新引入配置重建补丁。

四次诊断的失败日志／xcresult 均保留。详细结果、源码指纹和失败路径见 [原生方向验证清单](Verification/native-direction-cleanup.json)。Today 完整业务流程、实际输入法组合输入、真机、iOS 15 运行期和 Swift 6.3 精确编译器未执行。

## 公开架构 API 精简

移除页面 prepareForLocalization／finishLocalization 回调、update.apply(to:) 转发和静态工厂、UIKitLocalizationUpdateReason 位掩码、公开事务参与者注册及独立方向协议、公开 SwiftUI 包装视图与整棵子树重置开关、导航按钮 result builder、根恢复枚举／工厂和特殊 presented 边界协议。页面仅实现 applyLocalization(_:)；首次配置直接创建 UIKitLocalizationUpdate(snapshot:)，后续刷新需求由前后快照推导。

保留框架内部事务接口，维持核心层与 UIKit 的依赖边界，以及多个协调器的全部窗口方向先于任何页面内容更新的保证。普通 presented 链继续刷新，根控制器替换与特殊系统界面重建由应用自己负责。SwiftUI 使用私有 ViewModifier 注入同一控制器与环境，业务视图自行管理局部身份。主示例已有的局部 List 身份策略保留。

- **通过**：iOS 模拟器包测试 61 项，0 失败。相较上一轮 59 项新增快照差异刷新和跨协调器顺序验证；页面生命周期、根替换及导航数组测试同步迁移至新 API。
- **通过**：AppLocalization、LanguageSwitchingDemo、Today 三个通用 iOS 构建。
- **通过**：主示例 UI 回归 2 项，0 失败，xcresult 运行期警告 0。验证语言来回切换字形、编辑草稿、无再次点击的连续输入，以及 LTR／RTL 原生返回手势。
- **首次失败，已修复**：包测试编译时仍引用删除的 preparedNavigationDirections 测试字段；改为检查首次 apply 所记录的方向后，完整包测试通过。首次失败日志与 xcresult 保留。
- **未执行**：Today 完整 EventKit 业务流程、实际输入法组合输入、真机、iOS 15 运行期和 Swift 6.3 精确编译器。

详细路径、源码指纹和删除的接口见 [公开架构 API 精简验证清单](Verification/architecture-surface-cleanup.json)。以下记录按历史阶段保留，已移除的恢复与包装 API 不再代表当前接入方式。

## 原生列表与恢复架构移除

用户明确选择采用原生列表行为，移除业务 ID 精确锚点、偏移和正交分页恢复机制。删除 UIKitListLocalizationCoordinator.swift、UIKitLocalizationSubscription.swift 和 UICollectionViewLocalization.swift；清理所有示例中的 listLocalization 属性、初始化映射、布局重建闭包及只用于恢复的 complete(revision:) completion。

同步删除控制器的适配器订阅查询、窗口同步的订阅扫描，以及只有适配器使用的方向优先级分组。保留全部窗口先更新方向、再更新页面内容的阶段，保证多窗口不会在同一轮配置中混用旧方向。事务重入处理、显式窗口注册、页面刷新和原生导航仍保留。

列表现在使用原生布局、代理、数据源、方向继承和滚动行为。框架不主动重载列表、重建布局或恢复滚动位置，不再承诺数据重排／行高变化后的精确阅读锚点。业务仍使用稳定 diffable ID，以避免替换编辑行身份。

原生列表包测试共 59 项通过、0 失败。之前 78 项中的 20 项列表恢复／适配器专属测试已随功能删除；增加 1 项原生列表的数据源、布局实例和选择状态保留回归。原生复用测试改为只注册应用窗口，不创建列表适配器；覆盖 cell、header、supplementary、离屏复用、显式方向例外和自定义内容实例。多窗口测试加强了全部窗口方向先于任何页面内容更新的断言。

AppLocalization、LanguageSwitchingDemo、Today 三个通用 iOS 构建均通过。主示例 UI 回归 2 项通过、0 失败、0 运行期警告，继续验证中／英／阿拉伯语字形、草稿、编辑焦点、连续输入和原生双向返回手势。Today 完整业务流程、实际输入法组合输入、真机、iOS 15 运行期和 Swift 6.3 精确编译器仍未执行。

构建、UI 回归和验证边界见 [原生列表验证清单](Verification/native-list-cleanup.json)。此前的稳定锚点和适配器自动订阅记录仅作为历史证据保留，不再代表当前框架能力。

## 原生输入与绑定移除

进一步删除 UIKitTextInputLocalization.swift 中的绑定对象和对齐策略类型。Today 的 TextFieldContentView、TextViewContentView 删除 inputBinding、refresh 调用、仅用于绑定刷新的 didMoveToWindow、AppLocalization import 和语言服务依赖。保留原生输入实例、业务代理和配置更新中的相同值／markedTextRange 保护。

输入控件采用 UIKit 语义继承和 natural 对齐。此行为不等同于之前强制对齐应用前缘；框架也不再修补业务自行修改的 typingAttributes，特殊固定策略由原生 UIKit 属性表达。

包测试 78 项通过、0 失败；AppLocalization、LanguageSwitchingDemo 和 Today 三个通用 iOS 构建通过。原有 11 项绑定测试替换为 4 项原生输入测试，并新增 1 项列表自动订阅弱引用测试，所以总数由 84 调整为 78。保留实际窗口中的自定义输入实例、焦点、选区回归，新增原生单行／安全／多行／搜索输入方向继承，以及富文本附件、段落、代理和固定方向策略检查。单窗口适配器同步测试改为验证列表。

本轮没有重跑主示例 UI 手势测试；绑定此前未用于该示例。Today 完整业务流程、实际输入法组合输入、真机、iOS 15 运行期和 Swift 6.3 精确编译器未验证。证据见 [原生输入验证清单](Verification/native-input-cleanup.json)。下方自动绑定的历史结果保留，不能视为最新接入方式。

## 适配器自动订阅与组件树移除

删除 UIKitLocalizationApplying.localizationChildren 和 UIKitLocalizationComponents 遍历器。列表协调器与输入绑定通过内部弱订阅自动参与事务，业务只持有适配器。Today 的两个输入内容视图移除协议和空回调，详情页面不再扫描 cell.contentView。两个示例的列表适配器改为在列表／数据源就绪时创建，避免未访问的 lazy 属性没有实际订阅。

内部方向阶段先更新全部窗口／容器，再更新适配器，随后配置业务内容；准备仍全部发生在状态发布之前，完成仍全部发生在内容更新之后。窗口激活同步通过已注册适配器的公开 view.window 归属筛选，不访问私有子视图，不重复投递正常语言事务。

| 本轮验证 | 结果 |
| --- | --- |
| iOS 包测试 | 84 项通过，0 失败 |
| 主示例 UI 回归 | 2 项通过，0 失败，0 运行期警告 |
| AppLocalization 通用 iOS 构建 | 通过 |
| LanguageSwitchingDemo 通用 iOS 构建 | 通过 |
| Today 通用 iOS 构建 | 通过 |

新增测试覆盖适配器与窗口协调器的两种创建顺序、方向先于页面数据变化、列表锚点与选中 ID 恢复，以及单窗口同步只更新所属输入绑定。原有焦点／选区测试在移除组件树后仍通过，自动输入更新、组合输入延后和弱引用释放也继续验证。UI 回归继续检查实际屏幕字形、连续输入、键盘焦点和双向返回手势。

首轮布局测试辅助方法固定使用英文控制器创建适配器，与传入的 RTL update 不一致。自动初始化引入额外方向切换，单项测试有 7 个断言失败；修正测试提供器后，布局重建次数和实例断言原样通过，未放宽断言。原始失败保留在清单中。

证据：[自动订阅验证清单](Verification/automatic-adapters.json)、[结果摘录](Verification/automatic-adapters.txt)。本轮仍使用 iOS 27.2 模拟器与 Swift 6.4.2；未执行 Today 完整 EventKit 编辑业务、真机、iOS 15 运行期或 Swift 6.3 精确编译器验证。

## 根页面方向图标清理

同日移除主页面工具栏中手动添加的返回方向 Image，它没有返回动作，却被导航栏呈现为类似返回按钮的外观；同时删除未使用的 nav.direction.icon 文案。详情页的系统返回按钮与导航方向桥接未修改。模拟器构建、启动及截图检查通过，主示例通用 iOS 构建通过；本次未重跑完整 UI 手势测试。见 [根页面无返回图标截图](Verification/root-without-back-icon.jpg)，构建日志为 `/tmp/applocalization-root-icon-removal-build.log`。

## SwiftUI List 字形镜像修复

用户截图显示导航标题正常，但中文语言页的 List 整体水平镜像，连英文、中文和 LTR 字形也被翻转。新增屏幕识别测试后，在同一 iOS 27.2 模拟器上稳定复现英文 → 阿拉伯文 → 中文的失败；无障碍标签与应用语言状态始终正确，因此此前仅检查文字存在的 UI 测试不能排除这个缺陷。

依次尝试去掉控制器方向 trait、去掉窗口方向 trait、同时去掉两者、进一步去掉宿主视图语义写入，以及停用窗口注册与导航方向桥接，均未消除同一失败。因此不能把 `window.traitOverrides.layoutDirection` 视为该问题的必要触发条件；所有诊断性框架／桥接修改已撤回。观察结果支持将恢复限定在 SwiftUI List 的方向切换边界，不推断其私有缓存实现。

最终方案在主页面和 Push 页面中增加稳定 VStack 容器，仅对内层 List 使用 `.id(localizationController.layoutDirection)`。导航链接、Sheet 状态和草稿输入框位于重建边界之外，框架的根视图身份策略不变。首个只加 List identity 的尝试虽然修复字形，却导致导航目的地草稿重置；该失败已保留，稳定容器版本通过了草稿、键盘焦点、连续输入和双向返回手势回归。

方向改变会重建示例列表及其行内容，并重置列表滚动位置；同方向切换不重建。此方案是示例层的局部恢复，不能视为任意业务 List 都能无损重建。状态应放在稳定的页面层或模型中。

最终 UI 测试 2 项通过、0 失败，xcresult 运行期警告为 0；主示例通用 iOS 构建通过。屏幕识别覆盖主页面中／英／阿拉伯语往返和详情页 RTL／LTR 编辑过程，另保留人工查看的原始截图：[修复前中文](Verification/mirror-before-chinese.png)、[修复后中文](Verification/mirror-fixed-chinese.png)、[修复后阿拉伯文](Verification/mirror-fixed-arabic.png)、[保留草稿的编辑页](Verification/mirror-fixed-draft.png)。应用截图不包含系统键盘；键盘存在性与不重新点击输入框的连续输入由 UI 断言验证。

最新结果与原始失败路径见 [字形镜像验证清单](Verification/swiftui-list-mirror-fix.json) 和 [诊断日志摘录](Verification/swiftui-list-mirror-fix.txt)。最终验证仍限于 iPhone 18 Pro / iOS 27.2；Swift 6.3 精确编译器、iOS 15 运行期与真机未执行。本轮框架源码无净变化，未重跑包测试，之前的 82 项结果属于下方布局类型移除验证。

## Flow Layout 公共类型移除验证

同日进一步删除 `LocalizedCollectionViewFlowLayout`。主示例的水平卡片尺寸、间距和镜像策略归入示例私有的 DemoCardLayout；普通复用测试使用原生 UICollectionViewFlowLayout，水平语义锚点回归使用测试私有的镜像布局。

重新执行 iOS 包测试：82 项通过，0 失败。AppLocalization、LanguageSwitchingDemo 和 Today 三个通用 iOS 构建均通过。本轮保留原有镜像行为，未重复执行 UI 手势测试；下面的 UI 结果属于前一轮原生复用精简验证。证据见 [布局类型移除验证](Verification/flow-layout-removal.json)。

## 原生复用入口精简验证

删除 UIKitLocalizationContext、UITableViewLocalization、UIKitReusableLocalization 三个源文件，移除本地化 dequeue、registration 工厂、独立配置／挂载操作及只服务于它们的更新原因。Table／Collection 的方向和可见内容刷新集中在 UIKitListLocalizationCoordinator，列表协调器和输入绑定直接依赖 LocalizationController。两个示例改用原生 UIKit dequeue／registration，在 willDisplay 重用业务配置入口。

| 检查 | 最新结果 |
| --- | --- |
| iOS 包测试 | 82 项通过，0 失败 |
| 主示例 UI 测试 | 1 项通过，0 失败，xcresult 测试警告 0 条 |
| AppLocalization 通用 iOS 构建 | 通过 |
| LanguageSwitchingDemo 通用 iOS 构建 | 通过 |
| Today 通用 iOS 构建 | 通过 |

原有 11 项复用包装测试替换为 5 项原生生命周期测试，并移除另一项重复的旧 Context 测试，测试总数从 89 调整为 82。新测试覆盖原生 Table dequeue、Collection cell/supplementary registration、diffable reconfigure、离屏再显示、最新文本、生效方向、trait 容器间重新挂载、固定 LTR／空间／播放内容节点和自定义内容实例保留。其他事务、列表状态恢复和输入测试继续执行。

首轮测试有 53 个断言失败，暴露了测试对 UIKit 行为的错误假设：列表会主动设置 cell/contentView/header 的语义属性，不能要求它们始终 unspecified；普通 UIView 的 semanticContentAttribute 也不能替代控制器 trait 作用域。修正后的测试断言实际生效方向，并使用真实 trait 容器验证重新挂载；特殊方向断言针对业务拥有的内容节点，而非由 UIKit 管理的复用外壳。首轮失败日志仍保留，未将其记为通过。

最终 UI 回归仍包含连续语言切换、无需重新点击输入框的追加输入，以及双向返回手势。测试后的源码变化仅为列表初始化参数的中文注释和空白整理；随后 iOS 包构建及 UI 测试使用最终源码完成。

证据：[清理结果与源码指纹](Verification/native-reuse-cleanup.json)、[测试与构建摘录](Verification/native-reuse-cleanup.txt)。完整结果为 `/tmp/applocalization-cleanup-tests-2.xcresult` 和 `/tmp/applocalization-cleanup-ui.xcresult`。未验证范围仍同下文；本次没有完成 Today EventKit 业务端到端验收或 iOS 15／16 运行验证。

## 架构重构基线结果

| 检查 | 结果 | 范围 |
| --- | --- | --- |
| AppLocalization 包测试 | 通过：89 项，0 失败，0 跳过 | 在 iOS 模拟器运行，包含核心、资源、UIKit 及布局测试 |
| LanguageSwitchingDemo UI 测试 | 通过：1 项，0 失败，0 跳过 | 真实点击、文本输入、双向边缘手势 |
| AppLocalization 通用 iOS 构建 | 通过 | Swift 6 语言模式 |
| LanguageSwitchingDemo 通用 iOS 构建 | 通过 | 关闭代码签名，保持 iOS 15 部署目标 |
| Today 通用 iOS 构建 | 通过 | 关闭代码签名，保持原工程 iOS 18 部署目标 |

包测试验证了快照一次发布、事务阶段顺序、重入合并、弱引用、系统语言匹配与旧选择持久化，以及显式注册窗口的同步、presented 链和原有导航对象保留。列表测试覆盖业务 ID 重排／删除、迟到 completion、表格高度变化、Flow／Compositional Layout、语义水平偏移，以及通过真实正交布局的公开回调记录和恢复居中分页条目。输入测试检查自定义内容实例、焦点、选区和固定 LTR 输入配合应用前缘对齐。

窗口测试使用多个 UIWindow 对象，不能替代独立 UIScene 会话的端到端验证。列表几何和输入单元测试也不能替代完整的用户拖动、输入法组合输入或 Today 业务流程验收。

UI 测试在主示例中切换英文／阿拉伯文，进入 Push 页面，输入 `Retained draft`，留在详情页切换方向并确认草稿保留。在 RTL 下从错误的左边缘滑动不会返回，从右边缘滑动能够返回；切回 LTR 后左边缘能够返回。没有通过重建根界面或替换返回手势代理来满足断言。

## 截图与原始证据

- [阿拉伯文根页面](Verification/root-arabic.png)
- [阿拉伯文详情页与保留的草稿](Verification/detail-arabic-draft.png)
- [返回后的英文根页面](Verification/root-english-after-pop.png)
- [测试结果及构建警告摘录](Verification/test-results.txt)
- [环境、结果路径与源码 SHA-256](Verification/verification.json)

截图来自最终通过的 UI 测试结果附件。完整日志和 xcresult 暂存在本机 `/tmp`，可能被系统清理；仓库保留上述精简证据。

| 证据 | 本机路径 |
| --- | --- |
| 最终包测试 | `/tmp/applocalization-refactor-tests-complete.xcresult` |
| 最终 UI 测试 | `/tmp/applocalization-ui-final.xcresult` |
| 包构建 | `/tmp/applocalization-package-final.log` |
| 主示例构建 | `/tmp/applocalization-demo-final.log` |
| Today 构建 | `/tmp/applocalization-today-final.log` |

验证后 SwiftUI 环境文件从 UIKit 目录移回 SwiftUI 目录，文件内容哈希一致。证据清单记录这一仅路径变化；上述运行结果对应同一份文件内容。

## SwiftUI 编辑状态警告修复

实际调用栈显示，SwiftUI 更新 List 的布局方向时，底层 UICollectionView 的语义属性更新触发 reloadData，随后输入框 resignFirstResponder，进入 PlatformTextFieldCoordinator.didEndEditing；此时仍在 SwiftUI 的 PlatformViewChild.updateValue 内。应用草稿绑定也在这一调用栈中收到原值回写。仅过滤重复草稿赋值仍会出现警告，说明它不足以处理系统文本框的编辑状态更新。

修复将 Push 页原生 TextField 从 List 的复用行移到 `.safeAreaInset(edge: .top)`，继续使用原有 `$draft`。语言列表改变方向时不再结束输入框编辑。未引入延时状态提交、焦点恢复调用或私有视图访问，框架核心代码没有变化。

UI 测试将 `Modifying state during view update` 转为失败，并增加连续 RTL → LTR → RTL 切换：每次检查键盘仍存在，在不重新点击输入框的情况下追加 ` RTL` 和 ` LTR`，确认草稿为 `Retained draft RTL LTR`，再验证错误边缘不返回和双向正确边缘返回。

| 后续验证 | 结果 |
| --- | --- |
| 原实现加警告失败检查 | 失败：准确捕获原有警告 |
| 仅过滤重复草稿赋值的诊断尝试 | 失败：同一警告仍存在，修改已撤回 |
| 独立输入边界，原交互流程 | 通过，状态更新警告 0 次 |
| 加强用例首次运行 | 失败：后续命中查询时截图显示系统 App 切换器；此前连续编辑断言已通过，状态更新警告 0 次 |
| 加强用例原样复跑 | 通过：1 项，0 失败；xcresult 测试警告 0 条 |
| 主示例和 Today 通用 iOS 构建 | 通过 |

本次只修改主示例及其 UI 测试，未重跑包测试；上方 89 项包测试属于架构重构基线。修复验证仍限于同一 iOS 27.2 模拟器，不能推断其他系统版本的完整运行结果。

证据：[修复后的编辑页与插入光标](Verification/detail-arabic-editing-fixed.png)、[诊断调用栈及结果摘录](Verification/swiftui-warning-fix.txt)、[修复验证清单](Verification/swiftui-warning-fix.json)。应用窗口截图不包含系统键盘，键盘存在性和继续输入由 UI 测试断言验证。最终完整结果位于 `/tmp/applocalization-warning-fix-verified.xcresult`；失败运行路径也保留在清单中。

## 其他警告与历史诊断

- 架构重构基线曾出现上述 SwiftUI 警告，后续修复及验收见上一节。早期延后 UIKit 桥接刷新的尝试未消除警告，已撤回；保留 `/tmp/applocalization-ui-bridge.xcresult`，不作为修复证据。
- 当前 SDK 的 XCTest／XCUIAutomation 最低二进制版本高于 UI 测试目标声明的 iOS 15，链接器给出 iOS 17 版本警告。实际测试在 iOS 27.2 执行，不能据此证明测试可在 iOS 15 运行。
- 示例没有依赖 AppIntents，Xcode 提示跳过其元数据提取。构建成功。

早期基线测试曾因资源测试假定 `.xcstrings` 的构建产物形态而失败；测试已兼容源码 catalog 和 Xcode 编译后的 `.strings`。早期 UI 手势用例也曾失败，之后调整为从窗口边缘执行手势并完成复验。最终结果不抹去这些失败，也不将多项调整后的通过归因于某个未经隔离的单一原因。

## 未执行范围

- Swift 6.3 精确版本编译器。
- iOS 15／16 运行与物理设备验证。
- iPad 独立多 UIScene 会话的真实交互。
- Today 的 EventKit 授权、保存和完整编辑流程。
- 从系统“设置”更改 App 语言后的进程重启与业务路由恢复。

以上均未作为通过项。应用名、权限提示、通知、Widget 和扩展仍属于系统或独立进程边界，不承诺进程内实时更新。

## 复现命令

从仓库根目录运行，用本机可用的模拟器 ID 替换占位符：

```bash
xcodebuild -scheme AppLocalization -destination 'platform=iOS Simulator,id=<模拟器 ID>' -parallel-testing-enabled NO test
xcodebuild -project Examples/LanguageSwitchingDemo/LanguageSwitchingDemo.xcodeproj -scheme LocalizationValidation -destination 'platform=iOS Simulator,id=<模拟器 ID>' -parallel-testing-enabled NO test
xcodebuild -scheme AppLocalization -destination 'generic/platform=iOS' build
xcodebuild -project Examples/LanguageSwitchingDemo/LanguageSwitchingDemo.xcodeproj -scheme LanguageSwitchingDemo -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Examples/Today/Today.xcodeproj -scheme Today -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

包直接导入 UIKit，macOS 宿主的 `swift test` 不再是受支持入口。
