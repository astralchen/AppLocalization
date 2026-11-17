# Today

基于 Apple Saving Reminders 示例的 UIKit 本地化接入。原示例许可见 LICENSE，保留现有 iOS 18 部署目标，使用 Swift 6 语言模式与 Swift 6.3+ 工具链。

Today.xcodeproj 通过本地 Swift Package 链接仓库根目录的 AppLocalization。

- SceneDelegate 注册／注销应用窗口，激活时同步；AppDelegate 不再转发本地化通知。
- 设置 Table 与提醒 Collection 使用原生 UIKit 方向继承、布局和滚动行为，不持有额外的本地化协调器。
- 详情编辑行的 ID 不包含文案、Date 或草稿值；内容从 workingReminder 读取。
- 自定义输入内容保留实例，不导入 AppLocalization，不持有输入绑定，也不设置本地化刷新钩子。标题配置携带原生 UIUserInterfaceLayoutDirection，直接设置 UITextField.semanticContentAttribute 和 textAlignment，让空光标及草稿对齐应用前缘；备注继续使用 natural 对齐。此做法参考 UIKitLanguageDemo 的 applyTextField。
- diffable 直接提交业务 snapshot，不再接入本地化滚动位置恢复。
- 详情页首次加载、编辑状态变化和语言更新共用一次快照提交；分区身份直接读取 diffable data source，不使用分区下标偏移。
- 输入配置直接创建具体的 UIContentConfiguration，不扩展所有 cell 或为整个协议提供默认状态更新。不同内容类型使用独立的原生 CellRegistration，避免查看／编辑时替换不兼容的内容视图。

构建：

```sh
xcodebuild -project Examples/Today/Today.xcodeproj -scheme Today -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

完整验证范围见仓库 Docs/Validation.md；原生输入回归测试不等同于 Today 所有 EventKit 业务流程均已验证。

详情编辑回归使用真实 ReminderViewController、输入内容视图和场景窗口，保存结果由测试闭包接收；不将其视为 EventKit 持久化验证：

```sh
xcodebuild -project Examples/Today/Today.xcodeproj -scheme TodayValidation -destination 'platform=iOS Simulator,id=<模拟器 ID>' -parallel-testing-enabled NO test
```

覆盖语言往返时的输入实例、草稿、焦点、选区和组合文本，以及加载前进入编辑、取消和新增保存行为。新增提醒弹窗还实际测量 ar → en-US → ar → zh-Hans 的空光标位置，并验证不重新聚焦即可继续输入。

语言选项直接读取主 Bundle 的 localizations，跟随系统使用 preferredLocalizations，回退使用开发语言。服务构造时不再重复声明语言数组；英语标识符采用 String Catalog 的 en，旧 en-US 偏好仍可匹配。解析器显式复用控制器的回退语言。
