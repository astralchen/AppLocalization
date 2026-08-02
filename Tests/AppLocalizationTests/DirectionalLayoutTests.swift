import XCTest
@testable import AppLocalization

final class DirectionalLayoutTests: XCTestCase {
    func testDetectsRightToLeftLocales() {
        XCTAssertEqual(AppLocale.arabic.layoutDirection, .rightToLeft)
        XCTAssertEqual(AppLocale.englishUS.layoutDirection, .leftToRight)
        XCTAssertEqual(AppLocale.simplifiedChinese.layoutDirection, .leftToRight)
        XCTAssertEqual(AppLocale(identifier: "pa-PK").layoutDirection, .rightToLeft)
        XCTAssertEqual(AppLocale(identifier: "az-Arab").layoutDirection, .rightToLeft)
        XCTAssertEqual(AppLocale(identifier: "ar-Latn").layoutDirection, .leftToRight)
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

    func testIgnoresStationaryAndBelowThresholdPanTranslations() {
        XCTAssertNil(
            DirectionalLayout.semanticHorizontalDirection(
                translationX: 0,
                layoutDirection: .rightToLeft,
                minimumDistance: 0
            )
        )
        XCTAssertNil(
            DirectionalLayout.semanticHorizontalDirection(
                translationX: -12,
                layoutDirection: .rightToLeft,
                minimumDistance: 12
            )
        )
        XCTAssertEqual(
            DirectionalLayout.semanticHorizontalDirection(
                translationX: -13,
                layoutDirection: .rightToLeft,
                minimumDistance: 12
            ),
            .trailing
        )
        XCTAssertNil(
            DirectionalLayout.semanticHorizontalDirection(
                translationX: .nan,
                layoutDirection: .leftToRight,
                minimumDistance: 0
            )
        )
    }

    func testMapsSemanticEdgesToPhysicalEdges() {
        XCTAssertEqual(
            DirectionalLayout.physicalEdge(for: .leading, layoutDirection: .leftToRight),
            .left
        )
        XCTAssertEqual(
            DirectionalLayout.physicalEdge(for: .trailing, layoutDirection: .leftToRight),
            .right
        )
        XCTAssertEqual(
            DirectionalLayout.physicalEdge(for: .leading, layoutDirection: .rightToLeft),
            .right
        )
        XCTAssertEqual(
            DirectionalLayout.physicalEdge(for: .trailing, layoutDirection: .rightToLeft),
            .left
        )
    }

    func testBackSwipeAndNavigationTransitionDirectionsFollowLayoutDirection() {
        XCTAssertEqual(DirectionalLayout.backSwipeEdge(layoutDirection: .leftToRight), .left)
        XCTAssertEqual(DirectionalLayout.backSwipeEdge(layoutDirection: .rightToLeft), .right)
        XCTAssertTrue(DirectionalLayout.isBackSwipe(translationX: 40, layoutDirection: .leftToRight))
        XCTAssertTrue(DirectionalLayout.isBackSwipe(translationX: -40, layoutDirection: .rightToLeft))
        XCTAssertFalse(DirectionalLayout.isBackSwipe(translationX: 0, layoutDirection: .rightToLeft))
        XCTAssertFalse(
            DirectionalLayout.isBackSwipe(
                translationX: -10,
                layoutDirection: .rightToLeft,
                minimumDistance: 12
            )
        )
        XCTAssertEqual(DirectionalLayout.pushStartOffset(width: 320, layoutDirection: .leftToRight), 320)
        XCTAssertEqual(DirectionalLayout.pushStartOffset(width: 320, layoutDirection: .rightToLeft), -320)
        XCTAssertEqual(DirectionalLayout.popEndOffset(width: 320, layoutDirection: .leftToRight), 320)
        XCTAssertEqual(DirectionalLayout.popEndOffset(width: 320, layoutDirection: .rightToLeft), -320)
    }
}
