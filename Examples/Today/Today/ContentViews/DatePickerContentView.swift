/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import UIKit

class DatePickerContentView: UIView, UIContentView {
    struct Configuration: UIContentConfiguration {
        var date = Date.now
        var locale = Locale.current
        var onChange: (Date) -> Void = { _ in }

        func makeContentView() -> UIView & UIContentView {
            return DatePickerContentView(self)
        }
    }

    let datePicker = UIDatePicker()
    var configuration: UIContentConfiguration {
        didSet {
            configure(configuration: configuration)
        }
    }

    init(_ configuration: UIContentConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        addPinnedSubview(datePicker)
        datePicker.addTarget(self, action: #selector(didPick(_:)), for: .valueChanged)
        datePicker.preferredDatePickerStyle = .inline
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(configuration: UIContentConfiguration) {
        guard let configuration = configuration as? Configuration else { return }
        datePicker.date = configuration.date
        datePicker.locale = configuration.locale
        datePicker.semanticContentAttribute =
            TodayLocalizationServices.shared.localizationController.layoutDirection.semanticContentAttribute
    }

    @objc private func didPick(_ sender: UIDatePicker) {
        guard let configuration = configuration as? DatePickerContentView.Configuration else { return }
        configuration.onChange(sender.date)
    }
}

extension UICollectionViewListCell {
    func datePickerConfiguration() -> DatePickerContentView.Configuration {
        DatePickerContentView.Configuration()
    }
}
