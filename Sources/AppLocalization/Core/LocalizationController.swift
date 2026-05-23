import Combine
import Foundation

/// 应用内本地化状态的单一事实源。
///
/// `LocalizationController` 只管理 App 自己选择的 locale，不修改系统语言，
/// 也不依赖 `AppleLanguages` 或 Bundle swizzling。SwiftUI 可以观察
/// `currentLocale`，UIKit 则通过通知触发显式刷新。
///
/// 并发边界：语言状态会驱动 `@Published`、UIKit 刷新和 SwiftUI 环境更新，
/// 必须固定在主 actor 上。不要把这个控制器标成 `Sendable` 后跨任务随意修改，
/// 否则容易出现后台线程发布 UI 状态或多次切换时状态交错。
@MainActor
public final class LocalizationController: ObservableObject {
    /// App 内 locale 变化通知。
    ///
    /// UIKit 多窗口刷新通常监听这个通知，然后调用
    /// `UIWindowSceneLocalizationCoordinator.reloadAllScenes(for:)`。
    nonisolated public static let localizationDidChangeNotification = Notification.Name("LocalizationController.localizationDidChange")

    /// 通知 `userInfo` 中保存 `LocalizationChange` 的 key。
    nonisolated public static let localizationChangeUserInfoKey = "LocalizationController.localizationChange"

    /// 持久化“跟随系统”的 sentinel。
    ///
    /// 这不是一个真实语言 identifier，而是一种选择状态。读取到它时，控制器会
    /// 根据系统首选语言解析出 App 实际支持的 `currentLocale`。这样设置页可以显示
    /// “跟随系统”，业务 UI 仍然只面对真实可渲染的 locale。
    nonisolated public static let followSystemLocaleIdentifier = "system"

    /// App 明确支持的 locale 列表。
    public let supportedLocales: [AppLocale]

    /// 存储值不可用或缺失 key 时使用的 fallback locale。
    public let fallbackLocale: AppLocale

    private let preferenceStore: LocalePreferenceStore
    private let notificationCenter: NotificationCenter
    private let systemLocaleIdentifierProvider: () -> String?

    /// 当前 App 内实际生效的 locale。
    ///
    /// 当 `followsSystemLocale == true` 时，这里也不是 sentinel，而是根据系统语言
    /// 映射出来的真实支持语言。例如系统是 `zh-Hant`，App 只支持 `zh-Hans`，
    /// 则 `currentLocale == .simplifiedChinese`。
    @Published public private(set) var currentLocale: AppLocale

    /// 当前设置是否选择了“跟随系统”。
    ///
    /// 这个状态和 `currentLocale` 分开保存，因为“跟随系统解析到简中”和“用户手动
    /// 选择简中”最终文案一样，但设置页的勾选位置不同。
    @Published public private(set) var followsSystemLocale: Bool

    /// 创建本地化控制器。
    ///
    /// - Parameters:
    ///   - supportedLocales: App 可选 locale，不能为空。
    ///   - fallbackLocale: 默认 locale；如果不在支持列表内，会退回到第一个支持项。
    ///   - preferenceStore: locale 持久化实现，默认使用 `UserDefaults`。
    ///   - notificationCenter: 通知中心，测试时可注入独立实例。
    ///   - systemLocaleIdentifierProvider: 系统首选语言 provider，默认读取
    ///     `Locale.preferredLanguages.first`，测试时可注入 `zh-Hant`、`ar-SA` 等场景。
    public init(
        supportedLocales: [AppLocale],
        fallbackLocale: AppLocale,
        preferenceStore: LocalePreferenceStore = UserDefaultsLocalePreferenceStore(),
        notificationCenter: NotificationCenter = .default,
        systemLocaleIdentifierProvider: @escaping () -> String? = { Locale.preferredLanguages.first }
    ) {
        precondition(!supportedLocales.isEmpty, "LocalizationController requires at least one supported locale.")
        self.supportedLocales = supportedLocales
        self.fallbackLocale = supportedLocales.first(where: { $0.identifier == fallbackLocale.identifier }) ?? supportedLocales[0]
        self.preferenceStore = preferenceStore
        self.notificationCenter = notificationCenter
        self.systemLocaleIdentifierProvider = systemLocaleIdentifierProvider

        let storedIdentifier = preferenceStore.localeIdentifier
        if storedIdentifier == Self.followSystemLocaleIdentifier || storedIdentifier == nil {
            followsSystemLocale = true
            currentLocale = Self.resolveSupportedLocale(
                forSystemIdentifier: systemLocaleIdentifierProvider(),
                supportedLocales: supportedLocales,
                fallbackLocale: self.fallbackLocale
            )
        } else if let storedIdentifier,
                  let storedLocale = Self.supportedLocale(
                    matching: storedIdentifier,
                    in: supportedLocales
                  ) {
            followsSystemLocale = false
            currentLocale = storedLocale
        } else {
            followsSystemLocale = false
            currentLocale = self.fallbackLocale
        }
    }

    /// 当前 locale 对应的 Foundation `Locale`。
    ///
    /// SwiftUI root 会把它注入到 `EnvironmentValues.locale`。
    public var locale: Locale {
        currentLocale.locale
    }

    /// 当前 locale 对应的 UI 排版方向。
    ///
    /// 用于 SwiftUI `layoutDirection`、UIKit `semanticContentAttribute`、
    /// 手势方向和自定义导航动画。
    public var layoutDirection: AppUserInterfaceLayoutDirection {
        currentLocale.layoutDirection
    }

    /// 选择一个支持的 locale、持久化，并发布 `LocalizationChange`。
    ///
    /// 在设置页或语言选择器里调用。传入不支持的 identifier，或已经明确选择
    /// 同一个 locale 时会返回 `false`。如果当前是“跟随系统”且解析结果刚好也是
    /// 这个 locale，仍然会返回 `true`，因为设置页的选择状态从“跟随系统”变成了
    /// “手动选择该语言”。
    ///
    /// ```swift
    /// Button("Arabic") {
    ///     localizationController.setLocale(identifier: "ar")
    /// }
    /// ```
    @discardableResult
    public func setLocale(identifier: String) -> Bool {
        guard let nextLocale = Self.supportedLocale(matching: identifier, in: supportedLocales) else {
            return false
        }

        guard followsSystemLocale || nextLocale != currentLocale else {
            return false
        }

        let previousLocale = currentLocale
        followsSystemLocale = false
        currentLocale = nextLocale
        preferenceStore.saveLocaleIdentifier(nextLocale.identifier)
        postChange(from: previousLocale, to: nextLocale)
        return true
    }

    /// 选择“跟随系统”并解析成当前系统下最合适的支持语言。
    ///
    /// 逻辑是：先按完整 identifier 匹配，再按基础语言匹配，最后回退到
    /// `fallbackLocale`。例如系统是 `zh-Hant`，App 只支持 `zh-Hans`，基础语言
    /// 都是 `zh`，因此当前实际 locale 会落到 `zh-Hans`。
    @discardableResult
    public func setFollowsSystemLocale() -> Bool {
        let nextLocale = resolvedSystemLocale()
        guard !followsSystemLocale || nextLocale != currentLocale else {
            return false
        }

        let previousLocale = currentLocale
        followsSystemLocale = true
        currentLocale = nextLocale
        preferenceStore.saveLocaleIdentifier(Self.followSystemLocaleIdentifier)
        postChange(from: previousLocale, to: nextLocale)
        return true
    }

    /// 当 App 已经处于“跟随系统”时，重新读取系统语言并在需要时发布刷新。
    ///
    /// 可在 App 回到前台、收到系统 locale 变化通知，或设置页重新出现时调用。
    /// 如果用户手动选择了某个语言，此方法不会做任何事。
    @discardableResult
    public func refreshSystemLocaleIfNeeded() -> Bool {
        guard followsSystemLocale else { return false }

        let nextLocale = resolvedSystemLocale()
        guard nextLocale != currentLocale else { return false }

        let previousLocale = currentLocale
        currentLocale = nextLocale
        postChange(from: previousLocale, to: nextLocale)
        return true
    }

    private func resolvedSystemLocale() -> AppLocale {
        Self.resolveSupportedLocale(
            forSystemIdentifier: systemLocaleIdentifierProvider(),
            supportedLocales: supportedLocales,
            fallbackLocale: fallbackLocale
        )
    }

    private func postChange(from previousLocale: AppLocale, to currentLocale: AppLocale) {
        let change = LocalizationChange(
            previousLocale: previousLocale,
            currentLocale: currentLocale
        )
        notificationCenter.post(
            name: Self.localizationDidChangeNotification,
            object: self,
            userInfo: [Self.localizationChangeUserInfoKey: change]
        )
    }

    private static func resolveSupportedLocale(
        forSystemIdentifier systemIdentifier: String?,
        supportedLocales: [AppLocale],
        fallbackLocale: AppLocale
    ) -> AppLocale {
        guard let systemIdentifier, !systemIdentifier.isEmpty else {
            return fallbackLocale
        }

        if let exactLocale = supportedLocale(matching: systemIdentifier, in: supportedLocales) {
            return exactLocale
        }

        let systemBaseLanguage = baseLanguageIdentifier(for: systemIdentifier)
        return supportedLocales.first { $0.baseLanguageIdentifier == systemBaseLanguage }
            ?? fallbackLocale
    }

    private static func supportedLocale(
        matching identifier: String,
        in supportedLocales: [AppLocale]
    ) -> AppLocale? {
        let normalizedIdentifier = normalizedLocaleIdentifier(identifier)
        return supportedLocales.first {
            normalizedLocaleIdentifier($0.identifier) == normalizedIdentifier
        }
    }

    private static func normalizedLocaleIdentifier(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    }

    private static func baseLanguageIdentifier(for identifier: String) -> String {
        identifier
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map(String.init) ?? identifier
    }
}
