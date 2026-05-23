import XCTest
@testable import AppLocalization

final class AppLocaleDisplayNameTests: XCTestCase {
    func testNativeDisplayNameUsesCandidateLocaleAndDoesNotDependOnPreferredLocale() {
        XCTAssertTrue(
            AppLocale.englishUS.nativeDisplayName.contains("English")
        )
        XCTAssertEqual(AppLocale.simplifiedChinese.nativeDisplayName, "简体中文")
        XCTAssertEqual(AppLocale.arabic.nativeDisplayName, "العربية")
    }

    func testNativeDisplayNameFallsBackToConfiguredDisplayNameWhenFoundationCannotResolveIdentifier() {
        let customLocale = AppLocale(identifier: "x-app-custom", displayName: "Custom Language")

        XCTAssertEqual(customLocale.nativeDisplayName, "Custom Language")
    }

    func testUsesPreferredLocaleForLanguageDisplayName() {
        XCTAssertEqual(
            AppLocale.englishUS.localizedDisplayName(preferredBy: .simplifiedChinese),
            "英语（美国）"
        )
    }

    func testFallsBackToCandidateScriptWhenPreferredLocaleIsSameLanguageFamily() {
        let traditionalChineseUser = AppLocale(identifier: "zh-Hant", displayName: "繁體中文")

        XCTAssertEqual(
            AppLocale.simplifiedChinese.localizedDisplayName(preferredBy: traditionalChineseUser),
            "简体中文"
        )
    }

    func testUsesCandidateFallbackWhenFoundationCannotResolveIdentifier() {
        let customLocale = AppLocale(identifier: "x-app-custom", displayName: "Custom Language")

        XCTAssertEqual(
            customLocale.localizedDisplayName(preferredBy: .englishUS),
            "Custom Language"
        )
    }
}
