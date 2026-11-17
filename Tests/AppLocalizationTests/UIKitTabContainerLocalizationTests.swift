import UIKit
import XCTest
@testable import AppLocalization

@MainActor
final class UIKitTabContainerLocalizationTests: XCTestCase {
    @available(iOS 17.0, *)
    func testRegistrationAndRoundTripsSynchronizeTabTraitsBeforeChildren() {
        for initialLocale in [AppLocale(identifier: "zh-Hans"), AppLocale(identifier: "ar")] {
            let localization = LocalizationController(
                resourceBundle: localizationTestBundle(["zh-Hans", "ar"], developmentLocalization: "zh-Hans"),
                preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: initialLocale.identifier)
            )
            let coordinator = UIWindowSceneLocalizationCoordinator(localizationController: localization)
            let page = TabDirectionRecordingPage()
            let tabs = UITabBarController()
            tabs.viewControllers = [page, UIViewController()]
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 768, height: 1024))
            window.rootViewController = tabs
            tabs.loadViewIfNeeded()
            page.loadViewIfNeeded()
            window.makeKeyAndVisible()
            let opposite: UITraitEnvironmentLayoutDirection = initialLocale == AppLocale(identifier: "ar") ? .leftToRight : .rightToLeft
            if let scene = window.windowScene { scene.traitOverrides.layoutDirection = opposite }
            else { window.traitOverrides.layoutDirection = opposite }
            defer { window.isHidden = true }
            coordinator.register(window: window)
            defer { coordinator.unregister(window: window) }

            func verify(_ locale: AppLocale) {
                let expected: UITraitEnvironmentLayoutDirection = locale == AppLocale(identifier: "ar") ? .rightToLeft : .leftToRight
                XCTAssertEqual(tabs.traitCollection.layoutDirection, expected)
                XCTAssertEqual(page.observedContainerDirection, expected)
                XCTAssertEqual(tabs.view.effectiveUserInterfaceLayoutDirection, locale.layoutDirection)
                XCTAssertEqual(tabs.tabBar.effectiveUserInterfaceLayoutDirection, locale.layoutDirection)
                XCTAssertTrue(window.rootViewController === tabs)
                XCTAssertTrue(tabs.selectedViewController === page)
            }
            verify(initialLocale)
            for locale in [AppLocale(identifier: "ar"), AppLocale(identifier: "zh-Hans"), AppLocale(identifier: "ar"), AppLocale(identifier: "zh-Hans")] {
                localization.setLocale(identifier: locale.identifier)

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
    func applyLocalization(_ update: LocalizationUpdate) {
        observedContainerDirection = tabBarController?.traitCollection.layoutDirection
    }
}
