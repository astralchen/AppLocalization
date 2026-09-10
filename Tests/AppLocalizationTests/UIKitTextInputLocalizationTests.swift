#if canImport(UIKit)
import UIKit
import XCTest
@testable import AppLocalization

@MainActor
final class UIKitTextInputLocalizationTests: XCTestCase {
    @MainActor
    private final class State {
        var locale: AppLocale = .simplifiedChinese
        var revision: UInt64 = 0
        lazy var context = UIKitLocalizationContext { [unowned self] in
            LocalizationSnapshot(locale: locale, followsSystemLocale: false, revision: revision)
        }
        func select(_ locale: AppLocale) {
            self.locale = locale
            revision += 1
        }
    }

    func testSingleLineAndSecureInputUseFreshSnapshotsAndDefaultParagraphs() {
        for secure in [false, true] {
            let state = State()
            let field = UITextField()
            field.isSecureTextEntry = secure
            let binding = state.context.makeTextInputBinding(to: field)
            for locale in [AppLocale.simplifiedChinese, .arabic, .englishUS, .arabic] {
                state.select(locale)
                for text in ["", "VV77", "uu天", "مرحبا", "hello مرحبا 123"] {
                    field.text = text
                    binding.refresh()
                    let alignment: NSTextAlignment = locale == .arabic ? .right : .left
                    XCTAssertEqual(field.text, text)
                    XCTAssertEqual(field.textAlignment, alignment)
                    XCTAssertEqual((field.defaultTextAttributes[.paragraphStyle] as? NSParagraphStyle)?.alignment, alignment)
                    XCTAssertEqual(field.semanticContentAttribute, locale.layoutDirection.semanticContentAttribute)
                }
            }
        }
    }

    func testSingleLinePreservesExistingRichTextRunsAndSelection() {
        let state = State()
        let field = UITextField()
        let content = NSMutableAttributedString(string: "blue red", attributes: [.foregroundColor: UIColor.blue])
        content.addAttributes([.foregroundColor: UIColor.red, .font: UIFont.boldSystemFont(ofSize: 23)], range: NSRange(location: 5, length: 3))
        field.attributedText = content
        let binding = state.context.makeTextInputBinding(to: field)
        state.select(.arabic)
        binding.refresh()
        XCTAssertEqual(field.attributedText?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .blue)
        XCTAssertEqual(field.attributedText?.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? UIColor, .red)
        XCTAssertEqual(field.attributedText?.attribute(.font, at: 5, effectiveRange: nil) as? UIFont, .boldSystemFont(ofSize: 23))
    }

    func testSearchBindingUsesPublicTextFieldAndMirrorsSearchBar() {
        let state = State()
        let search = UISearchBar()
        let binding = state.context.makeTextInputBinding(to: search)
        state.select(.arabic)
        binding.refresh()
        XCTAssertEqual(search.searchTextField.textAlignment, .right)
        XCTAssertEqual(search.semanticContentAttribute, .forceRightToLeft)
        state.select(.englishUS)
        binding.refresh()
        XCTAssertEqual(search.searchTextField.textAlignment, .left)
    }

    func testFixedAlignmentStillRefreshesInterfaceDirection() {
        let state = State()
        let field = UITextField()
        let binding = state.context.makeTextInputBinding(to: field, alignment: .fixed(.center))
        state.select(.arabic)
        binding.refresh()
        XCTAssertEqual(field.textAlignment, .center)
        XCTAssertEqual(field.semanticContentAttribute, .forceRightToLeft)
    }

    func testTextViewPreservesRichTextAndAttachmentsAcrossDirections() {
        let state = State()
        let view = UITextView()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 7
        paragraph.baseWritingDirection = .natural
        let font = UIFont.boldSystemFont(ofSize: 21)
        let text = NSMutableAttributedString(string: "hello مرحبا\n第二段\n", attributes: [
            .font: font, .foregroundColor: UIColor.red, .paragraphStyle: paragraph,
            .link: URL(string: "https://example.com")!
        ])
        let attachment = NSTextAttachment()
        text.append(NSAttributedString(attachment: attachment))
        view.attributedText = text
        view.selectedRange = NSRange(location: 3, length: 2)
        let binding = state.context.makeTextInputBinding(to: view)
        for locale in [AppLocale.arabic, .simplifiedChinese, .englishUS, .arabic] {
            state.select(locale)
            binding.refresh()
            XCTAssertEqual(view.text, text.string)
            XCTAssertEqual(view.selectedRange, NSRange(location: 3, length: 2))
            XCTAssertTrue(view.textStorage.attribute(.attachment, at: text.length - 1, effectiveRange: nil) as? NSTextAttachment === attachment)
            XCTAssertEqual(view.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, font)
            XCTAssertEqual(view.textStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
            XCTAssertEqual(view.textStorage.attribute(.link, at: 0, effectiveRange: nil) as? URL, URL(string: "https://example.com"))
            let actual = view.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
            XCTAssertEqual(actual?.lineSpacing, 7)
            XCTAssertEqual(actual?.baseWritingDirection, .natural)
            XCTAssertEqual(actual?.alignment, locale == .arabic ? .right : .left)
        }
    }

    func testRefreshRepairsBusinessTypingAttributeResetWithoutReplacingDelegate() {
        let state = State()
        let view = UITextView()
        let delegate = InputDelegate()
        view.delegate = delegate
        let binding = state.context.makeTextInputBinding(to: view)
        state.select(.arabic)
        view.typingAttributes = [.font: UIFont.systemFont(ofSize: 19), .foregroundColor: UIColor.blue]
        binding.refresh()
        XCTAssertTrue(view.delegate === delegate)
        XCTAssertEqual((view.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.alignment, .right)
        XCTAssertEqual(view.typingAttributes[.foregroundColor] as? UIColor, .blue)
        XCTAssertEqual(view.typingAttributes[.font] as? UIFont, .systemFont(ofSize: 19))
    }

    func testEditingNotificationsApplyLatestSnapshotOnlyToBoundInput() {
        let state = State()
        let field = UITextField()
        let other = UITextField()
        let binding = state.context.makeTextInputBinding(to: field)
        state.select(.arabic)
        NotificationCenter.default.post(name: UITextField.textDidChangeNotification, object: other)
        XCTAssertEqual(field.textAlignment, .left)
        NotificationCenter.default.post(name: UITextField.textDidChangeNotification, object: field)
        XCTAssertEqual(field.textAlignment, .right)
        withExtendedLifetime(binding) {}
    }

    func testCompositionDefersUpdatesUntilPublicEditingNotification() {
        let state = State()
        let field = ComposingField()
        let binding = state.context.makeTextInputBinding(to: field)
        field.composing = true
        state.select(.arabic)
        binding.refresh()
        XCTAssertEqual(field.textAlignment, .left)
        state.select(.englishUS)
        state.select(.arabic)
        field.composing = false
        NotificationCenter.default.post(name: UITextField.textDidChangeNotification, object: field)
        XCTAssertEqual(field.textAlignment, .right)
        withExtendedLifetime(binding) {}
    }

    func testBindingDoesNotRetainInputAndCanReleaseWithQueuedRefresh() async {
        let state = State()
        weak var releasedField: UITextField?
        weak var releasedBinding: UIKitTextInputLocalizationBinding?
        var binding: UIKitTextInputLocalizationBinding?
        autoreleasepool {
            let field = UITextField()
            releasedField = field
            binding = state.context.makeTextInputBinding(to: field)
            releasedBinding = binding
            NotificationCenter.default.post(name: UITextField.textDidChangeNotification, object: field)
        }
        XCTAssertNil(releasedField)
        binding?.refresh()
        binding = nil
        await Task.yield()
        XCTAssertNil(releasedBinding)
    }

    private final class InputDelegate: NSObject, UITextViewDelegate {}
    /// 此替身只验证延后策略；真实拼音组合输入另由演示工程的模拟器测试覆盖。
    private final class ComposingField: UITextField {
        var composing = false
        override var markedTextRange: UITextRange? { composing ? CompositionRange() : nil }
    }
    private final class CompositionRange: UITextRange {}
}
#endif
