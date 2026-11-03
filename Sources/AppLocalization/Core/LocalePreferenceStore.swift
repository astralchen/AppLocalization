import Foundation

/// 存储应用区域设置选择的接口。
///
/// 本地化控制器在主 actor 上访问此存储，使持久化操作与界面更新保持顺序一致。
@MainActor
public protocol LocalePreferenceStore: AnyObject {
    /// 已保存的区域设置标识符；尚未保存选择时为 `nil`。
    ///
    /// 此值可以是 ``LocalizationController/followSystemLocaleIdentifier``，
    /// 表示应用跟随系统语言偏好。
    var localeIdentifier: String? { get }

    /// 保存指定的区域设置选择。
    ///
    /// - Parameter identifier: 要保存的区域设置标识符或跟随系统标识符。
    func saveLocaleIdentifier(_ identifier: String)
}

/// 基于用户默认设置的区域设置存储。
@MainActor
public final class UserDefaultsLocalePreferenceStore: LocalePreferenceStore {
    private let userDefaults: UserDefaults
    private let key: String

    /// 使用指定默认设置数据库和键创建存储。
    ///
    /// - Parameters:
    ///   - userDefaults: 用于读写的默认设置数据库。默认值为 `.standard`。
    ///   - key: 保存区域设置选择的键。默认值为 `app.locale.identifier`。
    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "app.locale.identifier"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    /// 保存在默认设置数据库中的区域设置选择。
    public var localeIdentifier: String? {
        userDefaults.string(forKey: key)
    }

    /// 将区域设置选择保存到默认设置数据库。
    ///
    /// - Parameter identifier: 要保存的区域设置标识符或跟随系统标识符。
    public func saveLocaleIdentifier(_ identifier: String) {
        userDefaults.set(identifier, forKey: key)
    }
}

/// 将区域设置选择保存在内存中的存储。
@MainActor
public final class InMemoryLocalePreferenceStore: LocalePreferenceStore {
    /// 当前保存在内存中的区域设置选择。
    public private(set) var localeIdentifier: String?

    /// 使用可选的初始选择创建内存存储。
    ///
    /// - Parameter localeIdentifier: 初始选择；`nil` 表示尚未保存选择。
    public init(localeIdentifier: String? = nil) {
        self.localeIdentifier = localeIdentifier
    }

    /// 将区域设置选择保存到内存。
    ///
    /// - Parameter identifier: 要保存的区域设置标识符或跟随系统标识符。
    public func saveLocaleIdentifier(_ identifier: String) {
        localeIdentifier = identifier
    }
}
