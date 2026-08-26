/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import UIKit
import AppLocalization

class ReminderListViewController: UICollectionViewController, UIKitLocalizationApplying {
    let services = TodayLocalizationServices.shared
    private let settingsButton = UIBarButtonItem()
    private let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
    var usesLocalizedSampleData = false

    var dataSource: DataSource?
    var reminders: [Reminder] = []
    var listStyle: ReminderListStyle = .today
    var filteredReminders: [Reminder] {
        let calendar = services.localizationController.locale.calendar
        return reminders.filter { listStyle.shouldInclude(date: $0.dueDate, calendar: calendar) }.sorted {
            $0.dueDate < $1.dueDate
        }
    }
    let listStyleSegmentedControl = UISegmentedControl(items: [])
    var headerView: ProgressHeaderView?
    var progress: CGFloat {
        let chunkSize = 1.0 / CGFloat(filteredReminders.count)
        let progress = filteredReminders.reduce(0.0) {
            let chunk = $1.isComplete ? chunkSize : 0
            return $0 + chunk
        }
        return progress
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.backgroundColor = .todayGradientFutureBegin

        let listLayout = listLayout()
        collectionView.collectionViewLayout = listLayout

        let cellRegistration = services.localizationContext.makeCellRegistration(
            handler: cellRegistrationHandler
        )

        dataSource = DataSource(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: Reminder.ID) in
            return collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration, for: indexPath, item: itemIdentifier)
        }

        let headerRegistration = services.localizationContext.makeSupplementaryRegistration(
            elementKind: ProgressHeaderView.elementKind,
            handler: supplementaryRegistrationHandler
        )
        dataSource?.supplementaryViewProvider = { supplementaryView, elementKind, indexPath in
            return self.collectionView.dequeueConfiguredReusableSupplementary(
                using: headerRegistration, for: indexPath)
        }

        addButton.target = self
        addButton.action = #selector(didPressAddButton(_:))
        settingsButton.image = UIImage(systemName: "gearshape")
        settingsButton.target = self
        settingsButton.action = #selector(didPressSettingsButton(_:))

        listStyleSegmentedControl.selectedSegmentIndex = listStyle.rawValue
        listStyleSegmentedControl.addTarget(
            self, action: #selector(didChangeListStyle(_:)), for: .valueChanged)
        navigationItem.titleView = listStyleSegmentedControl
        navigationItem.style = .navigator
        applyLocalization(.initial(snapshot: services.localizationController.currentSnapshot))

        updateSnapshot()

        collectionView.dataSource = dataSource

        prepareReminderStore()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshBackground()
    }
    override func collectionView(
        _ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath
    ) -> Bool {
        let id = filteredReminders[indexPath.item].id
        pushDetailViewForReminder(withId: id)
        return false
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        services.localizationContext.restoreOnAttachment(cell)
    }

    override func collectionView(
        _ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView,
        forElementKind elementKind: String, at indexPath: IndexPath
    ) {
        services.localizationContext.restoreOnAttachment(view)
        guard elementKind == ProgressHeaderView.elementKind,
              let progressView = view as? ProgressHeaderView
        else {
            return
        }
        progressView.progress = progress
    }

    func refreshBackground() {
        collectionView.backgroundView = nil
        let backgroundView = UIView()
        let gradientLayer = CAGradientLayer.gradientLayer(for: listStyle, in: collectionView.frame)
        backgroundView.layer.addSublayer(gradientLayer)
        collectionView.backgroundView = backgroundView
    }

    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        if update.requiresLayoutDirectionRefresh {
            collectionView.applyLocalization(
                update,
                rebuildingLayoutWith: listLayout
            )
            navigationItem.setBarButtonItem(
                settingsButton,
                side: .leading
            )
            navigationItem.setBarButtonItem(
                addButton,
                side: .trailing
            )
        }
        guard update.requiresLocalizedContentRefresh else { return }
        #if DEBUG
        if usesLocalizedSampleData {
            reminders = Reminder.sampleData(resolver: services.resolver)
        }
        #endif
        while listStyleSegmentedControl.numberOfSegments < ReminderListStyle.allCases.count {
            listStyleSegmentedControl.insertSegment(
                withTitle: nil,
                at: listStyleSegmentedControl.numberOfSegments,
                animated: false
            )
        }
        for style in ReminderListStyle.allCases {
            listStyleSegmentedControl.setTitle(
                style.name(resolver: services.resolver),
                forSegmentAt: style.rawValue
            )
        }
        listStyleSegmentedControl.selectedSegmentIndex = listStyle.rawValue
        settingsButton.accessibilityLabel = services.resolver.string(
            "settings.button.accessibility",
            bundle: .main
        )
        addButton.accessibilityLabel = services.resolver.string(
            "accessibility.add.reminder",
            bundle: .main
        )
        updateSnapshot(reloading: filteredReminders.map(\.id))
        headerView?.reloadLocalizedContent()
    }

    func pushDetailViewForReminder(withId id: Reminder.ID) {
        let reminder = reminder(withId: id)
        let viewController = ReminderViewController(reminder: reminder) { [weak self] reminder in
            self?.updateReminder(reminder)
            self?.updateSnapshot(reloading: [reminder.id])
        }
        navigationController?.pushViewController(viewController, animated: true)
    }

    func showError(_ error: Error) {
        let alert = UIAlertController(
            title: services.resolver.string("error.title", bundle: .main),
            message: localizedMessage(for: error),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: services.resolver.string("common.ok", bundle: .main),
                style: .default,
                handler: { [weak self] _ in
                    self?.dismiss(animated: true)
                }))
        present(alert, animated: true, completion: nil)
    }

    private func listLayout() -> UICollectionViewCompositionalLayout {
        var listConfiguration = UICollectionLayoutListConfiguration(appearance: .grouped)
        listConfiguration.headerMode = .supplementary
        listConfiguration.showsSeparators = false
        listConfiguration.trailingSwipeActionsConfigurationProvider = makeSwipeActions
        listConfiguration.backgroundColor = .clear
        return UICollectionViewCompositionalLayout.list(using: listConfiguration)
    }

    private func makeSwipeActions(for indexPath: IndexPath?) -> UISwipeActionsConfiguration? {
        guard let indexPath, let id = dataSource?.itemIdentifier(for: indexPath) else {
            return nil
        }
        let deleteActionTitle = services.resolver.string("reminder.delete", bundle: .main)
        let deleteAction = UIContextualAction(style: .destructive, title: deleteActionTitle) {
            [weak self] _, _, completion in
            self?.deleteReminder(withId: id)
            self?.updateSnapshot()
            completion(false)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    private func localizedMessage(for error: Error) -> String {
        if let todayError = error as? TodayError {
            return todayError.localizedDescription(resolver: services.resolver)
        }
        return error.localizedDescription
    }

    private func supplementaryRegistrationHandler(
        progressView: ProgressHeaderView, elementKind: String, indexPath: IndexPath
    ) {
        headerView = progressView
        progressView.reloadLocalizedContent()
    }

}
