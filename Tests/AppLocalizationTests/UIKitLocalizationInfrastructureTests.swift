#if canImport(UIKit)
import UIKit
import XCTest
@testable import AppLocalization

@MainActor
final class UIKitLocalizationInfrastructureTests: XCTestCase {
    func testDirectionPoliciesWriteOnlyDeclaredSemantics() {
        let container = UIView()
        container.semanticContentAttribute = .forceLeftToRight
        let inherited = UIView()
        inherited.semanticContentAttribute = .playback
        let application = UIButton(type: .system)
        let followingContainer = UIView()
        let fixed = UIView()
        container.addSubview(inherited)
        container.addSubview(application)
        container.addSubview(followingContainer)
        container.addSubview(fixed)

        let update = makeUpdate(locale: .arabic, revision: 1)
        UIViewLayoutDirectionUpdater.apply(
            update,
            to: [
                UIViewLayoutDirectionTarget(inherited, policy: .inherited),
                UIViewLayoutDirectionTarget(application, policy: .followApplication),
                UIViewLayoutDirectionTarget(
                    followingContainer,
                    policy: .followContainer
                ),
                UIViewLayoutDirectionTarget(fixed, policy: .fixed(.spatial)),
                // Duplicate targets in one component update are ignored.
                UIViewLayoutDirectionTarget(application, policy: .followApplication)
            ]
        )

        XCTAssertEqual(inherited.semanticContentAttribute, .playback)
        XCTAssertEqual(application.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(followingContainer.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(fixed.semanticContentAttribute, .spatial)
    }

    func testFollowContainerResolvesAgainAfterDetachedViewIsReattached() {
        let leftToRightContainer = UIView()
        leftToRightContainer.semanticContentAttribute = .forceLeftToRight
        let rightToLeftContainer = UIView()
        rightToLeftContainer.semanticContentAttribute = .forceRightToLeft
        let view = UIView()
        let target = UIViewLayoutDirectionTarget(view, policy: .followContainer)

        leftToRightContainer.addSubview(view)
        UIViewLayoutDirectionUpdater.apply(
            makeUpdate(locale: .englishUS, revision: 0, reasons: [.attachment]),
            to: target
        )
        XCTAssertEqual(view.semanticContentAttribute, .forceLeftToRight)

        view.removeFromSuperview()
        // Detached views intentionally keep their last value until an owner
        // attaches or measures them with a current update.
        XCTAssertEqual(view.semanticContentAttribute, .forceLeftToRight)

        rightToLeftContainer.addSubview(view)
        UIViewLayoutDirectionUpdater.apply(
            makeUpdate(locale: .arabic, revision: 1, reasons: [.attachment]),
            to: target
        )
        XCTAssertEqual(view.semanticContentAttribute, .forceRightToLeft)
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
        let change = setLocale(
            .arabic,
            on: fixture.controller,
            notificationCenter: fixture.notificationCenter
        )
        coordinator.apply(change, animated: false)

        XCTAssertEqual(registeredWindow.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(
            registeredController.receivedUpdates.last?.snapshot.revision,
            fixture.controller.currentSnapshot.revision
        )
        XCTAssertEqual(unregisteredWindow.semanticContentAttribute, .unspecified)
        XCTAssertTrue(unregisteredController.receivedUpdates.isEmpty)
    }

    func testReloadAllScenesUpdatesOnlyCallerSelectedWindowWithoutRegisteringIt() {
        let fixture = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(
            localizationController: fixture.controller
        )
        let root = RecordingViewController()
        root.loadViewIfNeeded()
        let window = UIWindow()
        window.rootViewController = root
        let excludedRoot = RecordingViewController()
        excludedRoot.loadViewIfNeeded()
        let excludedWindow = UIWindow()
        excludedWindow.rootViewController = excludedRoot

        let change = setLocale(
            .arabic,
            on: fixture.controller,
            notificationCenter: fixture.notificationCenter
        )
        coordinator.reload(
            change,
            windows: [window, excludedWindow],
            animated: false,
            including: { $0 === window }
        )

        XCTAssertEqual(window.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(root.receivedUpdates.last?.snapshot.revision, change.current.revision)
        XCTAssertEqual(excludedWindow.semanticContentAttribute, .unspecified)
        XCTAssertTrue(excludedRoot.receivedUpdates.isEmpty)

        let receivedCount = root.receivedUpdates.count
        coordinator.synchronize(window: window)
        XCTAssertEqual(root.receivedUpdates.count, receivedCount)
    }

    func testCoordinatorDoesNotLoadUnloadedControllerAndRejectsStaleChange() {
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

        let oldChange = setLocale(
            .arabic,
            on: fixture.controller,
            notificationCenter: fixture.notificationCenter
        )
        coordinator.apply(oldChange, animated: false)
        let finalChange = setLocale(
            .englishUS,
            on: fixture.controller,
            notificationCenter: fixture.notificationCenter
        )
        coordinator.apply(finalChange, animated: false)

        XCTAssertFalse(unloadedChild.isViewLoaded)
        XCTAssertEqual(window.semanticContentAttribute, .forceLeftToRight)

        coordinator.apply(oldChange, animated: false)
        XCTAssertEqual(window.semanticContentAttribute, .forceLeftToRight)
        XCTAssertEqual(
            root.receivedUpdates.last?.snapshot.revision,
            finalChange.current.revision
        )
    }

    func testRecreateRecoveryAppliesLatestUpdateToFactoryRoot() {
        let fixture = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(
            localizationController: fixture.controller
        )
        let initialRoot = RecordingViewController()
        initialRoot.loadViewIfNeeded()
        let window = UIWindow()
        window.rootViewController = initialRoot
        var recreatedRoot: RecordingViewController?
        coordinator.register(window: window) { _ in
            let root = RecordingViewController()
            root.loadViewIfNeeded()
            recreatedRoot = root
            return root
        }

        let change = setLocale(
            .arabic,
            on: fixture.controller,
            notificationCenter: fixture.notificationCenter
        )
        coordinator.apply(change, animated: false) { _, _ in .recreateRoot }

        XCTAssertTrue(window.rootViewController === recreatedRoot)
        XCTAssertEqual(window.semanticContentAttribute, .forceRightToLeft)
        XCTAssertEqual(
            recreatedRoot?.receivedUpdates.last?.snapshot.revision,
            change.current.revision
        )
        XCTAssertTrue(
            recreatedRoot?.receivedUpdates.last?.reasons.contains(.attachment)
                == true
        )
    }

    @available(iOS 17.0, *)
    func testCoordinatorSynchronizesNavigationEnvironmentOnArabicRegistration() {
        let fixture = makeController()
        _ = setLocale(.arabic, on: fixture.controller, notificationCenter: fixture.notificationCenter)
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: fixture.controller)
        let root = RecordingViewController()
        let navigation = UINavigationController(rootViewController: root)
        let window = UIWindow()
        // 模拟系统仍使用从左到右布局，但应用已选择阿拉伯语。
        window.traitOverrides.layoutDirection = .leftToRight
        window.rootViewController = navigation
        navigation.loadViewIfNeeded()
        root.loadViewIfNeeded()

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
        window.traitOverrides.layoutDirection = .rightToLeft
        window.rootViewController = navigation
        navigation.loadViewIfNeeded()
        root.loadViewIfNeeded()
        coordinator.register(window: window)
        XCTAssertEqual(navigation.traitCollection.layoutDirection, .leftToRight)
        XCTAssertEqual(root.navigationDirections.last, .leftToRight)

        for locale in [AppLocale.arabic, .englishUS, .arabic] {
            let change = setLocale(locale, on: fixture.controller, notificationCenter: fixture.notificationCenter)
            coordinator.apply(change, animated: false)
            let expected: UITraitEnvironmentLayoutDirection = locale == .arabic ? .rightToLeft : .leftToRight
            XCTAssertEqual(navigation.traitCollection.layoutDirection, expected)
            XCTAssertEqual(root.navigationDirections.last, expected)
            XCTAssertEqual(navigation.navigationBar.semanticContentAttribute, change.current.layoutDirection.semanticContentAttribute)
        }
    }

    @available(iOS 17.0, *)
    func testCoordinatorPreparesEveryLoadedPageBeforeChangingNavigationDirection() {
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
        coordinator.register(window: window)

        let change = setLocale(.arabic, on: fixture.controller, notificationCenter: fixture.notificationCenter)
        coordinator.apply(change, animated: false)

        for page in [root, detail] {
            // 即使控制器同时出现在 children 和导航栈中，每轮也只准备一次。
            XCTAssertEqual(page.preparationCount, 2)
            XCTAssertEqual(page.preparedNavigationDirections.last, .leftToRight)
            XCTAssertEqual(page.navigationDirections.last, .rightToLeft)
        }
        XCTAssertFalse(unloaded.isViewLoaded)
        XCTAssertEqual(unloaded.preparationCount, 0)
    }

    func testNavigationItemPlacementUsesUIKitSemanticSlots() {
        let navigationItem = UINavigationItem()
        let leadingItem = UIBarButtonItem(systemItem: .close)
        let trailingItem = UIBarButtonItem(systemItem: .action)

        navigationItem.setBarButtonItem(leadingItem, side: .leading)
        navigationItem.setBarButtonItem(trailingItem, side: .trailing)

        XCTAssertTrue(navigationItem.leftBarButtonItem === leadingItem)
        XCTAssertTrue(navigationItem.rightBarButtonItem === trailingItem)

        navigationItem.setBarButtonItem(trailingItem, side: .leading)

        XCTAssertTrue(navigationItem.leftBarButtonItem === trailingItem)
        XCTAssertNil(navigationItem.rightBarButtonItem)

        navigationItem.setBarButtonItem(trailingItem, side: .trailing)

        XCTAssertNil(navigationItem.leftBarButtonItem)
        XCTAssertTrue(navigationItem.rightBarButtonItem === trailingItem)
    }

    func testNavigationBarItemBuilderPreservesOrderAndMovesSharedItems() {
        let navigationItem = UINavigationItem()
        let firstItem = UIBarButtonItem(systemItem: .add)
        let conditionalItem = UIBarButtonItem(systemItem: .edit)
        let arrayItems = [
            UIBarButtonItem(systemItem: .search),
            UIBarButtonItem(systemItem: .action)
        ]
        let includesConditionalItem = true
        let omittedItem: UIBarButtonItem? = nil
        navigationItem.leftItemsSupplementBackButton = true

        navigationItem.setBarButtonItems(side: .trailing) {
            firstItem
            if includesConditionalItem {
                conditionalItem
            }
            arrayItems
            firstItem
            omittedItem
        }

        XCTAssertEqual(
            navigationItem.rightBarButtonItems?.map(ObjectIdentifier.init),
            ([firstItem, conditionalItem] + arrayItems)
                .map(ObjectIdentifier.init)
        )

        navigationItem.setBarButtonItems(side: .leading) {
            conditionalItem
            for item in arrayItems {
                item
            }
        }

        XCTAssertEqual(
            navigationItem.leftBarButtonItems?.map(ObjectIdentifier.init),
            ([conditionalItem] + arrayItems).map(ObjectIdentifier.init)
        )
        XCTAssertEqual(
            navigationItem.rightBarButtonItems?.map(ObjectIdentifier.init),
            [firstItem].map(ObjectIdentifier.init)
        )
        XCTAssertTrue(navigationItem.leftItemsSupplementBackButton)

        navigationItem.setBarButtonItems(side: .leading) {}

        XCTAssertNil(navigationItem.leftBarButtonItems)
        XCTAssertEqual(
            navigationItem.rightBarButtonItems?.map(ObjectIdentifier.init),
            [firstItem].map(ObjectIdentifier.init)
        )
        XCTAssertTrue(navigationItem.leftItemsSupplementBackButton)
    }

    private func makeController() -> (
        controller: LocalizationController,
        notificationCenter: NotificationCenter
    ) {
        let notificationCenter = NotificationCenter()
        return (
            LocalizationController(
                supportedLocales: [.englishUS, .arabic],
                fallbackLocale: .englishUS,
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
    ) -> LocalizationChange {
        let recorder = ChangeRecorder()
        let token = notificationCenter.addObserver(
            forName: LocalizationController.localizationDidChangeNotification,
            object: controller,
            queue: nil
        ) { notification in
            recorder.change = notification.userInfo?[
                LocalizationController.localizationChangeUserInfoKey
            ] as? LocalizationChange
        }
        defer { notificationCenter.removeObserver(token) }
        XCTAssertTrue(controller.setLocale(identifier: locale.identifier))
        return recorder.change!
    }

    private func makeUpdate(
        locale: AppLocale,
        revision: UInt64,
        reasons: UIKitLocalizationUpdateReason = [.layoutDirection]
    ) -> UIKitLocalizationUpdate {
        UIKitLocalizationUpdate(
            snapshot: LocalizationSnapshot(
                locale: locale,
                followsSystemLocale: false,
                revision: revision
            ),
            reasons: reasons
        )
    }
}

@MainActor
private final class RecordingViewController: UIViewController,
    UIKitLocalizationApplying, UIKitLocalizationPreparing {
    private(set) var receivedUpdates: [UIKitLocalizationUpdate] = []
    private(set) var navigationDirections: [UITraitEnvironmentLayoutDirection] = []
    private(set) var preparedNavigationDirections: [UITraitEnvironmentLayoutDirection] = []
    private(set) var preparationCount = 0

    func prepareForLocalization(_ update: UIKitLocalizationUpdate) {
        preparationCount += 1
        if let navigationController {
            preparedNavigationDirections.append(navigationController.traitCollection.layoutDirection)
        }
    }


    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        XCTAssertEqual(view.semanticContentAttribute, update.semanticContentAttribute)
        receivedUpdates.append(update)
        if let navigationController {
            navigationDirections.append(navigationController.traitCollection.layoutDirection)
        }
    }
}

private final class ChangeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: LocalizationChange?

    var change: LocalizationChange? {
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
#endif
