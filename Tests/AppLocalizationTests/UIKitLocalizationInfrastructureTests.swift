import UIKit
import XCTest
@testable import AppLocalization

@MainActor
final class UIKitLocalizationInfrastructureTests: XCTestCase {
    func testConfiguredButtonKeepsIdentityActionsAndPlacementAcrossDirectionChanges() throws {
        let fixture = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: fixture.controller)
        let root = ConfiguredButtonPage()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = root
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let button = root.button
        let identity = ObjectIdentifier(button)
        var taps = 0
        button.addAction(UIAction { _ in taps += 1 }, for: .touchUpInside)
        let plain = UIButton(type: .system)
        plain.setTitle("打开", for: .normal)
        root.view.addSubview(plain)
        coordinator.register(window: window)
        for placement in [NSDirectionalRectEdge.leading, .trailing] {
            root.configuration.imagePlacement = placement
            for identifier in ["ar", "en-US", "en-US", "ar", "en-US"] {
                button.isSelected = true
                button.isEnabled = false
                button.isHighlighted = true
                let stateBefore = button.state
                fixture.controller.setLocale(identifier: identifier)
                XCTAssertEqual(button.state, stateBefore)
                // 同方向同步也配置业务内容，但不能清空已有配置内容。
                let imageBeforeSync = button.imageView
                coordinator.synchronize(window: window)
                XCTAssertTrue(button.imageView === imageBeforeSync)
                for (highlighted, enabled, selected) in [(false, true, false), (true, true, true), (false, false, true), (false, true, false)] {
                    button.isHighlighted = highlighted
                    button.isEnabled = enabled
                    button.isSelected = selected
                    coordinator.synchronize(window: window)
                    window.layoutIfNeeded()
                    button.layoutIfNeeded()
                    XCTAssertEqual(ObjectIdentifier(button), identity)
                    XCTAssertEqual(button.isHighlighted, highlighted)
                    XCTAssertEqual(button.isEnabled, enabled)
                    XCTAssertEqual(button.isSelected, selected)
                    XCTAssertEqual(button.configuration?.title, "详情")
                    XCTAssertEqual(button.configuration?.imagePlacement, placement)
                    XCTAssertEqual(button.configuration?.imagePadding, 8)
                    XCTAssertEqual(plain.semanticContentAttribute, .unspecified)
                    XCTAssertEqual(plain.effectiveUserInterfaceLayoutDirection, fixture.controller.layoutDirection)
                    let image = try XCTUnwrap(button.imageView)
                    let title = try XCTUnwrap(button.titleLabel)
                    let imageFrame = image.convert(image.bounds, to: button)
                    let titleFrame = title.convert(title.bounds, to: button)
                    XCTAssertGreaterThan(imageFrame.width, 0)
                    XCTAssertGreaterThan(titleFrame.width, 0)
                    let imageOnRight = (placement == .leading) == (fixture.controller.layoutDirection == .rightToLeft)
                    if imageOnRight { XCTAssertGreaterThan(imageFrame.minX, titleFrame.maxX) }
                    else { XCTAssertLessThan(imageFrame.maxX, titleFrame.minX) }
                }
                let beforeTap = taps
                button.sendActions(for: .touchUpInside)
                XCTAssertEqual(taps, beforeTap + 1)
            }
        }
    }

    func testCoordinatorUpdatesRegisteredHiddenWindowAndSkipsUnregisteredWindow() {
        let fixture = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(
            localizationController: fixture.controller
        )
        let registeredController = RecordingViewController()
        registeredController.loadViewIfNeeded()
        let registeredWindow = UIWindow()
        registeredWindow.rootViewController = registeredController
        registeredWindow.isHidden = true

        let unregisteredController = RecordingViewController()
        unregisteredController.loadViewIfNeeded()
        let unregisteredWindow = UIWindow()
        unregisteredWindow.rootViewController = unregisteredController

        coordinator.register(window: registeredWindow)
        _ = setLocale(
            AppLocale(identifier: "ar"),
            on: fixture.controller,
            notificationCenter: fixture.notificationCenter
        )


        XCTAssertEqual(registeredWindow.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        XCTAssertEqual(
            registeredController.receivedUpdates.last?.snapshot.revision,
            fixture.controller.currentSnapshot.revision
        )
        XCTAssertEqual(unregisteredWindow.semanticContentAttribute, .unspecified)
        XCTAssertTrue(unregisteredController.receivedUpdates.isEmpty)
    }

    func testCoordinatorDoesNotLoadUnloadedControllerDuringAutomaticDelivery() {
        let fixture = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(
            localizationController: fixture.controller
        )
        let root = RecordingViewController()
        root.loadViewIfNeeded()
        let unloadedChild = RecordingViewController()
        root.addChild(unloadedChild)
        unloadedChild.didMove(toParent: root)
        let window = UIWindow()
        window.rootViewController = root
        coordinator.register(window: window)

        _ = setLocale(
            AppLocale(identifier: "ar"),
            on: fixture.controller,
            notificationCenter: fixture.notificationCenter
        )

        let finalChange = setLocale(
            AppLocale(identifier: "en-US"),
            on: fixture.controller,
            notificationCenter: fixture.notificationCenter
        )


        XCTAssertFalse(unloadedChild.isViewLoaded)
        XCTAssertEqual(window.effectiveUserInterfaceLayoutDirection, .leftToRight)

        XCTAssertEqual(window.effectiveUserInterfaceLayoutDirection, .leftToRight)
        XCTAssertEqual(
            root.receivedUpdates.last?.snapshot.revision,
            finalChange.snapshot.revision
        )
    }

    func testApplicationCanReplaceRootAndSynchronizeLatestLanguage() {
        let fixture = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: fixture.controller)
        let window = UIWindow()
        let initialRoot = RecordingViewController()
        initialRoot.loadViewIfNeeded()
        window.rootViewController = initialRoot
        coordinator.register(window: window)
        let change = setLocale(AppLocale(identifier: "ar"), on: fixture.controller, notificationCenter: fixture.notificationCenter)
        // 业务直接使用 UIKit 替换根控制器，再同步当前状态。
        let replacement = RecordingViewController()
        replacement.loadViewIfNeeded()
        window.rootViewController = replacement
        coordinator.synchronize(window: window)
        XCTAssertTrue(window.rootViewController === replacement)
        XCTAssertEqual(window.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        XCTAssertEqual(replacement.receivedUpdates.last?.snapshot, change.snapshot)
        XCTAssertNil(replacement.receivedUpdates.last?.previousSnapshot)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        XCTAssertEqual(replacement.view.effectiveUserInterfaceLayoutDirection, .rightToLeft)
        window.isHidden = true
    }

    @available(iOS 17.0, *)
    func testCoordinatorSynchronizesNavigationEnvironmentOnArabicRegistration() {
        let fixture = makeController()
        _ = setLocale(AppLocale(identifier: "ar"), on: fixture.controller, notificationCenter: fixture.notificationCenter)
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: fixture.controller)
        let root = RecordingViewController()
        let navigation = UINavigationController(rootViewController: root)
        let window = UIWindow()
        // 模拟系统仍使用从左到右布局，但应用已选择阿拉伯语。
        window.rootViewController = navigation
        navigation.loadViewIfNeeded()
        root.loadViewIfNeeded()
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        if let scene = window.windowScene { scene.traitOverrides.layoutDirection = .leftToRight }
        else { window.traitOverrides.layoutDirection = .leftToRight }

        coordinator.register(window: window)

        XCTAssertEqual(navigation.traitCollection.layoutDirection, .rightToLeft)
        XCTAssertEqual(navigation.navigationBar.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(root.navigationDirections.last, .rightToLeft)
    }

    @available(iOS 17.0, *)
    func testCoordinatorMirrorsNavigationEnvironmentBeforeUpdatingChildAcrossLanguageChanges() {
        let fixture = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: fixture.controller)
        let root = RecordingViewController()
        let navigation = UINavigationController(rootViewController: root)
        let window = UIWindow()
        // 反向模拟系统环境，确保首次英文同步也会覆盖系统方向。
        window.rootViewController = navigation
        navigation.loadViewIfNeeded()
        root.loadViewIfNeeded()
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        if let scene = window.windowScene { scene.traitOverrides.layoutDirection = .rightToLeft }
        else { window.traitOverrides.layoutDirection = .rightToLeft }
        coordinator.register(window: window)
        XCTAssertEqual(navigation.traitCollection.layoutDirection, .leftToRight)
        XCTAssertEqual(root.navigationDirections.last, .leftToRight)

        for locale in [AppLocale(identifier: "ar"), AppLocale(identifier: "en-US"), AppLocale(identifier: "ar")] {
            let change = setLocale(locale, on: fixture.controller, notificationCenter: fixture.notificationCenter)

            let expected: UITraitEnvironmentLayoutDirection = locale == AppLocale(identifier: "ar") ? .rightToLeft : .leftToRight
            XCTAssertEqual(navigation.traitCollection.layoutDirection, expected)
            XCTAssertEqual(root.navigationDirections.last, expected)
            XCTAssertEqual(navigation.navigationBar.semanticContentAttribute, change.semanticContentAttribute)
        }
    }

    @available(iOS 17.0, *)
    func testCoordinatorUpdatesEachLoadedPageOnceWithoutLoadingChildren() {
        let fixture = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: fixture.controller)
        let root = RecordingViewController()
        let detail = RecordingViewController()
        let unloaded = RecordingViewController()
        detail.addChild(unloaded)
        unloaded.didMove(toParent: detail)
        let navigation = UINavigationController()
        navigation.setViewControllers([root, detail], animated: false)
        let window = UIWindow()
        window.rootViewController = navigation
        navigation.loadViewIfNeeded()
        root.loadViewIfNeeded()
        detail.loadViewIfNeeded()
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        coordinator.register(window: window)

        _ = setLocale(AppLocale(identifier: "ar"), on: fixture.controller, notificationCenter: fixture.notificationCenter)


        for page in [root, detail] {
            // 即使控制器同时出现在 children 和导航栈中，每轮也只更新一次。
            XCTAssertEqual(page.receivedUpdates.count, 2)
            XCTAssertEqual(page.navigationDirections.first, .leftToRight)
            XCTAssertEqual(page.navigationDirections.last, .rightToLeft)
        }
        XCTAssertFalse(unloaded.isViewLoaded)
        XCTAssertEqual(unloaded.receivedUpdates.count, 0)
    }

    func testNativeNavigationItemsRetainIdentityAcrossDirectionChanges() {
        let fixture = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: fixture.controller)
        let root = RecordingViewController()
        let leading = UIBarButtonItem(systemItem: .close)
        let trailing = UIBarButtonItem(systemItem: .add)
        root.navigationItem.leftBarButtonItem = leading
        root.navigationItem.rightBarButtonItem = trailing
        let navigation = UINavigationController(rootViewController: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        coordinator.register(window: window)
        for identifier in ["ar", "en-US", "ar", "en-US"] {
            fixture.controller.setLocale(identifier: identifier)
            // 槽位与实例保持稳定，实际按钮的物理位置由 App UI 回归检查。
            XCTAssertTrue(root.navigationItem.leftBarButtonItem === leading)
            XCTAssertTrue(root.navigationItem.rightBarButtonItem === trailing)
            XCTAssertEqual(navigation.navigationBar.effectiveUserInterfaceLayoutDirection,
                           fixture.controller.layoutDirection)
            XCTAssertEqual(root.receivedUpdates.last?.snapshot, fixture.controller.currentSnapshot)
        }
    }

    func testInitialSynchronizationAndNotificationsShareOneUpdateType() throws {
        let notifications = NotificationCenter()
        let controller = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "ar"], developmentLocalization: "en-US"),
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "en-US"),
            notificationCenter: notifications, systemLocaleIdentifiersProvider: { ["en-US"] })
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let page = RecordingViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = page
        window.makeKeyAndVisible()
        let recorder = ChangeRecorder()
        let token = notifications.addObserver(
            forName: LocalizationController.localizationDidChangeNotification, object: controller, queue: nil
        ) { notification in
            recorder.change = notification.userInfo?[LocalizationController.localizationChangeUserInfoKey] as? LocalizationUpdate
        }
        defer { notifications.removeObserver(token); window.isHidden = true }
        coordinator.register(window: window)
        coordinator.synchronize(window: window)
        XCTAssertNil(recorder.change)
        XCTAssertEqual(page.receivedUpdates.count, 2)
        for update in page.receivedUpdates {
            XCTAssertNil(update.previousSnapshot)
            XCTAssertTrue(update.requiresLocalizedContentRefresh)
            XCTAssertTrue(update.requiresLayoutDirectionRefresh)
            XCTAssertEqual(update.snapshot.revision, 0)
        }
        XCTAssertFalse(controller.setLocale(identifier: "en-US"))
        XCTAssertEqual(page.receivedUpdates.count, 2)
        XCTAssertNil(recorder.change)

        // 生效语言相同，只有跟随系统模式变化：内容更新，方向不重复刷新。
        controller.setFollowsSystemLocale()
        let selection = try XCTUnwrap(recorder.change)
        XCTAssertEqual(page.receivedUpdates.last, selection)
        XCTAssertEqual(selection.previousSnapshot?.locale, selection.snapshot.locale)
        XCTAssertEqual(selection.previousSnapshot?.followsSystemLocale, false)
        XCTAssertTrue(selection.snapshot.followsSystemLocale)
        XCTAssertTrue(selection.requiresLocalizedContentRefresh)
        XCTAssertFalse(selection.requiresLayoutDirectionRefresh)

        for identifier in ["ar", "en-US"] {
            let previous = controller.currentSnapshot
            controller.setLocale(identifier: identifier)
            let update = try XCTUnwrap(recorder.change)
            XCTAssertEqual(update.previousSnapshot, previous)
            XCTAssertEqual(update.snapshot, controller.currentSnapshot)
            XCTAssertEqual(page.receivedUpdates.last, update)
            XCTAssertTrue(update.requiresLocalizedContentRefresh)
            XCTAssertTrue(update.requiresLayoutDirectionRefresh)
        }
        // 显式同步始终完整刷新，但不产生新版本或伪造变更通知。
        recorder.change = nil
        let snapshot = controller.currentSnapshot
        coordinator.synchronize(window: window)
        XCTAssertEqual(page.receivedUpdates.last, LocalizationUpdate(snapshot: snapshot))
        XCTAssertEqual(controller.currentSnapshot, snapshot)
        XCTAssertNil(recorder.change)
    }

    private func makeController() -> (
        controller: LocalizationController,
        notificationCenter: NotificationCenter
    ) {
        let notificationCenter = NotificationCenter()
        return (
            LocalizationController(
                resourceBundle: localizationTestBundle(["en-US", "ar"], developmentLocalization: "en-US"),
                preferenceStore: InMemoryLocalePreferenceStore(
                    localeIdentifier: "en-US"
                ),
                notificationCenter: notificationCenter
            ),
            notificationCenter
        )
    }

    private func setLocale(
        _ locale: AppLocale,
        on controller: LocalizationController,
        notificationCenter: NotificationCenter
    ) -> LocalizationUpdate {
        let recorder = ChangeRecorder()
        let token = notificationCenter.addObserver(
            forName: LocalizationController.localizationDidChangeNotification,
            object: controller,
            queue: nil
        ) { notification in
            recorder.change = notification.userInfo?[
                LocalizationController.localizationChangeUserInfoKey
            ] as? LocalizationUpdate
        }
        defer { notificationCenter.removeObserver(token) }
        XCTAssertTrue(controller.setLocale(identifier: locale.identifier))
        return recorder.change!
    }

}

@MainActor
private final class RecordingViewController: UIViewController,
    UIKitLocalizationApplying {
    private(set) var receivedUpdates: [LocalizationUpdate] = []
    private(set) var navigationDirections: [UITraitEnvironmentLayoutDirection] = []
    func applyLocalization(_ update: LocalizationUpdate) {
        if view.window != nil {
            XCTAssertEqual(view.effectiveUserInterfaceLayoutDirection, update.layoutDirection)
        }
        receivedUpdates.append(update)
        if let navigationController {
            navigationDirections.append(navigationController.traitCollection.layoutDirection)
        }
    }
}

private final class ChangeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: LocalizationUpdate?

    var change: LocalizationUpdate? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
        set {
            lock.lock()
            storage = newValue
            lock.unlock()
        }
    }
}

/// 模拟具体页面直接配置自己的按钮，不提供通用视图包装。
@MainActor
private final class ConfiguredButtonPage: UIViewController, UIKitLocalizationApplying {
    let button = UIButton(type: .system)
    var configuration: UIButton.Configuration = {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = "详情"
        configuration.image = UIImage(systemName: "star")
        configuration.imagePadding = 8
        return configuration
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        button.frame = CGRect(x: 20, y: 100, width: 280, height: 50)
        view.addSubview(button)
    }

    func applyLocalization(_ update: LocalizationUpdate) {
        let semantic = update.semanticContentAttribute
        if button.semanticContentAttribute != semantic {
            button.configuration = nil
        }
        button.semanticContentAttribute = semantic
        button.configuration = configuration
        button.setNeedsLayout()
    }
}
