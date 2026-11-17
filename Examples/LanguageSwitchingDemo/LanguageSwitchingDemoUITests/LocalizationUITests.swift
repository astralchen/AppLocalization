import XCTest
import Vision

@MainActor
final class LocalizationUITests: XCTestCase {
    func testEmptyDraftCaretFollowsLeadingEdgeAfterLanguageSwitches() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demo.locale.identifier", "ar"]
        app.launch()
        let push = app.buttons["demo.push"]
        for _ in 0..<6 where !push.isHittable { app.swipeUp() }
        XCTAssertTrue(push.isHittable)
        push.tap()
        let draft = app.textFields["draft.field"]
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        draft.tap()
        for locale in ["ar", "en", "ar", "zh-Hans", "ar"] {
            app.buttons["language.option.\(locale)"].tap()
            XCTAssertTrue(app.keyboards.firstMatch.exists)
            attach(app, name: "empty-draft-\(locale)")
            try assertEmptyCaret(in: draft, rightToLeft: locale == "ar")
        }
        // 语言往返后直接输入，不能通过再次点击输入框恢复焦点。
        draft.typeText("Retained draft")
        XCTAssertEqual(draft.value as? String, "Retained draft")
        attach(app, name: "aligned-draft-ar")
    }

    func testSemanticPanUsesNativeEdgesAfterLanguageSwitches() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demo.locale.identifier", "en"]
        app.launch()
        XCTAssertTrue(app.buttons["language.option.ar"].waitForExistence(timeout: 10))
        let result = app.staticTexts["gesture.pan.result"]
        let window = app.windows.firstMatch
        for locale in ["en", "ar", "en"] {
            let language = app.buttons["language.option.\(locale)"]
            for _ in 0..<6 where !language.isHittable { app.swipeDown() }
            XCTAssertTrue(language.isHittable)
            language.tap()
            for _ in 0..<6 where !result.isHittable { app.swipeUp() }
            XCTAssertTrue(result.isHittable)
            let y = (result.frame.midY - window.frame.minY) / window.frame.height
            let left = window.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: y))
            let right = window.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: y))
            // 在手势示例内部真实横向拖动，不触碰系统返回边缘。
            left.press(forDuration: 0.05, thenDragTo: right)
            XCTAssertTrue(result.label.hasSuffix(locale == "ar" ? "leading" : "trailing"), result.label)
            right.press(forDuration: 0.05, thenDragTo: left)
            XCTAssertTrue(result.label.hasSuffix(locale == "ar" ? "trailing" : "leading"), result.label)
            attach(app, name: "semantic-pan-\(locale)")
        }
    }

    func testLanguageRoundTripKeepsReadableGlyphs() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demo.locale.identifier", "en"]
        app.launch()
        XCTAssertTrue(app.buttons["language.option.ar"].waitForExistence(timeout: 10))
        for locale in ["en", "ar", "zh-Hans", "ar", "en"] {
            app.buttons["language.option.\(locale)"].tap()
            attach(app, name: "glyphs-\(locale)")
            try assertReadableEnglish(in: app)
        }
    }

    func testConfiguredModalButtonSurvivesLiveLanguageSwitches() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demo.locale.identifier", "ar"]
        app.launch()
        let open = app.buttons["uikit.show.modal"]
        for _ in 0..<6 where !open.isHittable { app.swipeUp() }
        XCTAssertTrue(open.isHittable)
        open.tap()
        let picker = app.segmentedControls["uikit.modal.language"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let close = app.buttons["uikit.modal.configured.close"]
        let direction = app.staticTexts["uikit.modal.native.direction"]
        XCTAssertTrue(direction.waitForExistence(timeout: 5))
        // 页面在 RTL 已生效后才呈现，必须直接继承 Scene 的方向。
        XCTAssertEqual(direction.label, "RTL")
        // Modal 始终保持打开，通过原生控件在同一按钮实例上反复切换。
        for (label, name) in [("العربية", "ar"), ("English", "en"), ("简体中文", "zh"), ("العربية", "ar-again"), ("English", "en-again")] {
            picker.buttons.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch.tap()
            XCTAssertTrue(close.isHittable)
            XCTAssertEqual(direction.label, name.hasPrefix("ar") ? "RTL" : "LTR")
            let navigationClose = app.buttons["uikit.modal.navigation.close"]
            XCTAssertTrue(navigationClose.isHittable)
            if name.hasPrefix("ar") {
                XCTAssertGreaterThan(navigationClose.frame.midX, app.windows.firstMatch.frame.midX)
            } else {
                XCTAssertLessThan(navigationClose.frame.midX, app.windows.firstMatch.frame.midX)
            }
            attach(app, name: "configured-button-\(name)")
        }
        close.tap()
        XCTAssertFalse(picker.exists)
        XCTAssertFalse(close.exists)
        // 方向切换会重建根页面的 List 并回到顶部，验证返回根页而非离屏的 UIKit 行。
        XCTAssertTrue(app.buttons["language.option.en"].waitForExistence(timeout: 5))
    }

    func testCustomNavigationCloseActionAfterDirectionRoundTrip() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demo.locale.identifier", "en"]
        app.launch()
        let open = app.buttons["uikit.show.modal"]
        for _ in 0..<6 where !open.isHittable { app.swipeUp() }
        XCTAssertTrue(open.isHittable)
        open.tap()
        let picker = app.segmentedControls["uikit.modal.language"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let close = app.buttons["uikit.modal.navigation.close"]
        // 与原有用例的 RTL 初始呈现互补：从 LTR 开始，再往返切换。
        XCTAssertLessThan(close.frame.midX, app.windows.firstMatch.frame.midX)
        for label in ["العربية", "English", "العربية"] {
            picker.buttons.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch.tap()
            XCTAssertTrue(close.isHittable)
            if label == "العربية" {
                XCTAssertGreaterThan(close.frame.midX, app.windows.firstMatch.frame.midX)
            } else {
                XCTAssertLessThan(close.frame.midX, app.windows.firstMatch.frame.midX)
            }
        }
        attach(app, name: "custom-navigation-rtl-before-close")
        close.tap()
        XCTAssertFalse(picker.exists)
        XCTAssertTrue(app.buttons["language.option.ar"].waitForExistence(timeout: 5))
    }

    func testNativeRootAndSwiftUISheetInBothDirections() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demo.locale.identifier", "en"]
        app.launch()
        XCTAssertTrue(app.buttons["language.option.ar"].waitForExistence(timeout: 10))
        for (locale, title, closeTitle) in [("ar", "صفحة SwiftUI", "إغلاق"), ("en", "SwiftUI Sheet", "Close")] {
            for _ in 0..<5 where !app.buttons["language.option.\(locale)"].isHittable { app.swipeDown() }
            app.buttons["language.option.\(locale)"].tap()
            // 根导航项没有返回按钮，也没有自定义伪返回按钮。
            XCTAssertEqual(app.navigationBars.buttons.count, 0)
            let open = app.buttons["demo.sheet"]
            for _ in 0..<5 where !open.isHittable { app.swipeUp() }
            XCTAssertTrue(open.isHittable)
            open.tap()
            let close = app.buttons["demo.sheet.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            XCTAssertEqual(close.label, closeTitle)
            XCTAssertTrue(app.navigationBars[title].exists)
            XCTAssertTrue(app.staticTexts["demo.sheet.message"].exists)
            let middle = app.windows.firstMatch.frame.midX
            if locale == "ar" {
                XCTAssertGreaterThan(close.frame.midX, middle)
            } else {
                XCTAssertLessThan(close.frame.midX, middle)
            }
            attach(app, name: "native-sheet-\(locale)")
            close.tap()
            XCTAssertFalse(close.exists)
            XCTAssertTrue(open.waitForExistence(timeout: 5))
            XCTAssertEqual(app.navigationBars.buttons.count, 0)
        }
    }

    override func record(_ issue: XCTIssue) {
        // 将状态更新警告纳入验收，避免界面断言通过却遗漏 SwiftUI 运行期回归。
        if issue.compactDescription.contains("Modifying state during view update") {
            super.record(XCTIssue(
                type: .assertionFailure,
                compactDescription: issue.compactDescription,
                detailedDescription: issue.detailedDescription,
                sourceCodeContext: issue.sourceCodeContext,
                associatedError: issue.associatedError,
                attachments: issue.attachments
            ))
            return
        }
        super.record(issue)
    }

    func testLiveSwitchKeepsDraftNavigationAndSemanticBackGestures() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demo.locale.identifier", "en"]
        app.launch()
        let arabic = app.buttons["language.option.ar"]
        XCTAssertTrue(arabic.waitForExistence(timeout: 10))
        arabic.tap()
        XCTAssertTrue(app.staticTexts["RTL"].waitForExistence(timeout: 5))
        attach(app, name: "root-arabic")
        app.buttons["language.option.en"].tap()
        XCTAssertTrue(app.staticTexts["LTR"].waitForExistence(timeout: 5))
        let push = app.buttons["demo.push"]
        for _ in 0..<5 where !push.isHittable { app.swipeUp() }
        push.tap()
        let draft = app.textFields["draft.field"]
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Pop Gesture"].staticTexts["Pop Gesture"].exists)
        draft.tap()
        draft.typeText("Retained draft")
        // 点击语言行会触发真实热切换，不能重置导航目的地或输入状态。
        app.buttons["language.option.ar"].tap()
        XCTAssertTrue(draft.exists)
        XCTAssertEqual(draft.value as? String, "Retained draft")
        XCTAssertTrue(app.navigationBars["إيماءة الرجوع"].staticTexts["إيماءة الرجوع"].exists)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        // 不重新点击输入框，直接继续输入，验证切换后编辑焦点和插入位置仍然有效。
        draft.typeText(" RTL")
        XCTAssertEqual(draft.value as? String, "Retained draft RTL")
        try assertReadableEnglish(in: app)
        app.buttons["language.option.en"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        draft.typeText(" LTR")
        XCTAssertEqual(draft.value as? String, "Retained draft RTL LTR")
        try assertReadableEnglish(in: app, including: "Pop Gesture")
        attach(app, name: "detail-english-draft")
        app.buttons["language.option.ar"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertEqual(draft.value as? String, "Retained draft RTL LTR")
        XCTAssertTrue(app.navigationBars["إيماءة الرجوع"].staticTexts["إيماءة الرجوع"].exists)
        attach(app, name: "detail-arabic-draft")
        // 错误物理边缘不能出栈。
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.003, dy: 0.25))
            .press(forDuration: 0.05, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.25)))
        XCTAssertTrue(draft.exists)
        // 真实右边缘返回手势；返回后语言选择器和主页入口仍然存在。
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.997, dy: 0.25))
            .press(forDuration: 0.05, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.25)))
        XCTAssertTrue(push.waitForExistence(timeout: 5))
        XCTAssertFalse(draft.exists)
        for _ in 0..<5 where !app.buttons["language.option.en"].isHittable { app.swipeDown() }
        app.buttons["language.option.en"].tap()
        for _ in 0..<5 where !push.isHittable { app.swipeUp() }
        push.tap()
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.003, dy: 0.25))
            .press(forDuration: 0.05, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.25)))
        XCTAssertTrue(push.waitForExistence(timeout: 5))
        XCTAssertFalse(draft.exists)
        attach(app, name: "root-english-after-pop")
    }

    private func assertEmptyCaret(in field: XCUIElement, rightToLeft: Bool) throws {
        // 读取真实输入框截图中的蓝色光标，不依赖无障碍标签或内部 UIKit 视图。
        // 光标会闪烁，因此只在可见帧断言位置，不通过重新聚焦干预被测行为。
        for _ in 0..<6 {
            let screenshot = field.screenshot()
            let image = try XCTUnwrap(screenshot.image.cgImage)
            let width = image.width
            let height = image.height
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            try pixels.withUnsafeMutableBytes { bytes in
                let context = try XCTUnwrap(CGContext(
                    data: bytes.baseAddress, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
                ))
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            var columns: [Int] = []
            for x in 0..<width {
                let blueCount = (0..<height).filter { y in
                    let i = (y * width + x) * 4
                    return Int(pixels[i + 2]) > 150
                        && Int(pixels[i + 2]) > Int(pixels[i]) + 50
                        && Int(pixels[i + 2]) > Int(pixels[i + 1]) + 20
                }.count
                if blueCount > height / 4 { columns.append(x) }
            }
            guard let first = columns.first, let last = columns.last else { continue }
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = rightToLeft ? "caret-rtl" : "caret-ltr"
            attachment.lifetime = .keepAlways
            add(attachment)
            let relativeX = Double(first + last) / (2 * Double(width))
            if rightToLeft {
                XCTAssertGreaterThan(relativeX, 0.75, "RTL 空光标应靠右，实际相对位置：\(relativeX)")
            } else {
                XCTAssertLessThan(relativeX, 0.25, "LTR 空光标应靠左，实际相对位置：\(relativeX)")
            }
            return
        }
        XCTFail("连续截图未找到空输入框的可见光标")
    }

    private func assertReadableEnglish(in app: XCUIApplication, including title: String? = nil) throws {
        // 无障碍标签不会反映像素镜像；直接识别屏幕，确认英文原生名称仍可正常阅读。
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en"]
        let screenshot = app.screenshot()
        let image = try XCTUnwrap(screenshot.image.cgImage)
        try VNImageRequestHandler(cgImage: image).perform([request])
        let recognized = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        XCTAssertTrue(recognized.contains { $0.contains("English") }, "屏幕文字识别结果：\(recognized)")
        if let title {
            XCTAssertTrue(recognized.contains { $0.contains(title) }, "导航标题未绘制：\(recognized)")
        }
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
