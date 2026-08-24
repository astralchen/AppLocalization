import XCTest
@testable import AppLocalization

/// `NotificationCenter` 的观察者闭包在 Swift 6 中会被视为可能并发执行。
/// 测试不能在闭包中直接修改外部变量，因此使用带锁记录器保存观察结果。
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
        XCTAssertEqual(observedChange.get()?.previous.locale, .simplifiedChinese)
        XCTAssertEqual(observedChange.get()?.current.locale, .arabic)
        XCTAssertEqual(observedChange.get()?.localeChanged, true)
        XCTAssertEqual(observedChange.get()?.layoutDirectionChanged, true)
        XCTAssertEqual(observedChange.get()?.previous.revision, 0)
        XCTAssertEqual(observedChange.get()?.current.revision, 1)
        XCTAssertEqual(center.currentSnapshot.revision, 1)

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
            systemLocaleIdentifiersProvider: { ["zh-Hant"] }
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
            systemLocaleIdentifiersProvider: { ["ar-SA"] }
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
        XCTAssertEqual(observedChange.get()?.previous.locale, .englishUS)
        XCTAssertEqual(observedChange.get()?.current.locale, .arabic)

        notificationCenter.removeObserver(token)
    }

    @MainActor
    func testSelectingExplicitLocaleLeavesFollowSystemEvenWhenResolvedLocaleIsSame() {
        let store = InMemoryLocalePreferenceStore(localeIdentifier: LocalizationController.followSystemLocaleIdentifier)
        let center = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese],
            fallbackLocale: .englishUS,
            preferenceStore: store,
            systemLocaleIdentifiersProvider: { ["zh-Hant"] }
        )

        XCTAssertEqual(center.currentLocale, .simplifiedChinese)
        XCTAssertTrue(center.setLocale(identifier: "zh-Hans"))
        XCTAssertFalse(center.followsSystemLocale)
        XCTAssertEqual(center.currentLocale, .simplifiedChinese)
        XCTAssertEqual(store.localeIdentifier, "zh-Hans")
        XCTAssertEqual(center.currentSnapshot.revision, 1)
    }

    @MainActor
    func testFollowSystemChecksLaterPreferredLanguagesBeforeUsingFallback() {
        let store = InMemoryLocalePreferenceStore(
            localeIdentifier: LocalizationController.followSystemLocaleIdentifier
        )
        var preferredLanguages = ["fr-FR", "ar-SA"]
        let center = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese, .arabic],
            fallbackLocale: .englishUS,
            preferenceStore: store,
            systemLocaleIdentifiersProvider: { preferredLanguages }
        )

        XCTAssertEqual(center.currentLocale, .arabic)

        preferredLanguages = ["fr-FR", "zh-Hant"]
        XCTAssertTrue(center.refreshSystemLocaleIfNeeded())
        XCTAssertEqual(center.currentLocale, .simplifiedChinese)
    }

    @MainActor
    func testFollowSystemPrefersMatchingScriptWithinLanguage() {
        let traditionalChinese = AppLocale(
            identifier: "zh-Hant",
            displayName: "Traditional Chinese"
        )
        let center = LocalizationController(
            supportedLocales: [.simplifiedChinese, traditionalChinese, .englishUS],
            fallbackLocale: .englishUS,
            preferenceStore: InMemoryLocalePreferenceStore(
                localeIdentifier: LocalizationController.followSystemLocaleIdentifier
            ),
            systemLocaleIdentifiersProvider: { ["zh-Hant-HK"] }
        )

        XCTAssertEqual(center.currentLocale, traditionalChinese)
    }

    @MainActor
    func testFallbackLocaleMatchingNormalizesCaseAndSeparators() {
        let center = LocalizationController(
            supportedLocales: [.arabic, .englishUS],
            fallbackLocale: AppLocale(identifier: "EN_us"),
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "unsupported")
        )

        XCTAssertEqual(center.fallbackLocale, .englishUS)
        XCTAssertEqual(center.currentLocale, .englishUS)
    }

    @MainActor
    func testSingleSystemLocaleProviderInitializerRemainsCompatible() {
        let center = LocalizationController(
            supportedLocales: [.englishUS, .arabic],
            fallbackLocale: .englishUS,
            preferenceStore: InMemoryLocalePreferenceStore(),
            systemLocaleIdentifierProvider: { "ar-SA" }
        )

        XCTAssertEqual(center.currentLocale, .arabic)
    }

}
