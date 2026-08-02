/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import Foundation
import AppLocalization

struct Reminder: Equatable, Identifiable {
    var id: String = UUID().uuidString
    var title: String
    var dueDate: Date
    var notes: String? = nil
    var isComplete: Bool = false
}

extension [Reminder] {
    func indexOfReminder(withId id: Reminder.ID) -> Self.Index {
        guard let index = firstIndex(where: { $0.id == id }) else {
            fatalError()
        }
        return index
    }
}

#if DEBUG
extension Reminder {
    @MainActor
    static func sampleData(resolver: LocalizedStringResolver) -> [Reminder] {
        [
            Reminder(
                title: resolver.string("sample.1.title", bundle: .main),
                dueDate: Date().addingTimeInterval(800.0),
                notes: resolver.string("sample.1.notes", bundle: .main)
            ),
            Reminder(
                title: resolver.string("sample.2.title", bundle: .main),
                dueDate: Date().addingTimeInterval(14000.0),
                notes: resolver.string("sample.2.notes", bundle: .main),
                isComplete: true
            ),
            Reminder(
                title: resolver.string("sample.3.title", bundle: .main),
                dueDate: Date().addingTimeInterval(24000.0),
                notes: resolver.string("sample.3.notes", bundle: .main)
            ),
            Reminder(
                title: resolver.string("sample.4.title", bundle: .main),
                dueDate: Date().addingTimeInterval(3200.0),
                notes: resolver.string("sample.4.notes", bundle: .main),
                isComplete: true
            ),
            Reminder(
                title: resolver.string("sample.5.title", bundle: .main),
                dueDate: Date().addingTimeInterval(60000.0),
                notes: resolver.string("sample.5.notes", bundle: .main)
            ),
            Reminder(
                title: resolver.string("sample.6.title", bundle: .main),
                dueDate: Date().addingTimeInterval(72000.0),
                notes: resolver.string("sample.6.notes", bundle: .main)
            ),
            Reminder(
                title: resolver.string("sample.7.title", bundle: .main),
                dueDate: Date().addingTimeInterval(83000.0),
                notes: resolver.string("sample.7.notes", bundle: .main)
            ),
            Reminder(
                title: resolver.string("sample.8.title", bundle: .main),
                dueDate: Date().addingTimeInterval(92500.0),
                notes: resolver.string("sample.8.notes", bundle: .main)
            ),
            Reminder(
                title: resolver.string("sample.9.title", bundle: .main),
                dueDate: Date().addingTimeInterval(101000.0),
                notes: resolver.string("sample.9.notes", bundle: .main)
            )
        ]
    }
}
#endif
