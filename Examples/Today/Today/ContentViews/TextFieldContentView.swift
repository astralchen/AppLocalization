/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import UIKit

class TextFieldContentView: UIView, UIContentView {
    struct Configuration: UIContentConfiguration {
        var text: String? = ""
        var layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
        var onChange: (String) -> Void = { _ in }

        func makeContentView() -> UIView & UIContentView {
            return TextFieldContentView(self)
        }

        // 此配置不随 cell 的选中或高亮状态改变。
        func updated(for state: any UIConfigurationState) -> Self { self }
    }

    let textField = UITextField()
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

    func configure(configuration: UIContentConfiguration) {
        guard let configuration = configuration as? Configuration else { return }
        // 标题始终对齐应用前缘，包括没有文字时的光标；书写顺序仍由 UIKit 处理。
        let isRightToLeft = configuration.layoutDirection == .rightToLeft
        textField.semanticContentAttribute = isRightToLeft ? .forceRightToLeft : .forceLeftToRight
        textField.textAlignment = isRightToLeft ? .right : .left
        // 相同配置不重写编辑内容，避免重配置打断选区和组合输入。
        if (textField.text ?? "") != (configuration.text ?? ""), textField.markedTextRange == nil {
            textField.text = configuration.text
        }
    }

    @objc private func didChange(_ sender: UITextField) {
        guard let configuration = configuration as? TextFieldContentView.Configuration else { return }
        configuration.onChange(textField.text ?? "")
    }
}
