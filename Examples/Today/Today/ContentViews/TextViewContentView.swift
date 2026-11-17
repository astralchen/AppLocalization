/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import UIKit

class TextViewContentView: UIView, UIContentView {
    struct Configuration: UIContentConfiguration {
        var text: String? = ""
        var onChange: (String) -> Void = { _ in }

        func makeContentView() -> UIView & UIContentView {
            return TextViewContentView(self)
        }

        // 此配置不随 cell 的选中或高亮状态改变。
        func updated(for state: any UIConfigurationState) -> Self { self }
    }

    let textView = UITextView()
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
        addPinnedSubview(textView, height: 200)
        textView.backgroundColor = nil
        textView.delegate = self
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textAlignment = .natural
        configure(configuration: configuration)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(configuration: UIContentConfiguration) {
        guard let configuration = configuration as? Configuration else { return }
        // 相同配置不重写编辑内容，避免重配置打断选区和组合输入。
        if (textView.text ?? "") != (configuration.text ?? ""), textView.markedTextRange == nil {
            textView.text = configuration.text
        }
    }
}


extension TextViewContentView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        guard let configuration = configuration as? TextViewContentView.Configuration else { return }
        configuration.onChange(textView.text)
    }
}
