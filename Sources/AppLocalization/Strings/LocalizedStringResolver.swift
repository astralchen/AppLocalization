import Foundation

/// 使用应用所选区域设置解析本地化字符串的对象。
///
/// 每次查找时读取区域设置提供闭包。解析器查找编译后的本地化资源包，
/// 也支持读取源字符串目录中的简单字符串单元，例如包测试资源中的字符串目录。
@MainActor
public final class LocalizedStringResolver {
    /// 找不到键对应的翻译或回退值时调用的闭包。
    ///
    /// 参数依次为缺失的键、请求的应用区域设置和资源包。可使用此闭包记录或诊断缺失资源。
    public typealias MissingKeyHandler = @MainActor (_ key: String, _ locale: AppLocale, _ bundle: Bundle) -> Void

    private let localeProvider: @MainActor () -> AppLocale
    private let fallbackLocale: AppLocale
    private let missingKeyHandler: MissingKeyHandler
    private var catalogCache: [URL: CachedStringCatalog] = [:]
    private var localizedBundleCache: [LocalizedBundleCacheKey: CachedLocalizedBundle] = [:]

    /// 使用指定区域设置提供闭包和回退策略创建解析器。
    ///
    /// - Parameters:
    ///   - localeProvider: 每次查找时返回当前区域设置的闭包。
    ///   - fallbackLocale: 当前区域设置之后查找的回退区域设置。默认值为 `.englishUS`。
    ///   - missingKeyHandler: 所有资源查找均失败且未提供回退值时调用的闭包。
    ///     默认闭包不执行任何操作。
    public init(
        localeProvider: @escaping @MainActor () -> AppLocale,
        fallbackLocale: AppLocale = .englishUS,
        missingKeyHandler: @escaping MissingKeyHandler = { _, _, _ in }
    ) {
        self.localeProvider = localeProvider
        self.fallbackLocale = fallbackLocale
        self.missingKeyHandler = missingKeyHandler
    }

    /// 返回指定键对应的本地化字符串。
    ///
    /// 依次查找当前区域设置、回退区域设置、`Base` 本地化资源和源字符串目录的源语言。
    /// 没有匹配资源时使用 `fallbackValue`；该值也为 `nil` 时，调用缺失键处理闭包并返回 `key`。
    ///
    /// 提供格式参数时，使用当前应用区域设置格式化解析结果。解析包或框架中的字符串时，
    /// 应传入资源所属的资源包。应用区域设置变化后，需要重新解析字符串。
    ///
    /// - Parameters:
    ///   - key: 本地化字符串的键。
    ///   - table: 字符串表名称；为 `nil` 时使用 `Localizable`。
    ///   - bundle: 包含本地化资源的资源包。默认值为 `.main`。
    ///   - arguments: 应用于解析结果的格式参数。
    ///   - fallbackValue: 没有匹配资源时使用的回退值。
    /// - Returns: 本地化并按需格式化后的字符串；无法解析时返回 `key`。
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

    /// 从指定区域设置的已编译本地化资源包中返回格式字符串。
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

    /// 从未编译的字符串目录中返回简单字符串单元。
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

/// 解码源字符串目录所需的字段。
private struct StringCatalog: Decodable {
    let sourceLanguage: String?
    let strings: [String: StringCatalogEntry]
}

/// 源字符串目录中以键标识的条目。
private struct StringCatalogEntry: Decodable {
    let localizations: [String: StringCatalogLocalization]?
}

/// 字符串目录中指定区域设置的字符串内容。
private struct StringCatalogLocalization: Decodable {
    let stringUnit: StringCatalogStringUnit?
}

/// 简单的本地化字符串单元。
private struct StringCatalogStringUnit: Decodable {
    let value: String
}
