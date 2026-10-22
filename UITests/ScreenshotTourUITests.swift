import XCTest

/// Walks the main surfaces and attaches a screenshot of each one for visual review.
@MainActor
final class ScreenshotTourUITests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    func testTourOfEverySurface() {
        let app = XCUIApplication()
        app.launchEnvironment["KNOWWHEREAMI_TEST_STORE"] = UUID().uuidString
        app.launch()
        let reader = app.textViews["scriptReader"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        snap(app, "01 Reader ready")

        reader.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.34)).tap()
        snap(app, "02 Reader position selected")

        app.buttons["mode-live"].tap()
        XCTAssertTrue(app.buttons["nextParagraph"].waitForExistence(timeout: 3))
        app.buttons["nextParagraph"].tap()
        app.switches["stageLock"].tap()
        snap(app, "03 Live locked")
        app.switches["stageLock"].tap()
        app.buttons["mode-rehearsal"].tap()

        app.buttons["scriptLibrary"].tap()
        XCTAssertTrue(app.buttons["closeLibrary"].waitForExistence(timeout: 3))
        snap(app, "04 Library scripts")
        app.buttons["Rehearsals"].firstMatch.tap()
        snap(app, "05 Library rehearsals")
        app.buttons["closeLibrary"].tap()

        app.buttons["readerSettings"].tap()
        XCTAssertTrue(app.buttons["closeSettings"].waitForExistence(timeout: 3))
        snap(app, "06 Settings")
        app.buttons["closeSettings"].tap()

        app.buttons["editScript"].tap()
        XCTAssertTrue(app.textViews["scriptBodyField"].waitForExistence(timeout: 3))
        snap(app, "07 Editor")
        app.buttons["editorActions"].tap()
        app.buttons["clearDraft"].tap()
        app.buttons["saveScript"].tap()
        XCTAssertTrue(app.buttons["addScript"].waitForExistence(timeout: 3))
        snap(app, "08 Empty reader")
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 1.0)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
