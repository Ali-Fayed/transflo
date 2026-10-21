import XCTest

@MainActor
final class WelcomeWindowUITests: TransfloUITestCase {
    private func launch(language: String = "en") -> XCUIApplication {
        continueAfterFailure = false
        let app = makeApplication()
        // Explicit Getting Started replays onboarding even after completion.
        app.launchArguments = [LaunchArgument.openWelcome, "-settings.language", language,
                               "-settings.appearance", "light",
                               "-onboarding.guidedTourCompleted", "YES"]
        app.launch()
        app.activate()
        return app
    }

    func testWelcomeExplainsMenuBarAndOpensSettings() {
        let app = launch()
        let window = app.windows[WindowIdentifier.welcome]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(window.staticTexts["Transflo lives in your menu bar."].exists)
        attachDiagnosticScreenshot(window, named: "welcome-en")
        // Another app's window can sit over Welcome; bring Transflo forward before clicking.
        app.activate()
        window.buttons["Open Settings"].click()
        XCTAssertTrue(app.windows[WindowIdentifier.settings].waitForExistence(timeout: 10))
        XCTAssertFalse(window.exists)
    }

    func testArabicWelcomeCanBeDismissedWithoutQuitting() {
        let app = launch(language: "ar")
        let window = app.windows[WindowIdentifier.welcome]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(window.staticTexts["ستجد Transflo في شريط القوائم."].exists)
        attachDiagnosticScreenshot(window, named: "welcome-ar")
        app.activate()
        for _ in 0..<4 { window.buttons["متابعة"].click() }
        window.buttons["تم"].click()
        XCTAssertFalse(window.exists)
        XCTAssertNotEqual(app.state, .notRunning)
    }

    func testEveryPageBackDoneAndReplay() {
        let app = launch()
        let window = app.windows[WindowIdentifier.welcome]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        app.activate()
        XCTAssertFalse(window.buttons["Back"].exists)
        window.buttons["Continue"].click()
        XCTAssertTrue(window.staticTexts["1. Drag files from Finder"].exists)
        let progress = window.descendants(matching: .any)
            .matching(identifier: "transflo.onboarding.progress").firstMatch
        XCTAssertEqual(progress.label, "Page 2 of 5")
        window.buttons["Back"].click()
        XCTAssertTrue(window.staticTexts["Welcome to Transflo"].exists)
        for title in ["Convert", "Tools", "Actions"] {
            window.buttons["Continue"].click()
            XCTAssertTrue(window.staticTexts[title].exists)
        }
        window.buttons["Continue"].click()
        XCTAssertTrue(window.switches["Open at login"].exists || window.checkBoxes["Open at login"].exists)
        window.buttons["Done"].click()
        XCTAssertFalse(window.exists)
        XCTAssertNotEqual(app.state, .notRunning)
        app.terminate()
        app.launch()
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(window.staticTexts["Welcome to Transflo"].exists)
    }

    func testCompletedOrdinaryLaunchStaysInMenuBar() {
        let app = makeApplication()
        app.launchArguments = ["-onboarding.guidedTourCompleted", "YES"]
        app.launch()
        XCTAssertFalse(app.windows[WindowIdentifier.welcome].waitForExistence(timeout: 2))
        XCTAssertNotEqual(app.state, .notRunning)
    }

    /// A brand-new install: no saved preferences and no launch arguments.
    func testFirstLaunchOpensTourInFront() {
        let app = makeApplication()
        app.launch()
        let window = app.windows[WindowIdentifier.welcome]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(window.staticTexts["Welcome to Transflo"].waitForExistence(timeout: 5))
        XCTAssertTrue(window.isHittable)
    }

    /// Macs that ran a development build carry the old flag; it must not silence the tour.
    func testLegacyCompletionFlagStillShowsTour() {
        let app = makeApplication()
        app.launchArguments = ["-settings.hasCompletedOnboarding", "YES"]
        app.launch()
        XCTAssertTrue(app.windows[WindowIdentifier.welcome].waitForExistence(timeout: 10))
    }
}
