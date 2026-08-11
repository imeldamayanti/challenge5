import XCTest

/// The two verifications that cannot be done from a unit test: that the flow can actually be walked
/// on a device, and that it survives the largest Dynamic Type size (`NFR-A11Y-01`).
///
/// These tests navigate and capture screenshots as attachments. They assert on reachability and on
/// truncation, which is measurable: a `UILabel`-backed SwiftUI `Text` reports its rendered frame, so
/// a label whose frame is clipped by its container is detectable rather than a matter of opinion.
final class DiscoveryFlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Launch helpers

    private func launch(
        contentSize: String? = nil,
        language: String = "en"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        // Language comes through UserDefaults' argument domain, which is a real override path.
        // Onboarding is dismissed by tapping Skip below rather than by a launch flag, so the gate
        // itself is exercised and no test hook has to exist in production code.
        var arguments = ["-kultara.preferredLanguage", language]
        if let contentSize {
            arguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launchArguments = arguments
        app.launch()

        // FR-ONB-02: skippable from the first screen. Every test below depends on that being true.
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 10) {
            skip.tap()
        }
        return app
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let screenshot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    // MARK: - The flow at default size

    func testQuestListPreviewAndSettingsAreReachable() {
        let app = launch()

        // Quest list
        let questTitle = app.staticTexts["Example Old-Town Trail"]
        XCTAssertTrue(questTitle.waitForExistence(timeout: 10), "Quest list did not show the quest")
        XCTAssertTrue(app.staticTexts["Estimated cost"].exists, "FR-DISC-05: cost missing from the card")
        attach(app, named: "quest-list")

        // Preview, one tap away (FR-DISC-07)
        questTitle.tap()
        XCTAssertTrue(app.staticTexts["Checkpoints"].waitForExistence(timeout: 10),
                      "Preview did not open")
        XCTAssertTrue(app.staticTexts["Safety"].exists, "FR-DISC-03: safety notice missing")
        attach(app, named: "quest-preview")

        // Back, then Settings
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(questTitle.waitForExistence(timeout: 10))
        app.navigationBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Language"].waitForExistence(timeout: 10),
                      "Settings did not open")
        attach(app, named: "settings")
    }

    func testPreviewWithholdsEveryCheckpointStoryAndClue() {
        // FR-DISC-04, verified against the rendered screen rather than a view model.
        let app = launch()
        let questTitle = app.staticTexts["Example Old-Town Trail"]
        XCTAssertTrue(questTitle.waitForExistence(timeout: 10))
        questTitle.tap()
        XCTAssertTrue(app.staticTexts["Checkpoints"].waitForExistence(timeout: 10))

        // Sentences that exist only in checkpoint lore or in clues, from the fixture.
        let forbidden = [
            "An example claim labelled documented, to exercise the label rendering.",
            "An example claim labelled oral tradition, to exercise the label distinction.",
            "Follow the street north until you reach the forked stone gate.",
            "Walk east past the row of warungs and look for the open square.",
        ]
        for sentence in forbidden {
            XCTAssertFalse(app.staticTexts[sentence].exists,
                           "Preview leaked checkpoint content: \(sentence)")
        }
    }

    // MARK: - NFR-A11Y-01, the largest accessibility size

    func testTheWholeFlowSurvivesTheLargestDynamicTypeSize() {
        let app = launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")

        let questTitle = app.staticTexts["Example Old-Town Trail"]
        XCTAssertTrue(questTitle.waitForExistence(timeout: 15),
                      "Quest list unusable at the largest accessibility size")
        attach(app, named: "a11y-quest-list")
        reportTruncation(in: app, screen: "quest list")

        questTitle.tap()
        XCTAssertTrue(app.staticTexts["Checkpoints"].waitForExistence(timeout: 15),
                      "Preview unreachable at the largest accessibility size")
        attach(app, named: "a11y-quest-preview")
        reportTruncation(in: app, screen: "quest preview")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(questTitle.waitForExistence(timeout: 15))
        app.navigationBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Language"].waitForExistence(timeout: 15),
                      "Settings unreachable at the largest accessibility size")
        attach(app, named: "a11y-settings")
        reportTruncation(in: app, screen: "settings")
    }

    /// Reports labels that run past the window's edges, which is what horizontal truncation and
    /// overlap look like from the outside. Written as a report rather than an assertion so one
    /// clipped label does not hide the rest of the screen's problems.
    private func reportTruncation(in app: XCUIApplication, screen: String) {
        let window = app.windows.firstMatch.frame
        var offenders: [String] = []

        for element in app.staticTexts.allElementsBoundByIndex {
            guard element.exists, element.isHittable || element.frame.height > 0 else { continue }
            let frame = element.frame
            guard frame.width > 0, frame.height > 0 else { continue }
            if frame.minX < window.minX - 0.5 || frame.maxX > window.maxX + 0.5 {
                offenders.append("\"\(element.label.prefix(60))\" frame \(frame) exceeds window \(window)")
            }
        }

        if offenders.isEmpty {
            print("A11Y-OK  \(screen): no label exceeds the window horizontally at AccessibilityXXXL.")
        } else {
            print("A11Y-CLIPPED  \(screen):")
            offenders.forEach { print("   \($0)") }
        }
        XCTAssertTrue(offenders.isEmpty, "\(screen): \(offenders.joined(separator: " | "))")
    }
}
