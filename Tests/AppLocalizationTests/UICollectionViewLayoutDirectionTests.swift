#if canImport(UIKit)
import UIKit
import XCTest
@testable import AppLocalization

@MainActor
final class UICollectionViewLayoutDirectionTests: XCTestCase {
    func testDetachedReusableCellAppliesLatestSnapshotBeforeConfiguration() {
        let snapshotBox = CollectionSnapshotBox(makeUpdate(.rightToLeft).snapshot)
        let context = UIKitLocalizationContext { snapshotBox.snapshot }
        let cell = UICollectionViewListCell()

        context.restoreBeforeConfiguration(cell)

        XCTAssertEqual(cell.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(cell.contentView.semanticContentAttribute, .forceRightToLeft)

        snapshotBox.snapshot = makeUpdate(.leftToRight).snapshot
        context.restoreOnAttachment(cell)

        XCTAssertEqual(cell.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(cell.contentView.semanticContentAttribute, .forceLeftToRight)
    }

    func testMaterializedContentConfigurationIsRecreatedForDirectionChange() {
        let tracker = ContentConfigurationTracker()
        let cell = UICollectionViewListCell()
        cell.contentConfiguration = TrackingContentConfiguration(tracker: tracker)
        let initialMaterializationCount = tracker.materializationCount

        cell.applyLocalizationDirection(makeUpdate(.rightToLeft))

        XCTAssertGreaterThan(tracker.materializationCount, initialMaterializationCount)
        let rightToLeftMaterializationCount = tracker.materializationCount

        cell.applyLocalizationDirection(makeUpdate(.leftToRight))

        XCTAssertGreaterThan(
            tracker.materializationCount,
            rightToLeftMaterializationCount
        )
    }

    func testAppliesDirectionToMaterializedStandardListCellBoundaries() throws {
        let collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 200),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Int> {
            cell,
            _,
            item in
            var configuration = cell.defaultContentConfiguration()
            configuration.text = "Item \(item)"
            cell.contentConfiguration = configuration
        }
        let dataSource = UICollectionViewDiffableDataSource<Int, Int>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(
                using: registration,
                for: indexPath,
                item: item
            )
        }
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems([1])
        dataSource.apply(snapshot, animatingDifferences: false)
        collectionView.layoutIfNeeded()

        let cell = try XCTUnwrap(
            collectionView.cellForItem(at: IndexPath(item: 0, section: 0))
        )

        collectionView.applyLocalization(
            makeUpdate(.rightToLeft),
            preservingVisibleItem: false
        )

        XCTAssertEqual(cell.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(cell.contentView.semanticContentAttribute, .forceRightToLeft)

        collectionView.applyLocalization(
            makeUpdate(.leftToRight),
            preservingVisibleItem: false
        )

        XCTAssertEqual(cell.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(cell.contentView.semanticContentAttribute, .forceLeftToRight)
        _ = dataSource
    }

    func testRebuildsLayoutOnlyWhenSemanticDirectionChanges() {
        let initialLayout = TrackingCollectionViewLayout()
        let collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 200),
            collectionViewLayout: initialLayout
        )
        var layouts: [TrackingCollectionViewLayout] = []

        collectionView.applyLocalization(
            makeUpdate(.rightToLeft),
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
        collectionView.applyLocalization(
            makeUpdate(.rightToLeft),
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

        collectionView.applyLocalization(
            makeUpdate(.leftToRight),
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

        collectionView.applyLocalization(
            makeUpdate(.rightToLeft),
            preservingVisibleItem: false
        )

        XCTAssertEqual(collectionView.semanticContentAttribute, .forceRightToLeft)
        XCTAssertTrue(collectionView.collectionViewLayout === layout)
        XCTAssertGreaterThan(layout.invalidationCount, invalidationCount)
    }

    func testAnchorRestoresRelativePositionAcrossCollectionInstances() throws {
        let firstFixture = makeScrollableCollectionView(
            direction: .leftToRight
        )
        let firstCollectionView = firstFixture.collectionView
        let expectedIndexPath = IndexPath(item: 12, section: 0)
        let expectedPartialOffset: CGFloat = 17
        let firstFrame = try XCTUnwrap(
            firstCollectionView.layoutAttributesForItem(
                at: expectedIndexPath
            )?.frame
        )
        firstCollectionView.setContentOffset(
            CGPoint(
                x: firstCollectionView.contentOffset.x,
                y: firstFrame.minY
                    - firstCollectionView.adjustedContentInset.top
                    + expectedPartialOffset
            ),
            animated: false
        )
        firstCollectionView.layoutIfNeeded()

        let anchor = try XCTUnwrap(
            firstCollectionView.captureLocalizationAnchor()
        )
        XCTAssertEqual(anchor.indexPath, expectedIndexPath)

        let secondFixture = makeScrollableCollectionView(
            direction: .rightToLeft
        )
        let secondCollectionView = secondFixture.collectionView
        secondCollectionView.restoreLocalizationAnchor(anchor)

        let restoredFrame = try XCTUnwrap(
            secondCollectionView.layoutAttributesForItem(
                at: anchor.indexPath
            )?.frame
        )
        XCTAssertEqual(
            restoredFrame.minY
                - (
                    secondCollectionView.contentOffset.y
                        + secondCollectionView.adjustedContentInset.top
                ),
            anchor.offsetFromViewportTop,
            accuracy: 0.5
        )
        _ = firstFixture.dataSource
        _ = secondFixture.dataSource
    }

    private func makeUpdate(
        _ direction: AppUserInterfaceLayoutDirection
    ) -> UIKitLocalizationUpdate {
        UIKitLocalizationUpdate(
            snapshot: LocalizationSnapshot(
                locale: direction == .rightToLeft ? .arabic : .englishUS,
                followsSystemLocale: false,
                revision: 1
            ),
            reasons: [.layoutDirection]
        )
    }

    private func makeScrollableCollectionView(
        direction: UIUserInterfaceLayoutDirection
    ) -> (
        collectionView: UICollectionView,
        dataSource: UICollectionViewDiffableDataSource<Int, Int>
    ) {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 280, height: 44)
        layout.minimumLineSpacing = 8
        let collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 240),
            collectionViewLayout: layout
        )
        collectionView.contentInset = UIEdgeInsets(
            top: 88,
            left: 12,
            bottom: 20,
            right: 12
        )
        collectionView.semanticContentAttribute = direction == .rightToLeft
            ? .forceRightToLeft
            : .forceLeftToRight
        let registration = UICollectionView.CellRegistration<
            UICollectionViewCell,
            Int
        > { _, _, _ in }
        let dataSource = UICollectionViewDiffableDataSource<Int, Int>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(
                using: registration,
                for: indexPath,
                item: item
            )
        }
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(Array(0..<40))
        dataSource.apply(snapshot, animatingDifferences: false)
        collectionView.layoutIfNeeded()
        return (collectionView, dataSource)
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

@MainActor
private final class ContentConfigurationTracker {
    var materializationCount = 0
}

private struct TrackingContentConfiguration: UIContentConfiguration {
    let tracker: ContentConfigurationTracker

    func makeContentView() -> UIView & UIContentView {
        tracker.materializationCount += 1
        return TrackingContentView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> Self {
        self
    }
}

private final class TrackingContentView: UIView, UIContentView {
    var configuration: UIContentConfiguration

    init(configuration: UIContentConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
private final class CollectionSnapshotBox {
    var snapshot: LocalizationSnapshot

    init(_ snapshot: LocalizationSnapshot) {
        self.snapshot = snapshot
    }
}
#endif
