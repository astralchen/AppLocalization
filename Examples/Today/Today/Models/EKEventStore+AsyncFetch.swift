/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import EventKit
import Foundation

extension EKReminder: @unchecked @retroactive Sendable {}

extension EKEventStore {
    @MainActor
    func reminders(matching predicate: NSPredicate) async throws -> [EKReminder] {
        try await withCheckedThrowingContinuation { continuation in
            fetchReminders(matching: predicate) { reminders in
                if let reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: TodayError.failedReadingReminders)
                }
            }
        }
    }
}
