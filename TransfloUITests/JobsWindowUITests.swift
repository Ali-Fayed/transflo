import XCTest

/// Captures the Jobs window through the debug-only `-TransfloPreviewJobs` launch argument, which runs
/// one scratch conversion that succeeds and one that fails.
@MainActor
final class JobsWindowUITests: TransfloUITestCase {
    private func jobs(language: String, appearance: String) -> XCUIElement {
        continueAfterFailure = false
        let app = makeApplication()
        app.launchArguments = [
            LaunchArgument.previewJobs,
            "-settings.language", language,
            "-settings.appearance", appearance
        ]
        app.launch()
        let window = app.windows[WindowIdentifier.jobs]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        return window
    }

    func testJobsListShowsResultsInEnglishLight() {
        let window = jobs(language: "en", appearance: "light")
        XCTAssertTrue(window.staticTexts["History"].exists)
        XCTAssertTrue(window.buttons["Show in Finder"].waitForExistence(timeout: 10))
        XCTAssertTrue(window.staticTexts["Convert to PNG"].exists)
        XCTAssertTrue(window.buttons["Clear Finished"].isEnabled)
        attachDiagnosticScreenshot(window, named: "jobs-en-light")
        // The preview jobs' result disc sits near the screen center and can cover the button until it hides.
        let hud = XCUIApplication().dialogs[WindowIdentifier.jobResult]
        let hidden = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: hud)
        wait(for: [hidden], timeout: 10)
        XCUIApplication().activate()
        window.buttons["Clear Finished"].click()
        let empty = window.staticTexts["Nothing here yet. Drop files on the wheel to start."]
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
    }

    func testJobsListInArabicDark() {
        let window = jobs(language: "ar", appearance: "dark")
        XCTAssertTrue(window.staticTexts["السجل"].exists)
        XCTAssertTrue(window.buttons["إظهار في Finder"].waitForExistence(timeout: 10))
        attachDiagnosticScreenshot(window, named: "jobs-ar-dark")
    }
}
