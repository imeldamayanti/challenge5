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
        // FR-DISC-05 and FR-DISC-02: the Home design's card shows neither cost nor distance. Both
        // survived the restyle, and this is what keeps them there.
        //
        // The card is one accessibility element — it is a single button, and VoiceOver should read
        // it as one thing rather than as eight fragments — so the fields are asserted against its
        // combined label rather than as separate static texts.
        let cardLabel = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Example Old-Town Trail"))
            .allElementsBoundByIndex
            .map(\.label)
            .joined(separator: " | ")
        XCTAssertTrue(cardLabel.contains("Estimated cost"), "FR-DISC-05: cost missing from the card — \(cardLabel)")
        XCTAssertTrue(cardLabel.contains("Distance"), "FR-DISC-02: distance missing from the card — \(cardLabel)")
        XCTAssertTrue(cardLabel.contains("checkpoint"), "the card counts checkpoints, not quests — \(cardLabel)")
        XCTAssertTrue(cardLabel.contains("Walking time") && cardLabel.contains("Total time"),
                      "NFR-CONT-06: walking time and total time must be separate figures — \(cardLabel)")
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

    func testTheMapSurfaceShowsAMarkerPerQuestAndOpensPreview() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Example Old-Town Trail"].waitForExistence(timeout: 10))

        app.buttons["Map"].firstMatch.tap()
        let marker = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "Example Old-Town Trail")).firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 10), "No map marker for the quest")
        // `exists` is not enough: XCUITest finds and taps elements scrolled out of view, so a map
        // that opens on empty ocean passes an existence check. The first thing a user sees has to
        // be the pins.
        XCTAssertTrue(marker.isHittable,
                      "The map opened with no marker on screen — marker \(marker.frame), window \(app.windows.firstMatch.frame)")
        attach(app, named: "region-map")

        // Overlap is the other way NFR-A11Y-01 fails on this screen: quests in one city sit metres
        // apart, so their markers and labels can land on top of each other regardless of type size.
        // Each marker is one accessibility element, so the frames are comparable.
        let markers = app.buttons.allElementsBoundByIndex.filter {
            $0.exists && $0.label.contains("Example") && $0.frame.width > 0
        }
        XCTAssertEqual(markers.count, 3, "Expected one marker per quest, got \(markers.map(\.label))")
        for i in markers.indices {
            for j in markers.indices where j > i {
                XCTAssertFalse(markers[i].frame.intersects(markers[j].frame),
                               "Markers overlap: \(markers[i].label) \(markers[i].frame) vs \(markers[j].label) \(markers[j].frame)")
            }
        }

        marker.tap()
        XCTAssertTrue(app.staticTexts["Checkpoints"].waitForExistence(timeout: 10),
                      "A map marker did not open the quest preview")
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
