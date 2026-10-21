import XCTest

@MainActor
final class MobilePDFMarkupUITests: XCTestCase {
    func testAnnotateAndRedactSecondPDFPage() {
        continueAfterFailure = false
        for tool in ["annotate", "redact"] {
            let app = XCUIApplication()
            app.launchArguments = ["-transflo-mobile-defaults", "TransfloPDFUI.\(UUID().uuidString)",
                                   "-settings.language", "en", "-onboarding.guidedTourCompleted", "YES",
                                   "-transflo-mobile-preview-pdf"]
            app.launch()
            let tools = app.buttons["Tools"].firstMatch
            XCTAssertTrue(tools.waitForExistence(timeout: 15))
            tools.tap()
            let search = app.textFields["mobile.actions.search"]
            search.tap()
            search.typeText(tool)
            app.buttons["mobile.action.tool.\(tool)"].tap()
            let next = app.buttons["Next page"].firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: 10))
            XCTAssertTrue(next.isEnabled)
            next.tap()
            XCTAssertTrue(app.staticTexts["Page 2 of 2"].waitForExistence(timeout: 5))
            let board = app.descendants(matching: .any)["editor.markup.board"].firstMatch
            XCTAssertTrue(board.waitForExistence(timeout: 5))
            board.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2)).press(
                forDuration: 0.1, thenDragTo: board.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.6)))
            let apply = app.buttons["mobile.markup.apply"]
            XCTAssertTrue(apply.isEnabled)
            apply.tap()
            XCTAssertTrue(app.otherElements["ShareSheet.RemoteContainerView"].waitForExistence(timeout: 30))
            app.terminate()
        }
    }
}
