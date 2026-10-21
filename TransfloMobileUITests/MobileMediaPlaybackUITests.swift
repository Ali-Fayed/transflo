import XCTest

extension MobileLaunchUITests {
    func testActionSearchAndVideoPlaybackEditor() {
        continueAfterFailure = false
        let app = launch(previewVideo: true)
        let tools = app.buttons["Tools"].firstMatch
        XCTAssertTrue(tools.waitForExistence(timeout: 15))
        tools.tap()
        let search = app.textFields["mobile.actions.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Trim")
        let trim = app.buttons["mobile.action.tool.trim"]
        XCTAssertTrue(trim.waitForExistence(timeout: 5))
        trim.tap()
        XCTAssertTrue(app.otherElements["mobile.video.preview"].waitForExistence(timeout: 10))
        let play = app.buttons["mobile.video.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        XCTAssertTrue(play.isEnabled)
        let scrubber = app.sliders["mobile.video.scrubber"]
        XCTAssertTrue(scrubber.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["mobile.video.time"].label, "0:00")
        play.tap()
        XCTAssertEqual(play.label, "Pause preview")
        play.tap()
        XCTAssertEqual(play.label, "Play preview")
        let fullScreen = app.buttons["mobile.video.fullScreen"]
        XCTAssertTrue(fullScreen.isHittable)
        let timeBeforeFullScreen = app.staticTexts["mobile.video.time"].label
        fullScreen.tap()
        let close = app.buttons["Close full screen"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertEqual(app.staticTexts["mobile.video.time"].label, timeBeforeFullScreen)
        let handle = app.descendants(matching: .any)["mobile.trim.start"].firstMatch
        let endHandle = app.descendants(matching: .any)["mobile.trim.end"].firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(endHandle.exists)
        revealTimeline(handle, in: app)
        XCTAssertTrue(handle.isHittable, app.debugDescription)
        XCTAssertTrue(endHandle.isHittable, app.debugDescription)
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(
            dx: (endHandle.frame.midX - handle.frame.midX) * 0.25, dy: 0)))
        XCTAssertNotNil(handle.value)
        XCTAssertNotEqual(handle.value as? String, "0:00")
        XCTAssertEqual(app.staticTexts["mobile.video.time"].label, "0:00")
        XCTAssertNotEqual(app.staticTexts["mobile.video.duration"].label, "0:12")
        let apply = app.buttons["mobile.editor.apply"]
        XCTAssertTrue(apply.isEnabled)
        apply.tap()
        XCTAssertTrue(app.otherElements["ShareSheet.RemoteContainerView"].waitForExistence(timeout: 30))
    }

    private func revealTimeline(_ handle: XCUIElement, in app: XCUIApplication) {
        // Scroll the editor's margin: dragging the video surface controls the player instead.
        let editor = app.scrollViews["mobile.editor.scroll"]
        for _ in 0..<3 where !handle.isHittable {
            editor.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.85))
                .press(forDuration: 0.05, thenDragTo:
                    editor.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.25)))
        }
    }
}
