/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import Foundation
import AppLocalization
import UIKit

@MainActor
final class TodayLocalizationServices {
    static let shared = TodayLocalizationServices()

    let localizationController: LocalizationController
    let resolver: LocalizedStringResolver
    lazy var localizationCoordinator = UIWindowSceneLocalizationCoordinator(
        localizationController: localizationController
    )

    private init() {
        let localizationController = LocalizationController(
            preferenceStore: UserDefaultsLocalePreferenceStore(key: "today.locale.identifier")
        )

        self.localizationController = localizationController
        self.resolver = LocalizedStringResolver(
            localeProvider: { [localizationController] in
                localizationController.currentLocale
            },
            fallbackLocale: AppLocale(identifier: localizationController.fallbackLocalization),
            missingKeyHandler: { key, locale, _ in
                assertionFailure("Missing localization key '\(key)' for \(locale.identifier)")
            }
        )
    }
}
