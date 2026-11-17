import Combine
import XCTest
import UIKit

@testable import AppLocalization

@MainActor
final class LocalizationTransactionTests: XCTestCase {
    func testStorageRepairReentryRunsAfterRepairWithoutPublishingAnExtraRevision() {
        let store = TransactionStore()
        store.localeIdentifier = "removed-language"
        let controller = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "ar"]), preferenceStore: store)
        var published: [UInt64] = []
        let subscription = controller.$currentSnapshot.dropFirst().sink { published.append($0.revision) }
        var saved: [String] = []
        store.onSave = { identifier in
            saved.append(identifier)
            if identifier == "en-US" {
                XCTAssertTrue(controller.setLocale(identifier: "ar"))
                XCTAssertEqual(controller.currentSnapshot.revision, 0)
            }
        }
        XCTAssertTrue(controller.setLocale(identifier: "en-US"))
        XCTAssertEqual(saved, ["en-US", "ar"])
        XCTAssertEqual(published, [1])
        XCTAssertEqual(controller.currentLocale.identifier, "ar")
        XCTAssertEqual(store.localeIdentifier, "ar")
        store.onSave = { _ in }
        withExtendedLifetime(subscription) {}
    }

    private func makeController() -> LocalizationController {
        LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans", "ar"], developmentLocalization: "en-US"),
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "en-US"))
    }

    func testAllPreparationPrecedesPublicationAndCompletionPrecedesNextRevision() {
        let store = TransactionStore()
        let notifications = NotificationCenter()
        let controller = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans", "ar"], developmentLocalization: "en-US"),
            preferenceStore: store, notificationCenter: notifications)
        let first = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let second = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let oldPages = [TransactionPage(), TransactionPage()]
        let newPages = [TransactionPage(), TransactionPage()]
        let windows = oldPages.map(host)
        first.register(window: windows[0])
        second.register(window: windows[1])
        controller.register(first)
        var trace: [String] = []
        var completed = [UInt64](repeating: 0, count: 2)
        var applied = [UInt64](repeating: 0, count: 2)
        for index in windows.indices {
            windows[index].onLayout = {
                // 完成布局必须发生在本轮所有内容回调之后。
                if applied.allSatisfy({ $0 == controller.currentSnapshot.revision }) {
                    completed[index] = controller.currentSnapshot.revision
                }
            }
            for page in [oldPages[index], newPages[index]] {
                page.onApply = { update in
                    XCTAssertEqual(controller.currentSnapshot, update.snapshot)
                    XCTAssertTrue(windows.allSatisfy {
                        $0.effectiveUserInterfaceLayoutDirection == update.layoutDirection
                    })
                    let revision = update.snapshot.revision
                    applied[index] = revision
                    trace.append("apply-\(index)-\(revision)")
                    if index == 0, revision == 1 {
                        controller.setLocale(identifier: "zh-Hans")
                        controller.setLocale(identifier: "en-US")
                    }
                }
            }
        }
        store.onSave = { _ in
            let revision = controller.currentSnapshot.revision + 1
            trace.append("save-\(revision)")
            if revision == 1 {
                // 持久化前必须完成所有协调器的捕获；替换根页面不应改变本轮已捕获的成员。
                for index in windows.indices { windows[index].rootViewController = newPages[index] }
            }
        }
        let publication = controller.$currentSnapshot.dropFirst().sink { snapshot in
            XCTAssertEqual(controller.currentSnapshot.revision + 1, snapshot.revision)
            trace.append("publish-\(snapshot.revision)")
        }
        let completion = notifications.publisher(
            for: LocalizationController.localizationDidChangeNotification, object: controller
        ).sink { _ in
            MainActor.assumeIsolated {
                let revision = controller.currentSnapshot.revision
                XCTAssertEqual(completed, [revision, revision])
                trace.append("notify-\(revision)")
            }
        }
        controller.setLocale(identifier: "ar")
        XCTAssertEqual(trace, [1, 2].flatMap { revision in
            ["save", "publish", "apply-0", "apply-1", "notify"].map { "\($0)-\(revision)" }
        })
        XCTAssertEqual(oldPages.map(\.revisions), [[0, 1], [0, 1]])
        XCTAssertEqual(newPages.map(\.revisions), [[2], [2]])
        XCTAssertEqual(controller.currentLocale, AppLocale(identifier: "en-US"))
        XCTAssertEqual(controller.currentSnapshot.revision, 2)
        for window in windows { window.isHidden = true; window.onLayout = {} }
        for page in oldPages + newPages { page.onApply = { _ in } }
        store.onSave = { _ in }
        withExtendedLifetime((first, second, publication, completion)) {}
    }

    func testOneAtomicPublicationAndReentryFromWillChange() {
        let controller = makeController()
        var snapshots: [LocalizationSnapshot] = []
        let subscription = controller.$currentSnapshot.sink { value in snapshots.append(value) }
        var requested = false
        let willChange = controller.objectWillChange.sink { _ in
            MainActor.assumeIsolated {
                if !requested {
                    requested = true
                    controller.setLocale(identifier: "zh-Hans")
                }
            }
        }
        controller.setLocale(identifier: "ar")
        XCTAssertEqual(snapshots.map(\.locale), [AppLocale(identifier: "en-US"), AppLocale(identifier: "ar"), AppLocale(identifier: "zh-Hans")])
        XCTAssertEqual(snapshots.map(\.revision), [0, 1, 2])
        XCTAssertTrue(snapshots.allSatisfy { !$0.followsSystemLocale })
        withExtendedLifetime((subscription, willChange)) {}
    }

    func testRequestForCurrentStateCancelsEarlierDeferredRequest() {
        let controller = makeController()
        let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let page = TransactionPage()
        let window = host(page)
        defer { window.isHidden = true }
        coordinator.register(window: window)
        page.onApply = { _ in
            controller.setLocale(identifier: "zh-Hans")
            controller.setLocale(identifier: "ar")
        }
        controller.setLocale(identifier: "ar")
        XCTAssertEqual(controller.currentSnapshot.revision, 1)
        XCTAssertEqual(controller.currentLocale, AppLocale(identifier: "ar"))
        XCTAssertEqual(page.revisions, [0, 1])
        withExtendedLifetime(coordinator) {}
    }

    func testCoordinatorMembershipChangesAreFrozenUntilNextTransaction() {
        let store = TransactionStore()
        let controller = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans", "ar"], developmentLocalization: "en-US"),
            preferenceStore: store)
        let first = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let second = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let third = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        controller.unregister(third)
        let pages = [TransactionPage(), TransactionPage(), TransactionPage()]
        let windows = pages.map(host)
        for (coordinator, window) in zip([first, second, third], windows) { coordinator.register(window: window) }
        var trace: [Int] = []
        for index in pages.indices { pages[index].onApply = { _ in trace.append(index) } }
        store.onSave = { _ in
            controller.unregister(second)
            controller.register(third)
        }
        controller.setLocale(identifier: "ar")
        XCTAssertEqual(trace, [0, 1])
        controller.setLocale(identifier: "zh-Hans")
        XCTAssertEqual(trace, [0, 1, 0, 2])
        for window in windows { window.isHidden = true }
        store.onSave = { _ in }
        withExtendedLifetime((first, second, third)) {}
    }

    func testWeakCoordinatorEntriesPreserveOrderAndIdentityAfterRemoval() {
        let controller = makeController()
        let first = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        weak var released: UIWindowSceneLocalizationCoordinator?
        autoreleasepool {
            let temporary = UIWindowSceneLocalizationCoordinator(localizationController: controller)
            released = temporary
        }
        XCTAssertNil(released)
        let second = UIWindowSceneLocalizationCoordinator(localizationController: controller)
        let pages = [TransactionPage(), TransactionPage()]
        let windows = pages.map(host)
        first.register(window: windows[0])
        second.register(window: windows[1])
        var trace: [Int] = []
        pages[0].onApply = { _ in trace.append(0) }
        pages[1].onApply = { _ in trace.append(1) }
        controller.register(first)
        controller.setLocale(identifier: "ar")
        XCTAssertEqual(trace, [0, 1])
        controller.unregister(first)
        controller.unregister(first)
        controller.register(first)
        controller.setLocale(identifier: "en-US")
        XCTAssertEqual(trace, [0, 1, 1, 0])
        for window in windows { window.isHidden = true }
        withExtendedLifetime((first, second)) {}
    }

    func testDeliveryRetainsCoordinatorOnlyUntilTransactionFinishes() {
        let controller = makeController()
        let page = TransactionPage()
        let window = host(page)
        defer { window.isHidden = true }
        weak var released: UIWindowSceneLocalizationCoordinator?
        autoreleasepool {
            var coordinator: UIWindowSceneLocalizationCoordinator? =
                UIWindowSceneLocalizationCoordinator(localizationController: controller)
            released = coordinator
            coordinator?.register(window: window)
            page.onApply = { _ in
                controller.unregister(coordinator!)
                coordinator = nil
                XCTAssertNotNil(released)
            }
            controller.setLocale(identifier: "ar")
        }
        XCTAssertNil(released)
        controller.setLocale(identifier: "en-US")
        XCTAssertEqual(page.revisions, [0, 1])
    }

    func testBundleSourceAndExplicitSelectionHaveSeparateLifecycles() {
        var system = ["ar-SA"]
        let store = InMemoryLocalePreferenceStore()
        let controller = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "ar"], developmentLocalization: "en-US"),
            preferenceStore: store, systemLocaleIdentifiersProvider: { system }
        )
        XCTAssertEqual(controller.currentLocale, AppLocale(identifier: "ar"))
        controller.setLocale(identifier: "en-US")
        XCTAssertFalse(controller.refreshSystemLocaleIfNeeded())
        controller.setFollowsSystemLocale()
        system = ["en-GB"]
        controller.refreshSystemLocaleIfNeeded()
        XCTAssertEqual(controller.currentLocale, AppLocale(identifier: "en-US"))
        XCTAssertTrue(controller.followsSystemLocale)
        XCTAssertEqual(store.localeIdentifier, "system")
        let restored = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "ar"], developmentLocalization: "en-US"),
            preferenceStore: store, systemLocaleIdentifiersProvider: { system })
        XCTAssertTrue(restored.followsSystemLocale)
        XCTAssertEqual(restored.currentLocale, AppLocale(identifier: "en-US"))
    }

    func testSystemSourceInfersTraditionalScriptFromRegion() {
        let traditional = AppLocale(identifier: "zh-Hant")
        let controller = LocalizationController(
            resourceBundle: localizationTestBundle(["zh-Hans", traditional.identifier, "en-US"], developmentLocalization: "en-US"), preferenceStore: InMemoryLocalePreferenceStore(),
            systemLocaleIdentifiersProvider: { ["fr-FR", "zh-TW"] })
        XCTAssertEqual(controller.currentLocale, traditional)
    }

    func testSynchronizationReentryCannotOverwriteNewerState() {
        let controller = makeController()
        var revisions: [UInt64] = []
        controller.synchronize { snapshot in
            revisions.append(snapshot.revision)
            controller.setLocale(identifier: "ar")
            controller.synchronize { revisions.append($0.revision) }
            XCTAssertEqual(controller.currentSnapshot, snapshot)
        }
        XCTAssertEqual(revisions, [0, 1])
        XCTAssertEqual(controller.currentLocale, AppLocale(identifier: "ar"))
    }
    private func host(_ root: UIViewController) -> TransactionWindow {
        let window = TransactionWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = root
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }
}

@MainActor
private final class TransactionPage: UIViewController, UIKitLocalizationApplying {
    var onApply: (LocalizationUpdate) -> Void = { _ in }
    var revisions: [UInt64] = []
    func applyLocalization(_ update: LocalizationUpdate) {
        revisions.append(update.snapshot.revision)
        onApply(update)
    }
}

@MainActor
private final class TransactionWindow: UIWindow {
    var onLayout: () -> Void = {}
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        onLayout()
    }
}

@MainActor
private final class TransactionStore: LocalePreferenceStore {
    var localeIdentifier: String? = "en-US"
    var onSave: (String) -> Void = { _ in }
    func saveLocaleIdentifier(_ identifier: String) {
        onSave(identifier)
        localeIdentifier = identifier
    }
}
