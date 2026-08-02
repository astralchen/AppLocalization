import Foundation
import AppLocalization

@MainActor
final class DemoServices: ObservableObject {
    let localizationController: LocalizationController
    let resolver: LocalizedStringResolver

    init() {
        let localizationController = LocalizationController(
            supportedLocales: [.englishUS, .simplifiedChinese, .arabic],
            fallbackLocale: .englishUS,
            preferenceStore: UserDefaultsLocalePreferenceStore(key: "demo.locale.identifier")
        )
        self.localizationController = localizationController
        self.resolver = LocalizedStringResolver(
            localeProvider: { [localizationController] in localizationController.currentLocale },
            fallbackLocale: .englishUS,
            missingKeyHandler: { key, locale, _ in
                assertionFailure("Missing localization key '\(key)' for \(locale.identifier)")
            }
        )
    }
}
