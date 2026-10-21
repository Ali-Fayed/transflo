import XCTest

/// Keeps UI tests from changing the installed app's saved preferences.
@MainActor
class TransfloUITestCase: XCTestCase {
    private let suite = "TransfloUITests.\(UUID().uuidString)"
    private var applications: [XCUIApplication] = []

    func makeApplication() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["TRANSFLO_TEST_DEFAULTS_SUITE"] = suite
        applications.append(app)
        return app
    }

    /// Opt-in success images; XCTest still records diagnostics for failures automatically.
    func attachDiagnosticScreenshot(_ element: XCUIElement, named name: String) {
        guard ProcessInfo.processInfo.environment["TRANSFLO_UI_SCREENSHOTS"] == "1" else { return }
        XCUIApplication().activate()
        let attachment = XCTAttachment(screenshot: element.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    override func tearDown() {
        for app in applications where app.state != .notRunning { app.terminate() }
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        applications = []
        super.tearDown()
    }
}
