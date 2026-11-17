import UIKit
import XCTest

@testable import AppLocalization

@MainActor
final class UIKitWindowTransactionTests: XCTestCase {
    func testAllWindowsDirectionPrecedesPageUpdatesAndUnregisteredContentIsNotRefreshed() {
        let controller = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let first = Page()
        let second = Page()
        let windows = [host(first), host(second)]
        for window in windows { coordinator.register(window: window) }
        for page in [first, second] {
            page.onApply = { _ in
                XCTAssertEqual(windows.map(\.effectiveUserInterfaceLayoutDirection), [.rightToLeft, .rightToLeft])
            }
        }
        controller.setLocale(identifier: "ar")
        first.onApply = { _ in }
        second.onApply = { _ in }
        XCTAssertEqual(windows.map(\.effectiveUserInterfaceLayoutDirection), [.rightToLeft, .rightToLeft])
        XCTAssertEqual(first.appliedRevisions, [0, 1])
        XCTAssertEqual(second.appliedRevisions, [0, 1])
        coordinator.unregister(window: windows[1])
        controller.setLocale(identifier: "en-US")
        XCTAssertEqual(windows[0].effectiveUserInterfaceLayoutDirection, .leftToRight)
        // iOS 17+ 同一 Scene 共享方向，注销仅停止该窗口的内容投递。
        if #available(iOS 17.0, *), let scene = windows[0].windowScene, windows[1].windowScene === scene {
            windows[1].updateTraitsIfNeeded()
            XCTAssertEqual(windows[1].effectiveUserInterfaceLayoutDirection, .leftToRight)
        } else {
            XCTAssertEqual(windows[1].effectiveUserInterfaceLayoutDirection, .rightToLeft)
        }
        XCTAssertEqual(second.appliedRevisions, [0, 1])
        let count = second.appliedRevisions.count
        coordinator.synchronize(window: windows[1])
        XCTAssertEqual(second.appliedRevisions.count, count)
    }

    func testWindowRegistryIsWeakAndRepeatedRegistrationDoesNotDuplicateTransactions() {
        let controller = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        weak var releasedWindow: UIWindow?
        autoreleasepool {
            let temporary = UIWindow()
            releasedWindow = temporary
            coordinator.register(window: temporary)
        }
        // 协调器仍存活时，注册窗口可以正常释放。
        XCTAssertNil(releasedWindow)
        let page = Page()
        let window = host(page)
        coordinator.register(window: window)
        coordinator.register(window: window)
        XCTAssertEqual(page.appliedRevisions, [0, 0])
        controller.setLocale(identifier: "ar")
        XCTAssertEqual(page.appliedRevisions, [0, 0, 1])
        coordinator.unregister(window: window)
        coordinator.synchronize()
        controller.setLocale(identifier: "en-US")
        XCTAssertEqual(page.appliedRevisions, [0, 0, 1])
    }

    func testInitialRenderingReentryFinishesBeforeLanguageTransaction() {
        let controller = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let page = Page()
        let child = Page()
        page.addChild(child)
        child.loadViewIfNeeded()
        page.view.addSubview(child.view)
        child.didMove(toParent: page)
        page.onApply = { update in
            if update.snapshot.revision == 0 { controller.setLocale(identifier: "ar") }
        }
        let window = host(page)
        coordinator.register(window: window)
        XCTAssertEqual(page.appliedRevisions, [0, 1])
        XCTAssertEqual(child.appliedRevisions, [0, 1])
        XCTAssertEqual(window.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        XCTAssertEqual(child.view.effectiveUserInterfaceLayoutDirection, .rightToLeft)
    }

    func testPresentedPageAndNavigationStackRetainIdentity() {
        let controller = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let root = Page()
        let detail = Page()
        let navigation = UINavigationController()
        navigation.setViewControllers([root, detail], animated: false)
        let window = host(navigation)
        root.loadViewIfNeeded()
        detail.loadViewIfNeeded()
        let presented = Page()
        detail.present(presented, animated: false)
        presented.loadViewIfNeeded()
        let gesture = navigation.interactivePopGestureRecognizer
        coordinator.register(window: window)
        controller.setLocale(identifier: "ar")
        XCTAssertTrue(navigation.viewControllers[0] === root)
        XCTAssertTrue(navigation.viewControllers[1] === detail)
        XCTAssertTrue(detail.presentedViewController === presented)
        XCTAssertEqual(presented.appliedRevisions.last, 1)
        XCTAssertTrue(navigation.interactivePopGestureRecognizer === gesture)
        detail.dismiss(animated: false)
        withExtendedLifetime(window) {}
    }

    func testCoordinatorAndRegisteredWindowsAreNotRetainedByController() {
        let controller = makeController()
        weak var weakCoordinator: UIWindowSceneLocalizationCoordinator?
        weak var weakWindow: UIWindow?
        // NSHashTable.allObjects 返回的快照由自动释放池管理，池结束后再验证生命周期。
        autoreleasepool {
            let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
            weakCoordinator = coordinator
            let window = UIWindow()
            weakWindow = window
            coordinator.register(window: window)
        }
        XCTAssertNil(weakCoordinator)
        XCTAssertNil(weakWindow)
        controller.setLocale(identifier: "ar")
    }

    func testSeparateCoordinatorsUpdateAllWindowDirectionsBeforeAnyPageContent() {
        let controller = makeController()
        let coordinators = (0..<2).map { _ in UIWindowSceneLocalizationCoordinator(localizationController: controller) }
        let pages = [Page(), Page()]
        let windows = pages.map(host)
        for index in coordinators.indices { coordinators[index].register(window: windows[index]) }
        for page in pages {
            page.onApply = { _ in
                XCTAssertTrue(windows.allSatisfy { $0.effectiveUserInterfaceLayoutDirection == .rightToLeft })
            }
        }
        controller.setLocale(identifier: "ar")
        XCTAssertEqual(pages.map(\.appliedRevisions), [[0, 1], [0, 1]])
        withExtendedLifetime((coordinators, windows)) {}
    }

    @available(iOS 17.0, *)
    func testSceneDirectionReachesUnregisteredWindowWithoutContentDelivery() throws {
        let controller = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let root = Page()
        let window = host(root)
        let scene = try XCTUnwrap(window.windowScene)
        coordinator.register(window: window)
        let other = UIWindow(windowScene: scene)
        let otherPage = Page()
        other.rootViewController = otherPage
        other.makeKeyAndVisible()
        defer { other.isHidden = true; window.isHidden = true }
        for identifier in ["ar", "en-US", "ar"] {
            controller.setLocale(identifier: identifier)
            other.updateTraitsIfNeeded()
            XCTAssertEqual(scene.traitCollection.layoutDirection, controller.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight)
            XCTAssertEqual(otherPage.view.effectiveUserInterfaceLayoutDirection, controller.layoutDirection)
            XCTAssertTrue(otherPage.appliedRevisions.isEmpty)
            XCTAssertEqual(root.view.semanticContentAttribute, .unspecified)
            XCTAssertFalse(root.traitOverrides.contains(UITraitLayoutDirection.self))
        }

    }

    @available(iOS 17.0, *)
    func testWindowFallbackHandsDirectionBackToSceneAfterAttachment() throws {
        let controller = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let sceneWindow = host(UIViewController())
        let scene = try XCTUnwrap(sceneWindow.windowScene)
        defer { sceneWindow.isHidden = true }
        let window = UIWindow()
        window.windowScene = nil
        XCTAssertNil(window.windowScene)
        coordinator.register(window: window)
        controller.setLocale(identifier: "ar")
        XCTAssertEqual(window.traitOverrides.layoutDirection, .rightToLeft)
        XCTAssertTrue(window.traitOverrides.contains(UITraitLayoutDirection.self))
        window.windowScene = scene
        coordinator.synchronize(window: window)
        XCTAssertFalse(window.traitOverrides.contains(UITraitLayoutDirection.self))
        XCTAssertEqual(scene.traitCollection.layoutDirection, .rightToLeft)
        controller.setLocale(identifier: "en-US")
        XCTAssertEqual(window.effectiveUserInterfaceLayoutDirection, .leftToRight)
        XCTAssertEqual(scene.traitCollection.layoutDirection, .leftToRight)
    }

    @available(iOS 17.0, *)
    func testModernInheritancePreservesExplicitChildDirection() {
        let controller = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let root = Page()
        let child = UIViewController()
        root.addChild(child)
        root.view.addSubview(child.view)
        child.didMove(toParent: root)
        child.traitOverrides.layoutDirection = .leftToRight
        let window = host(root)
        defer { window.isHidden = true }
        coordinator.register(window: window)
        controller.setLocale(identifier: "ar")
        XCTAssertEqual(root.view.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        XCTAssertEqual(child.view.effectiveUserInterfaceLayoutDirection, .leftToRight)
        XCTAssertEqual(child.traitOverrides.layoutDirection, .leftToRight)
    }

    func testLegacyChildOverridePreservesOtherTraitsWithoutLoadingViews() {
        let parent = UIViewController()
        let child = UIViewController()
        parent.addChild(child)
        child.didMove(toParent: parent)
        parent.setOverrideTraitCollection(UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark), UITraitCollection(horizontalSizeClass: .compact)
        ]), forChild: child)
        for locale in [AppLocale(identifier: "ar"), AppLocale(identifier: "en-US")] {
            let update = LocalizationUpdate(snapshot: LocalizationSnapshot(locale: locale, followsSystemLocale: false, revision: 1))
            UIWindowSceneLocalizationCoordinator.applyLegacyDirection(update, to: child)
            let traits = parent.overrideTraitCollection(forChild: child)
            XCTAssertEqual(traits?.layoutDirection, locale == AppLocale(identifier: "ar") ? .rightToLeft : .leftToRight)
            XCTAssertEqual(traits?.userInterfaceStyle, .dark)
            XCTAssertEqual(traits?.horizontalSizeClass, .compact)
            XCTAssertFalse(parent.isViewLoaded)
            XCTAssertFalse(child.isViewLoaded)
        }
        child.loadViewIfNeeded()
        let update = LocalizationUpdate(snapshot: LocalizationSnapshot(locale: AppLocale(identifier: "ar"), followsSystemLocale: false, revision: 2))
        UIWindowSceneLocalizationCoordinator.applyLegacyDirection(update, to: child)
        XCTAssertEqual(child.view.semanticContentAttribute, .forceRightToLeft)
    }

    func testLegacyPresentationOverridePreservesOtherTraits() throws {
        let root = UIViewController()
        let window = host(root)
        defer { window.isHidden = true }
        let presented = UIViewController()
        root.present(presented, animated: false)
        defer { root.dismiss(animated: false) }
        let presentation = try XCTUnwrap(presented.presentationController)
        presentation.overrideTraitCollection = UITraitCollection(userInterfaceStyle: .dark)
        let update = LocalizationUpdate(snapshot: LocalizationSnapshot(locale: AppLocale(identifier: "ar"), followsSystemLocale: false, revision: 1))
        UIWindowSceneLocalizationCoordinator.applyLegacyDirection(update, to: presented)
        XCTAssertEqual(presentation.overrideTraitCollection?.layoutDirection, .rightToLeft)
        XCTAssertEqual(presentation.overrideTraitCollection?.userInterfaceStyle, .dark)
        XCTAssertEqual(presented.view.semanticContentAttribute, .forceRightToLeft)
    }

    private func makeController() -> LocalizationController {
        LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "ar"], developmentLocalization: "en-US"),
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "en-US"))
    }

    private func host(_ root: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = root
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }
}

@MainActor
private final class Page: UIViewController, UIKitLocalizationApplying {
    var onApply: (LocalizationUpdate) -> Void = { _ in }
    var appliedRevisions: [UInt64] = []
    func applyLocalization(_ update: LocalizationUpdate) {
        appliedRevisions.append(update.snapshot.revision)
        onApply(update)
    }
}
