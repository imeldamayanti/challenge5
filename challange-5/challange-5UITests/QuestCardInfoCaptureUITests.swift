import XCTest

/// TEMPORARY — captures the quest-availability sheet (`921:3869`) for the quest-card-information
/// restyle, then gets deleted. It enables the debug-only "Simulate arrival anywhere" switch
/// rather than pinning a `simctl` position, so arrival fires deterministically from the desk.
final class QuestCardInfoCaptureUITests: XCTestCase {

    private let questTitleEN = "The Last Traces of Badung"

    override func setUp() {
        continueAfterFailure = false
    }

    func testCaptureQuestAvailabilitySheet() {
        let app = XCUIApplication()
        // The simulate-arrival flag rides in as a launch argument rather than through the
        // Settings toggle: a synthesized tap on that Toggle flipped its UI without ever landing
        // in UserDefaults (verified against the app's plist), and a walker whose position is
        // Cupertinian waits on the checking screen forever. UserDefaults reads `-key value`
        // arguments transparently, so `@AppStorage` sees YES from the first line.
        app.launchArguments = ["-kultara.preferredLanguage", "en",
                               "-kultara.debug.simulateArrivalAnywhere", "YES"]
        app.launch()

        if let skip = waitFor(app.buttons["Skip"]) { skip.tap() }

        let guest = app.buttons["Continue as a guest"]
        if guest.waitForExistence(timeout: 10) {
            guest.tap()
            if let name = waitFor(app.textFields["Display name"]) {
                name.tap()
                name.typeText("Tester")
            }
            if let start = waitFor(app.buttons["Start Exploring"], timeout: 5) { start.tap() }
        }

        // Fresh sandbox, so no draft run from an earlier attempt can resume past the hook.
        let profile = app.buttons["Profile"].firstMatch
        XCTAssertTrue(profile.waitForExistence(timeout: 15), "No Profile tab")
        profile.tap()
        var settings = app.buttons["Settings"].firstMatch
        if !settings.waitForExistence(timeout: 10) {
            profile.tap()
            settings = app.buttons["Settings"].firstMatch
        }
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "No Settings entry")
        settings.tap()

        if let delete = waitFor(app.buttons["Delete all local data"]) {
            delete.tap()
            if let confirm = waitFor(app.buttons["Delete"]) { confirm.tap() }
        }

        if let back = waitFor(app.buttons["Back"].firstMatch) { back.tap() }
        if let quests = waitFor(app.buttons["Quests"].firstMatch) { quests.tap() }

        XCTAssertTrue(waitFor(app.staticTexts[questTitleEN], timeout: 15) != nil)
        let card = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", questTitleEN)).firstMatch
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()

        guard let ready = waitFor(app.buttons["Ready to Explore"]) else {
            XCTFail("Story preview never opened")
            return
        }
        ready.tap()

        // The FR-START-04 notice is the preview screen itself; its acknowledgement is Start.
        if let startRun = waitFor(app.buttons["Start at the first checkpoint"], timeout: 10) {
            startRun.tap()
        }

        // The permission dialog is Springboard's; the simulated provider may or may not trigger
        // one depending on how far the request path reaches, so keep handling it here.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        func dismissPermissionAlert() {
            for label in ["While Using App", "Allow While Using App", "OK"] {
                if springboard.buttons[label].exists {
                    springboard.buttons[label].tap()
                    return
                }
            }
        }

        let headline = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Quest to Explore in")).firstMatch
        let stageButtons = ["I understand", "Continue", "Reveal the legend", "Start the Journey",
                            "Next", "Skip the story"]
        let swipeHint = app.staticTexts["Swipe photo frame to reveal the legends"]
        let rubTarget = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", questTitleEN)).firstMatch
        let deadline = Date().addingTimeInterval(180)
        while !headline.exists && Date() < deadline {
            dismissPermissionAlert()
            // The cutscene intro advances by rubbing its picture clean, not by a button —
            // the button only exists under Reduce Motion.
            if swipeHint.exists && rubTarget.exists {
                for (dx0, dy0, dx1, dy1) in [(0.25, 0.35, 0.75, 0.55),
                                             (0.7, 0.3, 0.3, 0.6),
                                             (0.5, 0.45, 0.5, 0.45)] {
                    rubTarget.coordinate(withNormalizedOffset: CGVector(dx: dx0, dy: dy0))
                        .press(forDuration: 0.08,
                               thenDragTo: rubTarget.coordinate(
                                    withNormalizedOffset: CGVector(dx: dx1, dy: dy1)))
                }
            }
            for label in stageButtons {
                // The sheet's own Continue is in this list too — stop the instant the
                // headline shows, or this loop walks straight through it to the end.
                if headline.exists { break }
                let button = app.buttons[label].firstMatch
                if button.exists && button.isHittable {
                    button.tap()
                    break
                }
            }
            sleep(2)
        }

        XCTAssertTrue(headline.waitForExistence(timeout: 5),
                      "The availability sheet never appeared. Buttons: \(app.buttons.allElementsBoundByIndex.map(\.label))")

        let screenshot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        screenshot.name = "quest-card-info"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertTrue(app.buttons["Continue"].firstMatch.exists)
    }

    private func waitFor(_ element: XCUIElement, timeout: TimeInterval = 10) -> XCUIElement? {
        element.waitForExistence(timeout: timeout) ? element : nil
    }
}
