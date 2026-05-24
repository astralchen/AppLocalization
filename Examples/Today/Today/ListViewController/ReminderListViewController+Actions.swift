/*
 See LICENSE folder for this sample’s licensing information.
 */

import UIKit

extension ReminderListViewController {
    @objc func didPressSettingsButton(_ sender: UIBarButtonItem) {
        let settingsViewController = SettingsViewController()
        let navigationController = UINavigationController(rootViewController: settingsViewController)
        navigationController.view.semanticContentAttribute =
            TodayLocalizationServices.shared.localizationController.layoutDirection.semanticContentAttribute
        present(navigationController, animated: true)
    }

    @objc func eventStoreChanged(_ notification: NSNotification) {
        reminderStoreChanged()
    }

    @objc func didPressDoneButton(_ sender: ReminderDoneButton) {
        guard let id = sender.id else { return }
        completeReminder(withId: id)
    }

    @objc func didPressAddButton(_ sender: UIBarButtonItem) {
        let reminder = Reminder(title: "", dueDate: Date.now)
        let viewController = ReminderViewController(reminder: reminder) { [weak self] reminder in
            self?.addReminder(reminder)
            self?.updateSnapshot()
            self?.dismiss(animated: true)
        }
        viewController.isAddingNewReminder = true
        viewController.setEditing(true, animated: false)
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.view.semanticContentAttribute =
            TodayLocalizationServices.shared.localizationController.layoutDirection.semanticContentAttribute
        present(navigationController, animated: true)
    }

    @objc func didCancelAdd(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }

    @objc func didChangeListStyle(_ sender: UISegmentedControl) {
        listStyle = ReminderListStyle(rawValue: sender.selectedSegmentIndex) ?? .today
        updateSnapshot()
        refreshBackground()
    }
}
