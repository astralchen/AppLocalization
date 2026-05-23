import SwiftUI

struct UIKitDemoRepresentable: UIViewControllerRepresentable {
    let localizationController: LocalizationController
    let resolver: LocalizedStringResolver
    let onPushRequested: () -> Void

    func makeUIViewController(context: Context) -> UIKitLocalizationDemoViewController {
        UIKitLocalizationDemoViewController(
            localizationController: localizationController,
            resolver: resolver,
            onPushRequested: onPushRequested
        )
    }

    func updateUIViewController(_ viewController: UIKitLocalizationDemoViewController, context: Context) {
        _ = context.environment.locale
        _ = context.environment.layoutDirection
        viewController.reloadLocalizedContent()
        viewController.reloadLayoutDirection(localizationController.layoutDirection.uiLayoutDirection)
    }
}
