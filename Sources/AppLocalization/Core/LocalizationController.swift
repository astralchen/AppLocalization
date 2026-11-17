import Combine
import UIKit

/// 应用语言状态的唯一所有者；窗口协调器在主 actor 上同步执行。
/// 重入请求在当前事务完成后合并执行，最后一个请求生效。
@MainActor
public final class LocalizationController: ObservableObject {
    nonisolated public static let localizationDidChangeNotification = Notification.Name(
        "LocalizationController.localizationDidChange")
    nonisolated public static let localizationChangeUserInfoKey = "LocalizationController.localizationChange"
    nonisolated public static let followSystemLocaleIdentifier = "system"

    /// 资源包声明的可选本地化标识符，排除 Base；按大小写和分隔符等价规则去重。
    /// 顺序来自资源包，不承诺语言选择器的产品展示顺序。
    public let supportedLocalizations: [String]
    /// 无可用语言匹配时使用的资源语言，优先由资源包开发语言解析。
    public let fallbackLocalization: String

    /// 一次发布包含生效语言、选择模式和版本号，避免观察到半更新状态。
    /// @Published 在 willSet 发布；订阅闭包应使用传入的快照，此时 UIKit 事务尚未完成。
    /// 需要完成后的状态与布局时，观察 localizationDidChangeNotification。
    @Published public private(set) var currentSnapshot: LocalizationSnapshot
    public var currentLocale: AppLocale { currentSnapshot.locale }
    public var followsSystemLocale: Bool { currentSnapshot.followsSystemLocale }
    public var locale: Locale { currentLocale.locale }
    public var layoutDirection: UIUserInterfaceLayoutDirection { currentSnapshot.layoutDirection }

    private let preferenceStore: LocalePreferenceStore
    private let notificationCenter: NotificationCenter
    private let systemLocaleIdentifiersProvider: () -> [String]
    // 有序弱引用保留协调器注册顺序，不延长协调器生命周期。
    private let coordinators = NSPointerArray.weakObjects()

    private var isApplying = false
    private var pendingRequest: Request?
    private var pendingSynchronizations: [(LocalizationSnapshot) -> Void] = []

    private struct Request {
        let locale: AppLocale
        let followsSystem: Bool
    }

    /// 默认跟随系统为资源包匹配的 App 语言。
    /// 可注入偏好提供器用于测试或其他明确的 App 语言偏好；可选语言始终来自资源包。
    /// 继续识别原有持久化语言标识符和 "system" 哨兵值。
    /// 可选语言来自 resourceBundle.localizations，排除 Base；回退优先采用开发语言。
    /// 资源包必须声明至少一种语言（包括开发语言），否则触发前置条件失败。
    public init(
        resourceBundle: Bundle = .main,
        preferenceStore: LocalePreferenceStore = UserDefaultsLocalePreferenceStore(),
        notificationCenter: NotificationCenter = .default,
        systemLocaleIdentifiersProvider: (() -> [String])? = nil
    ) {
        var identifiers: [String] = []
        var seen = Set<String>()
        for identifier in resourceBundle.localizations {
            let identifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "_", with: "-")
            let key = AppLocaleIdentifier.normalized(identifier)
            guard !key.isEmpty, key != "base", key != Self.followSystemLocaleIdentifier else { continue }
            if seen.insert(key).inserted { identifiers.append(identifier) }
        }
        let development = resourceBundle.developmentLocalization?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
        // 仅 Base 本地化时，开发语言描述 Base 中的源内容。
        if identifiers.isEmpty, let development, !development.isEmpty,
           !["base", Self.followSystemLocaleIdentifier].contains(development.lowercased()) {
            identifiers.append(development)
        }
        precondition(!identifiers.isEmpty, "The resource bundle must declare a localization or development language.")
        let fallback = development.flatMap { LocaleMatcher.closestSupportedLocale(matching: $0, in: identifiers) }
            ?? resourceBundle.preferredLocalizations.compactMap {
                LocaleMatcher.supportedLocale(matching: $0, in: identifiers)
            }.first
            ?? identifiers[0]
        self.supportedLocalizations = identifiers
        self.fallbackLocalization = fallback
        self.preferenceStore = preferenceStore
        self.notificationCenter = notificationCenter
        let provider = systemLocaleIdentifiersProvider ?? { resourceBundle.preferredLocalizations }
        self.systemLocaleIdentifiersProvider = provider
        let stored = preferenceStore.localeIdentifier
        let followsSystem = stored == nil || stored == Self.followSystemLocaleIdentifier
        let locale =
            followsSystem
            ? LocaleMatcher.resolveSupportedLocale(
                forSystemIdentifiers: provider(), supportedLocales: identifiers, fallbackLocale: fallback
            )
            : stored.flatMap { LocaleMatcher.closestSupportedLocale(matching: $0, in: identifiers) } ?? fallback
        currentSnapshot = LocalizationSnapshot(
            locale: AppLocale(identifier: locale), followsSystemLocale: followsSystem, revision: 0)
    }

    /// 弱引用协调器；重复注册不会重复投递，调用方负责持有协调器。
    /// 投递期间的成员变更从下一次事务开始生效。
    func register(_ coordinator: UIWindowSceneLocalizationCoordinator) {
        coordinators.compact()
        let pointer = Unmanaged.passUnretained(coordinator).toOpaque()
        guard !(0..<coordinators.count).contains(where: { coordinators.pointer(at: $0) == pointer }) else { return }
        coordinators.addPointer(pointer)
    }

    func unregister(_ coordinator: UIWindowSceneLocalizationCoordinator) {
        let pointer = Unmanaged.passUnretained(coordinator).toOpaque()
        for index in (0..<coordinators.count).reversed() {
            if coordinators.pointer(at: index) == nil || coordinators.pointer(at: index) == pointer {
                coordinators.removePointer(at: index)
            }
        }
    }

    /// 界面选择发生变化或接受了延迟请求时返回 true；仅修正持久化偏好时返回 false。
    @discardableResult
    public func setLocale(identifier: String) -> Bool {
        guard let locale = LocaleMatcher.supportedLocale(matching: identifier, in: supportedLocalizations) else {
            return false
        }
        return submit(Request(locale: AppLocale(identifier: locale), followsSystem: false))
    }

    @discardableResult
    public func setFollowsSystemLocale() -> Bool {
        submit(Request(locale: resolvedSystemLocale(), followsSystem: true))
    }

    /// 在应用激活或系统语言来源变化时调用。
    @discardableResult
    public func refreshSystemLocaleIfNeeded() -> Bool {
        guard pendingRequest?.followsSystem ?? followsSystemLocale else { return false }
        return submit(Request(locale: resolvedSystemLocale(), followsSystem: true))
    }

    private func resolvedSystemLocale() -> AppLocale {
        AppLocale(identifier: LocaleMatcher.resolveSupportedLocale(
            forSystemIdentifiers: systemLocaleIdentifiersProvider(), supportedLocales: supportedLocalizations,
            fallbackLocale: fallbackLocalization))
    }

    private func submit(_ request: Request) -> Bool {
        // 即使请求与当前状态相同，也必须替换之前尚未执行的请求。
        if isApplying {
            pendingRequest = request
            return true
        }
        isApplying = true
        defer { isApplying = false }
        pendingRequest = request
        return drain()
    }

    // 注册与激活同步也进入同一队列，避免首次渲染回调重入覆盖新状态。
    func synchronize(_ body: @escaping (LocalizationSnapshot) -> Void) {
        pendingSynchronizations.append(body)
        guard !isApplying else { return }
        isApplying = true
        defer { isApplying = false }
        _ = drain()
    }

    private func drain() -> Bool {
        var changed = false
        while pendingRequest != nil || !pendingSynchronizations.isEmpty {
            guard let request = pendingRequest else {
                let synchronizations = pendingSynchronizations
                pendingSynchronizations.removeAll()
                for synchronize in synchronizations { synchronize(currentSnapshot) }
                continue
            }
            pendingRequest = nil
            let persistedIdentifier = request.followsSystem ? Self.followSystemLocaleIdentifier : request.locale.identifier
            if request.locale != currentLocale || request.followsSystem != followsSystemLocale {
                changed = true
                let update = LocalizationUpdate(
                    snapshot: LocalizationSnapshot(
                        locale: request.locale, followsSystemLocale: request.followsSystem,
                        revision: currentSnapshot.revision + 1
                    ), previousSnapshot: currentSnapshot)
                coordinators.compact()
                // 仅在本轮事务中强持有同一组协调器，阶段内注册／注销不会改变本轮投递。
                let delivery = coordinators.allObjects.compactMap { $0 as? UIWindowSceneLocalizationCoordinator }
                for coordinator in delivery { coordinator.prepareLocalization(update) }
                preferenceStore.saveLocaleIdentifier(persistedIdentifier)
                currentSnapshot = update.snapshot
                for coordinator in delivery { coordinator.applyLocalizationDirection(update) }
                for coordinator in delivery { coordinator.applyLocalization(update) }
                for coordinator in delivery { coordinator.finishLocalization(update) }
                // 通知在事务完成后发送，界面顺序由事务阶段保证。
                notificationCenter.post(
                    name: Self.localizationDidChangeNotification, object: self,
                    userInfo: [Self.localizationChangeUserInfoKey: update])
            } else if preferenceStore.localeIdentifier != persistedIdentifier {
                // 失效或旧格式的持久化偏好仍需修正；仅存储变化不递增版本、不发布 UI 更新。
                preferenceStore.saveLocaleIdentifier(persistedIdentifier)
            }
        }
        return changed
    }
}
