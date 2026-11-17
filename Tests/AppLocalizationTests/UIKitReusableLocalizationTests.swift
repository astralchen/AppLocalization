import UIKit
import XCTest
@testable import AppLocalization

@MainActor
final class UIKitReusableLocalizationTests: XCTestCase {
    func testNativeWindowDirectionChangesKeepDataSourceLayoutAndSelection() {
        let fixture = NativeCollectionFixture()
        defer { fixture.window.isHidden = true }
        let layout = fixture.collection.collectionViewLayout
        let snapshot = fixture.dataSource.snapshot()
        let selection = IndexPath(item: 3, section: 0)
        fixture.collection.selectItem(at: selection, animated: false, scrollPosition: [])
        for identifier in ["ar", "en-US", "ar"] {
            fixture.controller.setLocale(identifier: identifier)
            fixture.window.layoutIfNeeded()
            XCTAssertTrue(fixture.collection.collectionViewLayout === layout)
            XCTAssertTrue(fixture.collection.dataSource === fixture.dataSource)
            XCTAssertTrue(fixture.collection.delegate === fixture)
            XCTAssertEqual(fixture.dataSource.snapshot().itemIdentifiers, snapshot.itemIdentifiers)
            XCTAssertEqual(fixture.collection.indexPathsForSelectedItems, [selection])
            XCTAssertEqual(fixture.collection.effectiveUserInterfaceLayoutDirection,
                           fixture.controller.layoutDirection)
        }
    }

    func testNativeTableDequeueAndOffscreenRowsFollowCurrentLanguage() throws {
        let fixture = NativeTableFixture()
        defer { fixture.window.isHidden = true }
        let first = try XCTUnwrap(fixture.table.cellForRow(at: IndexPath(row: 0, section: 0)))
        XCTAssertEqual(first.semanticContentAttribute, .unspecified)
        for identifier in ["ar", "en-US", "ar"] {
            fixture.select(identifier)
            for row in [35, 0] {
                fixture.table.scrollToRow(at: IndexPath(row: row, section: 0), at: .top, animated: false)
                fixture.table.layoutIfNeeded()
                let cell = try XCTUnwrap(fixture.table.cellForRow(at: IndexPath(row: row, section: 0)))
                XCTAssertEqual((cell.contentConfiguration as? UIListContentConfiguration)?.text, identifier)
                XCTAssertEqual(cell.contentView.effectiveUserInterfaceLayoutDirection, fixture.controller.layoutDirection)
            }
            let header = try XCTUnwrap(fixture.table.headerView(forSection: 0))
            XCTAssertEqual(header.effectiveUserInterfaceLayoutDirection, fixture.controller.layoutDirection)
            XCTAssertEqual((header.contentConfiguration as? UIListContentConfiguration)?.text, identifier)
        }
        // 原生代理和数据源保持由业务所有。
        XCTAssertTrue(fixture.table.delegate === fixture)
        XCTAssertTrue(fixture.table.dataSource === fixture)
    }

    func testNativeCollectionRegistrationsAndReconfigurationNeedNoPreparation() throws {
        let fixture = NativeCollectionFixture()
        defer { fixture.window.isHidden = true }
        for identifier in ["ar", "en-US", "ar"] {
            fixture.select(identifier)
            for item in [35, 0] {
                fixture.collection.scrollToItem(at: IndexPath(item: item, section: 0), at: .top, animated: false)
                fixture.collection.layoutIfNeeded()
                let cell = try XCTUnwrap(fixture.collection.cellForItem(at: IndexPath(item: item, section: 0)) as? UICollectionViewListCell)
                XCTAssertEqual((cell.contentConfiguration as? UIListContentConfiguration)?.text, identifier)
                XCTAssertEqual(cell.contentView.effectiveUserInterfaceLayoutDirection, fixture.controller.layoutDirection)
                XCTAssertEqual(cell.accessories.count, 1)
            }
            fixture.collection.setContentOffset(.zero, animated: false)
            fixture.collection.layoutIfNeeded()
            let header = try XCTUnwrap(fixture.collection.supplementaryView(
                forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0)
            ) as? NativeHeader)
            XCTAssertEqual(header.label.text, identifier)
            XCTAssertEqual(header.effectiveUserInterfaceLayoutDirection, fixture.controller.layoutDirection)
        }
        XCTAssertTrue(fixture.collection.delegate === fixture)
        XCTAssertTrue(fixture.collection.dataSource === fixture.dataSource)
    }

    func testDetachedReusableBoundariesInheritNewContainerWithoutAContext() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let parent = UIViewController()
        window.rootViewController = parent
        let containers = [UIViewController(), UIViewController()]
        for (index, child) in containers.enumerated() {
            parent.addChild(child)
            parent.view.addSubview(child.view)
            child.didMove(toParent: parent)
            let direction: UITraitEnvironmentLayoutDirection = index == 0 ? .rightToLeft : .leftToRight
            if #available(iOS 17.0, *) { child.traitOverrides.layoutDirection = direction }
            else { parent.setOverrideTraitCollection(UITraitCollection(layoutDirection: direction), forChild: child) }
        }
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let tableCell = UITableViewCell()
        let collectionCell = UICollectionViewListCell()
        let header = UITableViewHeaderFooterView(reuseIdentifier: nil)
        let supplementary = UICollectionReusableView()
        for child in [containers[0], containers[1], containers[0]] {
            for view in [tableCell, collectionCell, header, supplementary] {
                view.removeFromSuperview()
                child.view.addSubview(view)
                XCTAssertEqual(view.semanticContentAttribute, .unspecified)
                XCTAssertEqual(view.effectiveUserInterfaceLayoutDirection, child.view.effectiveUserInterfaceLayoutDirection)
            }
            XCTAssertEqual(tableCell.contentView.effectiveUserInterfaceLayoutDirection, child.view.effectiveUserInterfaceLayoutDirection)
            XCTAssertEqual(collectionCell.contentView.effectiveUserInterfaceLayoutDirection, child.view.effectiveUserInterfaceLayoutDirection)
        }
    }

    func testNativeListInheritsDirectionWhilePreservingExplicitExceptions() throws {
        let fixture = NativeTableFixture()
        defer { fixture.window.isHidden = true }
        let cell = try XCTUnwrap(fixture.table.cellForRow(at: IndexPath(row: 0, section: 0)))
        let header = try XCTUnwrap(fixture.table.headerView(forSection: 0))
        // 特殊方向属于业务拥有的内容节点，cell 外壳仍由原生列表管理。
        let fixed = UILabel()
        let spatial = UIView()
        let playback = UIView()
        cell.contentView.addSubview(fixed)
        cell.contentView.addSubview(spatial)
        header.contentView.addSubview(playback)
        fixed.semanticContentAttribute = .forceLeftToRight
        spatial.semanticContentAttribute = .spatial
        playback.semanticContentAttribute = .playback
        fixture.select("ar")
        XCTAssertEqual(fixed.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(fixed.effectiveUserInterfaceLayoutDirection, .leftToRight)
        XCTAssertEqual(spatial.semanticContentAttribute, .spatial)
        XCTAssertEqual(playback.semanticContentAttribute, .playback)
    }

    func testNativeListKeepsCustomContentInstancesDuringWindowDirectionChanges() throws {
        let fixture = NativeTableFixture()
        defer { fixture.window.isHidden = true }
        let cell = try XCTUnwrap(fixture.table.cellForRow(at: IndexPath(row: 0, section: 0)))
        let header = try XCTUnwrap(fixture.table.headerView(forSection: 0))
        let tracker = ContentTracker()
        cell.contentConfiguration = CustomConfiguration(tracker: tracker)
        header.contentConfiguration = CustomConfiguration(tracker: tracker)
        let cellContent = cell.contentView
        let headerContent = header.contentView
        let count = tracker.count
        fixture.controller.setLocale(identifier: "ar")
        XCTAssertEqual(tracker.count, count)
        XCTAssertTrue(cell.contentView === cellContent)
        XCTAssertTrue(header.contentView === headerContent)
    }
}

@MainActor
private func nativeController() -> LocalizationController {
    LocalizationController(resourceBundle: localizationTestBundle(["en-US", "ar"], developmentLocalization: "en-US"),
        preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "en-US"))
}

@MainActor
private final class NativeTableFixture: NSObject, UITableViewDataSource, UITableViewDelegate {
    let controller = nativeController()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    let table = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), style: .plain)
    lazy var coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)

    override init() {
        super.init()
        let root = UIViewController()
        root.view.addSubview(table)
        window.rootViewController = root
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        table.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "header")
        table.rowHeight = 52
        table.sectionHeaderHeight = 40
        table.dataSource = self
        table.delegate = self
        window.makeKeyAndVisible()
        table.reloadData()
        window.layoutIfNeeded()
        coordinator.register(window: window)
    }

    func select(_ identifier: String) {
        controller.setLocale(identifier: identifier)
        for cell in table.visibleCells { render(cell) }
        if let header = table.headerView(forSection: 0) { render(header) }
    }

    func render(_ cell: UITableViewCell) {
        var content = cell.defaultContentConfiguration()
        content.text = controller.currentLocale.identifier
        cell.contentConfiguration = content
    }

    func render(_ header: UITableViewHeaderFooterView) {
        var content = header.defaultContentConfiguration()
        content.text = controller.currentLocale.identifier
        header.contentConfiguration = content
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 40 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        render(cell)
        return cell
    }
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) { render(cell) }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header")!
        render(header)
        return header
    }
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView { render(header) }
    }
}

@MainActor
private final class NativeCollectionFixture: NSObject, UICollectionViewDelegate {
    let controller = nativeController()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    let collection: UICollectionView
    var dataSource: UICollectionViewDiffableDataSource<Int, Int>!
    lazy var coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)

    override init() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 280, height: 52)
        layout.headerReferenceSize = CGSize(width: 320, height: 40)
        collection = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: layout)
        super.init()
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { [weak self] cell, _, _ in
            self?.render(cell)
        }
        let headerRegistration = UICollectionView.SupplementaryRegistration<NativeHeader>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] view, _, _ in view.label.text = self?.controller.currentLocale.identifier }
        dataSource = UICollectionViewDiffableDataSource<Int, Int>(collectionView: collection) { collection, path, item in
            collection.dequeueConfiguredReusableCell(using: registration, for: path, item: item)
        }
        dataSource.supplementaryViewProvider = { collection, _, path in
            collection.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: path)
        }
        collection.delegate = self
        let root = UIViewController()
        root.view.addSubview(collection)
        window.rootViewController = root
        window.makeKeyAndVisible()
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(Array(0..<40))
        dataSource.apply(snapshot, animatingDifferences: false)
        window.layoutIfNeeded()
        coordinator.register(window: window)
    }

    func select(_ identifier: String) {
        controller.setLocale(identifier: identifier)
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
        for case let header as NativeHeader in collection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader) {
            header.label.text = controller.currentLocale.identifier
        }
    }
    func render(_ cell: UICollectionViewListCell) {
        var content = cell.defaultContentConfiguration()
        content.text = controller.currentLocale.identifier
        cell.contentConfiguration = content
        cell.accessories = [.disclosureIndicator()]
    }
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? UICollectionViewListCell { render(cell) }
    }
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView,
                        forElementKind elementKind: String, at indexPath: IndexPath) {
        (view as? NativeHeader)?.label.text = controller.currentLocale.identifier
    }
}

private final class NativeHeader: UICollectionReusableView {
    let label = UILabel()
    override init(frame: CGRect) { super.init(frame: frame); addSubview(label) }
    required init?(coder: NSCoder) { fatalError("请使用 init(frame:)") }
}

@MainActor
private final class ContentTracker { var count = 0 }
private struct CustomConfiguration: UIContentConfiguration {
    let tracker: ContentTracker
    func makeContentView() -> UIView & UIContentView { tracker.count += 1; return CustomContent(self) }
    func updated(for state: UIConfigurationState) -> Self { self }
}
private final class CustomContent: UIView, UIContentView {
    var configuration: any UIContentConfiguration
    init(_ configuration: CustomConfiguration) { self.configuration = configuration; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("请使用配置初始化") }
}
