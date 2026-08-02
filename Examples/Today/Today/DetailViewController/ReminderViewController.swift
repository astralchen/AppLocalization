/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import UIKit
import AppLocalization

class ReminderViewController: UICollectionViewController, LocalizedContentUpdating, UserInterfaceLayoutDirectionUpdating {
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
        var listConfiguration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        listConfiguration.showsSeparators = false
        listConfiguration.headerMode = .firstItemInSection
        let listLayout = UICollectionViewCompositionalLayout.list(using: listConfiguration)
        super.init(collectionViewLayout: listLayout)
    }

    required init?(coder: NSCoder) {
        fatalError("Always initialize ReminderViewController using init(reminder:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let cellRegistration = UICollectionView.CellRegistration(handler: cellRegistrationHandler)
        dataSource = DataSource(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: Row) in
            return collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration, for: indexPath, item: itemIdentifier)
        }

        navigationItem.style = .navigator
        cancelButton.target = self
        cancelButton.action = #selector(didCancelEdit)
        editDoneButton.target = self
        editDoneButton.action = #selector(didToggleEditing)

        reloadLocalizedContent()
        reloadLayoutDirection(services.localizationController.layoutDirection.uiLayoutDirection)
        if isEditing {
            updateSnapshotForEditing()
        } else {
            updateSnapshotForViewing()
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing {
            prepareForEditing()
        } else {
            if isAddingNewReminder {
                onChange(workingReminder)
            } else {
                prepareForViewing()
            }
        }
        reloadLocalizedContent()
        reloadLayoutDirection(services.localizationController.layoutDirection.uiLayoutDirection)
    }

    func cellRegistrationHandler(cell: UICollectionViewListCell, indexPath: IndexPath, row: Row) {
        let section = section(for: indexPath)
        switch (section, row) {
        case (_, .header(let title)):
            cell.contentConfiguration = headerConfiguration(for: cell, with: title)
        case (.view, _):
            cell.contentConfiguration = defaultConfiguration(for: cell, at: row)
        case (.title, .editableText(let title)):
            cell.contentConfiguration = titleConfiguration(for: cell, with: title)
        case (.date, .editableDate(let date)):
            cell.contentConfiguration = dateConfiguration(for: cell, with: date)
        case (.notes, .editableText(let notes)):
            cell.contentConfiguration = notesConfiguration(for: cell, with: notes)
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

    func reloadLocalizedContent() {
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

        if dataSource != nil {
            if isEditing {
                updateSnapshotForEditing()
            } else {
                updateSnapshotForViewing()
            }
        }
    }

    func reloadLayoutDirection(_ direction: UIUserInterfaceLayoutDirection) {
        let appDirection = direction.appLayoutDirection
        view.semanticContentAttribute = appDirection.semanticContentAttribute
        collectionView.applyUserInterfaceLayoutDirection(appDirection)
        configureNavigationButtons(layoutDirection: direction)
    }

    private func prepareForEditing() {
        configureNavigationButtons(layoutDirection: services.localizationController.layoutDirection.uiLayoutDirection)
        updateSnapshotForEditing()
    }

    private func updateSnapshotForEditing() {
        var snapshot = Snapshot()
        snapshot.appendSections([.title, .date, .notes])
        snapshot.appendItems(
            [
                .header(Section.title.name(resolver: services.resolver)),
                .editableText(workingReminder.title)
            ],
            toSection: .title
        )
        snapshot.appendItems(
            [
                .header(Section.date.name(resolver: services.resolver)),
                .editableDate(workingReminder.dueDate)
            ],
            toSection: .date
        )
        snapshot.appendItems(
            [
                .header(Section.notes.name(resolver: services.resolver)),
                .editableText(workingReminder.notes)
            ],
            toSection: .notes
        )
        dataSource?.apply(snapshot)
    }

    private func prepareForViewing() {
        configureNavigationButtons(layoutDirection: services.localizationController.layoutDirection.uiLayoutDirection)
        if workingReminder != reminder {
            reminder = workingReminder
        }
        updateSnapshotForViewing()
    }

    private func updateSnapshotForViewing() {
        var snapshot = Snapshot()
        snapshot.appendSections([.view])
        snapshot.appendItems(
            [Row.header(""), Row.title, Row.date, Row.time, Row.notes], toSection: .view)
        dataSource?.apply(snapshot)
    }

    private func section(for indexPath: IndexPath) -> Section {
        let sectionNumber = isEditing ? indexPath.section + 1 : indexPath.section
        guard let section = Section(rawValue: sectionNumber) else {
            fatalError("Unable to find matching section")
        }
        return section
    }

    private func configureNavigationButtons(layoutDirection: UIUserInterfaceLayoutDirection) {
        if isEditing {
            navigationItem.setBarButtonItem(
                cancelButton,
                side: .leading,
                layoutDirection: layoutDirection
            )
            navigationItem.setBarButtonItem(
                editDoneButton,
                side: .trailing,
                layoutDirection: layoutDirection
            )
        } else {
            navigationItem.setBarButtonItem(nil, side: .leading, layoutDirection: layoutDirection)
            navigationItem.setBarButtonItem(
                editDoneButton,
                side: .trailing,
                layoutDirection: layoutDirection
            )
        }
    }
}
