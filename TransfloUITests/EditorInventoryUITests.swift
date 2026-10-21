import XCTest

/// Full editor inventory belongs to Extended; fast tests retain focused interaction coverage.
@MainActor
final class EditorInventoryUITests: TransfloUITestCase {
    private let tools = ["compress", "rotate", "resize", "crop", "adjust", "trim", "changeSpeed", "split",
                         "snapshot", "annotate", "redact", "addBackground", "collage", "bleep",
                         "reorganizePages", "extractPages", "editMetadata", "rename", "merge", "imagesToPDF",
                         "removeBackground", "normalize", "channels", "readCode", "removeMetadata"]

    func testEveryEditorFitsInEnglishLight() { inspect(language: "en", appearance: "light") }
    func testEveryEditorFitsInArabicDark() { inspect(language: "ar", appearance: "dark") }

    private func inspect(language: String, appearance: String) {
        continueAfterFailure = false
        for tool in tools {
            let app = makeApplication()
            app.launchArguments = [LaunchArgument.previewEditor, tool, "-settings.language", language,
                                   "-settings.appearance", appearance]
            app.launch()
            app.activate()
            let window = app.windows[WindowIdentifier.toolEditor]
            XCTAssertTrue(window.waitForExistence(timeout: 15), tool)
            XCTAssertTrue(window.descendants(matching: .any)["transflo.editor.ready"]
                .waitForExistence(timeout: 15), tool)
            let failure = language == "ar"
                ? "تعذرت قراءة هذا الملف. تحقق من توفره ودعم تنسيقه، ثم أعد المحاولة."
                : "This file could not be read. Check that it is available and supported, then retry."
            XCTAssertFalse(window.staticTexts[failure].exists, tool)
            inspectNewControls(tool, in: window, language: language)
            let action = window.buttons["transflo.editor.apply"]
            XCTAssertTrue(action.exists, tool)
            XCTAssertGreaterThan(action.frame.width, 30, tool)
            XCTAssertLessThanOrEqual(action.frame.maxY, window.frame.maxY, tool)
            XCTAssertGreaterThanOrEqual(action.frame.minY, window.frame.minY, tool)
            XCTAssertLessThanOrEqual(window.frame.width, 900, tool)
            attachDiagnosticScreenshot(window, named: "inventory-\(tool)-\(language)-top")
            window.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -2000)
            XCTAssertLessThanOrEqual(action.frame.maxY, window.frame.maxY, tool)
            XCTAssertGreaterThanOrEqual(action.frame.minY, window.frame.minY, tool)
            attachDiagnosticScreenshot(window, named: "inventory-\(tool)-\(language)-bottom")
            app.terminate()
        }
    }
    private func inspectNewControls(_ tool: String, in window: XCUIElement, language: String) {
        switch tool {
        case "imagesToPDF": XCTAssertTrue(window.buttons["A4"].exists)
        case "merge": XCTAssertTrue(window.staticTexts["Document 1.pdf"].exists)
        case "normalize": XCTAssertTrue(window.textFields["transflo.editor.loudness"].exists)
        case "channels":
            XCTAssertTrue(window.buttons[language == "ar" ? "اليمنى فقط" : "Right only"].exists)
        case "readCode":
            // Each decoded code is a checkbox row (AppCheckbox), titled with the code's text.
            XCTAssertTrue(window.checkBoxes["https://transfloformac.ali-fayed.com/"].exists)
            XCTAssertTrue(window.buttons["transflo.editor.apply"].isEnabled)
        case "removeMetadata":
            XCTAssertTrue(window.staticTexts[language == "ar" ? "الموقع وGPS" : "Location and GPS"].exists)
        case "removeBackground":
            XCTAssertTrue(window.sliders[language == "ar" ? "تنعيم الحواف" : "Edge feather"].exists)
        default: break
        }
    }
}
