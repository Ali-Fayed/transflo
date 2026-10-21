import XCTest

/// Settings › Wheel: picking which options each wheel shows. Runs in an isolated preference suite,
/// so unticking here never changes the installed app's wheels.
@MainActor
final class WheelSettingsUITests: TransfloUITestCase {
    private func wheelTab(language: String, appearance: String, tab: String) -> (XCUIApplication, XCUIElement) {
        continueAfterFailure = false
        let app = makeApplication()
        app.launchArguments = [LaunchArgument.openSettings, "-settings.language", language,
                               "-settings.appearance", appearance]
        app.launch()
        app.activate()
        let window = app.windows[WindowIdentifier.settings]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let radio = window.radioButtons[tab]
        XCTAssertTrue(radio.waitForExistence(timeout: 5))
        app.activate()
        radio.click()
        XCTAssertTrue(window.descendants(matching: .any)["settings.wheel.count"].waitForExistence(timeout: 5))
        return (app, window)
    }

    private func count(in window: XCUIElement) -> String {
        let element = window.descendants(matching: .any)["settings.wheel.count"]
        return element.label.isEmpty ? (element.value as? String ?? "") : element.label
    }

    func testUntickingAToolUpdatesTheCountInEnglishLight() {
        let (app, window) = wheelTab(language: "en", appearance: "light", tab: "Wheel")
        XCTAssertTrue(window.descendants(matching: .any)["settings.wheel.format.png"].exists)
        attachDiagnosticScreenshot(window, named: "settings-wheel-convert-en-light")
        window.radioButtons["Tools"].click()
        let crop = window.descendants(matching: .any)["settings.wheel.tool.crop"]
        XCTAssertTrue(crop.waitForExistence(timeout: 5))
        let before = count(in: window)
        app.activate()
        crop.click()
        let changed = expectation(for: NSPredicate { _, _ in self.count(in: window) != before }, evaluatedWith: nil)
        wait(for: [changed], timeout: 5)
        app.activate()
        window.buttons["Show All"].click()
        let restored = expectation(for: NSPredicate { _, _ in self.count(in: window) == before }, evaluatedWith: nil)
        wait(for: [restored], timeout: 5)
        attachDiagnosticScreenshot(window, named: "settings-wheel-tools-en-light")
        window.radioButtons["Actions"].click()
        let copy = window.descendants(matching: .any)["settings.wheel.action.copy"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertFalse(crop.exists)
        XCTAssertGreaterThan(window.staticTexts["Wheel size"].frame.minY, copy.frame.maxY)
        window.radioButtons["Convert"].click()
        XCTAssertTrue(window.descendants(matching: .any)["settings.wheel.format.png"].waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["Images"].exists)
        XCTAssertTrue(window.staticTexts["Documents"].exists)
        XCTAssertFalse(copy.exists)
    }

    func testHideAllWarnsInArabicDark() {
        let (app, window) = wheelTab(language: "ar", appearance: "dark", tab: "العجلة")
        window.radioButtons["إجراءات"].firstMatch.click()
        app.activate()
        window.buttons["إخفاء الكل"].click()
        let warning = window.staticTexts["لم يُحدَّد أي خيار، لذلك لن تُفتح هذه العجلة."]
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        attachDiagnosticScreenshot(window, named: "settings-wheel-actions-ar-dark")
        app.activate()
        window.buttons["إظهار الكل"].click()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: warning)
        wait(for: [gone], timeout: 5)
    }
}
