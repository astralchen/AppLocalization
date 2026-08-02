/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import Foundation
import AppLocalization

enum TodayError: LocalizedError {
    case accessDenied
    case accessRestricted
    case failedReadingCalendarItem
    case failedReadingReminders
    case reminderHasNoDueDate
    case unknown

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return NSLocalizedString(
                "The app doesn't have permission to read reminders.",
                comment: "access denied error description"
            )
        case .accessRestricted:
            return NSLocalizedString(
                "This device doesn't allow access to reminders.",
                comment: "access restricted error description"
            )
        case .failedReadingCalendarItem:
            return NSLocalizedString(
                "Failed to read a calendar item.",
                comment: "failed reading calendar item error description"
            )
        case .failedReadingReminders:
            return NSLocalizedString(
                "Failed to read reminders.",
                comment: "failed reading reminders error description"
            )
        case .reminderHasNoDueDate:
            return NSLocalizedString(
                "A reminder has no due date.",
                comment: "reminder has no due date error description"
            )
        case .unknown:
            return NSLocalizedString("An unknown error occurred.", comment: "unknown error description")
        }
    }

    @MainActor
    func localizedDescription(resolver: LocalizedStringResolver) -> String {
        switch self {
        case .accessDenied:
            return resolver.string("error.access.denied", bundle: .main)
        case .accessRestricted:
            return resolver.string("error.access.restricted", bundle: .main)
        case .failedReadingCalendarItem:
            return resolver.string("error.failed.calendar.item", bundle: .main)
        case .failedReadingReminders:
            return resolver.string("error.failed.reminders", bundle: .main)
        case .reminderHasNoDueDate:
            return resolver.string("error.no.due.date", bundle: .main)
        case .unknown:
            return resolver.string("error.unknown", bundle: .main)
        }
    }
}
