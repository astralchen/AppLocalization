import AppLocalization
import UIKit
import XCTest
@testable import Today

@MainActor
final class ReminderEditingTests: XCTestCase {
    func testLanguageRoundTripKeepsEditingCellDraftSelectionAndMarkedText() throws {
        let services = TodayLocalizationServices.shared
        let original = services.localizationController.currentSnapshot
        defer {
            if original.followsSystemLocale {
                services.localizationController.setFollowsSystemLocale()
            } else {
                services.localizationController.setLocale(identifier: original.locale.identifier)
            }
        }
        services.localizationController.setLocale(identifier: "en")
        var saved: [Reminder] = []
        let page = ReminderViewController(reminder: Reminder(title: "Original", dueDate: .now)) {
            saved.append($0)
        }
        let navigation = UINavigationController(rootViewController: page)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        services.localizationCoordinator.register(window: window)
        defer {
            services.localizationCoordinator.unregister(window: window)
            window.endEditing(true)
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
        page.setEditing(true, animated: false)
        window.layoutIfNeeded()
        let source = try XCTUnwrap(page.collectionView.dataSource as?
            UICollectionViewDiffableDataSource<ReminderViewController.Section, ReminderViewController.Row>)
        let path = try XCTUnwrap(source.indexPath(for: .editableTitle))
        let cell = try XCTUnwrap(page.collectionView.cellForItem(at: path))
        // 只查询业务拥有的内容视图，不访问 UIKit 私有视图类型。
        let content = try XCTUnwrap((cell.contentView as? TextFieldContentView)
            ?? cell.contentView.subviews.compactMap { $0 as? TextFieldContentView }.first)
        let field = content.textField
        field.text = "Draft 123"
        field.sendActions(for: .editingChanged)
        XCTAssertTrue(field.becomeFirstResponder())
        XCTAssertTrue(window.isKeyWindow)
        let start = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 2))
        let end = try XCTUnwrap(field.position(from: start, offset: 3))
        field.selectedTextRange = field.textRange(from: start, to: end)
        let gesture = navigation.interactivePopGestureRecognizer
        let delegate = gesture?.delegate

        for identifier in ["ar", "zh-Hans", "en"] {
            services.localizationController.setLocale(identifier: identifier)
            XCTAssertTrue(page.isEditing)
            XCTAssertTrue(page.collectionView.cellForItem(at: path) === cell)
            XCTAssertTrue(cell.contentView === content || cell.contentView.subviews.contains { $0 === content })
            XCTAssertTrue(field.isFirstResponder)
            XCTAssertEqual(field.text, "Draft 123")
            XCTAssertEqual(page.workingReminder.title, "Draft 123")
            XCTAssertEqual(page.navigationItem.rightBarButtonItem?.title,
                           services.resolver.string("common.done", bundle: .main))
            XCTAssertTrue(saved.isEmpty)
            let selection = try XCTUnwrap(field.selectedTextRange)
            XCTAssertEqual(field.offset(from: field.beginningOfDocument, to: selection.start), 2)
            XCTAssertEqual(field.offset(from: selection.start, to: selection.end), 3)
            XCTAssertTrue(navigation.interactivePopGestureRecognizer === gesture)
            XCTAssertTrue(navigation.interactivePopGestureRecognizer?.delegate === delegate)
        }

        field.setMarkedText("拼音", selectedRange: NSRange(location: 2, length: 0))
        let markedDraft = field.text
        XCTAssertNotNil(field.markedTextRange)
        services.localizationController.setLocale(identifier: "ar")
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertNotNil(field.markedTextRange)
        XCTAssertEqual(field.text, markedDraft)
        field.unmarkText()
        field.sendActions(for: .editingChanged)
        page.setEditing(false, animated: false)
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.title, markedDraft)
        XCTAssertEqual(source.snapshot().sectionIdentifiers, [.view])
    }

    func testEmptyTitleCaretFollowsApplicationLeadingEdge() throws {
        let services = TodayLocalizationServices.shared
        let original = services.localizationController.currentSnapshot
        defer {
            if original.followsSystemLocale {
                services.localizationController.setFollowsSystemLocale()
            } else {
                services.localizationController.setLocale(identifier: original.locale.identifier)
            }
        }
        services.localizationController.setLocale(identifier: "ar")
        let page = ReminderViewController(reminder: Reminder(title: "", dueDate: .now)) { _ in }
        page.isAddingNewReminder = true
        page.setEditing(true, animated: false)
        let root = UIViewController()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.makeKeyAndVisible()
        services.localizationCoordinator.register(window: window)
        defer {
            services.localizationCoordinator.unregister(window: window)
            window.endEditing(true)
            // 先完成原生弹窗关闭，再移除测试窗口，避免打断外观生命周期。
            let dismissed = expectation(description: "新增提醒弹窗完成关闭")
            root.dismiss(animated: false) { dismissed.fulfill() }
            wait(for: [dismissed], timeout: 5)
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
        let presented = expectation(description: "新增提醒弹窗完成展示")
        root.present(UINavigationController(rootViewController: page), animated: false) {
            presented.fulfill()
        }
        wait(for: [presented], timeout: 5)
        window.layoutIfNeeded()
        let source = try XCTUnwrap(page.collectionView.dataSource as?
            UICollectionViewDiffableDataSource<ReminderViewController.Section, ReminderViewController.Row>)
        let path = try XCTUnwrap(source.indexPath(for: .editableTitle))
        let cell = try XCTUnwrap(page.collectionView.cellForItem(at: path))
        let content = try XCTUnwrap((cell.contentView as? TextFieldContentView)
            ?? cell.contentView.subviews.compactMap { $0 as? TextFieldContentView }.first)
        let field = content.textField
        XCTAssertTrue(field.becomeFirstResponder())
        for identifier in ["ar", "en", "ar", "zh-Hans"] {
            services.localizationController.setLocale(identifier: identifier)
            window.layoutIfNeeded()
            field.layoutIfNeeded()
            XCTAssertEqual(field.text, "")
            XCTAssertTrue(field.isFirstResponder)
            XCTAssertTrue(page.collectionView.cellForItem(at: path) === cell)
            let caret = field.caretRect(for: field.beginningOfDocument)
            XCTAssertGreaterThan(caret.height, 0)
            if identifier == "ar" {
                XCTAssertGreaterThan(caret.midX, field.bounds.width * 0.75, "RTL 空光标应靠右：\(caret)，输入框：\(field.bounds)")
            } else {
                XCTAssertLessThan(caret.midX, field.bounds.width * 0.25, "LTR 空光标应靠左：\(caret)")
            }
        }
        // 方向往返后继续输入，不能通过重新聚焦或替换输入框恢复编辑。
        field.insertText("Draft")
        XCTAssertEqual(field.text, "Draft")
        XCTAssertEqual(page.workingReminder.title, "Draft")
    }

    func testEditingBeforeViewLoadAndCancelKeepNativeConfiguration() throws {
        var saved: [Reminder] = []
        let reminder = Reminder(title: "Original", dueDate: .now, notes: "Notes")
        let page = ReminderViewController(reminder: reminder) { saved.append($0) }
        page.setEditing(true, animated: false)
        page.loadViewIfNeeded()
        let source = try XCTUnwrap(page.collectionView.dataSource as?
            UICollectionViewDiffableDataSource<ReminderViewController.Section, ReminderViewController.Row>)
        XCTAssertEqual(source.snapshot().sectionIdentifiers, [.title, .date, .notes])
        XCTAssertEqual(source.snapshot().itemIdentifiers.filter { $0 == .editableTitle }.count, 1)
        XCTAssertNotNil(page.navigationItem.leftBarButtonItem)
        page.workingReminder.title = "Discard me"
        page.didCancelEdit()
        XCTAssertEqual(page.workingReminder, reminder)
        XCTAssertEqual(page.reminder, reminder)
        XCTAssertTrue(saved.isEmpty)
        XCTAssertFalse(page.isEditing)
        XCTAssertNil(page.navigationItem.leftBarButtonItem)
        XCTAssertEqual(source.snapshot().sectionIdentifiers, [.view])
    }

    func testNewReminderCommitsOnceAfterEditingWasSetBeforeLoading() {
        var saved: [Reminder] = []
        let page = ReminderViewController(reminder: Reminder(title: "", dueDate: .now)) {
            saved.append($0)
        }
        page.isAddingNewReminder = true
        page.setEditing(true, animated: false)
        page.loadViewIfNeeded()
        XCTAssertTrue(saved.isEmpty)
        page.workingReminder.title = "New reminder"
        page.didToggleEditing()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.title, "New reminder")
    }
}
