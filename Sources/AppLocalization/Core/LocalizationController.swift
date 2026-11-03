import Combine
import Foundation

/// 管理应用区域设置选择和本地化状态的对象。
///
/// SwiftUI 可观察此对象，UIKit 可通过变更通知更新内容。
/// 控制器管理应用自身的状态，不修改系统语言，也不替换资源包的查找行为。
@MainActor
public final class LocalizationController: ObservableObject {
    /// 区域设置或选择模式变化后发布的通知。
    ///
    /// 通知的对象为控制器。`userInfo` 字典通过 ``localizationChangeUserInfoKey``
    /// 保存对应的 ``LocalizationChange``。
    nonisolated public static let localizationDidChangeNotification = Notification.Name("LocalizationController.localizationDidChange")

    /// 通知的 `userInfo` 字典中用于保存本地化变更的键。
    nonisolated public static let localizationChangeUserInfoKey = "LocalizationController.localizationChange"

    /// 跟随系统语言偏好时使用的持久化标识符。
    ///
    /// 此值表示选择模式。控制器会先将其解析为受支持的区域设置，再赋给 ``currentLocale``。
    nonisolated public static let followSystemLocaleIdentifier = "system"

    /// 应用中可供选择的区域设置。
    public let supportedLocales: [AppLocale]

    /// 无法解析已存储标识符或系统语言时使用的受支持区域设置。
    public let fallbackLocale: AppLocale

    private let preferenceStore: LocalePreferenceStore
    private let notificationCenter: NotificationCenter
    private let systemLocaleIdentifiersProvider: () -> [String]

    /// 当前在应用内生效的区域设置。
    ///
    /// ``followsSystemLocale`` 为 `true` 时，此值为最符合系统语言偏好的受支持区域设置。
    @Published public private(set) var currentLocale: AppLocale

    /// 指示是否根据系统语言偏好确定区域设置的布尔值。
    ///
    /// 此值用于区分根据系统解析的区域设置与用户明确选择的同一区域设置。
    @Published public private(set) var followsSystemLocale: Bool

    private var revision: UInt64 = 0

    /// 当前本地化状态的不可变快照。
    public var currentSnapshot: LocalizationSnapshot {
        LocalizationSnapshot(
            locale: currentLocale,
            followsSystemLocale: followsSystemLocale,
            revision: revision
        )
    }

    /// 使用受支持的区域设置和偏好存储创建控制器。
    ///
    /// 未保存偏好时选择跟随系统模式。已保存的标识符不受支持时，使用回退区域设置，
    /// 但不启用跟随系统模式。
    ///
    /// - Parameters:
    ///   - supportedLocales: 可供选择的区域设置列表，不得为空。
    ///   - fallbackLocale: 回退区域设置。不受支持时使用列表中的第一项。
    ///   - preferenceStore: 用于读取和持久化选择的存储。
    ///   - notificationCenter: 用于发布变更通知的通知中心。
    ///   - systemLocaleIdentifiersProvider: 按偏好顺序返回系统语言标识符的闭包。
    ///     默认读取 `Locale.preferredLanguages`。
    /// - Precondition: `supportedLocales` 至少包含一个区域设置。
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

    /// 使用提供单个系统语言标识符的闭包创建控制器。
    ///
    /// 需要匹配完整的系统语言偏好列表时，应使用接受 `systemLocaleIdentifiersProvider`
    /// 的初始化方法。
    ///
    /// - Parameters:
    ///   - supportedLocales: 可供选择的区域设置列表，不得为空。
    ///   - fallbackLocale: 回退区域设置。不受支持时使用列表中的第一项。
    ///   - preferenceStore: 用于读取和持久化选择的存储。
    ///   - notificationCenter: 用于发布变更通知的通知中心。
    ///   - systemLocaleIdentifierProvider: 返回系统语言标识符的闭包；不可用时返回 `nil`。
    /// - Precondition: `supportedLocales` 至少包含一个区域设置。
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

    /// 与当前应用区域设置对应的 Foundation 区域设置。
    public var locale: Locale {
        currentLocale.locale
    }

    /// 与当前应用区域设置对应的界面布局方向。
    public var layoutDirection: AppUserInterfaceLayoutDirection {
        currentLocale.layoutDirection
    }

    /// 选择并持久化受支持的区域设置。
    ///
    /// 选择成功后关闭跟随系统模式，并发布变更通知。如果原先处于跟随系统模式，
    /// 即使选择的区域设置与当前相同，也会改变选择状态。
    ///
    /// - Parameter identifier: 受支持区域设置的 BCP 47 标识符。
    /// - Returns: 区域设置或选择模式变化时返回 `true`，否则返回 `false`。
    ///   不受支持的标识符不会改变当前选择。
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

    /// 选择最符合系统语言偏好的受支持区域设置。
    ///
    /// 按系统偏好顺序匹配，先比较完整标识符，再比较语言、脚本和地区。
    /// 没有匹配语言时使用 ``fallbackLocale``。选择变化时持久化结果并发布变更通知。
    ///
    /// - Returns: 区域设置或选择模式变化时返回 `true`，否则返回 `false`。
    @discardableResult
    public func setFollowsSystemLocale() -> Bool {
        let nextLocale = resolvedSystemLocale()
        return updateSelection(
            to: nextLocale,
            followsSystemLocale: true,
            persistedIdentifier: Self.followSystemLocaleIdentifier
        )
    }

    /// 在应用跟随系统语言偏好时刷新生效的区域设置。
    ///
    /// 在应用激活或系统区域设置偏好变化时调用。用户明确选择的应用区域设置保持不变。
    ///
    /// - Returns: 生效的区域设置变化时返回 `true`，否则返回 `false`。
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

        let previousSnapshot = currentSnapshot
        followsSystemLocale = nextFollowsSystemLocale
        currentLocale = nextLocale
        revision &+= 1
        if let persistedIdentifier {
            preferenceStore.saveLocaleIdentifier(persistedIdentifier)
        }
        postChange(from: previousSnapshot, to: currentSnapshot)
        return true
    }

    private func postChange(
        from previous: LocalizationSnapshot,
        to current: LocalizationSnapshot
    ) {
        let change = LocalizationChange(
            previous: previous,
            current: current
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
