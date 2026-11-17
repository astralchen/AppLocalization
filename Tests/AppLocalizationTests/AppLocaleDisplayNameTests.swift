import XCTest
@testable import AppLocalization

final class AppLocaleDisplayNameTests: XCTestCase {
    func testNativeDisplayNameUsesCandidateLocaleAndDoesNotDependOnPreferredLocale() {
        XCTAssertTrue(
            AppLocale(identifier: "en-US").nativeDisplayName.contains("English")
        )
        XCTAssertEqual(AppLocale(identifier: "zh-Hans").nativeDisplayName, "简体中文")
        XCTAssertEqual(AppLocale(identifier: "ar").nativeDisplayName, "العربية")
    }

    func testNativeDisplayNameFallsBackToConfiguredDisplayNameWhenFoundationCannotResolveIdentifier() {
        let customLocale = AppLocale(identifier: "x-app-custom", displayName: "Custom Language")

        XCTAssertEqual(customLocale.nativeDisplayName, "Custom Language")
    }

    func testUsesPreferredLocaleForLanguageDisplayName() {
        XCTAssertEqual(
            AppLocale(identifier: "en-US").localizedDisplayName(preferredBy: AppLocale(identifier: "zh-Hans")),
            "英语（美国）"
        )
    }

    func testFallsBackToCandidateScriptWhenPreferredLocaleIsSameLanguageFamily() {
        let traditionalChineseUser = AppLocale(identifier: "zh-Hant", displayName: "繁體中文")

        XCTAssertEqual(
            AppLocale(identifier: "zh-Hans").localizedDisplayName(preferredBy: traditionalChineseUser),
            "简体中文"
        )
    }

    func testUsesCandidateFallbackWhenFoundationCannotResolveIdentifier() {
        let customLocale = AppLocale(identifier: "x-app-custom", displayName: "Custom Language")

        XCTAssertEqual(
            customLocale.localizedDisplayName(preferredBy: AppLocale(identifier: "en-US")),
            "Custom Language"
        )
    }
}
