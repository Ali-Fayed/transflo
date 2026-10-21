import XCTest

/// Check for Updates, answered locally by `-TransfloPreviewUpdate` so no request leaves the Mac.
@MainActor
final class UpdateWindowUITests: TransfloUITestCase {
    private func openUpdates(_ outcome: String, language: String = "en") -> (XCUIApplication, XCUIElement) {
        continueAfterFailure = false
        let app = makeApplication()
        app.launchArguments = [LaunchArgument.openUpdates, LaunchArgument.previewUpdate, outcome,
                               "-settings.language", language]
        app.launch()
        app.activate()
        let window = app.windows[WindowIdentifier.updates]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        return (app, window)
    }

    /// Waits for the check to finish with `text` (or text starting with it) as its message.
    private func expectMessage(_ text: String, in window: XCUIElement) {
        let message = window.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@",
                                                              text, text)).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 10), "expected “\(text)”")
    }

    func testAvailableUpdateOffersTheDownload() {
        let (_, window) = openUpdates("available")
        expectMessage("A new version of Transflo is available.", in: window)
        XCTAssertTrue(window.staticTexts["Latest version: 9.9.9"].exists)
        XCTAssertTrue(window.buttons["View Update"].isEnabled)
        XCTAssertFalse(window.buttons["Check Again"].exists)
        attachDiagnosticScreenshot(window, named: "updates-available")
    }

    func testUpToDateAndUnpublishedOfferAnotherCheck() {
        let (app, window) = openUpdates("current")
        expectMessage("You’re using the latest version of Transflo.", in: window)
        XCTAssertFalse(window.buttons["View Update"].exists)
        app.terminate()
        let (_, unpublished) = openUpdates("unpublished")
        expectMessage("No public release is available yet.", in: unpublished)
        XCTAssertTrue(unpublished.buttons["Check Again"].isEnabled)
    }

    func testFailureCanBeRetriedInArabic() {
        let (_, window) = openUpdates("failed", language: "ar")
        expectMessage("تعذر التحقق من التحديثات", in: window)
        let retry = window.buttons["التحقق مجددًا"]
        XCTAssertTrue(retry.isEnabled)
        retry.click()
        expectMessage("تعذر التحقق من التحديثات", in: window)
        XCTAssertTrue(retry.isEnabled, "the retry finishes and can run again")
        XCTAssertTrue(window.buttons["إغلاق"].exists)
    }
}
