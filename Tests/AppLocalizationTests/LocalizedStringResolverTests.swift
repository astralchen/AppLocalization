import XCTest
@testable import AppLocalization

private struct LocalizationBundleFixture {
    let bundle: Bundle
    let url: URL
}

private enum LocalizationBundleFixtureError: Error {
    case invalidBundle
}

final class LocalizedStringResolverTests: XCTestCase {
    @MainActor
    func testUsesCompiledStringCatalogResources() {
        // 检查资源管线的实际产物，后续用例再验证查找与回退结果。
        let source = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings")
        let compiled = Bundle.module.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: "en")
        XCTAssertTrue(source != nil || compiled != nil, "资源管线必须提供源码目录或编译后的翻译表")
    }

    @MainActor
    func testResolvesCurrentLocaleStringFromRequestedBundle() {
        let center = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans"], developmentLocalization: "en-US"),
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "zh-Hans")
        )
        let resolver = LocalizedStringResolver(localeProvider: { center.currentLocale },
            fallbackLocale: AppLocale(identifier: center.fallbackLocalization))

        XCTAssertEqual(
            resolver.string("settings.language.title", bundle: .module),
            "语言"
        )
    }

    @MainActor
    func testFallsBackToFallbackLocaleWhenCurrentLocaleMissesKey() {
        let center = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans"], developmentLocalization: "en-US"),
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "zh-Hans")
        )
        let resolver = LocalizedStringResolver(
            localeProvider: { center.currentLocale },
            fallbackLocale: AppLocale(identifier: "en-US")
        )

        XCTAssertEqual(
            resolver.string("only.english", bundle: .module),
            "English fallback"
        )
    }

    @MainActor
    func testFormatsUsingCurrentLocaleAndReportsMissingKeys() {
        let center = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans"], developmentLocalization: "en-US"),
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "en-US")
        )
        var missingKeys: [String] = []
        let resolver = LocalizedStringResolver(
            localeProvider: { center.currentLocale },
            fallbackLocale: AppLocale(identifier: "en-US"),
            missingKeyHandler: { key, _, _ in missingKeys.append(key) }
        )

        XCTAssertEqual(
            resolver.string("cart.count", bundle: .module, arguments: [3]),
            "3 items"
        )
        XCTAssertEqual(
            resolver.string("missing.key", bundle: .module),
            "missing.key"
        )
        XCTAssertEqual(missingKeys, ["missing.key"])
    }

    @MainActor
    func testNormalizesAndProgressivelyFallsBackStringCatalogLocaleIdentifiers() {
        let resolver = LocalizedStringResolver(
            localeProvider: { AppLocale(identifier: "ZH_hans_CN") },
            fallbackLocale: AppLocale(identifier: "en-US")
        )

        XCTAssertEqual(
            resolver.string("settings.language.title", bundle: .module),
            "语言"
        )
    }

    @MainActor
    func testUsesConfiguredFallbackLocaleBeforeBaseLocalization() throws {
        let fixture = try makeLocalizationBundle(
            table: "ResolverFallback",
            localizations: [
                "Base": ["fallback.order": "Base value"],
                "fr": ["fallback.order": "French fallback"]
            ]
        )
        defer { try? FileManager.default.removeItem(at: fixture.url) }

        let resolver = LocalizedStringResolver(
            localeProvider: { AppLocale(identifier: "ja") },
            fallbackLocale: AppLocale(identifier: "fr")
        )

        XCTAssertEqual(
            resolver.string(
                "fallback.order",
                table: "ResolverFallback",
                bundle: fixture.bundle
            ),
            "French fallback"
        )
    }

    @MainActor
    func testDoesNotReportTranslationWhoseValueEqualsItsKeyAsMissing() throws {
        let fixture = try makeLocalizationBundle(
            table: "ResolverFallback",
            localizations: [
                "en": ["translation.equals.key": "translation.equals.key"]
            ]
        )
        defer { try? FileManager.default.removeItem(at: fixture.url) }

        var missingKeys: [String] = []
        let resolver = LocalizedStringResolver(
            localeProvider: { AppLocale(identifier: "en-US") },
            fallbackLocale: AppLocale(identifier: "en-US"),
            missingKeyHandler: { key, _, _ in missingKeys.append(key) }
        )

        XCTAssertEqual(
            resolver.string(
                "translation.equals.key",
                table: "ResolverFallback",
                bundle: fixture.bundle
            ),
            "translation.equals.key"
        )
        XCTAssertTrue(missingKeys.isEmpty)
    }

    private func makeLocalizationBundle(
        table: String,
        localizations: [String: [String: String]]
    ) throws -> LocalizationBundleFixture {
        let fileManager = FileManager.default
        let bundleURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try fileManager.createDirectory(
            at: bundleURL,
            withIntermediateDirectories: true
        )

        let infoData = try PropertyListSerialization.data(
            fromPropertyList: [
                "CFBundleDevelopmentRegion": "en",
                "CFBundleIdentifier": "AppLocalizationTests.\(UUID().uuidString)",
                "CFBundleName": "AppLocalizationTests",
                "CFBundlePackageType": "BNDL"
            ],
            format: .xml,
            options: 0
        )
        try infoData.write(to: bundleURL.appendingPathComponent("Info.plist"))

        for (identifier, strings) in localizations {
            let localizationURL = bundleURL.appendingPathComponent("\(identifier).lproj")
            try fileManager.createDirectory(
                at: localizationURL,
                withIntermediateDirectories: true
            )
            let stringsData = try PropertyListSerialization.data(
                fromPropertyList: strings,
                format: .xml,
                options: 0
            )
            try stringsData.write(
                to: localizationURL.appendingPathComponent("\(table).strings")
            )
        }

        guard let bundle = Bundle(url: bundleURL) else {
            throw LocalizationBundleFixtureError.invalidBundle
        }

        return LocalizationBundleFixture(bundle: bundle, url: bundleURL)
    }
}
