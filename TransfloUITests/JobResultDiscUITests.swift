import XCTest

/// Captures the result disc left at the wheel center, through the debug-only `-TransfloPreviewJob`
/// launch argument (a real drag can't be automated).
@MainActor
final class JobResultDiscUITests: TransfloUITestCase {
    private func disc(_ outcome: String, language: String, appearance: String) -> XCUIElement {
        continueAfterFailure = false
        let app = makeApplication()
        app.launchArguments = [
            LaunchArgument.previewJob, outcome,
            "-settings.language", language,
            "-settings.appearance", appearance
        ]
        app.launch()
        let panel = app.dialogs[WindowIdentifier.jobResult]
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        return panel
    }

    /// The disc is one accessible button whose label combines title, reason and file name.
    private func element(in panel: XCUIElement, labelContaining text: String) -> XCUIElement {
        panel.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func testSuccessfulConversionInEnglishLight() {
        let panel = disc("success", language: "en", appearance: "light")
        let done = element(in: panel, labelContaining: "Done — click to show")
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        XCTAssertTrue(done.label.contains("Holiday photo"))
        attachDiagnosticScreenshot(panel, named: "result-disc-success-en-light")
    }

    func testFailedConversionInArabicDark() {
        let panel = disc("failure", language: "ar", appearance: "dark")
        XCTAssertTrue(element(in: panel, labelContaining: "نُقل الملف أو حُذف.").waitForExistence(timeout: 4))
        attachDiagnosticScreenshot(panel, named: "result-disc-failure-ar-dark")
    }

    func testDiscHidesAfterSuccess() {
        let panel = disc("success", language: "en", appearance: "dark")
        XCTAssertTrue(element(in: panel, labelContaining: "Done").waitForExistence(timeout: 10))
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: panel)
        wait(for: [gone], timeout: 10)
    }
}
