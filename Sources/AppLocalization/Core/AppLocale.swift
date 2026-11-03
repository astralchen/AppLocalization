import Foundation

/// 区域设置标识符的规范化与资源查找规则。
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

    // 显式脚本优先于语言的默认书写方向。
    // 以下从右向左书写的脚本代码依据 Unicode CLDR ScriptMetadata。
    private static let rightToLeftScripts: Set<String> = [
        "adlm", "arab", "armi", "avst", "chrs", "cprt", "elym", "gara",
        "hatr", "hebr", "hung", "khar", "lydi", "mand", "mani", "mend",
        "merc", "mero", "narb", "nbat", "nkoo", "orkh", "ougr", "palm",
        "phli", "phlp", "phnx", "prti", "rohg", "samr", "sarb", "sidt",
        "sogd", "sogo", "syrc", "thaa", "yezi"
    ]

    /// 按从具体到宽泛的顺序返回资源标识符。
    ///
    /// 保留规范大小写和全小写形式，以兼容区分大小写的资源包。
    ///
    /// - Parameter identifier: 要展开的区域设置标识符。
    /// - Returns: 按查找优先级排列的资源标识符。
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

/// 应用界面的水平布局方向。
public enum AppUserInterfaceLayoutDirection: Equatable, Sendable {
    /// 前缘位于左侧的布局方向。
    case leftToRight

    /// 前缘位于右侧的布局方向。
    case rightToLeft
}

/// 应用支持的语言和地区。
///
/// 使用此类型解析显示名称、格式化数值并确定界面布局方向。
/// 选择应用区域设置不会更改系统语言。
public struct AppLocale: Equatable, Hashable, Codable, Sendable {
    /// BCP 47 区域设置标识符，例如 `en-US`、`zh-Hans` 或 `ar`。
    public let identifier: String

    /// 区域设置的回退显示名称。
    ///
    /// 语言选择器应使用 ``nativeDisplayName`` 或 ``localizedDisplayName(preferredBy:)``。
    public let displayName: String

    /// 使用指定标识符和显示名称创建区域设置。
    ///
    /// - Parameters:
    ///   - identifier: BCP 47 区域设置标识符。
    ///   - displayName: 回退显示名称。为 `nil` 时使用 `identifier`。
    public init(identifier: String, displayName: String? = nil) {
        self.identifier = identifier
        self.displayName = displayName ?? identifier
    }

    /// 用于格式化数字、日期和字符串的 Foundation 区域设置。
    public var locale: Locale {
        Locale(identifier: identifier)
    }

    /// 以该区域设置自身语言表示的名称。
    ///
    /// 将此值用作语言选择器的主标题，并使用候选语言自身的布局方向显示，
    /// 不受当前应用方向影响。Foundation 无法解析名称时，返回 ``displayName``。
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

    /// 区域设置标识符中的语言子标签。
    ///
    /// 例如，`en-US` 返回 `en`。此值适用于语言族匹配；界面方向应使用 ``layoutDirection``。
    public var baseLanguageIdentifier: String {
        AppLocaleIdentifier.baseLanguage(of: identifier)
    }

    /// 返回以首选显示语言表示的区域设置名称。
    ///
    /// 两个区域设置属于同一语言族时，使用接收者自身的语言，以保留脚本和地区差异。
    /// 否则依次尝试首选语言、接收者自身的语言和 ``displayName``。
    ///
    /// - Parameter preferredLocale: 显示名称时优先使用的区域设置。
    /// - Returns: 解析后的区域设置名称，或回退显示名称。
    public func localizedDisplayName(preferredBy preferredLocale: AppLocale) -> String {
        let displayLocale = preferredLocale.baseLanguageIdentifier == baseLanguageIdentifier
            ? locale
            : preferredLocale.locale

        return displayLocale.localizedString(forIdentifier: identifier)
            ?? locale.localizedString(forIdentifier: identifier)
            ?? displayName
    }

    /// 由区域设置标识符推导的界面布局方向。
    ///
    /// 显式脚本优先于语言的默认方向。空间内容和播放内容可能需要独立的方向策略。
    public var layoutDirection: AppUserInterfaceLayoutDirection {
        AppLocaleIdentifier.layoutDirection(of: identifier)
    }
}

public extension AppLocale {
    /// 美国英语区域设置。
    static let englishUS = AppLocale(identifier: "en-US", displayName: "English")

    /// 简体中文区域设置。
    static let simplifiedChinese = AppLocale(identifier: "zh-Hans", displayName: "简体中文")

    /// 阿拉伯语区域设置。
    static let arabic = AppLocale(identifier: "ar", displayName: "العربية")
}
