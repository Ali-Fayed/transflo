import XCTest

/// Settings organization, shared preferences, bounded sizing and language transitions.
@MainActor
final class SettingsWindowUITests: TransfloUITestCase {
    private func launch(language: String, appearance: String? = nil) -> XCUIApplication {
        continueAfterFailure = false
        let app = makeApplication()
        app.launchArguments = [LaunchArgument.openSettings, "-settings.language", language]
        if let appearance { app.launchArguments += ["-settings.appearance", appearance] }
        app.launch()
        app.activate()
        return app
    }

    private func selectTab(_ title: String, in window: XCUIElement, app: XCUIApplication) {
        let tab = window.radioButtons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        app.activate()
        // The initial content measurement resizes the hosting window. Retry a click made
        // during that resize, and avoid toggling a segment which is already selected.
        for _ in 0..<3 {
            if (tab.value as? NSNumber)?.intValue == 1 { return }
            tab.click()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (tab.value as? NSNumber)?.intValue == 1
            }, object: nil)
            if XCTWaiter.wait(for: [selected], timeout: 2) == .completed { return }
        }
        XCTFail("The \(title) tab did not become selected")
    }

    private func reveal(_ element: XCUIElement, in window: XCUIElement) {
        let scroll = window.scrollViews.firstMatch
        scroll.scroll(byDeltaX: 0, deltaY: 2500)
        for _ in 0..<7 {
            if element.isHittable { return }
            scroll.scroll(byDeltaX: 0, deltaY: -220)
        }
        XCTAssertTrue(element.isHittable)
    }

    private func toggle(_ label: String, in window: XCUIElement) -> XCUIElement {
        let checkbox = window.checkBoxes[label]
        return checkbox.exists ? checkbox : window.switches[label]
    }

    func testSettingsOpensWithEveryGeneralControlInEnglishLight() {
        let app = launch(language: "en", appearance: "light")
        let window = app.windows[WindowIdentifier.settings]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        for label in ["Language", "Open at login", "Wheel haptic feedback", "Accent color", "Tools wheel"] {
            XCTAssertTrue(window.staticTexts[label].exists)
        }
        reveal(window.buttons["⌥⌘↩"], in: window)
        XCTAssertTrue(window.buttons["⌥⌘↩"].isHittable)
        XCTAssertFalse(window.radioButtons["Keys"].exists)
        XCTAssertFalse(window.radioButtons["Customization"].exists)
        attachDiagnosticScreenshot(window, named: "settings-en-light")
    }

    func testAutomaticUpdateChecksCanBeTurnedOffAndStayOff() {
        let app = launch(language: "en")
        var window = app.windows[WindowIdentifier.settings]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        selectTab("About", in: window, app: app)
        let automatic = toggle("Check for updates automatically", in: window)
        reveal(automatic, in: window)
        XCTAssertEqual((automatic.value as? NSNumber)?.intValue, 1, "automatic checks start on")
        automatic.click()
        XCTAssertEqual((automatic.value as? NSNumber)?.intValue, 0)
        XCTAssertTrue(window.buttons["Check Now"].exists)
        app.terminate()
        app.launch()
        app.activate()
        window = app.windows[WindowIdentifier.settings]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        selectTab("About", in: window, app: app)
        XCTAssertEqual((toggle("Check for updates automatically", in: window).value as? NSNumber)?.intValue, 0)
    }

    func testCustomizationSurvivesQuitAndRelaunch() {
        let app = launch(language: "en")
        var window = app.windows[WindowIdentifier.settings]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        reveal(window.buttons["Blue"], in: window)
        window.buttons["Blue"].click()
        window.radioButtons["Dark"].click()
        let glass = toggle("Liquid Glass", in: window)
        let motion = toggle("Reduce motion", in: window)
        reveal(glass, in: window)
        glass.click()
        motion.click()
        let savedGlass = (glass.value as? NSNumber)?.intValue
        let savedMotion = (motion.value as? NSNumber)?.intValue
        selectTab("Wheel", in: window, app: app)
        reveal(window.radioButtons["Large"], in: window)
        window.radioButtons["Large"].click()
        app.terminate()
        app.launch()
        app.activate()
        window = app.windows[WindowIdentifier.settings]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(window.buttons["Blue"].isSelected)
        XCTAssertEqual((window.radioButtons["Dark"].value as? NSNumber)?.intValue, 1)
        XCTAssertEqual((toggle("Liquid Glass", in: window).value as? NSNumber)?.intValue, savedGlass)
        XCTAssertEqual((toggle("Reduce motion", in: window).value as? NSNumber)?.intValue, savedMotion)
        selectTab("Wheel", in: window, app: app)
        XCTAssertEqual((window.radioButtons["Large"].value as? NSNumber)?.intValue, 1)
        attachDiagnosticScreenshot(window, named: "settings-persisted-after-relaunch")
    }

    func testOutputNamingAndAdaptiveHeight() {
        let app = launch(language: "en", appearance: "light")
        let window = app.windows[WindowIdentifier.settings]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let width = window.frame.width
        XCTAssertFalse(window.radioButtons["Formats"].exists)
        let best = window.buttons["Best"]
        reveal(best, in: window)
        for label in ["Best", "Balanced", "Smaller"] { XCTAssertTrue(window.buttons[label].exists) }
        XCTAssertFalse(window.buttons["Size limit"].exists)
        XCTAssertFalse(window.buttons["Percentage"].exists)
        window.buttons["Smaller"].click()
        XCTAssertTrue(window.buttons["Smaller"].isSelected)
        reveal(window.radioButtons["Word"], in: window)
        window.radioButtons["Word"].click()
        XCTAssertTrue(window.staticTexts["Example: photo Cropped.jpg"].exists)
        let tallHeight = window.frame.height
        selectTab("About", in: window, app: app)
        let compact = expectation(for: NSPredicate { _, _ in window.frame.height < tallHeight - 40 },
                                  evaluatedWith: nil)
        wait(for: [compact], timeout: 5)
        XCTAssertEqual(window.frame.width, width, accuracy: 1)
        attachDiagnosticScreenshot(window, named: "settings-output-content-height")
    }

    func testEachTabFitsItsContentInEnglishAndArabic() {
        for (language, tabs) in [("en", ["General", "Wheel", "Recipes", "Compatibility", "About"]),
                                  ("ar", ["عام", "العجلة", "الوصفات", "التوافق", "حول"])] {
            let app = launch(language: language, appearance: language == "ar" ? "dark" : "light")
            let window = app.windows[WindowIdentifier.settings]
            XCTAssertTrue(window.waitForExistence(timeout: 10))
            let width = window.frame.width
            for tab in tabs {
                selectTab(tab, in: window, app: app)
                XCTAssertEqual(window.frame.width, width, accuracy: 1)
                XCTAssertLessThan(window.frame.height, 680)
                attachDiagnosticScreenshot(window, named: "settings-\(language)-\(tab)")
            }
            app.terminate()
        }
    }

    func testSwitchingPagesAndLanguageDoesNotLeaveInactiveSegments() {
        let app = launch(language: "en", appearance: "light")
        let window = app.windows[WindowIdentifier.settings]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let width = window.frame.width
        selectTab("Wheel", in: window, app: app)
        XCTAssertFalse(window.radioButtons["English"].exists)
        reveal(window.radioButtons["Large"], in: window)
        let labelLeft = window.staticTexts["Wheel size"].frame.minX
        for size in ["Large", "Compact", "Standard"] {
            selectTab(size, in: window, app: app)
            XCTAssertEqual((window.radioButtons[size].value as? NSNumber)?.intValue, 1)
            XCTAssertEqual(window.staticTexts["Wheel size"].frame.minX, labelLeft, accuracy: 1)
            XCTAssertEqual(window.frame.width, width, accuracy: 1)
        }
        selectTab("General", in: window, app: app)
        window.radioButtons["العربية"].click()
        XCTAssertFalse(window.radioButtons["التنسيقات"].exists)
        reveal(window.buttons["الأفضل"], in: window)
        XCTAssertTrue(window.buttons["أصغر"].exists)
        reveal(window.radioButtons["English"], in: window)
        window.radioButtons["English"].click()
        selectTab("Compatibility", in: window, app: app)
        XCTAssertTrue(window.descendants(matching: .any)["settings.compatibility.matrix"].exists)
        attachDiagnosticScreenshot(window, named: "settings-no-inactive-controls")
    }
}
