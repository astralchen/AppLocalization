import XCTest
@testable import AppLocalization

final class LocalizedStringResolverTests: XCTestCase {
    @MainActor
    func testUsesStringCatalogSourceResource() {
        XCTAssertNotNil(Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"))
    }

    @MainActor
    func testResolvesCurrentLocaleStringFromRequestedBundle() {
        let center = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese],
            fallbackLocale: .englishUS,
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "zh-Hans")
        )
        let resolver = LocalizedStringResolver(localeProvider: { center.currentLocale })

        XCTAssertEqual(
            resolver.string("settings.language.title", bundle: .module),
            "语言"
        )
    }

    @MainActor
    func testFallsBackToFallbackLocaleWhenCurrentLocaleMissesKey() {
        let center = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese],
            fallbackLocale: .englishUS,
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "zh-Hans")
        )
        let resolver = LocalizedStringResolver(
            localeProvider: { center.currentLocale },
            fallbackLocale: .englishUS
        )

        XCTAssertEqual(
            resolver.string("only.english", bundle: .module),
            "English fallback"
        )
    }

    @MainActor
    func testFormatsUsingCurrentLocaleAndReportsMissingKeys() {
        let center = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese],
            fallbackLocale: .englishUS,
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "en-US")
        )
        var missingKeys: [String] = []
        let resolver = LocalizedStringResolver(
            localeProvider: { center.currentLocale },
            fallbackLocale: .englishUS,
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
}
