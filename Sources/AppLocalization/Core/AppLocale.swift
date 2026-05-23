import Foundation

/// App 内部使用的界面排版方向。
///
/// 这里刻意不直接暴露 UIKit 或 SwiftUI 的方向类型，让 Core 层可以在
/// SwiftPM、测试和非 UIKit 环境中复用。平台相关转换放在 SwiftUI/UIKit
/// adapter 文件里完成。
public enum AppUserInterfaceLayoutDirection: Equatable, Sendable {
    case leftToRight
    case rightToLeft
}

/// App 支持的一种本地化区域设置。
///
/// `AppLocale` 代表“应用内选择的语言/地区”，不是系统语言。它封装了
/// BCP 47 标识符、展示名称、Foundation `Locale`，以及由语言推导出的
/// UI 排版方向。
public struct AppLocale: Equatable, Hashable, Codable, Sendable {
    /// BCP 47 语言标识符，例如 `en-US`、`zh-Hans`、`ar`。
    public let identifier: String

    /// 展示给用户看的名称。生产项目通常可以用本地化后的名称替换。
    public let displayName: String

    /// 创建一个应用内 locale。
    ///
    /// - Parameters:
    ///   - identifier: BCP 47 标识符。
    ///   - displayName: 可选展示名；未传入时使用 `identifier`。
    public init(identifier: String, displayName: String? = nil) {
        self.identifier = identifier
        self.displayName = displayName ?? identifier
    }

    /// Foundation 的 `Locale`，用于数字、日期、字符串格式化等场景。
    public var locale: Locale {
        Locale(identifier: identifier)
    }

    /// 语言自身的稳定显示名。
    ///
    /// 语言选择列表的主标题使用这个值，而不是使用当前 App 语言翻译后的名称。
    /// 这样用户在英文、中文、阿语之间反复切换时，普通语言项仍保持
    /// `English (United States)`、`简体中文`、`العربية` 这类“语言自己的名称”，
    /// 不会因为当前 App 语言变化而跳动。
    ///
    /// Foundation 无法解析自定义 identifier 时，回退到业务配置的 `displayName`。
    ///
    /// ```swift
    /// let title = AppLocale.simplifiedChinese.nativeDisplayName
    /// // title == "简体中文"
    /// ```
    public var nativeDisplayName: String {
        guard
            let resolvedName = locale.localizedString(forIdentifier: identifier),
            !resolvedName.isEmpty,
            resolvedName != identifier
        else {
            return displayName
        }

        return resolvedName
    }

    /// 基础语言标识符。
    ///
    /// 例如 `en-US` 会得到 `en`，`zh-Hans` 会得到 `zh`。判断 RTL/LTR
    /// 时使用基础语言更稳定，因为脚本或地区后缀不一定被底层 API 识别。
    public var baseLanguageIdentifier: String {
        identifier
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map(String.init) ?? identifier
    }

    /// 生成适合当前显示语言的语言名称。
    ///
    /// 语言选择器里的名称不能只用一个写死的 `displayName`：用户当前可能在
    /// 繁体中文、英文、阿语等不同环境下查看语言列表。默认优先用
    /// `preferredLocale` 的语言显示候选语言，方便用户理解。
    ///
    /// 但如果当前语言和候选语言属于同一语言族，只是脚本或地区不同，
    /// 则改用候选语言自身显示。例如繁中用户看到 App 只支持 `zh-Hans` 时，
    /// 显示“简体中文”比显示“簡體中文”更能准确表达实际可选语言。
    /// Foundation 无法解析自定义 identifier 时，最后回退到配置的 `displayName`。
    ///
    /// ```swift
    /// let title = AppLocale.simplifiedChinese.localizedDisplayName(
    ///     preferredBy: AppLocale(identifier: "zh-Hant")
    /// )
    /// // title == "简体中文"
    /// ```
    public func localizedDisplayName(preferredBy preferredLocale: AppLocale) -> String {
        let displayLocale = preferredLocale.baseLanguageIdentifier == baseLanguageIdentifier
            ? locale
            : preferredLocale.locale

        return displayLocale.localizedString(forIdentifier: identifier)
            ?? locale.localizedString(forIdentifier: identifier)
            ?? displayName
    }

    /// 根据语言推导出的界面方向。
    ///
    /// 这只回答“界面 chrome、列表、导航等是否应镜像”。地图、播放进度、
    /// 图表、游戏世界等空间语义内容不一定应该跟随这个方向镜像。
    public var layoutDirection: AppUserInterfaceLayoutDirection {
        let direction = NSLocale.characterDirection(forLanguage: baseLanguageIdentifier)
        return direction == .rightToLeft ? .rightToLeft : .leftToRight
    }
}

public extension AppLocale {
    /// 示例英文 locale。
    static let englishUS = AppLocale(identifier: "en-US", displayName: "English")

    /// 示例简体中文 locale。
    static let simplifiedChinese = AppLocale(identifier: "zh-Hans", displayName: "简体中文")

    /// 示例阿拉伯语 locale，用于覆盖 RTL 场景。
    static let arabic = AppLocale(identifier: "ar", displayName: "العربية")
}
