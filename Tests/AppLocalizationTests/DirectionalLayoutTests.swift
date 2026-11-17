import XCTest
import UIKit
@testable import AppLocalization

final class DirectionalLayoutTests: XCTestCase {
    @MainActor
    func testNativeUIKitDirectionCanBeUsedWithoutConversions() {
        let view = UIView()
        for locale in [AppLocale(identifier: "en-US"), AppLocale(identifier: "ar"), AppLocale(identifier: "zh-Hans")] {
            let direction: UIUserInterfaceLayoutDirection = locale.layoutDirection
            let update = LocalizationUpdate(snapshot: LocalizationSnapshot(
                locale: locale, followsSystemLocale: false, revision: 0))
            view.semanticContentAttribute = update.semanticContentAttribute
            XCTAssertEqual(update.layoutDirection, direction)
            XCTAssertEqual(view.effectiveUserInterfaceLayoutDirection, direction)
            XCTAssertEqual(DirectionalLayout.backSwipeRectEdge(layoutDirection: view.effectiveUserInterfaceLayoutDirection),
                           direction == .rightToLeft ? .right : .left)
            XCTAssertEqual(DirectionalLayout.backChevronSystemName(layoutDirection: direction),
                           direction == .rightToLeft ? "chevron.right" : "chevron.left")
        }
    }

    func testDetectsRightToLeftLocales() {
        XCTAssertEqual(AppLocale(identifier: "ar").layoutDirection, .rightToLeft)
        XCTAssertEqual(AppLocale(identifier: "en-US").layoutDirection, .leftToRight)
        XCTAssertEqual(AppLocale(identifier: "zh-Hans").layoutDirection, .leftToRight)
        XCTAssertEqual(AppLocale(identifier: "pa-PK").layoutDirection, .rightToLeft)
        XCTAssertEqual(AppLocale(identifier: "ar-Latn").layoutDirection, .leftToRight)
    }

    func testDirectionFollowsFoundationForExplicitScriptsAndRegions() {
        // 契约是遵循当前系统，不另行规定显式脚本的优先级。
        for identifier in ["az-Arab", "ar-Latn", "ff-Adlm", "he-Latn", "en-Arab", "pa-PK"] {
            let expected: Locale.LanguageDirection
            if #available(iOS 16.0, *) {
                expected = Locale.Language(identifier: identifier).characterDirection
            } else {
                expected = Locale.characterDirection(forLanguage: identifier)
            }
            XCTAssertEqual(AppLocale(identifier: identifier).layoutDirection,
                           expected == .rightToLeft ? .rightToLeft : .leftToRight, identifier)
        }
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

    func testHorizontalMappingRejectsOtherNativeEdgeSets() {
        let invalidEdges: [NSDirectionalRectEdge] = [
            [], .top, .bottom, [.leading, .trailing], [.top, .leading], .all,
            NSDirectionalRectEdge(rawValue: 1 << 12)
        ]
        for direction in [UIUserInterfaceLayoutDirection.leftToRight, .rightToLeft] {
            for edge in invalidEdges {
                XCTAssertNil(DirectionalLayout.physicalEdge(for: edge, layoutDirection: direction))
            }
        }
    }

    @MainActor
    func testNativeEdgesPreserveSemanticPanAndBackGestureRules() throws {
        let cases: [(UIUserInterfaceLayoutDirection, CGFloat, NSDirectionalRectEdge, UIRectEdge)] = [
            (.leftToRight, -40, .leading, .left),
            (.leftToRight, 40, .trailing, .right),
            (.rightToLeft, -40, .trailing, .left),
            (.rightToLeft, 40, .leading, .right)
        ]
        for (direction, translation, semantic, physical) in cases {
            let result: NSDirectionalRectEdge? = DirectionalLayout.semanticHorizontalDirection(
                translationX: translation, layoutDirection: direction, minimumDistance: 12)
            XCTAssertEqual(result, semantic)
            XCTAssertEqual(DirectionalLayout.physicalEdge(for: try XCTUnwrap(result), layoutDirection: direction), physical)
            XCTAssertEqual(DirectionalLayout.isBackSwipe(translationX: translation, layoutDirection: direction),
                           semantic == .trailing)
        }
        for direction in [UIUserInterfaceLayoutDirection.leftToRight, .rightToLeft] {
            let recognizer = UIScreenEdgePanGestureRecognizer()
            recognizer.edges = DirectionalLayout.backSwipeRectEdge(layoutDirection: direction)
            XCTAssertEqual(recognizer.edges, direction == .rightToLeft ? .right : .left)
            for value in [CGFloat.zero, 12, -12, .nan, .infinity, -.infinity] {
                XCTAssertNil(DirectionalLayout.semanticHorizontalDirection(
                    translationX: value, layoutDirection: direction, minimumDistance: 12))
                XCTAssertFalse(DirectionalLayout.isBackSwipe(
                    translationX: value, layoutDirection: direction, minimumDistance: 12))
            }
            // 保持无阈值重载的零位移兼容行为；返回手势判断仍排除零位移。
            XCTAssertEqual(DirectionalLayout.semanticHorizontalDirection(translationX: 0, layoutDirection: direction),
                           direction == .rightToLeft ? .trailing : .leading)
            XCTAssertFalse(DirectionalLayout.isBackSwipe(translationX: 0, layoutDirection: direction))
            XCTAssertEqual(DirectionalLayout.popEndOffset(width: -320, layoutDirection: direction),
                           direction == .rightToLeft ? -320 : 320)
        }
    }

    func testBackSwipeAndNavigationTransitionDirectionsFollowLayoutDirection() {
        XCTAssertEqual(DirectionalLayout.backSwipeRectEdge(layoutDirection: .leftToRight), .left)
        XCTAssertEqual(DirectionalLayout.backSwipeRectEdge(layoutDirection: .rightToLeft), .right)
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
