import Foundation

/// 区域设置标识符的内部规范化与回退规则。
enum AppLocaleIdentifier {
    struct Components {
        let language: String
        let script: String?
        let region: String?
    }

    static func normalized(_ identifier: String) -> String {
        identifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
    }

    static func components(of identifier: String) -> Components? {
        let subtags = normalized(identifier)
            .split(separator: "-")
            .map(String.init)

        guard let language = subtags.first, !language.isEmpty else {
            return nil
        }

        let remainingSubtags = subtags.dropFirst()
        let script = remainingSubtags.first {
            $0.count == 4 && $0.allSatisfy(\.isLetter)
        }
        let region = remainingSubtags.first {
            ($0.count == 2 && $0.allSatisfy(\.isLetter))
                || ($0.count == 3 && $0.allSatisfy(\.isNumber))
        }

        return Components(language: language, script: script, region: region)
    }

    static func baseLanguage(of identifier: String) -> String {
        components(of: identifier)?.language ?? normalized(identifier)
    }

    static func layoutDirection(of identifier: String) -> AppUserInterfaceLayoutDirection {
        if let script = components(of: identifier)?.script {
            return rightToLeftScripts.contains(script) ? .rightToLeft : .leftToRight
        }

        let languageIdentifier = identifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
        let direction = NSLocale.characterDirection(forLanguage: languageIdentifier)
        return direction == .rightToLeft ? .rightToLeft : .leftToRight
    }

    // 下列脚本在 Unicode CLDR ScriptMetadata 中标记为从右向左书写。
    // 显式脚本必须优先于语言的默认脚本。例如，`az-Arab` 从右向左书写，
    // 而 `ar-Latn` 从左向右书写。
    private static let rightToLeftScripts: Set<String> = [
        "adlm", "arab", "armi", "avst", "chrs", "cprt", "elym", "gara",
        "hatr", "hebr", "hung", "khar", "lydi", "mand", "mani", "mend",
        "merc", "mero", "narb", "nbat", "nkoo", "orkh", "ougr", "palm",
        "phli", "phlp", "phnx", "prti", "rohg", "samr", "sarb", "sidt",
        "sogd", "sogo", "syrc", "thaa", "yezi"
    ]

    /// 按从最具体到最宽泛的顺序生成资源查找标识符。
    ///
    /// `zh_Hant_HK` 会生成 `zh-Hant-HK`、`zh-Hant` 和 `zh` 等候选项。
    /// 同时保留规范大小写和全小写形式，以兼容区分大小写的资源包。
    ///
    /// - Parameter identifier: 要展开的区域设置标识符。
    /// - Returns: 按资源查找优先级排列的标识符。
    static func resourceLookupIdentifiers(for identifier: String) -> [String] {
        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let hyphenatedIdentifier = trimmedIdentifier.replacingOccurrences(of: "_", with: "-")
        let normalizedIdentifier = normalized(hyphenatedIdentifier)
        var identifiers: [String] = []

        append(trimmedIdentifier, to: &identifiers)
        append(hyphenatedIdentifier, to: &identifiers)

        var subtags = normalizedIdentifier.split(separator: "-").map(String.init)
        while !subtags.isEmpty {
            append(canonicalIdentifier(from: subtags), to: &identifiers)
            append(subtags.joined(separator: "-"), to: &identifiers)
            subtags.removeLast()
        }

        return identifiers
    }

    private static func canonicalIdentifier(from subtags: [String]) -> String {
        subtags.enumerated().map { index, subtag in
            if index == 0 {
                return subtag.lowercased()
            }
            if subtag.count == 4 && subtag.allSatisfy(\.isLetter) {
                return subtag.prefix(1).uppercased() + subtag.dropFirst().lowercased()
            }
            if subtag.count == 2 && subtag.allSatisfy(\.isLetter) {
                return subtag.uppercased()
            }
            return subtag.lowercased()
        }
        .joined(separator: "-")
    }

    private static func append(_ identifier: String, to identifiers: inout [String]) {
        guard !identifier.isEmpty, !identifiers.contains(identifier) else {
            return
        }
        identifiers.append(identifier)
    }
}

/// 应用内部使用的界面布局方向。
///
/// 此类型不依赖 UIKit 或 SwiftUI，因此可用于 Swift Package、测试及非 UIKit 环境。
/// 平台类型之间的转换由对应的 SwiftUI 和 UIKit 适配器提供。
public enum AppUserInterfaceLayoutDirection: Equatable, Sendable {
    /// 从左向右布局。
    case leftToRight

    /// 从右向左布局。
    case rightToLeft
}

/// 应用支持的一种本地化区域设置。
///
/// `AppLocale` 表示应用内选择的语言和地区，不会更改系统语言。该类型包含
/// BCP 47 标识符、显示名称、Foundation `Locale`，以及由标识符推导的布局方向。
public struct AppLocale: Equatable, Hashable, Codable, Sendable {
    /// BCP 47 语言标识符，例如 `en-US`、`zh-Hans`、`ar`。
    public let identifier: String

    /// 向用户显示的配置名称。
    ///
    /// 此值主要用于自定义标识符的回退显示。语言选择器通常应使用
    /// ``nativeDisplayName`` 或 ``localizedDisplayName(preferredBy:)``。
    public let displayName: String

    /// 创建应用内区域设置。
    ///
    /// - Parameters:
    ///   - identifier: BCP 47 标识符。
    ///   - displayName: 可选的显示名称。省略时使用 `identifier`。
    public init(identifier: String, displayName: String? = nil) {
        self.identifier = identifier
        self.displayName = displayName ?? identifier
    }

    /// 与标识符对应的 Foundation `Locale`。
    ///
    /// 使用此值格式化数字、日期和字符串。
    public var locale: Locale {
        Locale(identifier: identifier)
    }

    /// 使用该语言自身表示的稳定显示名称。
    ///
    /// 语言选择列表的主标题应使用此值，而不是使用当前应用语言翻译后的名称。
    /// 因此，当用户在英文、中文、阿拉伯文之间切换时，各语言项仍保持
    /// `English (United States)`、`简体中文`、`العربية` 这类“语言自己的名称”，
    /// 不会随当前应用语言变化。
    ///
    /// 当 Foundation 无法解析自定义标识符时，此属性返回 ``displayName``。
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
    /// 例如 `en-US` 会得到 `en`，`zh-Hans` 会得到 `zh`。该值用于语言族匹配；
    /// 排版方向仍需保留显式脚本和地区信息。
    public var baseLanguageIdentifier: String {
        AppLocaleIdentifier.baseLanguage(of: identifier)
    }

    /// 返回适合指定显示语言的语言名称。
    ///
    /// 默认使用 `preferredLocale` 的语言显示接收者，以便用户理解候选语言。
    ///
    /// 但如果当前语言和候选语言属于同一语言族，只是脚本或地区不同，
    /// 则改用候选语言自身显示。例如，应用仅支持 `zh-Hans` 时，繁体中文用户看到
    /// “简体中文”比“簡體中文”更能准确表达实际可选语言。
    /// 当 Foundation 无法解析自定义标识符时，此方法返回 ``displayName``。
    ///
    /// ```swift
    /// let title = AppLocale.simplifiedChinese.localizedDisplayName(
    ///     preferredBy: AppLocale(identifier: "zh-Hant")
    /// )
    /// // title == "简体中文"
    /// ```
    ///
    /// - Parameter preferredLocale: 用于显示名称的首选区域设置。
    /// - Returns: 本地化后的语言名称；无法解析时返回 ``displayName``。
    public func localizedDisplayName(preferredBy preferredLocale: AppLocale) -> String {
        let displayLocale = preferredLocale.baseLanguageIdentifier == baseLanguageIdentifier
            ? locale
            : preferredLocale.locale

        return displayLocale.localizedString(forIdentifier: identifier)
            ?? locale.localizedString(forIdentifier: identifier)
            ?? displayName
    }

    /// 根据语言、显式脚本和地区推导的界面布局方向。
    ///
    /// 此值仅表示界面控件、列表和导航等是否应镜像。地图、播放进度、
    /// 图表、游戏世界等空间语义内容不一定应该跟随这个方向镜像。
    public var layoutDirection: AppUserInterfaceLayoutDirection {
        AppLocaleIdentifier.layoutDirection(of: identifier)
    }
}

public extension AppLocale {
    /// 预置的美国英语区域设置。
    static let englishUS = AppLocale(identifier: "en-US", displayName: "English")

    /// 预置的简体中文区域设置。
    static let simplifiedChinese = AppLocale(identifier: "zh-Hans", displayName: "简体中文")

    /// 预置的阿拉伯文区域设置，用于覆盖从右向左布局场景。
    static let arabic = AppLocale(identifier: "ar", displayName: "العربية")
}
