/*
 有关此示例的许可信息，请参阅 LICENSE 文件夹。
 */

import Foundation
import AppLocalization
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class TodayLocalizationServices {
    static let shared = TodayLocalizationServices()

    let localizationController: LocalizationController
    let resolver: LocalizedStringResolver
#if canImport(UIKit)
    let localizationContext: UIKitLocalizationContext
    lazy var localizationCoordinator = UIWindowSceneLocalizationCoordinator(
        localizationController: localizationController
    )
#endif

    private init() {
        let localizationController = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese, .arabic],
            fallbackLocale: .englishUS,
            preferenceStore: UserDefaultsLocalePreferenceStore(key: "today.locale.identifier")
        )

        self.localizationController = localizationController
#if canImport(UIKit)
        self.localizationContext = UIKitLocalizationContext(
            localizationController: localizationController
        )
#endif
        self.resolver = LocalizedStringResolver(
            localeProvider: { [localizationController] in
                localizationController.currentLocale
            },
            fallbackLocale: .englishUS,
            missingKeyHandler: { key, locale, _ in
                assertionFailure("Missing localization key '\(key)' for \(locale.identifier)")
            }
        )
    }
}
