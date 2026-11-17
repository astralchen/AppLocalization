import UIKit
import XCTest
@testable import AppLocalization

@MainActor
final class UIKitTextInputLocalizationTests: XCTestCase {
    func testTransactionKeepsFocusedCustomContentAndSelection() throws {
        let controller = LocalizationController(resourceBundle: localizationTestBundle(["en-US", "ar"], developmentLocalization: "en-US"),
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "en-US"))
        let cell = UICollectionViewListCell(frame: CGRect(x: 0, y: 100, width: 320, height: 60))
        cell.contentConfiguration = EditingConfiguration()
        let content = try XCTUnwrap((cell.contentView as? EditingContent) ?? cell.contentView.subviews.compactMap { $0 as? EditingContent }.first)
        let root = EditingPage(cell: cell)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = root
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        coordinator.register(window: window)
        content.field.text = "draft 123"
        XCTAssertTrue(content.field.becomeFirstResponder())
        let start = try XCTUnwrap(content.field.position(from: content.field.beginningOfDocument, offset: 2))
        let end = try XCTUnwrap(content.field.position(from: start, offset: 3))
        content.field.selectedTextRange = content.field.textRange(from: start, to: end)
        for identifier in ["ar", "en-US"] {
            controller.setLocale(identifier: identifier)
            XCTAssertTrue(cell.contentView === content || cell.contentView.subviews.contains { $0 === content })
            XCTAssertTrue(content.field.isFirstResponder)
            XCTAssertEqual(content.field.text, "draft 123")
            let selection = try XCTUnwrap(content.field.selectedTextRange)
            XCTAssertEqual(content.field.offset(from: content.field.beginningOfDocument, to: selection.start), 2)
            XCTAssertEqual(content.field.offset(from: selection.start, to: selection.end), 3)
        }
        content.field.resignFirstResponder()
        withExtendedLifetime((window, coordinator)) {}
    }

    func testNativeInputsInheritDirectionWithoutBindings() {
        let field = UITextField()
        let secure = UITextField()
        secure.isSecureTextEntry = true
        let textView = UITextView()
        let search = UISearchBar()
        let root = UIViewController()
        let controller = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let window = host(root)
        for input in [field, secure, textView, search] as [UIView] { root.view.addSubview(input) }
        field.textAlignment = .natural
        secure.textAlignment = .natural
        textView.textAlignment = .natural
        field.text = "hello مرحبا 123"
        secure.text = "secret 123"
        textView.text = "第二段\nمرحبا"
        search.text = "query"
        coordinator.register(window: window)
        for identifier in ["ar", "en-US", "ar"] {
            controller.setLocale(identifier: identifier)
            let direction = controller.layoutDirection
            for input in [field, secure, textView, search] as [UIView] {
                XCTAssertEqual(input.effectiveUserInterfaceLayoutDirection, direction)
            }
            XCTAssertEqual(field.textAlignment, .natural)
            XCTAssertEqual(secure.textAlignment, .natural)
            XCTAssertEqual(textView.textAlignment, .natural)
            XCTAssertEqual(field.text, "hello مرحبا 123")
            XCTAssertEqual(secure.text, "secret 123")
            XCTAssertEqual(textView.text, "第二段\nمرحبا")
            XCTAssertEqual(search.text, "query")
        }
        withExtendedLifetime(window) {}
    }

    func testNativeTextViewKeepsEditingSelectionRichTextAndDelegate() {
        let controller = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let root = UIViewController()
        let window = host(root)
        let view = UITextView(frame: CGRect(x: 0, y: 100, width: 320, height: 200))
        let delegate = InputDelegate()
        view.delegate = delegate
        root.view.addSubview(view)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .natural
        paragraph.lineSpacing = 7
        let font = UIFont.boldSystemFont(ofSize: 21)
        let text = NSMutableAttributedString(string: "hello مرحبا\n第二段\n", attributes: [
            .font: font, .foregroundColor: UIColor.red, .paragraphStyle: paragraph
        ])
        let attachment = NSTextAttachment()
        text.append(NSAttributedString(attachment: attachment))
        view.attributedText = text
        coordinator.register(window: window)
        XCTAssertTrue(view.becomeFirstResponder())
        view.selectedRange = NSRange(location: 3, length: 2)
        for identifier in ["ar", "en-US", "ar"] {
            controller.setLocale(identifier: identifier)
            XCTAssertTrue(view.isFirstResponder)
            XCTAssertTrue(view.delegate === delegate)
            XCTAssertEqual(view.selectedRange, NSRange(location: 3, length: 2))
            XCTAssertEqual(view.text, text.string)
            XCTAssertTrue(view.textStorage.attribute(.attachment, at: text.length - 1, effectiveRange: nil) as? NSTextAttachment === attachment)
            XCTAssertEqual(view.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, font)
            XCTAssertEqual(view.textStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
            let actual = view.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
            XCTAssertEqual(actual?.lineSpacing, 7)
            XCTAssertEqual(actual?.alignment, .natural)
        }
        view.resignFirstResponder()
        withExtendedLifetime(window) {}
    }

    func testApplicationDoesNotOverrideNativeFixedInputPolicy() {
        let controller = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let root = UIViewController()
        let window = host(root)
        let phone = UITextField()
        phone.semanticContentAttribute = .forceLeftToRight
        phone.textAlignment = .center
        phone.text = "+1 234 567"
        root.view.addSubview(phone)
        coordinator.register(window: window)
        controller.setLocale(identifier: "ar")
        XCTAssertEqual(phone.effectiveUserInterfaceLayoutDirection, .leftToRight)
        XCTAssertEqual(phone.textAlignment, .center)
        XCTAssertEqual(phone.text, "+1 234 567")
        withExtendedLifetime(window) {}
    }

    private func makeController() -> LocalizationController {
        LocalizationController(resourceBundle: localizationTestBundle(["en-US", "ar"], developmentLocalization: "en-US"),
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "en-US"))
    }

    private func host(_ root: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = root
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }

    private final class InputDelegate: NSObject, UITextViewDelegate {}
}

private struct EditingConfiguration: UIContentConfiguration {
    func makeContentView() -> UIView & UIContentView { EditingContent(self) }
    func updated(for state: any UIConfigurationState) -> EditingConfiguration { self }
}

@MainActor
private final class EditingContent: UIView, UIContentView {
    let field = UITextField(frame: CGRect(x: 10, y: 5, width: 300, height: 50))
    var configuration: any UIContentConfiguration
    init(_ configuration: EditingConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        addSubview(field)
    }
    required init?(coder: NSCoder) { fatalError() }
}

@MainActor
private final class EditingPage: UIViewController {
    let cell: UICollectionViewListCell
    init(cell: UICollectionViewListCell) {
        self.cell = cell
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() { super.viewDidLoad(); view.addSubview(cell) }
}
