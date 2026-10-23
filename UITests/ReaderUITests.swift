import XCTest

@MainActor
final class ReaderUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KNOWWHEREAMI_TEST_STORE"] = UUID().uuidString
        app.launch()
        return app
    }

    func testEditorSavesAndCancelPreservesScript() {
        let app = launch()
        let edit = app.buttons["editScript"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let title = app.textFields["scriptTitleField"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Practice script".count))
        title.typeText("My presentation")
        app.buttons["editorActions"].tap()
        app.buttons["clearDraft"].tap()
        let body = app.textViews["scriptBodyField"]
        body.tap()
        body.typeText("Hello everyone. Today we create a better future together.")
        app.buttons["saveScript"].tap()
        XCTAssertTrue(waitForTitle(app, "My presentation", timeout: 3))
        XCTAssertTrue(app.textViews["scriptReader"].exists)
        edit.tap()
        XCTAssertEqual(app.textViews["scriptBodyField"].value as? String, "Hello everyone. Today we create a better future together.")
        app.buttons["editorActions"].tap()
        app.buttons["clearDraft"].tap()
        app.buttons["cancelEditor"].tap()
        app.buttons["Discard changes"].tap()
        edit.tap()
        XCTAssertEqual(app.textViews["scriptBodyField"].value as? String, "Hello everyone. Today we create a better future together.")
        app.buttons["cancelEditor"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(waitForTitle(app, "My presentation", timeout: 5))
        attachScreenshot(app, name: "Saved reader")
    }

    func testEmptyScriptCannotStartMicrophone() {
        let app = launch()
        app.buttons["editScript"].tap()
        app.buttons["editorActions"].tap()
        app.buttons["clearDraft"].tap()
        app.buttons["saveScript"].tap()
        XCTAssertFalse(app.buttons["toggleListening"].isEnabled)
        XCTAssertTrue(app.buttons["addScript"].exists)
        attachScreenshot(app, name: "Empty reader")
    }

    func testTypeSizeSettingsAndResetAreReachable() {
        let app = launch()
        app.buttons["readerSettings"].tap()
        app.buttons["increaseTextSize"].tap()
        app.buttons["increaseTextSize"].tap()
        XCTAssertTrue(app.staticTexts["readerTextSize"].label.contains("30 pt"))
        attachScreenshot(app, name: "Reader settings")
        app.buttons["closeSettings"].tap()
        XCTAssertTrue(app.buttons["restartReading"].isHittable)
        app.buttons["restartReading"].tap()
        XCTAssertTrue(app.staticTexts["Ready"].exists)
        attachScreenshot(app, name: "Initial reader")
    }

    func testWordSelectionAndResetUpdateReadingPosition() {
        let app = launch()
        let reader = app.textViews["scriptReader"]
        XCTAssertTrue(reader.waitForExistence(timeout: 4))
        reader.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.34)).tap()
        XCTAssertEqual(app.staticTexts["readerStatus"].label, "Paused")
        XCTAssertEqual(app.staticTexts["readerPosition"].label, "Position 1 of 144 words")
        attachScreenshot(app, name: "Selected reading position")
        app.buttons["restartReading"].tap()
        XCTAssertEqual(app.staticTexts["readerPosition"].label, "Position 0 of 144 words")
    }

    func testReaderRemainsUsableAtLargestAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchEnvironment["KNOWWHEREAMI_TEST_STORE"] = UUID().uuidString
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.textViews["scriptReader"].waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.textViews["scriptReader"].frame.height, 100)
        XCTAssertTrue(app.buttons["toggleListening"].isHittable)
        XCTAssertGreaterThanOrEqual(app.buttons["restartReading"].frame.height, 44)
        XCTAssertGreaterThanOrEqual(app.buttons["recenterReading"].frame.height, 44)
        XCTAssertEqual(app.buttons["toggleListening"].frame.midX, app.frame.midX, accuracy: 2)
        attachScreenshot(app, name: "Accessibility text size")
        app.buttons["scriptLibrary"].tap()
        let manuscript = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "manuscript-")).firstMatch
        XCTAssertTrue(manuscript.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(manuscript.frame.width, app.frame.width - 65)
        attachScreenshot(app, name: "Accessibility manuscript gallery")
        app.buttons["closeLibrary"].tap()
    }

    func testLibraryCreatesSwitchesDuplicatesDeletesAndPersistsScripts() {
        let app = launch()
        app.buttons["scriptLibrary"].tap()
        app.buttons["newScript"].tap()
        let title = app.textFields["scriptTitleField"]
        XCTAssertTrue(title.waitForExistence(timeout: 4))
        title.tap()
        title.typeText("Second talk")
        app.textViews["scriptBodyField"].tap()
        app.textViews["scriptBodyField"].typeText("A separate manuscript stays separate.\n\nA closing paragraph.")
        app.buttons["saveScript"].tap()
        XCTAssertTrue(waitForTitle(app, "Second talk", timeout: 4))
        app.buttons["scriptLibrary"].tap()
        XCTAssertTrue(app.staticTexts["Practice script"].waitForExistence(timeout: 3))
        attachScreenshot(app, name: "Multiple manuscripts")
        manuscriptCard(app, "Practice script").tap()
        let practiceLoaded = expectation(for: NSPredicate(format: "label ENDSWITH %@", "of 144 words"),
                                         evaluatedWith: app.staticTexts["readerPosition"])
        wait(for: [practiceLoaded], timeout: 3)
        app.terminate()
        app.launch()
        XCTAssertTrue(waitForTitle(app, "Practice script", timeout: 4))
        app.buttons["scriptLibrary"].tap()
        app.buttons["Actions for Second talk"].tap()
        app.buttons["Duplicate"].tap()
        XCTAssertTrue(app.staticTexts["Second talk copy"].waitForExistence(timeout: 3))
        app.buttons["Actions for Second talk"].tap()
        app.buttons["Delete"].tap()
        app.buttons["Delete script"].tap()
        let removed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["Second talk"])
        wait(for: [removed], timeout: 3)
        app.buttons["closeLibrary"].tap()
        XCTAssertTrue(waitForTitle(app, "Second talk copy", timeout: 3))
        app.terminate()
        app.launch()
        XCTAssertTrue(waitForTitle(app, "Second talk copy", timeout: 4))
    }

    func testLiveModeKeepsRescueControlsAvailableWhilePositionIsLocked() {
        let app = launch()
        app.buttons["Live"].tap()
        XCTAssertTrue(app.buttons["nextParagraph"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["rehearsalMetrics"].exists)
        app.buttons["nextParagraph"].tap()
        XCTAssertEqual(app.staticTexts["readerPosition"].label, "Position 8 of 144 words")
        app.switches["stageLock"].tap()
        XCTAssertEqual(app.switches["stageLock"].value as? String, "Locked")
        XCTAssertGreaterThanOrEqual(app.switches["stageLock"].frame.height, 44)
        let reader = app.textViews["scriptReader"]
        XCTAssertEqual(reader.frame.width, app.frame.width, accuracy: 1)
        reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).tap()
        XCTAssertEqual(app.staticTexts["readerPosition"].label, "Position 8 of 144 words")
        app.buttons["nextParagraph"].tap()
        XCTAssertEqual(app.staticTexts["readerPosition"].label, "Position 52 of 144 words")
        attachScreenshot(app, name: "Live mode locked with rescue controls")
        app.buttons["previousParagraph"].tap()
        XCTAssertEqual(app.staticTexts["readerPosition"].label, "Position 8 of 144 words")
        app.buttons["Rehearsal"].tap()
        XCTAssertTrue(app.buttons["finishRehearsal"].exists)
    }

    func testLiveTimerCanBeConfiguredAndStartedWithoutTheMicrophone() {
        let app = launch()
        app.buttons["Live"].tap()
        let countdown = app.staticTexts["liveCountdown"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 3))
        XCTAssertEqual(countdown.label, "Time limit")
        XCTAssertGreaterThan(countdown.frame.height, 40)
        app.buttons["liveTimeSettings"].tap()
        XCTAssertTrue(app.steppers["liveTimeLimitStepper"].waitForExistence(timeout: 3))
        app.buttons["liveDurationPreset"].tap()
        app.buttons["5 min"].tap()
        XCTAssertEqual(app.staticTexts["liveTimeLimitValue"].label, "5:00")
        attachScreenshot(app, name: "Live timer settings")
        app.buttons["startLiveCountdown"].tap()
        XCTAssertTrue(app.buttons["toggleListening"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["toggleListening"].label, "Start listening")
        XCTAssertEqual(app.staticTexts["readerStatus"].label, "Ready")
        let ticking = expectation(for: NSPredicate(format: "value != %@", "5 minutes, 0 seconds"), evaluatedWith: countdown)
        wait(for: [ticking], timeout: 4)
        attachScreenshot(app, name: "Live countdown started without microphone")
        app.terminate()
        app.launch()
        app.buttons["Live"].tap()
        XCTAssertEqual(app.staticTexts["liveCountdown"].value as? String, "5 minutes, 0 seconds")
    }

    func testDraftReplacementCanBeUndone() {
        let app = launch()
        app.buttons["editScript"].tap()
        let original = app.textViews["scriptBodyField"].value as? String
        app.buttons["editorActions"].tap()
        app.buttons["clearDraft"].tap()
        XCTAssertEqual(app.textViews["scriptBodyField"].value as? String, "")
        app.buttons["editorActions"].tap()
        app.buttons["undoDraftReplacement"].tap()
        XCTAssertEqual(app.textViews["scriptBodyField"].value as? String, original)
        app.buttons["cancelEditor"].tap()
        XCTAssertTrue(app.textViews["scriptReader"].waitForExistence(timeout: 3))
    }

    /// The script title lives in the navigation bar, as the bar's identifier or its title label.
    private func waitForTitle(_ app: XCUIApplication, _ title: String, timeout: TimeInterval) -> Bool {
        let match = NSPredicate(format: "identifier == %@ OR label == %@", title, title)
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if app.navigationBars.matching(match).firstMatch.exists
                || app.navigationBars.staticTexts.matching(match).firstMatch.exists { return true }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return false
    }

    private func manuscriptCard(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "manuscript-", title)).firstMatch
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
