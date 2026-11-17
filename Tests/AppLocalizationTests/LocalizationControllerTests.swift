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
    func testBundleSuppliesAvailableLanguagesAndDevelopmentFallback() {
        let bundle = localizationTestBundle(["Base", "en", "ar", "EN", "zh-Hans"], developmentLocalization: "en")
        let controller = LocalizationController(resourceBundle: bundle,
            preferenceStore: InMemoryLocalePreferenceStore(),
            systemLocaleIdentifiersProvider: { ["zh-Hans"] })
        XCTAssertEqual(Set(controller.supportedLocalizations.map { $0.lowercased() }), ["en", "ar", "zh-hans"])
        XCTAssertEqual(controller.supportedLocalizations.count, 3)
        XCTAssertEqual(controller.fallbackLocalization.lowercased(), "en")
        XCTAssertEqual(controller.currentLocale.identifier, "zh-Hans")
        XCTAssertTrue(controller.followsSystemLocale)
        // 当前偏好只有中文时，完整的语言列表仍然允许选择阿拉伯语。
        XCTAssertTrue(controller.setLocale(identifier: "ar"))
        XCTAssertFalse(controller.setLocale(identifier: "Base"))
    }

    @MainActor
    func testDefaultSystemChoiceUsesBundlePreferredLocalizations() {
        let bundle = localizationTestBundle(["en", "ar", "zh-Hans"], developmentLocalization: "en")
        let controller = LocalizationController(resourceBundle: bundle, preferenceStore: InMemoryLocalePreferenceStore())
        XCTAssertEqual(controller.currentLocale.identifier, bundle.preferredLocalizations.first)
        XCTAssertTrue(controller.followsSystemLocale)
    }

    @MainActor
    func testBaseOnlyBundleUsesItsDevelopmentLanguage() {
        let controller = LocalizationController(
            resourceBundle: localizationTestBundle(["Base"], developmentLocalization: "de"),
            preferenceStore: InMemoryLocalePreferenceStore())
        XCTAssertEqual(controller.supportedLocalizations, ["de"])
        XCTAssertEqual(controller.fallbackLocalization, "de")
        XCTAssertEqual(controller.currentLocale.identifier, "de")
    }

    @MainActor
    func testPersistedRegionalChoiceMigratesToAvailableBundleLanguage() {
        let store = InMemoryLocalePreferenceStore(localeIdentifier: "en-US")
        let controller = LocalizationController(
            resourceBundle: localizationTestBundle(["en", "ar"], developmentLocalization: "en"),
            preferenceStore: store)
        XCTAssertEqual(controller.currentLocale.identifier, "en")
        XCTAssertFalse(controller.followsSystemLocale)
        XCTAssertFalse(controller.setLocale(identifier: "en"))
        XCTAssertEqual(store.localeIdentifier, "en")
        XCTAssertEqual(controller.currentSnapshot.revision, 0)
    }

    @MainActor
    func testSelectingCurrentFallbackRepairsStorageWithoutFakeLanguageChange() {
        let store = InMemoryLocalePreferenceStore(localeIdentifier: "fr")
        let notifications = NotificationCenter()
        let controller = LocalizationController(
            resourceBundle: localizationTestBundle(["en", "ar"], developmentLocalization: "en"),
            preferenceStore: store, notificationCenter: notifications)
        let snapshot = controller.currentSnapshot
        let count = LockedValue(0)
        let token = notifications.addObserver(forName: LocalizationController.localizationDidChangeNotification,
                                              object: controller, queue: nil) { _ in count.mutate { $0 += 1 } }
        defer { notifications.removeObserver(token) }
        XCTAssertEqual(store.localeIdentifier, "fr")
        XCTAssertFalse(controller.setLocale(identifier: "en"))
        XCTAssertEqual(store.localeIdentifier, "en")
        XCTAssertEqual(controller.currentSnapshot, snapshot)
        XCTAssertEqual(count.get(), 0)
    }

    @MainActor
    func testSelectingSystemPersistsChoiceWithoutChangingResolvedState() {
        let store = InMemoryLocalePreferenceStore()
        let controller = LocalizationController(resourceBundle: localizationTestBundle(["en-US"]), preferenceStore: store)
        let snapshot = controller.currentSnapshot
        XCTAssertFalse(controller.setFollowsSystemLocale())
        XCTAssertEqual(store.localeIdentifier, "system")
        XCTAssertEqual(controller.currentSnapshot, snapshot)
    }

    @MainActor
    func testLoadsPersistedSupportedLocaleAndPublishesDirectionalChange() {
        let store = InMemoryLocalePreferenceStore(localeIdentifier: "zh-Hans")
        let notificationCenter = NotificationCenter()
        let center = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans", "ar"], developmentLocalization: "en-US"),
            preferenceStore: store,
            notificationCenter: notificationCenter
        )

        XCTAssertEqual(center.currentLocale, AppLocale(identifier: "zh-Hans"))
        XCTAssertEqual(center.currentLocale.layoutDirection, .leftToRight)

        let observedChange = LockedValue<LocalizationUpdate?>(nil)
        let token = notificationCenter.addObserver(
            forName: LocalizationController.localizationDidChangeNotification,
            object: center,
            queue: nil
        ) { notification in
            observedChange.set(notification.userInfo?[LocalizationController.localizationChangeUserInfoKey] as? LocalizationUpdate)
        }

        let didChange = center.setLocale(identifier: "ar")

        XCTAssertTrue(didChange)
        XCTAssertEqual(center.currentLocale, AppLocale(identifier: "ar"))
        XCTAssertEqual(store.localeIdentifier, "ar")
        XCTAssertEqual(observedChange.get()?.previousSnapshot?.locale, AppLocale(identifier: "zh-Hans"))
        XCTAssertEqual(observedChange.get()?.snapshot.locale, AppLocale(identifier: "ar"))
        XCTAssertEqual(observedChange.get()?.requiresLocalizedContentRefresh, true)
        XCTAssertEqual(observedChange.get()?.requiresLayoutDirectionRefresh, true)
        XCTAssertEqual(observedChange.get()?.previousSnapshot?.revision, 0)
        XCTAssertEqual(observedChange.get()?.snapshot.revision, 1)
        XCTAssertEqual(center.currentSnapshot.revision, 1)

        notificationCenter.removeObserver(token)
    }

    @MainActor
    func testUnsupportedLocaleFallsBackAndCannotBeSelected() {
        let store = InMemoryLocalePreferenceStore(localeIdentifier: "fr")
        let center = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans"], developmentLocalization: "en-US"),
            preferenceStore: store
        )

        XCTAssertEqual(center.currentLocale, AppLocale(identifier: "en-US"))
        XCTAssertFalse(center.setLocale(identifier: "ar"))
        XCTAssertEqual(center.currentLocale, AppLocale(identifier: "en-US"))
        XCTAssertEqual(store.localeIdentifier, "fr")
    }

    @MainActor
    func testSelectingEquivalentLocaleDoesNotPublishChange() {
        let store = InMemoryLocalePreferenceStore(localeIdentifier: "en-US")
        let notificationCenter = NotificationCenter()
        let center = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans"], developmentLocalization: "en-US"),
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
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans", "ar"], developmentLocalization: "en-US"),
            preferenceStore: store,
            systemLocaleIdentifiersProvider: { ["zh-Hant"] }
        )

        XCTAssertTrue(center.followsSystemLocale)
        XCTAssertEqual(center.currentLocale, AppLocale(identifier: "zh-Hans"))
    }

    @MainActor
    func testSelectingFollowSystemPersistsSentinelAndPublishesResolvedLocale() {
        let store = InMemoryLocalePreferenceStore(localeIdentifier: "en-US")
        let notificationCenter = NotificationCenter()
        let center = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans", "ar"], developmentLocalization: "en-US"),
            preferenceStore: store,
            notificationCenter: notificationCenter,
            systemLocaleIdentifiersProvider: { ["ar-SA"] }
        )

        let observedChange = LockedValue<LocalizationUpdate?>(nil)
        let token = notificationCenter.addObserver(
            forName: LocalizationController.localizationDidChangeNotification,
            object: center,
            queue: nil
        ) { notification in
            observedChange.set(notification.userInfo?[LocalizationController.localizationChangeUserInfoKey] as? LocalizationUpdate)
        }

        XCTAssertTrue(center.setFollowsSystemLocale())
        XCTAssertTrue(center.followsSystemLocale)
        XCTAssertEqual(center.currentLocale, AppLocale(identifier: "ar"))
        XCTAssertEqual(store.localeIdentifier, LocalizationController.followSystemLocaleIdentifier)
        XCTAssertEqual(observedChange.get()?.previousSnapshot?.locale, AppLocale(identifier: "en-US"))
        XCTAssertEqual(observedChange.get()?.snapshot.locale, AppLocale(identifier: "ar"))

        notificationCenter.removeObserver(token)
    }

    @MainActor
    func testSelectingExplicitLocaleLeavesFollowSystemEvenWhenResolvedLocaleIsSame() {
        let store = InMemoryLocalePreferenceStore(localeIdentifier: LocalizationController.followSystemLocaleIdentifier)
        let center = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans"], developmentLocalization: "en-US"),
            preferenceStore: store,
            systemLocaleIdentifiersProvider: { ["zh-Hant"] }
        )

        XCTAssertEqual(center.currentLocale, AppLocale(identifier: "zh-Hans"))
        XCTAssertTrue(center.setLocale(identifier: "zh-Hans"))
        XCTAssertFalse(center.followsSystemLocale)
        XCTAssertEqual(center.currentLocale, AppLocale(identifier: "zh-Hans"))
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
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans", "ar"], developmentLocalization: "en-US"),
            preferenceStore: store,
            systemLocaleIdentifiersProvider: { preferredLanguages }
        )

        XCTAssertEqual(center.currentLocale, AppLocale(identifier: "ar"))

        preferredLanguages = ["fr-FR", "zh-Hant"]
        XCTAssertTrue(center.refreshSystemLocaleIfNeeded())
        XCTAssertEqual(center.currentLocale, AppLocale(identifier: "zh-Hans"))
    }

    @MainActor
    func testFollowSystemPrefersMatchingScriptWithinLanguage() {
        let traditionalChinese = AppLocale(
            identifier: "zh-Hant",
            displayName: "Traditional Chinese"
        )
        let center = LocalizationController(
            resourceBundle: localizationTestBundle(["zh-Hans", traditionalChinese.identifier, "en-US"], developmentLocalization: "en-US"),
            preferenceStore: InMemoryLocalePreferenceStore(
                localeIdentifier: LocalizationController.followSystemLocaleIdentifier
            ),
            systemLocaleIdentifiersProvider: { ["zh-Hant-HK"] }
        )

        XCTAssertEqual(center.currentLocale.identifier, traditionalChinese.identifier)
    }

    @MainActor
    func testFallbackLocaleMatchingNormalizesCaseAndSeparators() {
        let center = LocalizationController(
            resourceBundle: localizationTestBundle(["ar", "en-US"], developmentLocalization: "EN_us"),
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "unsupported")
        )

        XCTAssertEqual(center.fallbackLocalization, "en-US")
        XCTAssertEqual(center.currentLocale, AppLocale(identifier: "en-US"))
    }

    @MainActor
    func testInjectedSystemSourceResolvesRegionalLanguage() {
        let center = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "ar"], developmentLocalization: "en-US"),
            preferenceStore: InMemoryLocalePreferenceStore(),
            systemLocaleIdentifiersProvider: { ["ar-SA"] }
        )

        XCTAssertEqual(center.currentLocale, AppLocale(identifier: "ar"))
    }

}
