import Foundation

/// App 内 locale 选择的持久化抽象。
///
/// 生产项目可以替换为账号级配置、Keychain、远端配置或测试内存存储。
///
/// 并发边界：这个 store 由 `LocalizationController` 调用，和语言 UI 状态一起
/// 放在主 actor 上。这样 `UserDefaults` 写入、内存测试 store 修改和 `@Published`
/// 更新保持顺序一致，避免后台任务和 UI 切换同时写入不同语言。
@MainActor
public protocol LocalePreferenceStore: AnyObject {
    /// 上次保存的 locale identifier。
    var localeIdentifier: String? { get }

    /// 保存当前选择的 locale identifier。
    func saveLocaleIdentifier(_ identifier: String)
}

/// 基于 `UserDefaults` 的默认持久化实现。
@MainActor
public final class UserDefaultsLocalePreferenceStore: LocalePreferenceStore {
    private let userDefaults: UserDefaults
    private let key: String

    /// 创建 `UserDefaults` 存储。
    ///
    /// - Parameters:
    ///   - userDefaults: 可注入 suite，便于 App Group 或测试隔离。
    ///   - key: 保存 locale identifier 的键。
    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "app.locale.identifier"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    /// 从 `UserDefaults` 读取 locale identifier。
    public var localeIdentifier: String? {
        userDefaults.string(forKey: key)
    }

    /// 写入 locale identifier。
    public func saveLocaleIdentifier(_ identifier: String) {
        userDefaults.set(identifier, forKey: key)
    }
}

/// 测试和预览使用的内存存储。
@MainActor
public final class InMemoryLocalePreferenceStore: LocalePreferenceStore {
    /// 当前内存中的 locale identifier。
    public private(set) var localeIdentifier: String?

    /// 创建内存存储，可指定初始 identifier。
    public init(localeIdentifier: String? = nil) {
        self.localeIdentifier = localeIdentifier
    }

    /// 保存到内存字段，不触碰磁盘。
    public func saveLocaleIdentifier(_ identifier: String) {
        localeIdentifier = identifier
    }
}
