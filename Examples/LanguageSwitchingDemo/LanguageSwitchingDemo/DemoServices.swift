import Foundation
import AppLocalization
import UIKit

@MainActor
final class DemoServices {
    let localizationController: LocalizationController
    let resolver: LocalizedStringResolver
    lazy var localizationCoordinator = UIWindowSceneLocalizationCoordinator(
        localizationController: localizationController
    )

    init() {
        let localizationController = LocalizationController(
            preferenceStore: UserDefaultsLocalePreferenceStore(key: "demo.locale.identifier")
        )
        self.localizationController = localizationController
        self.resolver = LocalizedStringResolver(
            localeProvider: { [localizationController] in localizationController.currentLocale },
            fallbackLocale: AppLocale(identifier: localizationController.fallbackLocalization),
            missingKeyHandler: { key, locale, _ in
                assertionFailure("Missing localization key '\(key)' for \(locale.identifier)")
            }
        )
    }
}
