import XCTest

/// Captures the wheel through the debug-only preview launch argument, because real Finder drags
/// cannot be automated without Accessibility access.
@MainActor
final class WheelPreviewUITests: TransfloUITestCase {
    private func wheel(_ name: String, language: String, appearance: String) -> XCUIElement {
        continueAfterFailure = false
        let app = makeApplication()
        app.launchArguments = [
            LaunchArgument.previewWheel, name,
            "-settings.language", language,
            "-settings.appearance", appearance
        ]
        app.launch()
        // A non-activating borderless panel is exposed to accessibility as a dialog, not a window.
        let window = app.dialogs[WindowIdentifier.wheel]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        return window
    }

    func testConvertWheelInEnglishLight() {
        let window = wheel("convert", language: "en", appearance: "light")
        XCTAssertTrue(window.buttons["PNG"].exists)
        // The preview hovers JPG: that petal is the selected button, and the hub names it.
        XCTAssertTrue(window.buttons["JPG"].isSelected)
        XCTAssertFalse(window.buttons["PNG"].isSelected)
        XCTAssertTrue(window.staticTexts["JPG"].exists)
        attachDiagnosticScreenshot(window, named: "wheel-convert-en-light")
    }

    func testActionsWheelInArabicDark() {
        let window = wheel("actions", language: "ar", appearance: "dark")
        // The preview hovers Terminal: its petal is selected and the hub pill names it.
        XCTAssertTrue(window.buttons["الطرفية"].isSelected)
        XCTAssertTrue(window.staticTexts["الطرفية"].exists)
        attachDiagnosticScreenshot(window, named: "wheel-actions-ar-dark")
    }

    func testActionsWheelInEnglishLight() {
        let window = wheel("actions", language: "en", appearance: "light")
        // Each petal is a button for VoiceOver, named after its option.
        for name in ["AirDrop", "Archive", "Copy", "Move", "Copy Path", "Terminal"] {
            XCTAssertTrue(window.buttons[name].exists, name)
        }
        XCTAssertTrue(window.buttons["Archive"].isSelected)
        attachDiagnosticScreenshot(window, named: "wheel-actions-en-light")
    }

    func testToolsWheelInEnglishDark() {
        let window = wheel("tools", language: "en", appearance: "dark")
        XCTAssertTrue(window.buttons["Compress"].exists)
        XCTAssertTrue(window.buttons["Size & Crop"].exists)
        XCTAssertTrue(window.buttons["Metadata"].exists)
        XCTAssertFalse(window.buttons["More"].exists)
        attachDiagnosticScreenshot(window, named: "wheel-tools-en-dark")
        window.buttons["Size & Crop"].click()
        XCTAssertTrue(window.buttons["Upscale 2×"].waitForExistence(timeout: 3))
        XCTAssertEqual(window.buttons.matching(identifier: "Upscale 2×").count, 1)
        XCTAssertTrue(window.buttons["Back"].exists)
        window.buttons["Back"].click()
        XCTAssertTrue(window.buttons["Metadata"].waitForExistence(timeout: 3))
        window.buttons["Metadata"].click()
        XCTAssertTrue(window.buttons["Remove Metadata"].waitForExistence(timeout: 3))
        XCTAssertEqual(window.buttons.matching(identifier: "Remove Metadata").count, 1)
    }
    func testGroupedToolsInArabic() {
        let window = wheel("tools", language: "ar", appearance: "dark")
        XCTAssertTrue(window.buttons["الحجم والقص"].exists)
        window.buttons["الحجم والقص"].click()
        XCTAssertTrue(window.buttons["تكبير ×2"].waitForExistence(timeout: 3))
        XCTAssertTrue(window.buttons["رجوع"].exists)
        attachDiagnosticScreenshot(window, named: "wheel-tools-size-ar-dark")
        window.buttons["رجوع"].click()
        XCTAssertTrue(window.buttons["البيانات الوصفية"].waitForExistence(timeout: 3))
    }

    func testSavedRecipeAppearsOnToolsWheelAfterRelaunch() {
        continueAfterFailure = false
        let app = makeApplication()
        app.launchArguments = [LaunchArgument.openSettings, LaunchArgument.settingsTab, "recipes",
                               "-settings.language", "en"]
        app.launch()
        let settings = app.windows[WindowIdentifier.settings]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.buttons["settings.recipes.new"].click()
        let name = settings.textFields["settings.recipes.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText("Quick clean")
        settings.buttons["+ Compress"].click()
        let save = settings.buttons["settings.recipes.save"]
        settings.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -600)
        save.click()
        XCTAssertTrue(settings.buttons["settings.recipes.edit.Quick clean"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = [LaunchArgument.previewWheel, "tools", "-settings.language", "en"]
        app.launch()
        let wheel = app.dialogs[WindowIdentifier.wheel]
        XCTAssertTrue(wheel.buttons["Recipes"].waitForExistence(timeout: 10))
        wheel.buttons["Recipes"].click()
        XCTAssertTrue(wheel.buttons["Quick clean"].waitForExistence(timeout: 5))
        XCTAssertFalse(wheel.buttons["Manage Recipes"].exists)
        attachDiagnosticScreenshot(wheel, named: "saved-recipe-wheel")
    }

    func testMultiFileBadgeAndSummaryOnEveryWheel() {
        for kind in ["convert", "tools", "actions"] {
            let app = makeApplication()
            app.launchArguments = [LaunchArgument.screenshotBackdrop, LaunchArgument.previewWheel, kind,
                                   LaunchArgument.previewItemCount, "2",
                                   "-settings.language", "en", "-settings.appearance", "light"]
            app.launch()
            app.activate()
            let window = app.dialogs[WindowIdentifier.wheel]
            XCTAssertTrue(window.waitForExistence(timeout: 10))
            XCTAssertTrue(window.staticTexts["transflo.wheel.item-count"].exists)
            let summary = window.descendants(matching: .any)["transflo.wheel.hub"]
            let description = summary.value as? String ?? summary.label
            XCTAssertTrue(description.contains("2.4"))
            XCTAssertTrue(description.contains("MB"))
            attachDiagnosticScreenshot(window, named: "wheel-\(kind)-multi-file")
            app.terminate()
        }
    }
}
