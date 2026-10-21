import XCTest

@MainActor
final class MobilePreferenceUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-transflo-mobile-defaults", "TransfloPreferencesUI.\(UUID().uuidString)",
                               "-settings.language", "en", "-onboarding.guidedTourCompleted", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Settings"].firstMatch.tap()
        return app
    }

    func testOutputAndHiddenFormatsPersistIntoActionPicker() {
        let app = launch()
        app.buttons["mobile.settings.output"].tap()
        let smaller = app.buttons["Smaller"].firstMatch
        XCTAssertTrue(smaller.waitForExistence(timeout: 5))
        smaller.tap()
        XCTAssertTrue(smaller.isSelected)
        app.buttons["BackButton"].firstMatch.tap()
        app.buttons["mobile.settings.actionCustomization"].tap()
        let png = app.switches["mobile.visibility.format.png"].firstMatch
        XCTAssertTrue(png.waitForExistence(timeout: 5))
        png.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertEqual(png.value as? String, "0", app.debugDescription)
        app.terminate()
        app.launchArguments.append("-transflo-mobile-preview-input")
        app.launch()
        let tools = app.buttons["Tools"].firstMatch
        XCTAssertTrue(tools.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["mobile.action.format.png"].exists)
        let close = app.buttons["mobile.sheet.close"].firstMatch
        XCTAssertTrue(close.isHittable)
        XCTAssertGreaterThan(close.frame.midX, app.frame.midX)
        tools.tap()
        let compress = app.buttons["mobile.action.tool.compress"]
        XCTAssertTrue(compress.waitForExistence(timeout: 5))
        compress.tap()
        XCTAssertTrue(smaller.waitForExistence(timeout: 10))
        XCTAssertTrue(smaller.isSelected)
    }

    func testCreateRecipeAndUseItFromTools() {
        let app = launch()
        app.buttons["mobile.settings.recipes"].tap()
        app.buttons["mobile.recipes.new"].tap()
        let name = app.textFields["mobile.recipe.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Quick export")
        app.buttons["mobile.recipe.addStep"].tap()
        let compress = app.buttons["mobile.recipe.step.compress"].firstMatch
        XCTAssertTrue(compress.waitForExistence(timeout: 5), app.debugDescription)
        compress.tap()
        app.buttons["mobile.recipe.save"].tap()
        XCTAssertTrue(app.buttons["mobile.recipe.Quick export"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments.append("-transflo-mobile-preview-input")
        app.launch()
        let tools = app.buttons["Tools"].firstMatch
        XCTAssertTrue(tools.waitForExistence(timeout: 15))
        tools.tap()
        let search = app.textFields["mobile.actions.search"]
        search.tap()
        search.typeText("Quick export")
        let recipe = app.buttons["Quick export"].firstMatch
        XCTAssertTrue(recipe.waitForExistence(timeout: 5), app.debugDescription)
        recipe.tap()
        XCTAssertTrue(app.buttons["mobile.saveFiles"].waitForExistence(timeout: 20))
    }
}
