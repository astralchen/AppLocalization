import Foundation

/// 统一的本地化字符串解析器。
    ///
/// UIKit 文本、命令式更新的文本，以及需要指定应用内区域设置的 SwiftUI 文本，
/// 均可使用此类型解析。
///
/// 解析器在每次查询时调用 `localeProvider`。由于该闭包通常访问
/// `LocalizationController.currentLocale`，解析器隔离在主 actor 上。
///
/// 解析器支持以下资源和回退行为：
///
/// - 已编译的 `.lproj/Localizable.strings`。
/// - 源文件形式的 `Localizable.xcstrings`，用于 Swift Package 测试。
/// - 回退区域设置。
/// - 缺失键日志或断言。
@MainActor
public final class LocalizedStringResolver {
    /// 找不到本地化键时调用的处理闭包。
    ///
    /// 生产环境可使用该闭包上报日志；调试环境可调用 `assertionFailure`。
    public typealias MissingKeyHandler = @MainActor (_ key: String, _ locale: AppLocale, _ bundle: Bundle) -> Void

    private let localeProvider: @MainActor () -> AppLocale
    private let fallbackLocale: AppLocale
    private let missingKeyHandler: MissingKeyHandler
    private var catalogCache: [URL: CachedStringCatalog] = [:]
    private var localizedBundleCache: [LocalizedBundleCacheKey: CachedLocalizedBundle] = [:]

    /// 创建字符串解析器。
    ///
    /// - Parameters:
    ///   - localeProvider: 返回当前区域设置的闭包。解析器会在每次查询时调用此闭包。
    ///   - fallbackLocale: 当前区域设置缺少指定键时采用的回退区域设置。
    ///   - missingKeyHandler: 当前区域设置和回退区域设置均缺少指定键时调用的闭包。
    public init(
        localeProvider: @escaping @MainActor () -> AppLocale,
        fallbackLocale: AppLocale = .englishUS,
        missingKeyHandler: @escaping MissingKeyHandler = { _, _, _ in }
    ) {
        self.localeProvider = localeProvider
        self.fallbackLocale = fallbackLocale
        self.missingKeyHandler = missingKeyHandler
    }

    /// 使用当前应用区域设置解析本地化字符串。
///
    /// UIKit 文本可统一使用此方法。SwiftUI 文本需要跟随应用区域设置而非系统区域
    /// 设置时，也可在 `body` 中调用此方法。解析框架或 Swift Package 中的资源时，
    /// 请传入资源所属的 `Bundle`。
    ///
    /// ```swift
    /// titleLabel.text = resolver.string(
    ///     "settings.language.title",
    ///     bundle: .main
    /// )
    ///
    /// countLabel.text = resolver.string(
    ///     "cart.count",
    ///     bundle: .main,
    ///     arguments: [items.count]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - key: 本地化资源中的键。
    ///   - table: 包含该键的字符串表名称。省略时使用 `Localizable`。
    ///   - bundle: 包含本地化资源的资源包。
    ///   - arguments: 应用于格式字符串的参数。
    ///   - fallbackValue: 所有本地化资源均缺少指定键时使用的值。
    /// - Returns: 解析并格式化后的字符串。没有匹配资源或回退值时返回 `key`。
    public func string(
        _ key: String,
        table: String? = nil,
        bundle: Bundle = .main,
        arguments: [CVarArg] = [],
        fallbackValue: String? = nil
    ) -> String {
        let currentLocale = localeProvider()
        var format = localizedFormat(
            key,
            locale: currentLocale,
            table: table,
            bundle: bundle
        ) ?? stringCatalogFormat(
            key,
            locale: currentLocale,
            table: table,
            bundle: bundle
        )

        if format == nil,
           AppLocaleIdentifier.normalized(currentLocale.identifier)
            != AppLocaleIdentifier.normalized(fallbackLocale.identifier) {
            format = localizedFormat(
                key,
                locale: fallbackLocale,
                table: table,
                bundle: bundle
            ) ?? stringCatalogFormat(
                key,
                locale: fallbackLocale,
                table: table,
                bundle: bundle
            )
        }

        format = format ?? localizedFormat(
            key,
            resourceIdentifiers: ["Base"],
            table: table,
            bundle: bundle
        ) ?? stringCatalogSourceFormat(
            key,
            table: table,
            bundle: bundle
        ) ?? fallbackValue

        guard let format else {
            missingKeyHandler(key, currentLocale, bundle)
            return key
        }

        guard !arguments.isEmpty else {
            return format
        }

        return String(format: format, locale: currentLocale.locale, arguments: arguments)
    }

    /// 从编译后的 `.lproj` 资源包中查找字符串。
    ///
    /// Xcode 会将字符串目录编译为各语言的 `.strings` 文件；正式应用
    /// 运行时大多数情况会命中这条路径。
    private func localizedFormat(
        _ key: String,
        locale: AppLocale,
        table: String?,
        bundle: Bundle
    ) -> String? {
        localizedFormat(
            key,
            resourceIdentifiers: AppLocaleIdentifier.resourceLookupIdentifiers(
                for: locale.identifier
            ),
            table: table,
            bundle: bundle
        )
    }

    private func localizedFormat(
        _ key: String,
        resourceIdentifiers: [String],
        table: String?,
        bundle: Bundle
    ) -> String? {
        let missingValue = "\u{0}AppLocalization.missing:\(key)"
        for identifier in resourceIdentifiers {
            guard let localizedBundle = localizedBundle(
                identifier: identifier,
                in: bundle
            ) else {
                continue
            }

            let value = localizedBundle.localizedString(
                forKey: key,
                value: missingValue,
                table: table
            )
            if value != missingValue {
                return value
            }
        }

        return nil
    }

    private func localizedBundle(identifier: String, in bundle: Bundle) -> Bundle? {
        let cacheKey = LocalizedBundleCacheKey(
            bundleURL: bundle.bundleURL,
            identifier: identifier
        )
        if let cachedBundle = localizedBundleCache[cacheKey] {
            switch cachedBundle {
            case .available(let bundle):
                return bundle
            case .unavailable:
                return nil
            }
        }

        guard let path = bundle.path(forResource: identifier, ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else {
            localizedBundleCache[cacheKey] = .unavailable
            return nil
        }

        localizedBundleCache[cacheKey] = .available(localizedBundle)
        return localizedBundle
    }

    /// 从源文件形式的 `.xcstrings` 中查找字符串。
    ///
    /// 此路径主要用于 Swift Package 测试和直接将字符串目录作为资源处理的场景。
    /// 真机应用构建后，字符串目录通常会由 Xcode 编译为 `.lproj/Localizable.strings`。
    private func stringCatalogFormat(
        _ key: String,
        locale: AppLocale,
        table: String?,
        bundle: Bundle
    ) -> String? {
        guard let catalog = stringCatalog(table: table, bundle: bundle),
              let entry = catalog.strings[key] else {
            return nil
        }

        return localizedValue(
            in: entry,
            identifiers: AppLocaleIdentifier.resourceLookupIdentifiers(
                for: locale.identifier
            )
        )
    }

    private func stringCatalogSourceFormat(
        _ key: String,
        table: String?,
        bundle: Bundle
    ) -> String? {
        guard let catalog = stringCatalog(table: table, bundle: bundle),
              let sourceLanguage = catalog.sourceLanguage,
              let entry = catalog.strings[key] else {
            return nil
        }

        return localizedValue(
            in: entry,
            identifiers: AppLocaleIdentifier.resourceLookupIdentifiers(
                for: sourceLanguage
            )
        )
    }

    private func localizedValue(
        in entry: StringCatalogEntry,
        identifiers: [String]
    ) -> String? {
        guard let localizations = entry.localizations else {
            return nil
        }

        for identifier in identifiers {
            if let value = localizations[identifier]?.stringUnit?.value {
                return value
            }

            let normalizedIdentifier = AppLocaleIdentifier.normalized(identifier)
            if let localization = localizations.first(where: {
                AppLocaleIdentifier.normalized($0.key) == normalizedIdentifier
            }), let value = localization.value.stringUnit?.value {
                return value
            }
        }

        return nil
    }

    private func stringCatalog(table: String?, bundle: Bundle) -> StringCatalog? {
        let catalogName = table ?? "Localizable"
        guard let catalogURL = bundle.url(forResource: catalogName, withExtension: "xcstrings") else {
            return nil
        }

        if let cachedCatalog = catalogCache[catalogURL] {
            switch cachedCatalog {
            case .available(let catalog):
                return catalog
            case .unavailable:
                return nil
            }
        }

        guard let data = try? Data(contentsOf: catalogURL),
              let catalog = try? JSONDecoder().decode(StringCatalog.self, from: data) else {
            catalogCache[catalogURL] = .unavailable
            return nil
        }

        catalogCache[catalogURL] = .available(catalog)
        return catalog
    }
}

private enum CachedStringCatalog {
    case available(StringCatalog)
    case unavailable
}

private struct LocalizedBundleCacheKey: Hashable {
    let bundleURL: URL
    let identifier: String
}

private enum CachedLocalizedBundle {
    case available(Bundle)
    case unavailable
}

/// 字符串目录的顶层结构，仅解码本框架需要的字段。
private struct StringCatalog: Decodable {
    let sourceLanguage: String?
    let strings: [String: StringCatalogEntry]
}

/// 字符串目录中的单个键条目。
private struct StringCatalogEntry: Decodable {
    let localizations: [String: StringCatalogLocalization]?
}

/// 指定区域设置的本地化内容。
private struct StringCatalogLocalization: Decodable {
    let stringUnit: StringCatalogStringUnit?
}

/// 字符串目录中的字符串单元。
private struct StringCatalogStringUnit: Decodable {
    let value: String
}
