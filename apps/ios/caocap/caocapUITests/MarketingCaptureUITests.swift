import XCTest

/// One-shot helper to dump Home / Workspace / Chat PNGs for the landing page.
/// Not part of the product test suite; delete after capturing.
final class MarketingCaptureUITests: XCTestCase {
    @MainActor
    func testWriteLandingScreenshots() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-intro_completed_v1", "YES",
            "-personalization_survey_completed_v1", "YES",
            "-agent_library_v1", "fresh-ui-test",
        ]
        app.launch()

        let captain = app.buttons["agent.open.cocaptain"]
        XCTAssertTrue(captain.waitForExistence(timeout: 20))

        let dir = URL(fileURLWithPath: "/tmp/caocap-landing-shots")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        try app.screenshot().pngRepresentation.write(to: dir.appendingPathComponent("home.png"))

        captain.tap()
        XCTAssertTrue(app.buttons["workspace.chat"].waitForExistence(timeout: 8))
        try app.screenshot().pngRepresentation.write(to: dir.appendingPathComponent("workspace.png"))

        app.buttons["workspace.chat"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 8))
        try app.screenshot().pngRepresentation.write(to: dir.appendingPathComponent("chat.png"))
    }
}
