import XCTest
@testable import AppLocalization

/// NotificationCenter 的 observer 闭包在 Swift 6 中会被视为可能并发执行。
/// 测试不能在闭包里直接修改外层 var，因此用带锁 recorder 保存观测结果。
private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        self.storage = value
    }

    func get() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func set(_ value: Value) {
        lock.lock()
        storage = value
        lock.unlock()
    }

    func mutate(_ body: (inout Value) -> Void) {
        lock.lock()
        body(&storage)
        lock.unlock()
    }
}

final class LocalizationControllerTests: XCTestCase {
    @MainActor
    func testLoadsPersistedSupportedLocaleAndPublishesDirectionalChange() {
        let store = InMemoryLocalePreferenceStore(localeIdentifier: "zh-Hans")
        let notificationCenter = NotificationCenter()
        let center = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese, .arabic],
            fallbackLocale: .englishUS,
            preferenceStore: store,
            notificationCenter: notificationCenter
        )

        XCTAssertEqual(center.currentLocale, .simplifiedChinese)
        XCTAssertEqual(center.currentLocale.layoutDirection, .leftToRight)

        let observedChange = LockedValue<LocalizationChange?>(nil)
        let token = notificationCenter.addObserver(
            forName: LocalizationController.localizationDidChangeNotification,
            object: center,
            queue: nil
        ) { notification in
            observedChange.set(notification.userInfo?[LocalizationController.localizationChangeUserInfoKey] as? LocalizationChange)
        }

        let didChange = center.setLocale(identifier: "ar")

        XCTAssertTrue(didChange)
        XCTAssertEqual(center.currentLocale, .arabic)
        XCTAssertEqual(store.localeIdentifier, "ar")
        XCTAssertEqual(observedChange.get()?.previousLocale, .simplifiedChinese)
        XCTAssertEqual(observedChange.get()?.currentLocale, .arabic)
        XCTAssertEqual(observedChange.get()?.textChanged, true)
        XCTAssertEqual(observedChange.get()?.layoutDirectionChanged, true)

        notificationCenter.removeObserver(token)
    }

    @MainActor
    func testUnsupportedLocaleFallsBackAndCannotBeSelected() {
        let store = InMemoryLocalePreferenceStore(localeIdentifier: "fr")
        let center = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese],
            fallbackLocale: .englishUS,
            preferenceStore: store
        )

        XCTAssertEqual(center.currentLocale, .englishUS)
        XCTAssertFalse(center.setLocale(identifier: "ar"))
        XCTAssertEqual(center.currentLocale, .englishUS)
        XCTAssertEqual(store.localeIdentifier, "fr")
    }

    @MainActor
    func testSelectingEquivalentLocaleDoesNotPublishChange() {
        let store = InMemoryLocalePreferenceStore(localeIdentifier: "en-US")
        let notificationCenter = NotificationCenter()
        let center = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese],
            fallbackLocale: .englishUS,
            preferenceStore: store,
            notificationCenter: notificationCenter
        )

        let publishCount = LockedValue(0)
        let token = notificationCenter.addObserver(
            forName: LocalizationController.localizationDidChangeNotification,
            object: center,
            queue: nil
        ) { _ in
            publishCount.mutate { $0 += 1 }
        }

        XCTAssertFalse(center.setLocale(identifier: "en-US"))
        XCTAssertEqual(publishCount.get(), 0)

        notificationCenter.removeObserver(token)
    }
    @MainActor
    func testFollowSystemResolvesTraditionalChineseToSupportedSimplifiedChinese() {
        let store = InMemoryLocalePreferenceStore(localeIdentifier: LocalizationController.followSystemLocaleIdentifier)
        let center = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese, .arabic],
            fallbackLocale: .englishUS,
            preferenceStore: store,
            systemLocaleIdentifierProvider: { "zh-Hant" }
        )

        XCTAssertTrue(center.followsSystemLocale)
        XCTAssertEqual(center.currentLocale, .simplifiedChinese)
    }

    @MainActor
    func testSelectingFollowSystemPersistsSentinelAndPublishesResolvedLocale() {
        let store = InMemoryLocalePreferenceStore(localeIdentifier: "en-US")
        let notificationCenter = NotificationCenter()
        let center = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese, .arabic],
            fallbackLocale: .englishUS,
            preferenceStore: store,
            notificationCenter: notificationCenter,
            systemLocaleIdentifierProvider: { "ar-SA" }
        )

        let observedChange = LockedValue<LocalizationChange?>(nil)
        let token = notificationCenter.addObserver(
            forName: LocalizationController.localizationDidChangeNotification,
            object: center,
            queue: nil
        ) { notification in
            observedChange.set(notification.userInfo?[LocalizationController.localizationChangeUserInfoKey] as? LocalizationChange)
        }

        XCTAssertTrue(center.setFollowsSystemLocale())
        XCTAssertTrue(center.followsSystemLocale)
        XCTAssertEqual(center.currentLocale, .arabic)
        XCTAssertEqual(store.localeIdentifier, LocalizationController.followSystemLocaleIdentifier)
        XCTAssertEqual(observedChange.get()?.previousLocale, .englishUS)
        XCTAssertEqual(observedChange.get()?.currentLocale, .arabic)

        notificationCenter.removeObserver(token)
    }

    @MainActor
    func testSelectingExplicitLocaleLeavesFollowSystemEvenWhenResolvedLocaleIsSame() {
        let store = InMemoryLocalePreferenceStore(localeIdentifier: LocalizationController.followSystemLocaleIdentifier)
        let center = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese],
            fallbackLocale: .englishUS,
            preferenceStore: store,
            systemLocaleIdentifierProvider: { "zh-Hant" }
        )

        XCTAssertEqual(center.currentLocale, .simplifiedChinese)
        XCTAssertTrue(center.setLocale(identifier: "zh-Hans"))
        XCTAssertFalse(center.followsSystemLocale)
        XCTAssertEqual(center.currentLocale, .simplifiedChinese)
        XCTAssertEqual(store.localeIdentifier, "zh-Hans")
    }

}
