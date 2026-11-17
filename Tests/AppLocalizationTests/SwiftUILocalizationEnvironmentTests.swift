import SwiftUI
import UIKit
import XCTest
@testable import AppLocalization

@MainActor
final class SwiftUILocalizationEnvironmentTests: XCTestCase {
    func testNativeDirectionReachesSwiftUIEnvironmentWithoutReplacingContent() async throws {
        let controller = LocalizationController(
            resourceBundle: localizationTestBundle(["en-US", "zh-Hans", "ar"], developmentLocalization: "en-US"),
            preferenceStore: InMemoryLocalePreferenceStore(localeIdentifier: "ar"))
        let observation = EnvironmentObservation()
        let host = UIHostingController(rootView: EnvironmentReader(observation: observation)
            .appLocalizationEnvironment(controller))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = host
        defer { window.isHidden = true; observation.onUpdate = { _, _, _ in } }
        var originalView: UIView?

        for identifier in ["ar", "en-US", "zh-Hans", "ar", "en-US"] {
            let expectedDirection: SwiftUI.LayoutDirection = identifier == "ar" ? .rightToLeft : .leftToRight
            let rendered = expectation(description: "环境更新为 \(identifier)")
            var fulfilled = false
            observation.onUpdate = { locale, direction, view in
                guard locale.identifier == identifier, direction == expectedDirection, !fulfilled else { return }
                fulfilled = true
                if let originalView {
                    XCTAssertTrue(view === originalView)
                } else {
                    originalView = view
                }
                rendered.fulfill()
            }
            if window.isHidden {
                window.makeKeyAndVisible()
            } else {
                controller.setLocale(identifier: identifier)
            }
            // 等待 SwiftUI 自己投递环境，不替换根视图或强制重建内容。
            await fulfillment(of: [rendered], timeout: 3)
            XCTAssertTrue(window.rootViewController === host)
            XCTAssertEqual(controller.layoutDirection, identifier == "ar" ? .rightToLeft : .leftToRight)
        }
        XCTAssertNotNil(originalView)
    }
}

@MainActor
private final class EnvironmentObservation {
    var onUpdate: (Locale, SwiftUI.LayoutDirection, UIView) -> Void = { _, _, _ in }
}

private struct EnvironmentReader: UIViewRepresentable {
    let observation: EnvironmentObservation
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ view: UIView, context: Context) {
        observation.onUpdate(context.environment.locale, context.environment.layoutDirection, view)
    }
}
