import XCTest
@testable import AppLocalization

final class LocalizationUpdateTests: XCTestCase {
    func testInitialRefreshIncludesContentAndDirectionForBothDirections() {
        for locale in [AppLocale(identifier: "en-US"), AppLocale(identifier: "ar")] {
            let snapshot = LocalizationSnapshot(locale: locale, followsSystemLocale: false, revision: 8)
            let update = LocalizationUpdate(snapshot: snapshot)
            XCTAssertEqual(update.snapshot, snapshot)
            XCTAssertNil(update.previousSnapshot)
            XCTAssertTrue(update.requiresLocalizedContentRefresh)
            XCTAssertTrue(update.requiresLayoutDirectionRefresh)
        }
    }

    func testRefreshRequirementsUseStateDifferencesRatherThanRevision() {
        let english = LocalizationSnapshot(locale: AppLocale(identifier: "en-US"), followsSystemLocale: false, revision: 0)
        let arabic = LocalizationSnapshot(locale: AppLocale(identifier: "ar"), followsSystemLocale: false, revision: 1)
        let cases: [(LocalizationSnapshot, LocalizationSnapshot, Bool, Bool)] = [
            (english, english, false, false),
            (english, LocalizationSnapshot(locale: AppLocale(identifier: "en-US"), followsSystemLocale: false, revision: 5), false, false),
            (english, LocalizationSnapshot(locale: AppLocale(identifier: "en-US"), followsSystemLocale: true, revision: 1), true, false),
            (english, LocalizationSnapshot(locale: AppLocale(identifier: "zh-Hans"), followsSystemLocale: false, revision: 1), true, false),
            (english, arabic, true, true),
            (arabic, english, true, true),
            (arabic, LocalizationSnapshot(locale: AppLocale(identifier: "ar-SA"), followsSystemLocale: false, revision: 2), true, false)
        ]
        for (previous, current, content, direction) in cases {
            let update = LocalizationUpdate(snapshot: current, previousSnapshot: previous)
            XCTAssertEqual(update.snapshot, current)
            XCTAssertEqual(update.previousSnapshot, previous)
            XCTAssertEqual(update.requiresLocalizedContentRefresh, content)
            XCTAssertEqual(update.requiresLayoutDirectionRefresh, direction)
        }
    }
}
