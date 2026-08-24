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

## 平台要求

- iOS 15.0 或更高版本
- macOS 12.0 或更高版本（Core/字符串能力）
- Swift 6 strict concurrency

UIKit 实现不依赖 iOS 16+ 的 trait registration API；方向更新全部隔离在 MainActor。

## 核心能力

- 应用内语言切换，不依赖重启 App。
- 使用最新的 `Localizable.xcstrings` 作为文案资源。
- 支持“跟随系统”和显式选择 App 语言。
- 支持当前系统语言与 App 支持语言不完全一致时的合理匹配，例如繁体中文系统优先解析到简体中文。
- SwiftUI 通过 `.locale` 与 `.layoutDirection` 即时刷新。
- UIKit 通过 `UIKitLocalizationApplying` 接收包含 revision 的原子 update，按“方向 → 文案/configuration → 布局缓存”顺序刷新。
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
  UIKit/         原子刷新协议、显式方向策略、注册 Window 协调器和列表适配

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

UIKit 页面实现一次性原子刷新协议。方向目标必须先于文案和 configuration：

```swift
final class SettingsViewController: UIViewController, UIKitLocalizationApplying {
    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        if update.requiresLayoutDirectionRefresh {
            UIViewLayoutDirectionUpdater.apply(
                update,
                to: [
                    UIViewLayoutDirectionTarget(
                        confirmButton,
                        policy: .followApplication
                    )
                ]
            )
        }
        guard update.requiresLocalizedContentRefresh else { return }
        title = resolver.string("settings.title", bundle: .main)
        titleLabel.text = resolver.string("settings.language", bundle: .main)
        confirmButton.setTitle(resolver.string("common.confirm", bundle: .main), for: .normal)
    }
}
```

显式注册应用拥有的 Window；注册时会立即应用最新 snapshot，Scene 再激活时再次同步：

```swift
let coordinator = UIWindowSceneLocalizationCoordinator(
    localizationController: localizationController
)
coordinator.register(window: window)
coordinator.synchronize(window: window)

// notification 中取出 LocalizationChange 后：
coordinator.apply(change)
```

默认注册模式只弱持有显式注册的应用 Window，包括 hidden Window；不会自行枚举键盘、
text-effects 等系统 Window。调用方确认 connected scenes 中的目标 Window 可以安全
更新时，也可以主动选择一次性发现模式：

```swift
coordinator.reloadAllScenes(
    for: change,
    including: { window in
        // 由应用判断这个 Window 是否归自己管理。
        applicationOwns(window)
    }
)
```

`reloadAllScenes` 扫描到的 Window 只参与本次分发，不会自动进入弱注册表。无法原地
更新时可按窗口返回 `.reattachExistingRoot` 或 `.recreateRoot`；未显式注册的 Window
没有 root factory，不能使用 `.recreateRoot`。

### Snapshot、revision 与异步更新

`LocalizationController.currentSnapshot` 同时携带 `locale`、`followsSystemLocale`、
`layoutDirection` 和单调递增的 `revision`。从“跟随系统”切为手动选择时，即使最终
Locale 相同，也会产生新 revision。diffable snapshot、Task、转场 completion 和异步
组件工厂在落地结果前必须比较 revision，或重新读取 `currentSnapshot`，禁止旧结果
覆盖后一次语言方向。

### UIView 方向策略

- `.inherited`：不写 semantic；用于普通 UIView/UILabel 和 leading/trailing 约束。
- `.followApplication`：显式跟随 App snapshot；适合已物化 configured button 等边界。
- `.followContainer`：挂载后读取直接父容器 effective direction；适合可拆卸、重用或跨容器移动的 View。
- `.fixed(...)`：保留 `.playback`、`.spatial` 或固定 LTR/RTL，不参与全局切换。

框架只更新组件显式声明的公开目标，不遍历 UIKit 私有 subtree，也不在运行时调用
`UIView.appearance().semanticContentAttribute`。View 离层期间无需立即刷新；重新加入
层级、离屏测量或重新配置前，由 owner 的 `UIKitLocalizationContext` 重新读取最新
snapshot 并应用目标。

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
tableView.applyLocalization(
    update,
    preservingVisibleRow: true
)
```

该方法不会调用 `reloadData()`。使用 `UITableViewDiffableDataSource` 时，内容刷新仍由
snapshot 管理。例如，可以重新配置当前 item，并在 snapshot 完成后应用方向：

```swift
let expectedRevision = localizationController.currentSnapshot.revision
var snapshot = dataSource.snapshot()
snapshot.reconfigureItems(snapshot.itemIdentifiers)
dataSource.apply(snapshot, animatingDifferences: false) {
    guard expectedRevision == localizationController.currentSnapshot.revision else { return }
    tableView.applyLocalization(
        .initial(snapshot: localizationController.currentSnapshot),
        preservingVisibleRow: true
    )
}
```

如果 snapshot 使用动画或会改变行顺序/高度，应在 completion 中再次调用方向 API，
避免方向布局与 snapshot 更新交叠。

普通 cell 无需实现额外协议：使用 `.unspecified` semantic、leading/trailing 约束或在
布局时读取 `effectiveUserInterfaceLayoutDirection` 即会跟随 table 刷新。只有显式强制
内部方向或缓存方向状态的自定义 cell，才需要实现 `UIKitLocalizationApplying`。

### Reusable View 生命周期

列表 owner 创建一个只保存 provider、不缓存具体 snapshot 的 Context：

```swift
let localizationContext = UIKitLocalizationContext(
    localizationController: localizationController
)
```

Context 在每次 configuration 与 attachment 时重新读取 `currentSnapshot`，因此不会把
创建 Context 时的旧 revision 应用到复用池或离层重挂的实例。

UITableView 使用类型安全的 dequeue 包装，返回 Cell 前先恢复方向，再由业务赋值文案和
configuration：

```swift
let cell: LanguageOptionCell = tableView.dequeueLocalizedReusableCell(
    withIdentifier: LanguageOptionCell.reuseIdentifier,
    for: indexPath,
    using: localizationContext
)
cell.contentConfiguration = makeConfiguration(for: indexPath)

func tableView(
    _ tableView: UITableView,
    willDisplay cell: UITableViewCell,
    forRowAt indexPath: IndexPath
) {
    localizationContext.restoreOnAttachment(cell)
}
```

`UIKitLocalizationContext.makeCellRegistration` 在业务 handler 之前自动恢复最新状态；
handler 的参数类型会推断 Cell 与 Item，业务代码只配置内容和外观，系统
`UICollectionViewListCell` 不需要方向恢复子类：

```swift
let registration = localizationContext.makeCellRegistration(
    handler: cellRegistrationHandler
)

func cellRegistrationHandler(
    cell: UICollectionViewListCell,
    indexPath: IndexPath,
    item: Item
) {
    var configuration = cell.defaultContentConfiguration()
    configuration.text = item.title
    cell.contentConfiguration = configuration
    cell.accessories = [.disclosureIndicator()]
}

func collectionView(
    _ collectionView: UICollectionView,
    willDisplay cell: UICollectionViewCell,
    forItemAt indexPath: IndexPath
) {
    localizationContext.restoreOnAttachment(cell)
}
```

Collection supplementary 使用对称的 registration 包装：

```swift
let headerRegistration: UICollectionView.SupplementaryRegistration<HeaderView> =
    localizationContext.makeSupplementaryRegistration(
        elementKind: UICollectionView.elementKindSectionHeader,
        handler: { header, _, indexPath in
            header.configure(section: indexPath.section)
        }
    )

func collectionView(
    _ collectionView: UICollectionView,
    willDisplaySupplementaryView view: UICollectionReusableView,
    forElementKind elementKind: String,
    at indexPath: IndexPath
) {
    localizationContext.restoreOnAttachment(view)
}
```

Table header/footer 可使用 `dequeueLocalizedReusableHeaderFooterView`。Configuration 与
attachment 恢复都会重新进入公开 content configuration 系统；
`UICollectionViewListCell` accessories 也会通过公开属性重新应用。框架不会遍历 UIKit
私有子树。固定 LTR、`.playback`、`.spatial`、手写 frame、横向滚动或方向缓存仍由业务
组件实现 `UIKitLocalizationApplying` 并声明自己拥有的额外 targets。

`UICollectionView` 在方向变化时需要更新 semantic、invalidate layout，并尽量保持逻辑上的可见 item，而不是直接复用旧 `contentOffset`：

```swift
collectionView.applyLocalization(
    update,
    preservingVisibleItem: true
)
```

如果 UIKit 的内部方向缓存要求业务 owner 局部替换整个 `UICollectionView`，可在旧实例
离层前捕获逻辑可视锚点，并在新实例完成 diffable snapshot、self-sizing、safe area 与
`adjustedContentInset` 布局后恢复：

```swift
let anchor = oldCollectionView.captureLocalizationAnchor()
// Replace the collection view and apply its latest snapshot.
if let anchor {
    newCollectionView.restoreLocalizationAnchor(anchor)
}
```

锚点保存 `IndexPath` 以及 item 到 adjusted viewport 顶部和语义 leading 的距离，不保存
旧的物理 `contentOffset`。因此它可跨 LTR/RTL 和不同 CollectionView 实例重新计算位置，
也不会把位于导航栏或安全区后方的 Cell 错当成顶部可见项。

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
- hidden Window、离层后重新加入、reuse pool 返回和异步新物化内容读取最终 revision。
- `.playback`、`.spatial` 和固定 LTR 控件不被全局方向覆盖。
- LTR/RTL 下导航按钮位置、返回图标、pop 手势方向正确。
- “跟随系统”能解析到最合适的支持语言。
- 应用名本地化资源能在构建产物中生成 `InfoPlist.strings`。
- App Icon asset catalog 能被 Xcode 编译，并包含 light/dark/tinted 三种外观。

## 设计原则

- App 语言是应用状态，不是系统语言。
- 不把 `AppleLanguages` 或 `Bundle.main` swizzling 作为主方案。
- 文案与方向由同一个 snapshot 原子触发，内部严格先方向、后文案/configuration。
- SwiftUI 依赖环境驱动刷新，UIKit 依赖 `UIKitLocalizationApplying` 显式重设内容。
- 多窗口默认只更新应用显式注册的 Window；批量发现必须由调用方显式选择并筛选范围。
- 普通界面可以镜像，空间语义内容需要单独判断。
