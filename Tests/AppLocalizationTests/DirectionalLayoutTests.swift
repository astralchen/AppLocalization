import XCTest
@testable import AppLocalization

final class DirectionalLayoutTests: XCTestCase {
    func testDetectsRightToLeftLocales() {
        XCTAssertEqual(AppLocale.arabic.layoutDirection, .rightToLeft)
        XCTAssertEqual(AppLocale.englishUS.layoutDirection, .leftToRight)
        XCTAssertEqual(AppLocale.simplifiedChinese.layoutDirection, .leftToRight)
    }

    func testConvertsPhysicalPanTranslationToSemanticDirection() {
        XCTAssertEqual(
            DirectionalLayout.semanticHorizontalDirection(
                translationX: 20,
                layoutDirection: .leftToRight
            ),
            .trailing
        )
        XCTAssertEqual(
            DirectionalLayout.semanticHorizontalDirection(
                translationX: 20,
                layoutDirection: .rightToLeft
            ),
            .leading
        )
    }

    func testBackSwipeAndNavigationTransitionDirectionsFollowLayoutDirection() {
        XCTAssertEqual(DirectionalLayout.backSwipeEdge(layoutDirection: .leftToRight), .left)
        XCTAssertEqual(DirectionalLayout.backSwipeEdge(layoutDirection: .rightToLeft), .right)
        XCTAssertTrue(DirectionalLayout.isBackSwipe(translationX: 40, layoutDirection: .leftToRight))
        XCTAssertTrue(DirectionalLayout.isBackSwipe(translationX: -40, layoutDirection: .rightToLeft))
        XCTAssertEqual(DirectionalLayout.pushStartOffset(width: 320, layoutDirection: .leftToRight), 320)
        XCTAssertEqual(DirectionalLayout.pushStartOffset(width: 320, layoutDirection: .rightToLeft), -320)
        XCTAssertEqual(DirectionalLayout.popEndOffset(width: 320, layoutDirection: .leftToRight), -320)
        XCTAssertEqual(DirectionalLayout.popEndOffset(width: 320, layoutDirection: .rightToLeft), 320)
    }
}
