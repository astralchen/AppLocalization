#if canImport(UIKit)
import UIKit
import XCTest
@testable import AppLocalization

@MainActor
final class UIKitReusableLocalizationTests: XCTestCase {
    func testContextReadsLatestSnapshotMapsReasonsAndInvokesComponentOnce() throws {
        let snapshotBox = ReusableSnapshotBox(makeSnapshot(.rightToLeft, revision: 1))
        let context = UIKitLocalizationContext { snapshotBox.snapshot }
        let cell = ReusableTrackingTableCell()

        context.prepareForConfiguration(cell)

        XCTAssertEqual(cell.receivedUpdates.count, 1)
        let configurationUpdate = try XCTUnwrap(cell.receivedUpdates.last)
        XCTAssertTrue(configurationUpdate.reasons.contains(.configuration))
        XCTAssertTrue(configurationUpdate.reasons.contains(.layoutDirection))
        XCTAssertFalse(configurationUpdate.reasons.contains(.attachment))
        XCTAssertEqual(cell.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(cell.contentView.semanticContentAttribute, .forceRightToLeft)

        snapshotBox.snapshot = makeSnapshot(.leftToRight, revision: 2)
        context.restoreOnAttachment(cell)

        XCTAssertEqual(cell.receivedUpdates.count, 2)
        let attachmentUpdate = try XCTUnwrap(cell.receivedUpdates.last)
        XCTAssertTrue(attachmentUpdate.reasons.contains(.attachment))
        XCTAssertTrue(attachmentUpdate.reasons.contains(.layoutDirection))
        XCTAssertFalse(attachmentUpdate.reasons.contains(.configuration))
        XCTAssertEqual(attachmentUpdate.snapshot.revision, 2)
        XCTAssertEqual(cell.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(cell.contentView.semanticContentAttribute, .forceLeftToRight)
    }

    func testCollectionCellAttachmentReplacesDetachedDirection() {
        let snapshotBox = ReusableSnapshotBox(makeSnapshot(.rightToLeft, revision: 1))
        let context = UIKitLocalizationContext { snapshotBox.snapshot }
        let cell = UICollectionViewListCell()

        context.prepareForConfiguration(cell)
        snapshotBox.snapshot = makeSnapshot(.leftToRight, revision: 2)
        context.restoreOnAttachment(cell)

        XCTAssertEqual(cell.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(cell.contentView.semanticContentAttribute, .forceLeftToRight)
    }

    func testHeaderFooterAndSupplementaryReceiveLifecycleUpdates() throws {
        let snapshotBox = ReusableSnapshotBox(makeSnapshot(.rightToLeft, revision: 7))
        let context = UIKitLocalizationContext { snapshotBox.snapshot }
        let header = ReusableTrackingHeaderFooterView()
        let supplementary = ReusableTrackingSupplementaryView()

        context.prepareForConfiguration(header)
        context.prepareForConfiguration(supplementary)
        snapshotBox.snapshot = makeSnapshot(.leftToRight, revision: 8)
        context.restoreOnAttachment(header)
        context.restoreOnAttachment(supplementary)

        XCTAssertEqual(header.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(header.receivedUpdates.count, 2)
        XCTAssertTrue(header.receivedUpdates[0].reasons.contains(.configuration))
        XCTAssertTrue(try XCTUnwrap(header.receivedUpdates.last).reasons.contains(.attachment))
        XCTAssertEqual(supplementary.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(supplementary.receivedUpdates.count, 2)
        XCTAssertTrue(supplementary.receivedUpdates[0].reasons.contains(.configuration))
        XCTAssertTrue(
            try XCTUnwrap(supplementary.receivedUpdates.last).reasons.contains(.attachment)
        )
    }

    func testReusablePoliciesPreserveInheritFollowContainerAndFixedSemantics() {
        let inheritedCell = UITableViewCell()
        inheritedCell.semanticContentAttribute = .forceRightToLeft
        UIKitLocalizationContext {
            self.makeSnapshot(.leftToRight, revision: 1)
        }.prepareForConfiguration(inheritedCell, policy: .inherited)
        XCTAssertEqual(inheritedCell.semanticContentAttribute, .forceRightToLeft)

        let container = UIView()
        container.semanticContentAttribute = .forceLeftToRight
        let containerCell = UITableViewCell()
        container.addSubview(containerCell)
        UIKitLocalizationContext {
            self.makeSnapshot(.rightToLeft, revision: 2)
        }.restoreOnAttachment(containerCell, policy: .followContainer)
        XCTAssertEqual(containerCell.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(containerCell.contentView.semanticContentAttribute, .forceLeftToRight)

        let fixedCell = UICollectionViewListCell()
        UIKitLocalizationContext {
            self.makeSnapshot(.rightToLeft, revision: 3)
        }.prepareForConfiguration(fixedCell, policy: .fixed(.playback))
        XCTAssertEqual(fixedCell.semanticContentAttribute, .playback)
        XCTAssertEqual(fixedCell.contentView.semanticContentAttribute, .playback)
    }

    func testHeaderFooterContentConfigurationIsRematerialized() {
        let tracker = ReusableContentConfigurationTracker()
        let header = UITableViewHeaderFooterView(reuseIdentifier: nil)
        header.contentConfiguration = ReusableTrackingContentConfiguration(tracker: tracker)
        let initialMaterializationCount = tracker.materializationCount

        UIKitLocalizationContext {
            self.makeSnapshot(.rightToLeft, revision: 1)
        }.prepareForConfiguration(header)

        XCTAssertGreaterThan(tracker.materializationCount, initialMaterializationCount)
    }

    func testTableCellContentConfigurationIsRematerialized() {
        let tracker = ReusableContentConfigurationTracker()
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.contentConfiguration = ReusableTrackingContentConfiguration(tracker: tracker)
        let initialMaterializationCount = tracker.materializationCount

        UIKitLocalizationContext {
            self.makeSnapshot(.rightToLeft, revision: 1)
        }.restoreOnAttachment(cell)

        XCTAssertGreaterThan(tracker.materializationCount, initialMaterializationCount)
    }

    func testListCellAccessoriesSurviveLifecycleRefresh() {
        let cell = UICollectionViewListCell()
        let button = UIButton(type: .system)
        cell.accessories = [
            .customView(
                configuration: UICellAccessory.CustomViewConfiguration(
                    customView: button,
                    placement: .leading(displayed: .always)
                )
            ),
            .disclosureIndicator(displayed: .always)
        ]

        UIKitLocalizationContext {
            self.makeSnapshot(.rightToLeft, revision: 1)
        }.prepareForConfiguration(cell)

        XCTAssertEqual(cell.accessories.count, 2)
        XCTAssertEqual(cell.semanticContentAttribute, .forceRightToLeft)
    }

    func testContextCellRegistrationRestoresLatestSnapshotBeforeBusinessHandler() throws {
        let snapshotBox = ReusableSnapshotBox(makeSnapshot(.rightToLeft, revision: 1))
        let context = UIKitLocalizationContext { snapshotBox.snapshot }
        var observedDirections: [UISemanticContentAttribute] = []
        var observedRevisions: [UInt64] = []
        let collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 200),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        let handler: UICollectionView.CellRegistration<
            ReusableTrackingCollectionCell,
            Int
        >.Handler = { cell, _, item in
            observedDirections.append(cell.semanticContentAttribute)
            observedRevisions.append(cell.receivedUpdates.last?.snapshot.revision ?? 0)
            if item == 1 {
                snapshotBox.snapshot = self.makeSnapshot(.leftToRight, revision: 2)
            }
        }
        let registration = context.makeCellRegistration(handler: handler)
        let _: UICollectionView.CellRegistration<
            ReusableTrackingCollectionCell,
            Int
        > = registration
        let dataSource = UICollectionViewDiffableDataSource<Int, Int>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            if item == 2 {
                snapshotBox.snapshot = self.makeSnapshot(.leftToRight, revision: 2)
            }
            return collectionView.dequeueConfiguredReusableCell(
                using: registration,
                for: indexPath,
                item: item
            )
        }
        var dataSnapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        dataSnapshot.appendSections([0])
        dataSnapshot.appendItems([1, 2])
        dataSource.apply(dataSnapshot, animatingDifferences: false)
        collectionView.layoutIfNeeded()

        XCTAssertEqual(observedDirections, [.forceRightToLeft, .forceLeftToRight])
        XCTAssertEqual(observedRevisions, [1, 2])
        _ = dataSource
    }

    func testTableViewLocalizedDequeueRestoresBeforeReturningCell() throws {
        let snapshotBox = ReusableSnapshotBox(makeSnapshot(.rightToLeft, revision: 11))
        let context = UIKitLocalizationContext { snapshotBox.snapshot }
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(
            ReusableTrackingTableCell.self,
            forCellReuseIdentifier: "TrackingCell"
        )

        let firstCell: ReusableTrackingTableCell = tableView.dequeueLocalizedReusableCell(
            withIdentifier: "TrackingCell",
            for: IndexPath(row: 0, section: 0),
            using: context
        )
        XCTAssertEqual(firstCell.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(try XCTUnwrap(firstCell.receivedUpdates.last).snapshot.revision, 11)

        snapshotBox.snapshot = makeSnapshot(.leftToRight, revision: 12)
        let secondCell: ReusableTrackingTableCell = tableView.dequeueLocalizedReusableCell(
            withIdentifier: "TrackingCell",
            for: IndexPath(row: 1, section: 0),
            using: context
        )
        XCTAssertEqual(secondCell.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(try XCTUnwrap(secondCell.receivedUpdates.last).snapshot.revision, 12)
    }

    func testContextSupplementaryRegistrationRestoresBeforeBusinessHandler() throws {
        let context = UIKitLocalizationContext {
            self.makeSnapshot(.rightToLeft, revision: 21)
        }
        var observedDirection: UISemanticContentAttribute?
        var observedRevision: UInt64?
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 40)
        layout.headerReferenceSize = CGSize(width: 320, height: 44)
        let collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 200),
            collectionViewLayout: layout
        )
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewCell, Int> {
            _,
            _,
            _ in
        }
        let supplementaryRegistration: UICollectionView.SupplementaryRegistration<
            ReusableTrackingSupplementaryView
        > = context.makeSupplementaryRegistration(
            elementKind: UICollectionView.elementKindSectionHeader,
            handler: { view, _, _ in
                observedDirection = view.semanticContentAttribute
                observedRevision = view.receivedUpdates.last?.snapshot.revision
            }
        )
        let dataSource = UICollectionViewDiffableDataSource<Int, Int>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration,
                for: indexPath,
                item: item
            )
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(
                using: supplementaryRegistration,
                for: indexPath
            )
        }
        var dataSnapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        dataSnapshot.appendSections([0])
        dataSnapshot.appendItems([1])
        dataSource.apply(dataSnapshot, animatingDifferences: false)
        collectionView.layoutIfNeeded()

        XCTAssertEqual(observedDirection, .forceRightToLeft)
        XCTAssertEqual(observedRevision, 21)
        _ = dataSource
    }

    func testTableViewLocalizedHeaderFooterDequeueRestoresConfiguration() throws {
        let context = UIKitLocalizationContext {
            self.makeSnapshot(.rightToLeft, revision: 13)
        }
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(
            ReusableTrackingHeaderFooterView.self,
            forHeaderFooterViewReuseIdentifier: "TrackingHeader"
        )

        let header: ReusableTrackingHeaderFooterView? =
            tableView.dequeueLocalizedReusableHeaderFooterView(
                withIdentifier: "TrackingHeader",
                using: context
            )

        XCTAssertEqual(try XCTUnwrap(header).semanticContentAttribute, .forceRightToLeft)
        XCTAssertTrue(
            try XCTUnwrap(header?.receivedUpdates.last).reasons.contains(.configuration)
        )
    }

    private func makeSnapshot(
        _ direction: AppUserInterfaceLayoutDirection,
        revision: UInt64
    ) -> LocalizationSnapshot {
        LocalizationSnapshot(
            locale: direction == .rightToLeft ? .arabic : .englishUS,
            followsSystemLocale: false,
            revision: revision
        )
    }
}

@MainActor
private final class ReusableTrackingTableCell: UITableViewCell, UIKitLocalizationApplying {
    private(set) var receivedUpdates: [UIKitLocalizationUpdate] = []

    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        receivedUpdates.append(update)
    }
}

@MainActor
private final class ReusableTrackingCollectionCell: UICollectionViewCell,
    UIKitLocalizationApplying {
    private(set) var receivedUpdates: [UIKitLocalizationUpdate] = []

    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        receivedUpdates.append(update)
    }
}

@MainActor
private final class ReusableTrackingHeaderFooterView: UITableViewHeaderFooterView,
    UIKitLocalizationApplying {
    private(set) var receivedUpdates: [UIKitLocalizationUpdate] = []

    convenience init() {
        self.init(reuseIdentifier: nil)
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        receivedUpdates.append(update)
    }
}

@MainActor
private final class ReusableTrackingSupplementaryView: UICollectionReusableView,
    UIKitLocalizationApplying {
    private(set) var receivedUpdates: [UIKitLocalizationUpdate] = []

    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        receivedUpdates.append(update)
    }
}

@MainActor
private final class ReusableContentConfigurationTracker {
    var materializationCount = 0
}

private struct ReusableTrackingContentConfiguration: UIContentConfiguration {
    let tracker: ReusableContentConfigurationTracker

    func makeContentView() -> UIView & UIContentView {
        tracker.materializationCount += 1
        return ReusableTrackingContentView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> Self {
        self
    }
}

private final class ReusableTrackingContentView: UIView, UIContentView {
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
private final class ReusableSnapshotBox {
    var snapshot: LocalizationSnapshot

    init(_ snapshot: LocalizationSnapshot) {
        self.snapshot = snapshot
    }
}
#endif
