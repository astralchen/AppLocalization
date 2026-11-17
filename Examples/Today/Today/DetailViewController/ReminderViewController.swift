/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import UIKit
import AppLocalization

class ReminderViewController: UICollectionViewController, UIKitLocalizationApplying {
    private typealias DataSource = UICollectionViewDiffableDataSource<Section, Row>
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Row>

    var reminder: Reminder {
        didSet {
            onChange(reminder)
        }
    }
    var workingReminder: Reminder
    var isAddingNewReminder = false
    var onChange: (Reminder) -> Void
    let services = TodayLocalizationServices.shared
    private var dataSource: DataSource?
    private let cancelButton = UIBarButtonItem()
    private let editDoneButton = UIBarButtonItem()

    init(reminder: Reminder, onChange: @escaping (Reminder) -> Void) {
        self.reminder = reminder
        self.workingReminder = reminder
        self.onChange = onChange
        super.init(collectionViewLayout: Self.makeListLayout())
    }

    required init?(coder: NSCoder) {
        fatalError("Always initialize ReminderViewController using init(reminder:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let configure: UICollectionView.CellRegistration<UICollectionViewListCell, Row>.Handler = {
            [weak self] (cell: UICollectionViewListCell, path: IndexPath, row: Row) in
            self?.cellRegistrationHandler(cell: cell, indexPath: path, row: row)
        }
        // 不同内容类型使用独立的原生复用池，避免查看／编辑切换时替换不兼容的内容视图。
        let displayRegistration = UICollectionView.CellRegistration(handler: configure)
        let titleRegistration = UICollectionView.CellRegistration(handler: configure)
        let dateRegistration = UICollectionView.CellRegistration(handler: configure)
        let notesRegistration = UICollectionView.CellRegistration(handler: configure)
        dataSource = DataSource(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: Row) in
            let registration: UICollectionView.CellRegistration<UICollectionViewListCell, Row>
            switch itemIdentifier {
            case .editableTitle: registration = titleRegistration
            case .editableDate: registration = dateRegistration
            case .editableNotes: registration = notesRegistration
            default: registration = displayRegistration
            }
            return collectionView.dequeueConfiguredReusableCell(
                using: registration, for: indexPath, item: itemIdentifier)
        }

        navigationItem.style = .navigator
        cancelButton.target = self
        cancelButton.action = #selector(didCancelEdit)
        editDoneButton.target = self
        editDoneButton.action = #selector(didToggleEditing)

        configureNavigationButtons()
        applyLocalization(LocalizationUpdate(snapshot: services.localizationController.currentSnapshot))
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        configureNavigationButtons()
        if !editing {
            if isAddingNewReminder {
                onChange(workingReminder)
            } else if workingReminder != reminder {
                reminder = workingReminder
            }
        }
        applyLocalization(LocalizationUpdate(snapshot: services.localizationController.currentSnapshot))
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let cell = cell as? UICollectionViewListCell,
              let row = dataSource?.itemIdentifier(for: indexPath) else { return }
        cellRegistrationHandler(cell: cell, indexPath: indexPath, row: row)
    }

    func cellRegistrationHandler(cell: UICollectionViewListCell, indexPath: IndexPath, row: Row) {
        guard let section = dataSource?.sectionIdentifier(for: indexPath.section) else { return }
        switch (section, row) {
        case (_, .header(let section)):
            cell.contentConfiguration = headerConfiguration(for: cell, with: section.name(resolver: services.resolver))
        case (.view, _):
            cell.contentConfiguration = defaultConfiguration(for: cell, at: row)
        case (.title, .editableTitle):
            cell.contentConfiguration = titleConfiguration(with: workingReminder.title)
        case (.date, .editableDate):
            cell.contentConfiguration = dateConfiguration(with: workingReminder.dueDate)
        case (.notes, .editableNotes):
            cell.contentConfiguration = notesConfiguration(with: workingReminder.notes)
        default:
            fatalError("Unexpected combination of section and row.")
        }
        cell.tintColor = .todayPrimaryTint
    }

    @objc func didCancelEdit() {
        if isAddingNewReminder {
            dismiss(animated: true)
            return
        }
        workingReminder = reminder
        setEditing(false, animated: true)
    }

    @objc func didToggleEditing() {
        setEditing(!isEditing, animated: true)
    }

    func applyLocalization(_ update: LocalizationUpdate) {
        guard update.requiresLocalizedContentRefresh else { return }
        title = services.resolver.string(
            isAddingNewReminder ? "reminder.add.title" : "reminder.detail.title",
            bundle: .main
        )
        navigationItem.title = title
        cancelButton.title = services.resolver.string("common.cancel", bundle: .main)
        editDoneButton.title = services.resolver.string(
            isEditing ? "common.done" : "common.edit",
            bundle: .main
        )

        updateSnapshot()
    }

    private func updateSnapshot() {
        guard let dataSource else { return }
        var snapshot = Snapshot()
        if isEditing {
            snapshot.appendSections([.title, .date, .notes])
            snapshot.appendItems([.header(.title), .editableTitle], toSection: .title)
            snapshot.appendItems([.header(.date), .editableDate], toSection: .date)
            snapshot.appendItems([.header(.notes), .editableNotes], toSection: .notes)
        } else {
            snapshot.appendSections([.view])
            snapshot.appendItems([.header(.view), .title, .date, .time, .notes], toSection: .view)
        }
        // 每次刷新只提交一个快照；稳定编辑行 ID 让 UIKit 保留输入视图和编辑状态。
        let existing = Set(dataSource.snapshot().itemIdentifiers)
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter { existing.contains($0) })
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func configureNavigationButtons() {
        navigationItem.leftBarButtonItem = isEditing ? cancelButton : nil
        navigationItem.rightBarButtonItem = editDoneButton
    }

    private static func makeListLayout() -> UICollectionViewCompositionalLayout {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.showsSeparators = false
        configuration.headerMode = .firstItemInSection
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }
}
