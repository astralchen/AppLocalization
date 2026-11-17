import UIKit
import XCTest
@testable import AppLocalization

@MainActor
final class UIKitCustomNavigationItemTests: XCTestCase {
    func testOnlyNavigationCustomViewsInvalidateOnDirectionChanges() {
        let controller = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans", "ar"], developmentLocalization: "en-US"),
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "en-US")
        )
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let root = UIViewController()
        let customView = SizingView()
        let contentView = SizingView()
        root.view.addSubview(contentView)
        root.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: customView)
        let navigation = UINavigationController(rootViewController: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        coordinator.register(window: window)
        let contentInvalidations = contentView.invalidations
        let initialInvalidations = customView.invalidations
        controller.setLocale(identifier: "ar")
        XCTAssertGreaterThan(customView.invalidations, initialInvalidations)
        controller.setLocale(identifier: "en-US")
        let directionInvalidations = customView.invalidations
        controller.setLocale(identifier: "zh-Hans")
        XCTAssertEqual(customView.invalidations, directionInvalidations)
        XCTAssertEqual(contentView.invalidations, contentInvalidations)
    }

    func testCustomNavigationItemsMirrorAndKeepViewsStateAndActions() {
        for initialLocale in ["en-US", "ar"] {
            let controller = LocalizationController(
                resourceBundle: localizationTestBundle(["en-US", "zh-Hans", "ar"], developmentLocalization: "en-US"),
                preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: initialLocale)
            )
            let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
            let root = UIViewController()
            let leading = UIButton(type: .system)
            leading.setTitle("Close", for: .normal)
            let trailing = UIButton(type: .system)
            trailing.setTitle("Done", for: .normal)
            // 自定义内容的方向例外应保留；按钮所在的导航槽位仍随应用换边。
            leading.semanticContentAttribute = .playback
            trailing.semanticContentAttribute = .forceLeftToRight
            let leadingItem = UIBarButtonItem(customView: leading)
            let trailingItem = UIBarButtonItem(customView: trailing)
            root.navigationItem.leftBarButtonItem = leadingItem
            root.navigationItem.rightBarButtonItem = trailingItem
            let navigation = UINavigationController(rootViewController: root)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = navigation
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            let gesture = navigation.interactivePopGestureRecognizer
            let delegate = gesture?.delegate
            var taps = 0
            leading.addAction(UIAction { _ in taps += 1 }, for: .touchUpInside)
            coordinator.register(window: window)

            // 文案始终不变，不借助标题变化、重新安装 item 或延迟回调刷新位置。
            for identifier in ["ar", "en-US", "zh-Hans", "ar", "en-US"] {
                leading.isSelected = true
                leading.isEnabled = false
                leading.isHighlighted = true
                let state = leading.state
                controller.setLocale(identifier: identifier)
                window.layoutIfNeeded()
                navigation.navigationBar.layoutIfNeeded()
                XCTAssertTrue(root.navigationItem.leftBarButtonItem === leadingItem)
                XCTAssertTrue(root.navigationItem.rightBarButtonItem === trailingItem)
                XCTAssertTrue(leadingItem.customView === leading)
                XCTAssertTrue(trailingItem.customView === trailing)
                XCTAssertTrue(leading.window === window)
                XCTAssertTrue(trailing.window === window)
                XCTAssertEqual(leading.state, state)
                XCTAssertEqual(leading.semanticContentAttribute, .playback)
                XCTAssertEqual(trailing.semanticContentAttribute, .forceLeftToRight)
                XCTAssertTrue(navigation.interactivePopGestureRecognizer === gesture)
                XCTAssertTrue(navigation.interactivePopGestureRecognizer?.delegate === delegate)
                let leadingX = leading.convert(leading.bounds, to: window).midX
                let trailingX = trailing.convert(trailing.bounds, to: window).midX
                if identifier == "ar" {
                    XCTAssertGreaterThan(leadingX, trailingX)
                } else {
                    XCTAssertLessThan(leadingX, trailingX)
                }
                leading.isEnabled = true
                leading.sendActions(for: .touchUpInside)
            }
            XCTAssertEqual(taps, 5)
        }
    }
}

@MainActor
private final class SizingView: UIView {
    private(set) var invalidations = 0

    override var intrinsicContentSize: CGSize { CGSize(width: 44, height: 30) }

    override func invalidateIntrinsicContentSize() {
        invalidations += 1
        super.invalidateIntrinsicContentSize()
    }
}
