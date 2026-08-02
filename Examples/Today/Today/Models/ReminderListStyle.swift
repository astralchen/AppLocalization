/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import Foundation
import AppLocalization

enum ReminderListStyle: Int, CaseIterable {
    case today
    case future
    case all

    @MainActor
    func name(resolver: LocalizedStringResolver) -> String {
        switch self {
        case .today:
            return resolver.string("list.today", bundle: .main)
        case .future:
            return resolver.string("list.future", bundle: .main)
        case .all:
            return resolver.string("list.all", bundle: .main)
        }
    }

    func shouldInclude(date: Date, calendar: Calendar) -> Bool {
        let isInToday = calendar.isDateInToday(date)
        switch self {
        case .today:
            return isInToday
        case .future:
            return (date > Date.now) && !isInToday
        case .all:
            return true
        }
    }
}
