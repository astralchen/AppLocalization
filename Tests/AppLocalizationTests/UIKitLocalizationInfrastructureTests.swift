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
    UIKitLocalizationApplying {
    private(set) var receivedUpdates: [UIKitLocalizationUpdate] = []

    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        XCTAssertEqual(view.semanticContentAttribute, update.semanticContentAttribute)
        receivedUpdates.append(update)
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
