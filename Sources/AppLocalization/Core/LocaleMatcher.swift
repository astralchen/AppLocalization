import Foundation

// 语言匹配独立于偏好存储和界面投递。
enum LocaleMatcher {
    static func resolveSupportedLocale(
        forSystemIdentifiers systemIdentifiers: [String],
        supportedLocales: [String],
        fallbackLocale: String
    ) -> String {
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

    static func closestSupportedLocale(
        matching identifier: String,
        in supportedLocales: [String]
    ) -> String? {
        guard !AppLocaleIdentifier.normalized(identifier).isEmpty else {
            return nil
        }

        if let exactLocale = supportedLocale(matching: identifier, in: supportedLocales) {
            return exactLocale
        }

        let language = AppLocaleIdentifier.baseLanguage(of: identifier)
        guard !language.isEmpty else { return nil }

        // 先限定同一语言族，避免首个不支持的偏好抢占后续可用语言。
        let candidates = supportedLocales.filter {
            AppLocaleIdentifier.baseLanguage(of: $0) == language
        }
        guard !candidates.isEmpty else { return nil }
        // Foundation 负责地区隐含脚本，例如 zh-TW 与 zh-Hant 的匹配。
        let preferred = Bundle.preferredLocalizations(
            from: candidates, forPreferences: [identifier]
        ).first
        return preferred.flatMap { supportedLocale(matching: $0, in: candidates) } ?? candidates.first
    }

    static func supportedLocale(
        matching identifier: String,
        in supportedLocales: [String]
    ) -> String? {
        let normalizedIdentifier = AppLocaleIdentifier.normalized(identifier)
        return supportedLocales.first {
            AppLocaleIdentifier.normalized($0) == normalizedIdentifier
        }
    }
}
