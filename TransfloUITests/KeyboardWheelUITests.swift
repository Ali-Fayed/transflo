import XCTest

/// Drives the keyboard wheel through the debug-only `-TransfloPreviewKeyboard` launch argument,
/// which opens it on a scratch HEIC as the hotkey would.
@MainActor
final class KeyboardWheelUITests: TransfloUITestCase {
    private func launch(language: String, appearance: String) -> (XCUIApplication, XCUIElement) {
        continueAfterFailure = false
        let app = makeApplication()
        app.launchArguments = [
            LaunchArgument.previewKeyboard,
            "-settings.language", language,
            "-settings.appearance", appearance
        ]
        app.launch()
        let wheel = app.dialogs[WindowIdentifier.wheel]
        XCTAssertTrue(wheel.waitForExistence(timeout: 10))
        return (app, wheel)
    }

    private func selectedPetal(in wheel: XCUIElement) -> XCUIElement {
        wheel.buttons.matching(NSPredicate(format: "isSelected == true")).firstMatch
    }

    func testArrowsAndReturnConvertTheSelection() {
        let (app, wheel) = launch(language: "en", appearance: "dark")
        wheel.typeKey(.rightArrow, modifierFlags: [])
        // An arrow selects a petal (which one depends on where the real pointer rests; arrow order
        // itself is covered by unit tests).
        XCTAssertTrue(selectedPetal(in: wheel).waitForExistence(timeout: 5))
        attachDiagnosticScreenshot(wheel, named: "keyboard-wheel-en-dark")
        wheel.typeKey(.return, modifierFlags: [])
        // Return ran the highlighted option: the result disc reports the conversion.
        let hud = app.dialogs[WindowIdentifier.jobResult]
        XCTAssertTrue(hud.waitForExistence(timeout: 10))
        let outcome = NSPredicate(format: "label CONTAINS 'PNG' OR label CONTAINS 'Done'")
        let png = hud.descendants(matching: .any).matching(outcome)
        XCTAssertTrue(png.firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(wheel.exists)
    }

    func testEscapeClosesInArabic() {
        let (_, wheel) = launch(language: "ar", appearance: "light")
        wheel.typeKey(.leftArrow, modifierFlags: [])
        XCTAssertTrue(selectedPetal(in: wheel).waitForExistence(timeout: 5))
        attachDiagnosticScreenshot(wheel, named: "keyboard-wheel-ar-light")
        wheel.typeKey(.escape, modifierFlags: [])
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: wheel)
        wait(for: [gone], timeout: 5)
    }
}
