import Foundation

/// 应用内区域设置选择的持久化接口。
///
/// 生产项目可以替换为账号级配置、Keychain、远端配置或测试内存存储。
///
/// 此存储由 `LocalizationController` 在主 actor 上调用，使持久化写入与界面状态更新
/// 保持顺序一致。
@MainActor
public protocol LocalePreferenceStore: AnyObject {
    /// 上次保存的区域设置标识符。
    var localeIdentifier: String? { get }

    /// 保存当前选择的区域设置标识符。
    ///
    /// - Parameter identifier: 要保存的区域设置标识符。
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
    ///   - userDefaults: 用于读写值的 `UserDefaults` 实例。可传入自定义套件以支持
    ///     App Group 或隔离测试数据。
    ///   - key: 保存区域设置标识符的键。
    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "app.locale.identifier"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    /// 从 `UserDefaults` 读取的区域设置标识符。
    public var localeIdentifier: String? {
        userDefaults.string(forKey: key)
    }

    /// 将区域设置标识符写入 `UserDefaults`。
    ///
    /// - Parameter identifier: 要保存的区域设置标识符。
    public func saveLocaleIdentifier(_ identifier: String) {
        userDefaults.set(identifier, forKey: key)
    }
}

/// 测试和预览使用的内存存储。
@MainActor
public final class InMemoryLocalePreferenceStore: LocalePreferenceStore {
    /// 当前保存在内存中的区域设置标识符。
    public private(set) var localeIdentifier: String?

    /// 使用可选的初始区域设置标识符创建内存存储。
    ///
    /// - Parameter localeIdentifier: 初始区域设置标识符。
    public init(localeIdentifier: String? = nil) {
        self.localeIdentifier = localeIdentifier
    }

    /// 将区域设置标识符保存到内存中。
    ///
    /// - Parameter identifier: 要保存的区域设置标识符。
    public func saveLocaleIdentifier(_ identifier: String) {
        localeIdentifier = identifier
    }
}
