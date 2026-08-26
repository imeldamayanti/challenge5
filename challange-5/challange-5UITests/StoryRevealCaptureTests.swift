import XCTest

/// Seventh capture pass: the Profile tab's Stamps tab — the tiered stamp wall the promo's
/// Frame 9 lays its trust statements over.
final class StoryRevealCaptureTests: XCTestCase {

    private let questTitleEN = "The Last Traces of Badung"

    override func setUp() {
        continueAfterFailure = false
    }

    func testWalkCapturesEveryStoryReveal() {
        let app = XCUIApplication()
        app.launchArguments = ["-kultara.preferredLanguage", "en"]
        app.launch()

        XCTAssertTrue(app.staticTexts[questTitleEN].waitForExistence(timeout: 20),
                      "Home never showed the quest")

        guard pressIf(app.buttons["Profile"].firstMatch) else { return }
        Thread.sleep(forTimeInterval: 1.5)

        let stampsTab = app.buttons["Stamps"].firstMatch
        guard stampsTab.waitForExistence(timeout: 8) else {
            attach(app, named: "x-no-stamps-tab")
            return
        }
        stampsTab.tap()
        Thread.sleep(forTimeInterval: 1.5)
        attach(app, named: "23-profile-stamps-wall")
    }

    @discardableResult
    private func pressIf(_ element: XCUIElement) -> Bool {
        guard element.exists, element.isHittable else { return false }
        element.tap()
        return true
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let screenshot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
