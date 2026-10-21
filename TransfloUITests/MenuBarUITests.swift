import XCTest

/// The menu offers one Settings entry; About reuses the same window's About page.
@MainActor
final class MenuBarUITests: TransfloUITestCase {
    func testSingleSettingsEntryAndAboutNavigation() {
        continueAfterFailure = false
        let app = makeApplication()
        app.launchArguments = [LaunchArgument.openSettings, "-settings.language", "en"]
        app.launch()
        let window = app.windows[WindowIdentifier.settings]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let status = app.statusItems.firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        status.click()
        XCTAssertTrue(status.menuItems["About Transflo"].waitForExistence(timeout: 5))
        for removed in ["Controls", "Customization", "Privacy Policy", "Support"] {
            XCTAssertFalse(status.menuItems[removed].exists)
        }
        status.menuItems["About Transflo"].click()
        XCTAssertTrue(window.buttons["Privacy Policy"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.windows.matching(identifier: WindowIdentifier.settings).count, 1)
    }
}
