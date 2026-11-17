# LanguageSwitchingDemo

用 Swift 6.3+ 工具链打开 `LanguageSwitchingDemo.xcodeproj`，运行 `LanguageSwitchingDemo` Scheme。最低 iOS 15，已链接仓库根目录的本地 AppLocalization 包。

示例演示 SwiftUI 环境传播、UIKit 自动事务更新、应用窗口显式注册、presented 模态刷新、Collection 原生布局与复用方向、语义手势和双向导航。语言切换保持根视图身份，不再转发通知给协调器。

Push 页面可输入草稿并直接切换语言。输入框位于列表上方的独立安全区域插入视图中，避免语言列表刷新方向时结束编辑。`LocalizationValidation` 共享 Scheme 使用 XCTest 执行英文／阿拉伯文切换、草稿和编辑焦点保留、连续输入及真实左右边缘返回；状态更新警告会使测试失败，截图保存在 xcresult 附件中。

草稿输入框使用 `.multilineTextAlignment(.leading)`；iOS 26+ 同时设置 `.multilineTextAlignment(strategy: .layoutBased)`，按布局环境决定对齐，让 RTL 的占位文字和空光标靠右，LTR 靠左。该配置仅作用于具体输入框，不改变其身份，也不新增 UIKit 桥接或通用绑定。iOS 15–25 保留 `.leading` 分支；本轮运行期验证使用 iOS 27.2。UI 回归直接检测空输入框截图中的光标位置，并保留语言往返及继续输入的截图。原生策略的定义见 [Apple 文档](https://developer.apple.com/documentation/swiftui/view/multilinetextalignment(strategy:))。

iOS 27.2 实测中，SwiftUI List 从 RTL 切回 LTR 后会出现整块列表字形镜像，即使停用窗口和导航方向桥接仍会复现。示例在稳定的 VStack 页面容器内按方向更新 List 身份，导航链接、Sheet 和草稿输入框放在该重建边界之外。方向改变会重建列表内容并重置列表滚动位置；同方向语言切换不重建。此恢复仅用于示例，不改变框架默认的 SwiftUI 根视图身份策略。UI 测试使用 Vision 识别实际屏幕上的英文语言名称，覆盖英文 → 阿拉伯文 → 中文 → 阿拉伯文 → 英文及详情页切换，避免仅验证无障碍标签而漏掉字形镜像。

资源使用 Localizable.xcstrings；应用名使用 InfoPlist.xcstrings，遵循系统元数据的刷新边界。图标包含浅色、深色和灰度 Tinted 版本，源文件保留在仓库 Design/AppIcon。

框架架构、API 迁移与实际验证范围见仓库根目录 README 和 Docs。

UIKit 配置式按钮验证入口：主页滚动到 UIKit 区域，点击“显示 UIKit Modal”。弹窗内的原生分段控件可切换英／中／阿拉伯语，底部带图标的关闭按钮始终保留同一实例。方向变化时，页面局部清空并重设该按钮的 configuration，再设置布局；不依赖框架包装。UI 测试覆盖来回切换和关闭 action，截图保存到 xcresult。

方向适配：iOS 17+ 由注册窗口所属 Scene 传播 traits，iOS 15/16 使用窗口／控制器公开语义边界及旧版容器 override。UIKit Modal 底部显示的是 UIKit 视图挂载后的实际方向；UI 测试从阿拉伯语启动后再呈现弹窗，检查其继承 RTL，然后来回切换。导航容器在所有版本继续设置语义方向。

示例采用 UIKit AppDelegate / SceneDelegate 生命周期，直接创建窗口并交给本地化协调器。DemoNavigationController 使用原生 pushViewController、present 和 dismiss 管理 SwiftUI 宿主；根页、详情页和 Sheet 不再使用 NavigationPopGestureConfigurator、隐藏 NavigationLink 或窗口探测视图。导航控制器在创建页面及本地化事务中同步自己拥有的 SwiftUI 宿主语义方向及 iOS 17+ trait override，保持 List 字形正常，并保留系统返回手势及代理。输入框和局部 List 身份方案保持不变。

编辑详情页使用原生紧凑导航标题（largeTitleDisplayMode.never），首页和 Sheet 保持大标题。标题由 SwiftUI navigationTitle 更新，导航容器负责原生栈和方向；详情页验证同时检查标题像素、连续输入和双向返回。

UIKit Modal 的导航栏关闭按钮使用 UIBarButtonItem(customView:)。在弹窗内反复切换语言，可以同时检查导航 customView 的位置、正文配置式按钮的图标位置，以及导航关闭按钮的实际点击行为。customView 的位置刷新由现有窗口协调器在方向阶段通过 invalidateIntrinsicContentSize 处理，页面不重新安装导航项，也没有额外包装。

语言选项直接读取主 Bundle 的 localizations，跟随系统使用 preferredLocalizations，回退使用开发语言。服务构造时不再重复声明语言数组；英语标识符采用 String Catalog 的 en，旧 en-US 偏好仍可匹配。解析器显式复用控制器的回退语言。
