#if canImport(UIKit)
import UIKit
import XCTest
@testable import AppLocalization

@MainActor
final class UICollectionViewLayoutDirectionTests: XCTestCase {
    func testRebuildsLayoutOnlyWhenSemanticDirectionChanges() {
        let initialLayout = TrackingCollectionViewLayout()
        let collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 200),
            collectionViewLayout: initialLayout
        )
        var layouts: [TrackingCollectionViewLayout] = []

        collectionView.applyUserInterfaceLayoutDirection(
            .rightToLeft,
            preservingVisibleItem: false,
            rebuildingLayoutWith: {
                let layout = TrackingCollectionViewLayout()
                layouts.append(layout)
                return layout
            }
        )

        XCTAssertEqual(collectionView.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(layouts.count, 1)
        XCTAssertTrue(collectionView.collectionViewLayout === layouts[0])

        let invalidationCount = layouts[0].invalidationCount
        collectionView.applyUserInterfaceLayoutDirection(
            .rightToLeft,
            preservingVisibleItem: false,
            rebuildingLayoutWith: {
                let layout = TrackingCollectionViewLayout()
                layouts.append(layout)
                return layout
            }
        )

        XCTAssertEqual(layouts.count, 1)
        XCTAssertTrue(collectionView.collectionViewLayout === layouts[0])
        XCTAssertGreaterThan(layouts[0].invalidationCount, invalidationCount)

        collectionView.applyUserInterfaceLayoutDirection(
            .leftToRight,
            preservingVisibleItem: false,
            rebuildingLayoutWith: {
                let layout = TrackingCollectionViewLayout()
                layouts.append(layout)
                return layout
            }
        )

        XCTAssertEqual(collectionView.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(layouts.count, 2)
        XCTAssertTrue(collectionView.collectionViewLayout === layouts[1])
    }

    func testKeepsAndInvalidatesCurrentLayoutWithoutFactory() {
        let layout = TrackingCollectionViewLayout()
        let collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 200),
            collectionViewLayout: layout
        )
        let invalidationCount = layout.invalidationCount

        collectionView.applyUserInterfaceLayoutDirection(
            .rightToLeft,
            preservingVisibleItem: false
        )

        XCTAssertEqual(collectionView.semanticContentAttribute, .forceRightToLeft)
        XCTAssertTrue(collectionView.collectionViewLayout === layout)
        XCTAssertGreaterThan(layout.invalidationCount, invalidationCount)
    }
}

@MainActor
private final class TrackingCollectionViewLayout: UICollectionViewLayout {
    private(set) var invalidationCount = 0

    override var collectionViewContentSize: CGSize {
        .zero
    }

    override func invalidateLayout() {
        invalidationCount += 1
        super.invalidateLayout()
    }

    override func layoutAttributesForElements(
        in rect: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {
        []
    }
}
#endif
