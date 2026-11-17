/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import UIKit

extension ReminderViewController {
    enum Row: Hashable {
        case header(Section)
        case date
        case notes
        case time
        case title
        case editableDate
        case editableTitle
        case editableNotes

        var imageName: String? {
            switch self {
            case .date: return "calendar.circle"
            case .notes: return "square.and.pencil"
            case .time: return "clock"
            default: return nil
            }
        }

        var image: UIImage? {
            guard let imageName else { return nil }
            let configuration = UIImage.SymbolConfiguration(textStyle: .headline)
            return UIImage(systemName: imageName, withConfiguration: configuration)
        }

        var textStyle: UIFont.TextStyle {
            switch self {
            case .title: return .headline
            default: return .subheadline
            }
        }
    }
}
