import Foundation

/// 统一的本地化字符串解析器。
///
/// 所有 UIKit 文案、命令式更新文案、以及需要指定 App 内 locale 的 SwiftUI
/// 文案都应从这里读取。
///
/// 并发边界：解析器每次读取 `localeProvider`，而 provider 通常会访问
/// `LocalizationController.currentLocale`。因此解析器也放在主 actor 上，
/// 确保文案刷新和当前语言状态读取在同一条 UI 状态线上完成。它支持：
/// - 已编译的 `.lproj/Localizable.strings`
/// - 源码形式的 `Localizable.xcstrings`，方便 SwiftPM 测试
/// - fallback locale
/// - missing key 日志或断言
@MainActor
public final class LocalizedStringResolver {
    /// 缺失 key 回调。
    ///
    /// 生产环境可上报日志；Debug 环境可 `assertionFailure`，让缺失文案尽早暴露。
    public typealias MissingKeyHandler = @MainActor (_ key: String, _ locale: AppLocale, _ bundle: Bundle) -> Void

    private let localeProvider: @MainActor () -> AppLocale
    private let fallbackLocale: AppLocale
    private let missingKeyHandler: MissingKeyHandler

    /// 创建字符串解析器。
    ///
    /// - Parameters:
    ///   - localeProvider: 每次解析时动态读取当前 locale，避免缓存旧语言。
    ///   - fallbackLocale: 当前 locale 缺失 key 时使用的兜底 locale。
    ///   - missingKeyHandler: 当前和 fallback 都找不到 key 时触发。
    public init(
        localeProvider: @escaping @MainActor () -> AppLocale,
        fallbackLocale: AppLocale = .englishUS,
        missingKeyHandler: @escaping MissingKeyHandler = { _, _, _ in }
    ) {
        self.localeProvider = localeProvider
        self.fallbackLocale = fallbackLocale
        self.missingKeyHandler = missingKeyHandler
    }

    /// 按当前 App locale 解析本地化字符串。
    ///
    /// UIKit 文案建议统一走这个 API；SwiftUI 如果需要跟随 App 内 locale
    /// 而不是系统 locale，也可以在 `body` 中调用它。解析 framework 或
    /// Swift Package 内的文案时，要传入资源所属 bundle。
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
    public func string(
        _ key: String,
        table: String? = nil,
        bundle: Bundle = .main,
        arguments: [CVarArg] = [],
        fallbackValue: String? = nil
    ) -> String {
        let currentLocale = localeProvider()
        let format = localizedFormat(
            key,
            locale: currentLocale,
            table: table,
            bundle: bundle
        ) ?? stringCatalogFormat(
            key,
            locale: currentLocale,
            table: table,
            bundle: bundle
        ) ?? localizedFormat(
            key,
            locale: fallbackLocale,
            table: table,
            bundle: bundle
        ) ?? stringCatalogFormat(
            key,
            locale: fallbackLocale,
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

    /// 从编译后的 `.lproj` bundle 中查找字符串。
    ///
    /// Xcode 会把 String Catalog 编译成各语言的 `.strings` 输出；正式 App
    /// 运行时大多数情况会命中这条路径。
    private func localizedFormat(
        _ key: String,
        locale: AppLocale,
        table: String?,
        bundle: Bundle
    ) -> String? {
        for identifier in bundleIdentifiers(for: locale) {
            guard let path = bundle.path(forResource: identifier, ofType: "lproj"),
                  let localizedBundle = Bundle(path: path) else {
                continue
            }

            let value = localizedBundle.localizedString(forKey: key, value: nil, table: table)
            if value != key {
                return value
            }
        }

        return nil
    }

    /// 为一个 locale 生成资源查找顺序。
    ///
    /// 例如 `en-US` 会依次尝试 `en-US`、`en-us`、`en`、`Base`。这样可以兼容
    /// `.xcstrings`、`.lproj` 目录大小写和地区后缀差异。
    private func bundleIdentifiers(for locale: AppLocale) -> [String] {
        var identifiers: [String] = []
        let candidates = [
            locale.identifier,
            locale.identifier.lowercased(),
            locale.baseLanguageIdentifier,
            locale.baseLanguageIdentifier.lowercased(),
            "Base"
        ]

        for identifier in candidates where !identifiers.contains(identifier) {
            identifiers.append(identifier)
        }
        return identifiers
    }

    /// 从源码形式的 `.xcstrings` 中查找字符串。
    ///
    /// 这主要服务于 SwiftPM 测试和直接把 String Catalog 作为资源处理的场景。
    /// 真机 App 构建后通常会被 Xcode 编译成 `.lproj/Localizable.strings`。
    private func stringCatalogFormat(
        _ key: String,
        locale: AppLocale,
        table: String?,
        bundle: Bundle
    ) -> String? {
        let catalogName = table ?? "Localizable"
        guard let catalogURL = bundle.url(forResource: catalogName, withExtension: "xcstrings"),
              let data = try? Data(contentsOf: catalogURL),
              let catalog = try? JSONDecoder().decode(StringCatalog.self, from: data),
              let entry = catalog.strings[key] else {
            return nil
        }

        for identifier in bundleIdentifiers(for: locale) {
            if let value = entry.localizations?[identifier]?.stringUnit?.value {
                return value
            }
        }

        return nil
    }
}

/// String Catalog 顶层结构，只解码本框架需要的字段。
private struct StringCatalog: Decodable {
    let strings: [String: StringCatalogEntry]
}

/// 单个 key 的 String Catalog 条目。
private struct StringCatalogEntry: Decodable {
    let localizations: [String: StringCatalogLocalization]?
}

/// 某个 locale 的本地化内容。
private struct StringCatalogLocalization: Decodable {
    let stringUnit: StringCatalogStringUnit?
}

/// String Catalog 的字符串单元。
private struct StringCatalogStringUnit: Decodable {
    let value: String
}
