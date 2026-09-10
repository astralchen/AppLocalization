#if canImport(UIKit)
import UIKit

/// 输入内容的对齐策略；它不改变字符的自然书写顺序。
public enum UIKitTextInputAlignmentPolicy: Equatable, Sendable {
    case followLayoutDirection
    case fixed(NSTextAlignment)
}

/// 由输入组件持有的本地化绑定。仅管理公开控件，不替换业务代理。
///
/// 语言更新、重新挂载及程序化改写内容、选区或输入属性后调用 `refresh()`。
/// 编辑通知会自动同步；输入法仍在组合文字时，延后文字属性更新到组合结束。
@MainActor
public final class UIKitTextInputLocalizationBinding: NSObject {
    private weak var textField: UITextField?
    private weak var textView: UITextView?
    private weak var searchBar: UISearchBar?
    private let snapshotProvider: @MainActor () -> LocalizationSnapshot
    private let alignment: UIKitTextInputAlignmentPolicy
    private var isRefreshing = false
    private var refreshScheduled = false

    init(
        textField: UITextField? = nil,
        textView: UITextView? = nil,
        searchBar: UISearchBar? = nil,
        alignment: UIKitTextInputAlignmentPolicy,
        snapshotProvider: @escaping @MainActor () -> LocalizationSnapshot
    ) {
        self.textField = searchBar?.searchTextField ?? textField
        self.textView = textView
        self.searchBar = searchBar
        self.alignment = alignment
        self.snapshotProvider = snapshotProvider
        super.init()
        let notifications: [Notification.Name] = textView == nil
            ? [UITextField.textDidBeginEditingNotification, UITextField.textDidChangeNotification,
               UITextField.textDidEndEditingNotification]
            : [UITextView.textDidBeginEditingNotification, UITextView.textDidChangeNotification,
               UITextView.textDidEndEditingNotification]
        for name in notifications {
            NotificationCenter.default.addObserver(
                self, selector: #selector(editingDidChange), name: name,
                object: self.textField ?? self.textView as UIView?
            )
        }
        refresh()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// 读取最新快照并幂等同步，不缓存创建绑定时的语言。
    public func refresh() {
        guard !isRefreshing else { return }
        guard let input = (textField as UIView?) ?? textView else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let snapshot = snapshotProvider()
        let semantic = snapshot.layoutDirection.semanticContentAttribute
        let resolvedAlignment: NSTextAlignment
        switch alignment {
        case .followLayoutDirection:
            resolvedAlignment = snapshot.layoutDirection == .rightToLeft ? .right : .left
        case let .fixed(value):
            resolvedAlignment = value
        }
        // 组合输入期间连同方向一起延后，避免输入系统重新排版破坏 marked text。
        if let field = textField {
            guard field.markedTextRange == nil else { return }
            if searchBar?.semanticContentAttribute != semantic {
                searchBar?.semanticContentAttribute = semantic
            }
            if input.semanticContentAttribute != semantic { input.semanticContentAttribute = semantic }
            refresh(field, alignment: resolvedAlignment)
        } else if let view = textView {
            guard view.markedTextRange == nil else { return }
            if input.semanticContentAttribute != semantic { input.semanticContentAttribute = semantic }
            refresh(view, alignment: resolvedAlignment)
        }
    }

    @objc private func editingDidChange() {
        guard !isRefreshing else { return }
        refresh()
        // UIKit 和业务代理可能在通知之后继续更新输入属性，在本轮编辑完成后合并校正。
        // 异步任务不持有控件或旧快照，也不会自行重复调度。
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshScheduled = false
            self.refresh()
        }
    }

    private func attributes(
        _ original: [NSAttributedString.Key: Any],
        aligned alignment: NSTextAlignment
    ) -> [NSAttributedString.Key: Any] {
        let existing = original[.paragraphStyle] as? NSParagraphStyle
        guard existing?.alignment != alignment else { return original }
        let paragraph = existing?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        paragraph.alignment = alignment
        var result = original
        result[.paragraphStyle] = paragraph
        return result
    }

    private func refresh(_ field: UITextField, alignment: NSTextAlignment) {
        let typing = field.typingAttributes
        // textAlignment 会同步默认段落对齐；直接重写 defaultTextAttributes 会把
        // 已有富文本的局部字体和颜色铺平成默认样式，因此不回写整个属性字典。
        if field.textAlignment != alignment { field.textAlignment = alignment }
        if field.isEditing {
            let updated = attributes(typing ?? field.defaultTextAttributes, aligned: alignment)
            if !NSDictionary(dictionary: field.typingAttributes ?? [:]).isEqual(to: updated) {
                field.typingAttributes = updated
            }
        }
    }

    private func refresh(_ view: UITextView, alignment: NSTextAlignment) {
        let typing = attributes(view.typingAttributes, aligned: alignment)
        // 只修改段落对齐，不替换 attributedText，保留附件身份、字符、选区和撤销栈。
        let storage = view.textStorage
        var changes: [(NSRange, NSParagraphStyle)] = []
        storage.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: storage.length)) {
            value, range, _ in
            let paragraph = value as? NSParagraphStyle
            guard paragraph?.alignment != alignment else { return }
            let updated = paragraph?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            updated.alignment = alignment
            changes.append((range, updated))
        }
        if view.textAlignment != alignment { view.textAlignment = alignment }
        if !changes.isEmpty {
            storage.beginEditing()
            for (range, paragraph) in changes {
                storage.addAttribute(.paragraphStyle, value: paragraph, range: range)
            }
            storage.endEditing()
        }
        if !NSDictionary(dictionary: view.typingAttributes).isEqual(to: typing) {
            view.typingAttributes = typing
        }
    }
}
#endif
