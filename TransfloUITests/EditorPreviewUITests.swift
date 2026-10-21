import XCTest

/// Captures tool editors through the debug-only `-TransfloPreviewEditor` launch argument.
@MainActor
final class EditorPreviewUITests: TransfloUITestCase {
    private func editor(_ tool: String, language: String, appearance: String) -> XCUIElement {
        continueAfterFailure = false
        let app = makeApplication()
        app.launchArguments = [
            LaunchArgument.previewEditor, tool,
            "-settings.language", language,
            "-settings.appearance", appearance
        ]
        app.launch()
        let window = app.windows[WindowIdentifier.toolEditor]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        return window
    }

    /// Clicks the slider's track at `fraction` of its width, as a person would. The editors' sliders are
    /// custom-drawn, so their accessible stand-in has no orientation for `adjust(toNormalizedSliderPosition:)`.
    private func setSlider(_ slider: XCUIElement, to fraction: CGFloat) {
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.coordinate(withNormalizedOffset: CGVector(dx: fraction, dy: 0.85)).click()
    }

    func testAdjustEditorInArabicDark() {
        let window = editor("adjust", language: "ar", appearance: "dark")
        XCUIApplication().activate()
        let exposure = window.sliders["التعريض"]
        XCTAssertTrue(exposure.waitForExistence(timeout: 5))
        setSlider(exposure, to: 0.7)
        XCTAssertTrue(window.buttons["transflo.adjust.reset.editor.exposure"].isEnabled)
        attachDiagnosticScreenshot(window, named: "editor-adjust-ar-dark")
    }

    func testCompressionPresets() {
        let window = editor("compress", language: "en", appearance: "light")
        XCUIApplication().activate()
        let compress = window.buttons["Compress"]
        XCTAssertTrue(compress.waitForExistence(timeout: 5))
        for preset in ["Smaller file", "Best quality", "Balanced"] {
            window.buttons[preset].click()
            XCTAssertTrue(window.buttons[preset].isSelected, preset)
        }
        XCTAssertTrue(compress.isEnabled)
        XCTAssertTrue(compress.isHittable)
        attachDiagnosticScreenshot(window, named: "editor-compress-en-light")
    }

    func testRotateAndMirrorControlsInBothLanguages() {
        for (language, appearance, reset, mirror) in [
            ("en", "light", "Reset", "Mirror horizontally"), ("ar", "dark", "إعادة تعيين", "انعكاس أفقي")
        ] {
            let window = editor("rotate", language: language, appearance: appearance)
            XCUIApplication().activate()
            let apply = window.buttons["transflo.editor.apply"]
            XCTAssertTrue(apply.waitForExistence(timeout: 5))
            window.buttons[reset].click()
            XCTAssertFalse(apply.isEnabled)
            let checkbox = window.checkBoxes[mirror]
            (checkbox.exists ? checkbox : window.switches[mirror]).click()
            XCTAssertTrue(apply.isEnabled)
            XCTAssertLessThanOrEqual(apply.frame.maxY, window.frame.maxY)
        }
    }

    func testAnnotateEditorInEnglishLight() {
        let window = editor("annotate", language: "en", appearance: "light")
        XCTAssertTrue(window.buttons["Arrow"].waitForExistence(timeout: 5))
        XCTAssertTrue(window.buttons["Teal"].exists)
        XCTAssertFalse(window.buttons["transflo.editor.apply"].isEnabled)
        attachDiagnosticScreenshot(window, named: "editor-annotate-en-light")
    }

    func testRedactEditorInArabicDark() {
        let window = editor("redact", language: "ar", appearance: "dark")
        XCTAssertTrue(window.buttons["تراجع"].waitForExistence(timeout: 5))
        attachDiagnosticScreenshot(window, named: "editor-redact-ar-dark")
    }

    func testCollageEditorInEnglishLight() {
        let window = editor("collage", language: "en", appearance: "light")
        XCTAssertTrue(window.staticTexts["Columns"].waitForExistence(timeout: 5))
        XCTAssertTrue(window.buttons["transflo.editor.apply"].isEnabled)
        attachDiagnosticScreenshot(window, named: "editor-collage-en-light")
    }

    func testReorganizeEditorInEnglishDark() {
        let window = editor("reorganizePages", language: "en", appearance: "dark")
        XCTAssertTrue(window.staticTexts["Page 4"].waitForExistence(timeout: 5))
        attachDiagnosticScreenshot(window, named: "editor-reorganize-en-dark")
    }

    func testExtractEditorInArabicLight() {
        let window = editor("extractPages", language: "ar", appearance: "light")
        // Stable identifiers keep selection independent of Foundation’s bidi formatting.
        let page = window.buttons["transflo.page.2"]
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        XCTAssertTrue(page.label.contains("الصفحة"))
        // Bring Transflo forward (another app's window may cover it), then click once the
        // asynchronously loaded thumbnails have settled.
        XCUIApplication().activate()
        let clickable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: page)
        wait(for: [clickable], timeout: 10)
        page.click()
        XCTAssertTrue(window.buttons["transflo.editor.apply"].isEnabled)
        attachDiagnosticScreenshot(window, named: "editor-extract-ar-light")
    }

    func testMetadataEditorInArabicDark() {
        let window = editor("editMetadata", language: "ar", appearance: "dark")
        XCTAssertTrue(window.staticTexts["العنوان"].waitForExistence(timeout: 5))
        attachDiagnosticScreenshot(window, named: "editor-metadata-ar-dark")
    }

    func testRenameEditorInEnglishLight() {
        let window = editor("rename", language: "en", appearance: "light")
        XCTAssertTrue(window.staticTexts["Holiday photo 1 1.heic"].waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["Holiday photo 4.heic"].exists)
        attachDiagnosticScreenshot(window, named: "editor-rename-en-light")
    }

    func testResizeEditorInEnglishDark() {
        let window = editor("resize", language: "en", appearance: "dark")
        XCTAssertTrue(window.staticTexts["Keep proportions"].waitForExistence(timeout: 5))
        attachDiagnosticScreenshot(window, named: "editor-resize-en-dark")
    }
    func testCropPortraitChipsPixelFieldsAndReset() {
        let window = editor("crop", language: "en", appearance: "light")
        XCUIApplication().activate()
        let portrait = window.buttons["9:16"]
        XCTAssertTrue(portrait.waitForExistence(timeout: 5))
        portrait.click()
        XCTAssertTrue(portrait.isSelected)
        XCTAssertTrue(window.textFields["Width"].exists)
        XCTAssertTrue(window.textFields["Height"].exists)
        XCTAssertTrue(window.buttons["transflo.editor.apply"].isEnabled)
        XCTAssertTrue(window.buttons["Square"].exists)
        window.buttons["Square"].click()
        let width = window.textFields["Width"]
        width.click()
        XCUIApplication().typeKey("a", modifierFlags: .command)
        width.typeText("120")
        XCUIApplication().typeKey(.tab, modifierFlags: [])
        XCTAssertEqual(window.textFields["Height"].value as? String, "120")
        let scroll = window.scrollViews.firstMatch
        for _ in 0..<4 where !window.buttons["Reset"].isHittable {
            scroll.scroll(byDeltaX: 0, deltaY: -180)
        }
        window.buttons["Reset"].click()
        XCTAssertTrue(window.buttons["Free"].isSelected)
        XCTAssertFalse(window.buttons["transflo.editor.apply"].isEnabled)
        width.click()
        XCUIApplication().typeKey("a", modifierFlags: .command)
        width.typeText("abc")
        XCUIApplication().typeKey(.tab, modifierFlags: [])
        XCTAssertFalse(window.buttons["transflo.editor.apply"].isEnabled)
        attachDiagnosticScreenshot(window, named: "editor-crop-pixels-en-light")
    }

    func testCropChipsInArabicDark() {
        let window = editor("crop", language: "ar", appearance: "dark")
        XCUIApplication().activate()
        XCTAssertTrue(window.buttons["4:5"].waitForExistence(timeout: 5))
        window.buttons["4:5"].click()
        XCTAssertTrue(window.buttons["transflo.editor.apply"].isEnabled)
        attachDiagnosticScreenshot(window, named: "editor-crop-pixels-ar-dark")
    }
    func testBeautifyControlsAndLivePreview() {
        let window = editor("addBackground", language: "en", appearance: "light")
        XCUIApplication().activate()
        let save = window.buttons["Save with Background"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(window.buttons["Black"].exists)
        window.buttons["transflo.background.moss"].click()
        window.buttons["9:16"].click()
        setSlider(window.sliders["Padding"], to: 0.5)
        let ready = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        wait(for: [ready], timeout: 10)
        attachDiagnosticScreenshot(window, named: "editor-beautify-en-light")
        window.buttons["Reset"].click()
        XCTAssertTrue(window.buttons["Auto"].isSelected)
        XCTAssertTrue(window.buttons["transflo.background.lagoon"].isSelected)
    }

    func testBeautifyInArabicDark() {
        let window = editor("addBackground", language: "ar", appearance: "dark")
        XCUIApplication().activate()
        XCTAssertTrue(window.buttons["حفظ مع الخلفية"].waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["نسبة أبعاد اللوحة"].exists)
        attachDiagnosticScreenshot(window, named: "editor-beautify-ar-dark")
    }
}
