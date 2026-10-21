import XCTest

/// Captures the floating shelf through the debug-only `-TransfloPreviewShelf` launch argument.
@MainActor
final class ShelfUITests: TransfloUITestCase {
    private func shelf(language: String, appearance: String) -> XCUIElement {
        continueAfterFailure = false
        let app = makeApplication()
        app.launchArguments = [
            LaunchArgument.previewShelf,
            "-settings.language", language,
            "-settings.appearance", appearance
        ]
        app.launch()
        let panel = app.dialogs[WindowIdentifier.shelf]
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        return panel
    }

    func testShelfInEnglishLight() {
        let panel = shelf(language: "en", appearance: "light")
        XCTAssertTrue(panel.staticTexts["Holiday photo 1.heic"].waitForExistence(timeout: 5))
        XCTAssertTrue(panel.staticTexts["Shelf"].exists)
        attachDiagnosticScreenshot(panel, named: "shelf-en-light")
    }

    func testShelfInArabicDarkCollapses() {
        let panel = shelf(language: "ar", appearance: "dark")
        XCTAssertTrue(panel.staticTexts["الرف"].waitForExistence(timeout: 5))
        attachDiagnosticScreenshot(panel, named: "shelf-ar-dark")
        panel.buttons["طيّ"].click()
        let pill = XCUIApplication().dialogs[WindowIdentifier.shelf].buttons["إظهار الرف"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        attachDiagnosticScreenshot(XCUIApplication().dialogs[WindowIdentifier.shelf], named: "shelf-collapsed-ar-dark")
    }
}
