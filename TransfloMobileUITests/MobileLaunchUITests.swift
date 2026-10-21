import XCTest

/// Exercises native tabs, safe-area layouts, first-run onboarding and document-picker cancellation.
@MainActor
final class MobileLaunchUITests: XCTestCase {
    func launch(
        firstRun: Bool = false, previewInput: Bool = false, previewVideo: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-transflo-mobile-defaults", "TransfloMobileUITests.\(UUID().uuidString)",
                               "-settings.language", "en"]
        if previewVideo { app.launchArguments.append("-transflo-mobile-preview-video") }
        if previewInput { app.launchArguments.append("-transflo-mobile-preview-input") }
        app.launch()
        if !firstRun {
            let skip = app.buttons["mobile.onboarding.skip"]
            XCTAssertTrue(skip.waitForExistence(timeout: 10))
            skip.tap()
            if !previewInput && !previewVideo {
                XCTAssertTrue(app.buttons["mobile.select.image"].waitForExistence(timeout: 5))
            }
        }
        return app
    }

    func testLaunchesInPortraitAndLandscape() {
        let app = launch()
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft, .landscapeRight, .portrait] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
            XCTAssertTrue(app.buttons["mobile.select.image"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["Activity"].exists)
        }
    }

    func testSettingsAndHistoryTabs() {
        let app = launch()
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["mobile.settings"].waitForExistence(timeout: 5))
        let appearance = app.buttons["mobile.settings.appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        appearance.tap()
        let dark = app.buttons["Dark"].firstMatch
        XCTAssertTrue(dark.waitForExistence(timeout: 5))
        dark.tap()
        let language = app.buttons["mobile.settings.language"]
        XCTAssertTrue(language.waitForExistence(timeout: 5))
        language.tap()
        let english = app.buttons["English"].firstMatch
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        english.tap()
        app.buttons["mobile.settings.about"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["mobile.about"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Made for your files. Built for your device."].exists)
        XCTAssertFalse(app.links["Source code"].exists)
        app.buttons["BackButton"].firstMatch.tap()
        app.buttons["Activity"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["mobile.jobs"].waitForExistence(timeout: 5))
        app.buttons["Home"].firstMatch.tap()
        XCTAssertTrue(app.buttons["mobile.select.image"].waitForExistence(timeout: 5))
    }

    func testHomeOffersSixSupportedInputTypesWithoutArchive() {
        let app = launch()
        for kind in ["image", "pdf", "audio", "video", "text", "document"] {
            XCTAssertTrue(app.buttons["mobile.select.\(kind)"].exists)
        }
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@",
                                                        "mobile.select.")).count, 6)
        XCTAssertFalse(app.buttons["mobile.select.archive"].exists)
        XCTAssertFalse(app.buttons["mobile.select.subtitle"].exists)
    }

    func testCancellingFilesReturnsHomeWithoutAnError() {
        let app = launch()
        XCTAssertEqual(app.buttons["mobile.select.image"].label, "Image")
        XCTAssertFalse(app.buttons["mobile.select.subtitle"].exists)
        XCTAssertFalse(app.buttons["Paste"].exists)
        app.buttons["mobile.select.image"].tap()
        XCTAssertTrue(app.sheets.buttons["Photo Library"].exists)
        app.sheets.buttons["Files"].firstMatch.tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "إلغاء"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
        XCTAssertTrue(app.buttons["mobile.select.image"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["mobile.importError"].exists)
    }

    func testFirstRunTourColorCompletionAndNoReplayButtons() {
        let app = launch(firstRun: true)
        let next = app.buttons["mobile.onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        let demo = app.descendants(matching: .any)["mobile.onboarding.actions"]
        XCTAssertTrue(demo.waitForExistence(timeout: 5))
        next.tap()
        next.tap()
        let violet = app.buttons["Violet"]
        XCTAssertTrue(violet.waitForExistence(timeout: 5))
        violet.tap()
        XCTAssertTrue(violet.isSelected)
        next.tap()
        XCTAssertTrue(app.buttons["mobile.select.image"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["mobile.select.image"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mobile.onboarding.skip"].exists)
        app.buttons["Settings"].firstMatch.tap()
        app.buttons["mobile.settings.customization"].tap()
        XCTAssertTrue(violet.waitForExistence(timeout: 5))
        XCTAssertTrue(violet.isSelected)
        XCTAssertFalse(app.buttons["mobile.replayOnboarding"].exists)
        app.buttons["Home"].firstMatch.tap()
        XCTAssertFalse(app.buttons["mobile.homeTour"].exists)
    }
    func testConversionAutomaticallyOffersPhotosOrFiles() {
        continueAfterFailure = false
        let app = launch(previewInput: true)
        let png = app.buttons["PNG"].firstMatch
        XCTAssertTrue(png.waitForExistence(timeout: 10))
        png.tap()
        let files = app.buttons["mobile.saveFiles"]
        XCTAssertTrue(files.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["mobile.savePhotos"].exists)
        files.tap()
        let name = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), app.debugDescription)
        // Let the remote browser reveal its destination, then interact with the loaded form.
        name.tap()
        name.typeText("-export")
        let save = app.buttons["DOCPicker.actionButton"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10), app.debugDescription)
        save.tap()
        XCTAssertTrue(app.buttons["Activity"].firstMatch.waitForExistence(timeout: 5))
        let history = app.buttons["clock.arrow.circlepath"].firstMatch
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"),
                                               object: history)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed, app.debugDescription)
        history.tap()
        XCTAssertTrue(app.buttons["Share"].firstMatch.waitForExistence(timeout: 5))
    }

    func testPDFConversionAutomaticallyOpensSharing() {
        continueAfterFailure = false
        let app = launch(previewInput: true)
        let pdf = app.buttons["PDF"].firstMatch
        XCTAssertTrue(pdf.waitForExistence(timeout: 10))
        pdf.tap()
        let sheet = app.otherElements["ShareSheet.RemoteContainerView"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements["LP.CaptionBar.BottomCaption"].label.contains("PDF"))
        XCTAssertFalse(app.buttons["mobile.savePhotos"].exists)
    }

    func testImageSavesToPhotos() {
        continueAfterFailure = false
        let app = launch(previewInput: true)
        let png = app.buttons["PNG"].firstMatch
        XCTAssertTrue(png.waitForExistence(timeout: 10))
        png.tap()
        let photos = app.buttons["mobile.savePhotos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 10))
        photos.tap()
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            let allow = alert.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Allow")).firstMatch
            XCTAssertTrue(allow.exists)
            allow.tap()
        }
        XCTAssertTrue(app.staticTexts["Saved to Photos."].waitForExistence(timeout: 15), app.debugDescription)
    }

    func testResizeEditorFromGroupedWheel() {
        continueAfterFailure = false
        let app = launch(previewInput: true)
        let tools = app.buttons["Tools"].firstMatch
        XCTAssertTrue(tools.waitForExistence(timeout: 10))
        tools.tap()
        let resize = app.buttons["Resize"].firstMatch
        XCTAssertTrue(resize.waitForExistence(timeout: 5))
        resize.tap()
        let apply = app.buttons["mobile.editor.apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 10))
        app.buttons["Half size"].firstMatch.tap()
        apply.tap()
        XCTAssertTrue(app.buttons["mobile.saveFiles"].waitForExistence(timeout: 10))
    }

    func testWheelConvertsInLandscape() {
        continueAfterFailure = false
        let app = launch(previewInput: true)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let png = app.buttons["PNG"].firstMatch
        XCTAssertTrue(png.waitForExistence(timeout: 10))
        XCTAssertTrue(png.isHittable)
        png.tap()
        XCTAssertTrue(app.buttons["mobile.saveFiles"].waitForExistence(timeout: 10))
    }

    func testVideoWheelOffersCompressionAndSharesMP4() {
        continueAfterFailure = false
        let app = launch(previewVideo: true)
        let tools = app.buttons["Tools"].firstMatch
        XCTAssertTrue(tools.waitForExistence(timeout: 15))
        tools.tap()
        let compress = app.buttons["Compress"].firstMatch
        XCTAssertTrue(compress.waitForExistence(timeout: 5))
        compress.tap()
        let apply = app.buttons["mobile.editor.apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["mobile.video.time"].label, "0:00")
        app.buttons["Smaller"].firstMatch.tap()
        apply.tap()
        let sheet = app.otherElements["ShareSheet.RemoteContainerView"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["mobile.savePhotos"].exists)
    }

    func testSharedNavigationBarAcrossTabsAndSettingsDestinations() {
        continueAfterFailure = false
        let app = launch()
        let heading = app.staticTexts["mobile.navigation.title"].firstMatch
        // Tab, then the title its screen shows: Files' screen is "Converted Files".
        for (tab, title) in [("Home", "Home"), ("Files", "Converted Files"), ("Activity", "Activity"),
                             ("Settings", "Settings")] {
            app.buttons[tab].firstMatch.tap()
            XCTAssertTrue(heading.waitForExistence(timeout: 5))
            XCTAssertEqual(heading.label, title)
            XCTAssertTrue(heading.isHittable)
        }
        app.buttons["mobile.settings.customization"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["mobile.customization"].waitForExistence(timeout: 5))
        XCTAssertEqual(heading.label, "Customization")
        let back = app.buttons["BackButton"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), app.debugDescription)
        back.tap()
        app.buttons["mobile.settings.about"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["mobile.about"].waitForExistence(timeout: 5))
        XCTAssertEqual(heading.label, "About")
        back.tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(heading.isHittable)
        app.buttons["Home"].firstMatch.tap()
        XCTAssertTrue(app.buttons["mobile.select.image"].waitForExistence(timeout: 5))
        XCTAssertEqual(heading.label, "Home")
    }
}
