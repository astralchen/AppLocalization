/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import Foundation
import AppLocalization

extension ReminderViewController {
    enum Section: Int, Hashable {
        case view
        case title
        case date
        case notes

        @MainActor
        func name(resolver: LocalizedStringResolver) -> String {
            switch self {
            case .view: return ""
            case .title:
                return resolver.string("section.title", bundle: .main)
            case .date:
                return resolver.string("section.date", bundle: .main)
            case .notes:
                return resolver.string("section.notes", bundle: .main)
            }
        }
    }
}
