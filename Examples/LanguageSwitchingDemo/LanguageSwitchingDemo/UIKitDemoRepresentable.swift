import SwiftUI
import AppLocalization

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
        viewController.applyLocalization(
            .initial(snapshot: localizationController.currentSnapshot)
        )
    }
}

struct WindowLocalizationRegistrationView: UIViewRepresentable {
    let coordinator: UIWindowSceneLocalizationCoordinator

    func makeUIView(context: Context) -> WindowRegistrationView {
        let view = WindowRegistrationView()
        view.coordinator = coordinator
        return view
    }

    func updateUIView(_ view: WindowRegistrationView, context: Context) {
        view.coordinator = coordinator
        view.synchronizeCurrentWindow()
    }
}

final class WindowRegistrationView: UIView {
    weak var coordinator: UIWindowSceneLocalizationCoordinator?
    private weak var registeredWindow: UIWindow?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        synchronizeCurrentWindow()
    }

    func synchronizeCurrentWindow() {
        if let registeredWindow, registeredWindow !== window {
            coordinator?.unregister(window: registeredWindow)
            self.registeredWindow = nil
        }
        guard let window else { return }
        if registeredWindow !== window {
            coordinator?.register(window: window)
            registeredWindow = window
        } else {
            coordinator?.synchronize(window: window)
        }
    }
}
