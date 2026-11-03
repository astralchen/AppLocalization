#if canImport(UIKit)
import UIKit

/// 本地化输入控件的文本对齐策略。
///
/// 对齐方式不会改变文本的自然书写顺序。
public enum UIKitTextInputAlignmentPolicy: Equatable, Sendable {
    /// 将文本对齐到应用布局方向的前缘。
    case followLayoutDirection

    /// 使用指定的文本对齐方式，不受应用布局方向影响。
    case fixed(NSTextAlignment)
}

/// 使文本输入控件的方向和对齐方式与应用本地化状态同步的对象。
///
/// 通过 ``UIKitLocalizationContext`` 创建绑定，并在输入控件的生命周期内持有它。
/// 绑定弱引用控件，并保留控件现有的代理。
///
/// 编辑通知会自动刷新绑定。区域设置变化、重新挂载或通过代码修改文本、选区、
/// 输入属性后，应调用 ``refresh()``。存在输入法组合文本时，延后方向和对齐更新。
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

    /// 使用最新本地化快照更新输入控件的方向和对齐方式。
    ///
    /// 保留现有文本，仅在需要时修改段落对齐。输入控件存在组合文本时不执行更新；
    /// 后续编辑通知或显式刷新会应用当前快照。
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
        // 同时延后方向和对齐更新，保留输入法组合文本。
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
        // 在 UIKit 和代理完成更新后合并执行第二次刷新。
        // 执行排队的刷新时重新读取当前快照。
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
        // 通过设置段落对齐保留默认属性，避免覆盖富文本各范围的字体和颜色。
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
        // 原地更新段落属性，保留文本、附件和选区。
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
