import Combine
import Foundation

/// 应用内本地化状态的单一事实源。
///
/// `LocalizationController` 仅管理应用选择的区域设置，不修改系统语言，也不依赖
/// `AppleLanguages` 或 `Bundle` 方法交换。SwiftUI 可观察 ``currentLocale``，
/// UIKit 则通过通知触发显式刷新。
///
/// 语言状态会驱动 `@Published`、UIKit 刷新和 SwiftUI 环境更新，因此控制器隔离在
/// 主 actor 上。
@MainActor
public final class LocalizationController: ObservableObject {
    /// 应用内区域设置发生变化时发布的通知。
    ///
    /// UIKit 多窗口刷新通常监听这个通知，然后调用
    /// `UIWindowSceneLocalizationCoordinator.reloadAllScenes(for:)`。
    nonisolated public static let localizationDidChangeNotification = Notification.Name("LocalizationController.localizationDidChange")

    /// 通知 `userInfo` 中用于保存 `LocalizationChange` 的键。
    nonisolated public static let localizationChangeUserInfoKey = "LocalizationController.localizationChange"

    /// 表示“跟随系统”设置状态的持久化标识符。
    ///
    /// 此值不是实际的语言标识符。读取到此值时，控制器会根据系统首选语言解析应用
    /// 实际支持的 ``currentLocale``。设置界面可据此显示“跟随系统”，其他界面则始终
    /// 使用可渲染的区域设置。
    nonisolated public static let followSystemLocaleIdentifier = "system"

    /// 应用明确支持的区域设置列表。
    public let supportedLocales: [AppLocale]

    /// 无法使用持久化值或缺少翻译时采用的回退区域设置。
    public let fallbackLocale: AppLocale

    private let preferenceStore: LocalePreferenceStore
    private let notificationCenter: NotificationCenter
    private let systemLocaleIdentifiersProvider: () -> [String]

    /// 当前在应用内生效的区域设置。
    ///
    /// 当 ``followsSystemLocale`` 为 `true` 时，此属性仍保存根据系统语言映射出的
    /// 受支持区域设置。例如，系统使用 `zh-Hant`，而应用仅支持 `zh-Hans`，
    /// 则 `currentLocale == .simplifiedChinese`。
    @Published public private(set) var currentLocale: AppLocale

    /// 当前设置是否选择了“跟随系统”。
    ///
    /// 这个状态和 `currentLocale` 分开保存，因为“跟随系统解析到简中”和“用户手动
    /// 选择简中”最终文案一样，但设置页的勾选位置不同。
    @Published public private(set) var followsSystemLocale: Bool

    /// 使用受支持的区域设置创建本地化控制器。
    ///
    /// - Parameters:
    ///   - supportedLocales: 应用可选择的区域设置。此数组不能为空。
    ///   - fallbackLocale: 默认区域设置。不在支持列表中时使用第一项。
    ///   - preferenceStore: 区域设置的持久化实现。默认使用 `UserDefaults`。
    ///   - notificationCenter: 通知中心，测试时可注入独立实例。
    ///   - systemLocaleIdentifiersProvider: 返回系统首选语言标识符的闭包。默认读取
    ///     `Locale.preferredLanguages`。
    ///
    /// - Precondition: `supportedLocales` 至少包含一个元素。
    public init(
        supportedLocales: [AppLocale],
        fallbackLocale: AppLocale,
        preferenceStore: LocalePreferenceStore = UserDefaultsLocalePreferenceStore(),
        notificationCenter: NotificationCenter = .default,
        systemLocaleIdentifiersProvider: @escaping () -> [String] = { Locale.preferredLanguages }
    ) {
        precondition(!supportedLocales.isEmpty, "LocalizationController requires at least one supported locale.")
        self.supportedLocales = supportedLocales
        self.fallbackLocale = Self.supportedLocale(
            matching: fallbackLocale.identifier,
            in: supportedLocales
        ) ?? supportedLocales[0]
        self.preferenceStore = preferenceStore
        self.notificationCenter = notificationCenter
        self.systemLocaleIdentifiersProvider = systemLocaleIdentifiersProvider

        let storedIdentifier = preferenceStore.localeIdentifier
        if storedIdentifier == Self.followSystemLocaleIdentifier || storedIdentifier == nil {
            followsSystemLocale = true
            currentLocale = Self.resolveSupportedLocale(
                forSystemIdentifiers: systemLocaleIdentifiersProvider(),
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

    /// 使用单个系统语言提供闭包创建本地化控制器。
    ///
    /// - Parameters:
    ///   - supportedLocales: 应用可选择的区域设置。此数组不能为空。
    ///   - fallbackLocale: 默认区域设置。不在支持列表中时使用第一项。
    ///   - preferenceStore: 区域设置的持久化实现。
    ///   - notificationCenter: 用于发布变更通知的通知中心。
    ///   - systemLocaleIdentifierProvider: 返回单个系统语言标识符的闭包。
    ///
    /// - Important: 新代码应优先使用接受 `systemLocaleIdentifiersProvider` 的初始化方法，
    ///   以便在首选语言不受支持时继续检查后续系统语言偏好。
    /// - Precondition: `supportedLocales` 至少包含一个元素。
    public convenience init(
        supportedLocales: [AppLocale],
        fallbackLocale: AppLocale,
        preferenceStore: LocalePreferenceStore = UserDefaultsLocalePreferenceStore(),
        notificationCenter: NotificationCenter = .default,
        systemLocaleIdentifierProvider: @escaping () -> String?
    ) {
        self.init(
            supportedLocales: supportedLocales,
            fallbackLocale: fallbackLocale,
            preferenceStore: preferenceStore,
            notificationCenter: notificationCenter,
            systemLocaleIdentifiersProvider: {
                systemLocaleIdentifierProvider().map { [$0] } ?? []
            }
        )
    }

    /// 与当前区域设置对应的 Foundation `Locale`。
    ///
    /// SwiftUI 根视图会将此值注入 `EnvironmentValues.locale`。
    public var locale: Locale {
        currentLocale.locale
    }

    /// 与当前区域设置对应的界面布局方向。
    ///
    /// 用于 SwiftUI `layoutDirection`、UIKit `semanticContentAttribute`、
    /// 手势方向和自定义导航动画。
    public var layoutDirection: AppUserInterfaceLayoutDirection {
        currentLocale.layoutDirection
    }

    /// 选择并持久化受支持的区域设置，然后发布 `LocalizationChange`。
    ///
    /// 传入不受支持的标识符，或已经明确选择同一区域设置时，此方法返回 `false`。
    /// 如果当前为“跟随系统”，即使解析结果与目标区域设置相同，此方法仍返回 `true`，
    /// 因为选择状态已变为手动选择。
    ///
    /// ```swift
    /// Button("Arabic") {
    ///     localizationController.setLocale(identifier: "ar")
    /// }
    /// ```
    ///
    /// - Parameter identifier: 要选择的 BCP 47 区域设置标识符。
    /// - Returns: 选择状态发生变化时为 `true`；否则为 `false`。
    @discardableResult
    public func setLocale(identifier: String) -> Bool {
        guard let nextLocale = Self.supportedLocale(matching: identifier, in: supportedLocales) else {
            return false
        }

        return updateSelection(
            to: nextLocale,
            followsSystemLocale: false,
            persistedIdentifier: nextLocale.identifier
        )
    }

    /// 选择“跟随系统”并解析成当前系统下最合适的支持语言。
    ///
    /// 控制器按系统语言偏好顺序逐项查找：先匹配完整标识符，再比较语言、脚本和
    /// 地区，最后回退到 ``fallbackLocale``。例如，系统使用 `zh-Hant`，而应用仅支持
    /// `zh-Hans`，则当前区域设置会解析为 `zh-Hans`。
    ///
    /// - Returns: 选择状态或当前区域设置发生变化时为 `true`；否则为 `false`。
    @discardableResult
    public func setFollowsSystemLocale() -> Bool {
        let nextLocale = resolvedSystemLocale()
        return updateSelection(
            to: nextLocale,
            followsSystemLocale: true,
            persistedIdentifier: Self.followSystemLocaleIdentifier
        )
    }

    /// 在应用跟随系统时重新读取系统语言，并按需发布变更。
    ///
    /// 可在应用进入前台、收到系统区域设置变更通知或设置界面重新出现时调用。
    /// 如果用户手动选择了某个语言，此方法不会做任何事。
    ///
    /// - Returns: 当前区域设置发生变化时为 `true`；否则为 `false`。
    @discardableResult
    public func refreshSystemLocaleIfNeeded() -> Bool {
        guard followsSystemLocale else { return false }

        let nextLocale = resolvedSystemLocale()
        guard nextLocale != currentLocale else { return false }

        return updateSelection(
            to: nextLocale,
            followsSystemLocale: true,
            persistedIdentifier: nil
        )
    }

    private func resolvedSystemLocale() -> AppLocale {
        Self.resolveSupportedLocale(
            forSystemIdentifiers: systemLocaleIdentifiersProvider(),
            supportedLocales: supportedLocales,
            fallbackLocale: fallbackLocale
        )
    }

    private func updateSelection(
        to nextLocale: AppLocale,
        followsSystemLocale nextFollowsSystemLocale: Bool,
        persistedIdentifier: String?
    ) -> Bool {
        guard followsSystemLocale != nextFollowsSystemLocale || currentLocale != nextLocale else {
            return false
        }

        let previousLocale = currentLocale
        followsSystemLocale = nextFollowsSystemLocale
        currentLocale = nextLocale
        if let persistedIdentifier {
            preferenceStore.saveLocaleIdentifier(persistedIdentifier)
        }
        postChange(from: previousLocale, to: nextLocale)
        return true
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
        forSystemIdentifiers systemIdentifiers: [String],
        supportedLocales: [AppLocale],
        fallbackLocale: AppLocale
    ) -> AppLocale {
        for systemIdentifier in systemIdentifiers {
            if let supportedLocale = closestSupportedLocale(
                matching: systemIdentifier,
                in: supportedLocales
            ) {
                return supportedLocale
            }
        }

        return fallbackLocale
    }

    private static func closestSupportedLocale(
        matching identifier: String,
        in supportedLocales: [AppLocale]
    ) -> AppLocale? {
        guard !AppLocaleIdentifier.normalized(identifier).isEmpty else {
            return nil
        }

        if let exactLocale = supportedLocale(matching: identifier, in: supportedLocales) {
            return exactLocale
        }

        guard let preferredComponents = AppLocaleIdentifier.components(of: identifier) else {
            return nil
        }

        var bestMatch: (locale: AppLocale, score: Int)?
        for locale in supportedLocales {
            guard let components = AppLocaleIdentifier.components(of: locale.identifier),
                  components.language == preferredComponents.language else {
                continue
            }

            var score = 0
            if let preferredScript = preferredComponents.script {
                if components.script == preferredScript {
                    score += 4
                } else if components.script != nil {
                    score -= 4
                }
            }
            if let preferredRegion = preferredComponents.region {
                if components.region == preferredRegion {
                    score += 2
                } else if components.region != nil {
                    score -= 1
                }
            }

            if let existingMatch = bestMatch, score <= existingMatch.score {
                continue
            }
            bestMatch = (locale, score)
        }

        return bestMatch?.locale
    }

    private static func supportedLocale(
        matching identifier: String,
        in supportedLocales: [AppLocale]
    ) -> AppLocale? {
        let normalizedIdentifier = AppLocaleIdentifier.normalized(identifier)
        return supportedLocales.first {
            AppLocaleIdentifier.normalized($0.identifier) == normalizedIdentifier
        }
    }
}
