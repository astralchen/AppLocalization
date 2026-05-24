/*
 See LICENSE folder for this sample's licensing information.
 */

import Foundation

@MainActor
final class TodayLocalizationServices {
    static let shared = TodayLocalizationServices()

    let localizationController: LocalizationController
    let resolver: LocalizedStringResolver

    private init() {
        let localizationController = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese, .arabic],
            fallbackLocale: .englishUS,
            preferenceStore: UserDefaultsLocalePreferenceStore(key: "today.locale.identifier")
        )

        self.localizationController = localizationController
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

