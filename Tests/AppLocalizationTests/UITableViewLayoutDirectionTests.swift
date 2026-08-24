#if canImport(UIKit)
import UIKit
import XCTest
@testable import AppLocalization

@MainActor
final class UITableViewLayoutDirectionTests: XCTestCase {
    func testAppliesSemanticDirectionWithoutReloadingData() {
        let cell = DirectionObservingCell()
        let dataSource = TableDataSource(rowCounts: [1]) { _ in cell }
        let fixture = makeTableFixture()
        let tableView = fixture.tableView
        tableView.dataSource = dataSource
        tableView.reloadData()
        tableView.layoutIfNeeded()
        let reloadCount = tableView.reloadDataCallCount
        let cellRequestCount = dataSource.cellRequestCount
        let layoutPassCount = cell.layoutPassCount

        tableView.applyLocalization(
            makeUpdate(.rightToLeft),
            preservingVisibleRow: false
        )

        XCTAssertEqual(tableView.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(cell.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(cell.contentView.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(tableView.reloadDataCallCount, reloadCount)
        XCTAssertEqual(dataSource.cellRequestCount, cellRequestCount)
        XCTAssertGreaterThan(cell.layoutPassCount, layoutPassCount)
        XCTAssertEqual(cell.observedLayoutDirections.last, .rightToLeft)

        tableView.applyLocalization(
            makeUpdate(.leftToRight),
            preservingVisibleRow: false
        )

        XCTAssertEqual(tableView.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(cell.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(cell.contentView.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(tableView.reloadDataCallCount, reloadCount)
        XCTAssertEqual(dataSource.cellRequestCount, cellRequestCount)
    }

    func testRefreshesVisibleCellLayoutAndDirectionCallback() throws {
        let cell = DirectionTrackingCell()
        let dataSource = TableDataSource(rowCounts: [1]) { _ in cell }
        let fixture = makeTableFixture()
        let tableView = fixture.tableView
        tableView.dataSource = dataSource
        tableView.reloadData()
        tableView.layoutIfNeeded()
        XCTAssertTrue(tableView.visibleCells.contains { $0 === cell })
        let layoutPassCount = cell.layoutPassCount
        let configurationUpdateCount = cell.configurationUpdateCount

        tableView.applyLocalization(makeUpdate(.rightToLeft))

        XCTAssertEqual(try XCTUnwrap(cell.receivedDirections.last), .rightToLeft)
        XCTAssertEqual(cell.semanticContentAttribute, .forceRightToLeft)
        XCTAssertGreaterThan(cell.layoutPassCount, layoutPassCount)
        XCTAssertGreaterThan(cell.configurationUpdateCount, configurationUpdateCount)
    }

    func testRefreshesVisibleHeaderLayoutAndDirectionCallback() throws {
        let header = DirectionTrackingHeaderFooterView(reuseIdentifier: nil)
        let dataSource = TableDataSource(rowCounts: [1])
        let delegate = TableHeaderDelegate(header: header)
        let fixture = makeTableFixture()
        let tableView = fixture.tableView
        tableView.dataSource = dataSource
        tableView.delegate = delegate
        tableView.reloadData()
        tableView.layoutIfNeeded()
        XCTAssertTrue(tableView.headerView(forSection: 0) === header)
        let layoutPassCount = header.layoutPassCount
        let configurationUpdateCount = header.configurationUpdateCount

        tableView.applyLocalization(makeUpdate(.rightToLeft))

        XCTAssertEqual(try XCTUnwrap(header.receivedDirections.last), .rightToLeft)
        XCTAssertGreaterThan(header.layoutPassCount, layoutPassCount)
        XCTAssertGreaterThan(header.configurationUpdateCount, configurationUpdateCount)
    }

    func testRefreshesTableHeaderAndFooterLayoutAndDirectionCallback() {
        let header = DirectionTrackingView(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
        let footer = DirectionTrackingView(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
        let dataSource = TableDataSource(rowCounts: [1])
        let fixture = makeTableFixture()
        let tableView = fixture.tableView
        tableView.dataSource = dataSource
        tableView.tableHeaderView = header
        tableView.tableFooterView = footer
        tableView.reloadData()
        tableView.layoutIfNeeded()
        let headerLayoutPassCount = header.layoutPassCount
        let footerLayoutPassCount = footer.layoutPassCount

        tableView.applyLocalization(makeUpdate(.rightToLeft))

        XCTAssertEqual(header.receivedDirections.last, .rightToLeft)
        XCTAssertEqual(footer.receivedDirections.last, .rightToLeft)
        XCTAssertGreaterThan(header.layoutPassCount, headerLayoutPassCount)
        XCTAssertGreaterThan(footer.layoutPassCount, footerLayoutPassCount)
    }

    func testPreservesTopVisibleRowAndItsRelativePosition() throws {
        let dataSource = TableDataSource(rowCounts: [40])
        let fixture = makeTableFixture()
        let tableView = fixture.tableView
        tableView.dataSource = dataSource
        tableView.rowHeight = 44
        tableView.reloadData()
        tableView.layoutIfNeeded()

        let expectedAnchor = IndexPath(row: 12, section: 0)
        let partialRowOffset: CGFloat = 11
        tableView.setContentOffset(
            CGPoint(
                x: tableView.contentOffset.x,
                y: tableView.rectForRow(at: expectedAnchor).minY + partialRowOffset
            ),
            animated: false
        )
        tableView.layoutIfNeeded()

        let originalAnchor = try XCTUnwrap(tableView.indexPathsForVisibleRows?.sorted().first)
        XCTAssertEqual(originalAnchor, expectedAnchor)
        let originalRelativePosition = tableView.rectForRow(at: originalAnchor).minY
            - tableView.contentOffset.y
        tableView.afterNextLayout = {
            var shiftedOffset = tableView.contentOffset
            shiftedOffset.y += 27
            tableView.contentOffset = shiftedOffset
        }

        tableView.applyLocalization(makeUpdate(.rightToLeft))

        let restoredRows = try XCTUnwrap(tableView.indexPathsForVisibleRows)
        XCTAssertTrue(restoredRows.contains(originalAnchor))
        XCTAssertEqual(
            tableView.rectForRow(at: originalAnchor).minY - tableView.contentOffset.y,
            originalRelativePosition,
            accuracy: 0.5
        )
    }

    func testKeepsDiffableSnapshotWithoutReloadingTable() {
        let fixture = makeTableFixture()
        let tableView = fixture.tableView
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        let dataSource = UITableViewDiffableDataSource<Int, Int>(tableView: tableView) {
            tableView,
            indexPath,
            _ in
            tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        }
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems([1, 2, 3])
        dataSource.apply(snapshot, animatingDifferences: false)
        tableView.layoutIfNeeded()
        let reloadCount = tableView.reloadDataCallCount

        tableView.applyLocalization(makeUpdate(.rightToLeft))

        XCTAssertEqual(tableView.reloadDataCallCount, reloadCount)
        XCTAssertEqual(dataSource.snapshot().sectionIdentifiers, [0])
        XCTAssertEqual(dataSource.snapshot().itemIdentifiers, [1, 2, 3])
    }

    func testHandlesEmptyTable() {
        let dataSource = TableDataSource(rowCounts: [0])
        let fixture = makeTableFixture()
        let tableView = fixture.tableView
        tableView.dataSource = dataSource

        tableView.applyLocalization(makeUpdate(.rightToLeft))

        XCTAssertEqual(tableView.semanticContentAttribute, .forceRightToLeft)
        XCTAssertTrue(tableView.indexPathsForVisibleRows?.isEmpty ?? true)
    }

    private func makeTableFixture() -> TableFixture {
        TableFixture(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
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
}

@MainActor
private final class TableDataSource: NSObject, UITableViewDataSource {
    var rowCounts: [Int]
    private(set) var cellRequestCount = 0
    private let cellProvider: (IndexPath) -> UITableViewCell

    init(
        rowCounts: [Int],
        cellProvider: @escaping (IndexPath) -> UITableViewCell = { _ in
            UITableViewCell(style: .default, reuseIdentifier: nil)
        }
    ) {
        self.rowCounts = rowCounts
        self.cellProvider = cellProvider
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        rowCounts.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rowCounts[section]
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        cellRequestCount += 1
        return cellProvider(indexPath)
    }
}

@MainActor
private final class DirectionObservingCell: UITableViewCell {
    private(set) var layoutPassCount = 0
    private(set) var observedLayoutDirections: [UIUserInterfaceLayoutDirection] = []

    override func layoutSubviews() {
        layoutPassCount += 1
        observedLayoutDirections.append(effectiveUserInterfaceLayoutDirection)
        super.layoutSubviews()
    }
}

@MainActor
private final class DirectionTrackingCell: UITableViewCell, UIKitLocalizationApplying {
    private(set) var receivedDirections: [UIUserInterfaceLayoutDirection] = []
    private(set) var layoutPassCount = 0
    private(set) var configurationUpdateCount = 0

    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        receivedDirections.append(update.layoutDirection)
        semanticContentAttribute = update.semanticContentAttribute
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        configurationUpdateCount += 1
        super.updateConfiguration(using: state)
    }

    override func layoutSubviews() {
        layoutPassCount += 1
        super.layoutSubviews()
    }
}

@MainActor
private final class DirectionTrackingHeaderFooterView: UITableViewHeaderFooterView,
    UIKitLocalizationApplying {
    private(set) var receivedDirections: [UIUserInterfaceLayoutDirection] = []
    private(set) var layoutPassCount = 0
    private(set) var configurationUpdateCount = 0

    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        receivedDirections.append(update.layoutDirection)
        semanticContentAttribute = update.semanticContentAttribute
    }

    override func updateConfiguration(using state: UIViewConfigurationState) {
        configurationUpdateCount += 1
        super.updateConfiguration(using: state)
    }

    override func layoutSubviews() {
        layoutPassCount += 1
        super.layoutSubviews()
    }
}

@MainActor
private final class TableHeaderDelegate: NSObject, UITableViewDelegate {
    private let header: UITableViewHeaderFooterView

    init(header: UITableViewHeaderFooterView) {
        self.header = header
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        44
    }
}

@MainActor
private final class DirectionTrackingView: UIView, UIKitLocalizationApplying {
    private(set) var receivedDirections: [UIUserInterfaceLayoutDirection] = []
    private(set) var layoutPassCount = 0

    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        receivedDirections.append(update.layoutDirection)
        semanticContentAttribute = update.semanticContentAttribute
    }

    override func layoutSubviews() {
        layoutPassCount += 1
        super.layoutSubviews()
    }
}

@MainActor
private final class ReloadTrackingTableView: UITableView {
    private(set) var reloadDataCallCount = 0
    var afterNextLayout: (() -> Void)?

    override func reloadData() {
        reloadDataCallCount += 1
        super.reloadData()
    }

    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        let action = afterNextLayout
        afterNextLayout = nil
        action?()
    }
}

@MainActor
private final class TableFixture {
    let tableView: ReloadTrackingTableView
    private let window: UIWindow

    init(frame: CGRect) {
        tableView = ReloadTrackingTableView(frame: frame)
        window = UIWindow(frame: frame)

        let viewController = UIViewController()
        window.rootViewController = viewController
        viewController.view.addSubview(tableView)
        window.isHidden = false
    }
}
#endif
