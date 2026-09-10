/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import UIKit
import AppLocalization

class TextFieldContentView: UIView, UIContentView, UIKitLocalizationApplying {
    struct Configuration: UIContentConfiguration {
        var text: String? = ""
        var onChange: (String) -> Void = { _ in }

        func makeContentView() -> UIView & UIContentView {
            return TextFieldContentView(self)
        }
    }

    let textField = UITextField()
    private lazy var inputBinding = TodayLocalizationServices.shared.localizationContext
        .makeTextInputBinding(to: textField)
    var configuration: UIContentConfiguration {
        didSet {
            configure(configuration: configuration)
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 0, height: 44)
    }

    init(_ configuration: UIContentConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        addPinnedSubview(textField, insets: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
        textField.addTarget(self, action: #selector(didChange(_:)), for: .editingChanged)
        textField.clearButtonMode = .whileEditing
        configure(configuration: configuration)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        inputBinding.refresh()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { inputBinding.refresh() }
    }

    func configure(configuration: UIContentConfiguration) {
        guard let configuration = configuration as? Configuration else { return }
        // 相同配置不重写编辑内容，避免重配置打断选区和组合输入。
        if (textField.text ?? "") != (configuration.text ?? ""), textField.markedTextRange == nil {
            textField.text = configuration.text
        }
        inputBinding.refresh()
    }

    @objc private func didChange(_ sender: UITextField) {
        guard let configuration = configuration as? TextFieldContentView.Configuration else { return }
        configuration.onChange(textField.text ?? "")
    }
}

extension UICollectionViewListCell {
    func textFieldConfiguration() -> TextFieldContentView.Configuration {
        TextFieldContentView.Configuration()
    }
}
