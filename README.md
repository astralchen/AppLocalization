# AppLocalization

`AppLocalization` 是一套用于 iOS 应用内语言切换的示例框架和演示工程。目标是在不重启 App 的前提下，让 SwiftUI、UIKit、混合栈、多窗口、present/modal、`UITableView`、`UICollectionView`、导航栏和手势方向都能随语言与 RTL/LTR 变化正确刷新。

这个仓库同时包含：

- 可复用 Swift Package：`Sources/AppLocalization`
- 单元测试：`Tests/AppLocalizationTests`
- iOS 示例工程：`Examples/LanguageSwitchingDemo/LanguageSwitchingDemo.xcodeproj`
- 示例 String Catalog：`Examples/LanguageSwitchingDemo/LanguageSwitchingDemo/Localizable.xcstrings`
- 应用名本地化 String Catalog：`Examples/LanguageSwitchingDemo/LanguageSwitchingDemo/InfoPlist.xcstrings`
- App Icon 源文件：`Design/AppIcon`
- App Icon 资源：`Examples/LanguageSwitchingDemo/LanguageSwitchingDemo/Assets.xcassets`

## 核心能力

- 应用内语言切换，不依赖重启 App。
- 使用最新的 `Localizable.xcstrings` 作为文案资源。
- 支持“跟随系统”和显式选择 App 语言。
- 支持当前系统语言与 App 支持语言不完全一致时的合理匹配，例如繁体中文系统优先解析到简体中文。
- SwiftUI 通过 `.locale` 与 `.layoutDirection` 即时刷新。
- UIKit 通过显式 reload 协议刷新 label、button、title、placeholder、navigation item 等一次性赋值内容。
- 多 scene / 多 window 刷新，不依赖单个 `keyWindow`。
- 支持 presented view controller 链路刷新。
- 覆盖 RTL/LTR 下的导航按钮位置、返回图标、pop 手势方向、push/pop 动画方向。
- 覆盖 `UITableView` 可见内容方向刷新与可见 row 保持，以及 `UICollectionView` 横向布局、可见 item 保持、RTL 滚动方向和 layout invalidation。
- 区分普通界面镜像和空间语义内容，避免地图、图表、播放进度等被错误镜像。
- 通过 `InfoPlist.xcstrings` 演示应用名国际化。

## 目录结构

```text
Sources/AppLocalization/
  Core/          语言状态、Locale 模型、持久化和变更事件
  Strings/       本地化字符串解析器
  Directional/   semantic 方向、手势和导航方向工具
  SwiftUI/       SwiftUI environment 注入
  UIKit/         UIKit reload 协议、scene/window 刷新、方向适配

Examples/LanguageSwitchingDemo/
  LanguageSwitchingDemo.xcodeproj
  LanguageSwitchingDemo/
    Localizable.xcstrings
    InfoPlist.xcstrings
    Assets.xcassets
    DemoRootView.swift
    UIKitLocalizationDemoViewController.swift
    PushPopGestureDemoView.swift
    GestureDirectionDemoView.swift

Tests/AppLocalizationTests/
```

## 快速开始

运行测试：

```sh
swift test
```

构建示例工程：

```sh
xcodebuild \
  -project Examples/LanguageSwitchingDemo/LanguageSwitchingDemo.xcodeproj \
  -scheme LanguageSwitchingDemo \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

在 Xcode 中打开示例：

```sh
open Examples/LanguageSwitchingDemo/LanguageSwitchingDemo.xcodeproj
```

## 基本集成方式

将仓库根目录添加为本地 Swift Package，并在 App target 中链接 `AppLocalization` library product。使用框架 API 的 Swift 文件需要导入模块：

```swift
import AppLocalization
```

创建全局语言服务：

```swift
import AppLocalization

let localizationController = LocalizationController(
    supportedLocales: [.englishUS, .simplifiedChinese, .arabic],
    fallbackLocale: .englishUS,
    preferenceStore: UserDefaultsLocalePreferenceStore(
        key: "app.locale.identifier"
    )
)

let resolver = LocalizedStringResolver(
    localeProvider: { localizationController.currentLocale },
    fallbackLocale: .englishUS
)
```

SwiftUI 根视图注入环境：

```swift
RootView(
    localizationController: localizationController,
    resolver: resolver
)
.appLocalizationEnvironment(localizationController)
```

UIKit 页面实现刷新协议：

```swift
final class SettingsViewController: UIViewController,
    LocalizedContentUpdating,
    UserInterfaceLayoutDirectionUpdating {

    func reloadLocalizedContent() {
        title = resolver.string("settings.title", bundle: .main)
        titleLabel.text = resolver.string("settings.language", bundle: .main)
        confirmButton.setTitle(resolver.string("common.confirm", bundle: .main), for: .normal)
    }

    func reloadLayoutDirection(_ direction: UIUserInterfaceLayoutDirection) {
        view.semanticContentAttribute = direction.appLayoutDirection.semanticContentAttribute
    }
}
```

语言变化后刷新所有 scene：

```swift
UIWindowSceneLocalizationCoordinator().reloadAllScenes(
    for: change,
    // 默认原地刷新；只有系统容器无法响应方向变化时才重建 root。
    rebuildRootWindows: false,
    animateRootRebuild: true
)
```

## 语言选择显示规则

示例工程里的语言选择列表采用两行显示：

- 主标题：语言自身名称，稳定不随当前 App 语言变化，例如 `English (United States)`、`简体中文`、`العربية`。
- 副标题：按当前 App 语言本地化显示，会随语言切换刷新。
- “跟随系统”：主标题随当前 App 语言本地化，副标题显示系统偏好解析后的实际 App 语言。

这样可以避免用户在多语言之间频繁切换时，普通语言项名称跳动或在 RTL 环境下出现中文/英文视觉反排。

## RTL/LTR 设计要点

不要把物理方向直接当成业务语义：

```swift
let semanticDirection = DirectionalLayout.semanticHorizontalDirection(
    translationX: translation.x,
    layoutDirection: localizationController.layoutDirection
)
```

导航与返回也使用 semantic 映射：

```swift
let edge = DirectionalLayout.backSwipeRectEdge(
    layoutDirection: localizationController.layoutDirection
)

let imageName = DirectionalLayout.backChevronSystemName(
    layoutDirection: localizationController.layoutDirection
)
```

`UITableView` 在方向变化时更新 semantic 和布局，同时保持最上方可见 row 及其相对位置：

```swift
tableView.applyUserInterfaceLayoutDirection(
    localizationController.layoutDirection,
    preservingVisibleRow: true
)
```

该方法不会调用 `reloadData()`。使用 `UITableViewDiffableDataSource` 时，内容刷新仍由
snapshot 管理。例如，可以重新配置当前 item，并在 snapshot 完成后应用方向：

```swift
var snapshot = dataSource.snapshot()
snapshot.reconfigureItems(snapshot.itemIdentifiers)
dataSource.apply(snapshot, animatingDifferences: false) {
    tableView.applyUserInterfaceLayoutDirection(
        localizationController.layoutDirection,
        preservingVisibleRow: true
    )
}
```

如果 snapshot 使用动画或会改变行顺序/高度，应在 completion 中再次调用方向 API，
避免方向布局与 snapshot 更新交叠。

普通 cell 无需实现额外协议：使用 `.unspecified` semantic、leading/trailing 约束或在
布局时读取 `effectiveUserInterfaceLayoutDirection` 即会跟随 table 刷新。只有显式强制
内部方向或缓存方向状态的自定义 cell，才需要实现 `UserInterfaceLayoutDirectionUpdating`。

`UICollectionView` 在方向变化时需要更新 semantic、invalidate layout，并尽量保持逻辑上的可见 item，而不是直接复用旧 `contentOffset`：

```swift
collectionView.applyUserInterfaceLayoutDirection(
    localizationController.layoutDirection,
    preservingVisibleItem: true
)
```

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

## 验证清单

推荐在改动语言切换逻辑后运行：

```sh
swift test
xcodebuild \
  -project Examples/LanguageSwitchingDemo/LanguageSwitchingDemo.xcodeproj \
  -scheme LanguageSwitchingDemo \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

重点回归场景：

- 中文、英文、阿语之间多次随机切换，页面布局不混乱。
- SwiftUI 文案即时刷新。
- UIKit label、button、navigation item、tab item 即时刷新。
- presented 页面和 modal 链路能刷新或被正确重建。
- `UITableView` 切换方向后 cell、header、footer 和当前可见 row 正确。
- `UICollectionView` RTL 下滚动方向、顺序、当前 item 正确。
- LTR/RTL 下导航按钮位置、返回图标、pop 手势方向正确。
- “跟随系统”能解析到最合适的支持语言。
- 应用名本地化资源能在构建产物中生成 `InfoPlist.strings`。
- App Icon asset catalog 能被 Xcode 编译，并包含 light/dark/tinted 三种外观。

## 设计原则

- App 语言是应用状态，不是系统语言。
- 不把 `AppleLanguages` 或 `Bundle.main` swizzling 作为主方案。
- 文案刷新和方向刷新分开处理。
- SwiftUI 依赖环境驱动刷新，UIKit 依赖协议显式重设内容。
- 多窗口按 `UIApplication.shared.connectedScenes` 分发刷新。
- 普通界面可以镜像，空间语义内容需要单独判断。
