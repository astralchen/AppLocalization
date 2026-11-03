#if canImport(UIKit)
import UIKit
import XCTest
@testable import AppLocalization

@MainActor
final class UIKitTabContainerLocalizationTests: XCTestCase {
    @available(iOS 17.0, *)
    func testRegistrationAndRoundTripsSynchronizeTabTraitsBeforeChildren() {
        for initialLocale in [AppLocale.simplifiedChinese, .arabic] {
            let localization = LocalizationController(
                supportedLocales: [.simplifiedChinese, .arabic],
                fallbackLocale: .simplifiedChinese,
                preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: initialLocale.identifier)
            )
            let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: localization)
            let page = TabDirectionRecordingPage()
            let tabs = UITabBarController()
            tabs.viewControllers = [page, UIViewController()]
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 768, height: 1024))
            window.traitOverrides.layoutDirection = initialLocale == .arabic ? .leftToRight : .rightToLeft
            window.rootViewController = tabs
            tabs.loadViewIfNeeded()
            page.loadViewIfNeeded()
            coordinator.register(window: window)
            defer { coordinator.unregister(window: window) }

            func verify(_ locale: AppLocale) {
                let expected: UITraitEnvironmentLayoutDirection = locale == .arabic ? .rightToLeft : .leftToRight
                XCTAssertEqual(tabs.traitCollection.layoutDirection, expected)
                XCTAssertEqual(page.observedContainerDirection, expected)
                XCTAssertEqual(tabs.view.semanticContentAttribute, locale.layoutDirection.semanticContentAttribute)
                XCTAssertEqual(tabs.tabBar.semanticContentAttribute, locale.layoutDirection.semanticContentAttribute)
                XCTAssertTrue(window.rootViewController === tabs)
                XCTAssertTrue(tabs.selectedViewController === page)
            }
            verify(initialLocale)
            for locale in [AppLocale.arabic, .simplifiedChinese, .arabic, .simplifiedChinese] {
                let previous = localization.currentSnapshot
                localization.setLocale(identifier: locale.identifier)
                coordinator.apply(LocalizationChange(previous: previous, current: localization.currentSnapshot), animated: false)
                verify(locale)
                coordinator.synchronize(window: window)
                verify(locale)
            }
        }
    }
}

@MainActor
private final class TabDirectionRecordingPage: UIViewController, UIKitLocalizationApplying {
    var observedContainerDirection: UITraitEnvironmentLayoutDirection?
    func applyLocalization(_ update: UIKitLocalizationUpdate) {
        observedContainerDirection = tabBarController?.traitCollection.layoutDirection
    }
}
#endif
