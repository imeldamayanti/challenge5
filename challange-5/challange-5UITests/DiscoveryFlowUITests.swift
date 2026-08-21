import XCTest

/// The two verifications that cannot be done from a unit test: that the flow can actually be walked
/// on a device, and that it survives the largest Dynamic Type size (`NFR-A11Y-01`).
///
/// These tests navigate and capture screenshots as attachments. They assert on reachability and on
/// truncation, which is measurable: a `UILabel`-backed SwiftUI `Text` reports its rendered frame, so
/// a label whose frame is clipped by its container is detectable rather than a matter of opinion.
final class DiscoveryFlowUITests: XCTestCase {

    /// The shipped quest's `title.en` (`quests/badung-empat-wajah.json`). Hoisted so a content
    /// change touches one line rather than eleven.
    private let questTitleEN = "The Last Traces of Badung"
    /// `StoryPreviewScreen`'s action label — what a tapped quest card now opens straight into
    /// (`KultaraRootView.startOrResumeRun`), with no browsing screen in front of it any more.
    private let readyToExploreEN = "Ready to Explore"

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

        // The splash wireframe auto-advances, but tapping through it keeps the test's timings its
        // own rather than the animation's.
        let splashContinue = app.buttons["Continue"]
        if splashContinue.waitForExistence(timeout: 10) {
            splashContinue.tap()
        }

        // FR-ONB-02: skippable from the first screen. Every test below depends on that being true.
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 10) {
            skip.tap()
        }

        passEntryScreens(app)

        // `app.launch()` starts a fresh process but not a fresh sandbox: a Run started by an
        // earlier test method in this run is still on disk, and `startOrResumeRun` resumes a draft
        // rather than opening the Story Preview a test expects (`FR-START-06`, working as
        // intended — it is this suite's isolation that assumed otherwise). Deleting local data on
        // every launch is what makes each test method's result independent of run order, and it
        // doubles as `FR-SET-02`'s own reachability check.
        //
        // At the largest accessibility size every row in Settings is taller and the tab bar's
        // labels wrap, so this walk genuinely takes longer — the same reason `openSettings` below
        // takes an explicit `timeout:` rather than a fixed one.
        resetAppData(app, timeout: contentSize == nil ? 10 : 20)
        return app
    }


    /// Past the three entry screens (`791:5145`, `791:5109`, `822:2235`), which stand where the
    /// login wireframe used to.
    ///
    /// The guest route rather than the credential form: it is the one path with no password on it,
    /// and its single field is what the screen insists on before it lets go (`AuthViewModel`).
    /// Every check is conditional, because a run that has already passed these screens does not see
    /// them again — the entry is persisted, unlike the wireframe it replaced.
    private func passEntryScreens(_ app: XCUIApplication) {
        let guest = app.buttons["Continue as a guest"]
        guard guest.waitForExistence(timeout: 10) else { return }
        guest.tap()

        let name = app.textFields["Display name"]
        if name.waitForExistence(timeout: 10) {
            name.tap()
            name.typeText("Tester")
        }

        let start = app.buttons["Start Exploring"]
        if start.waitForExistence(timeout: 5) { start.tap() }
    }

    private func resetAppData(_ app: XCUIApplication, timeout: TimeInterval = 10) {
        let profile = app.buttons["Profile"].firstMatch
        // Right after the guest screen hands over, the tab bar can still be settling into
        // place — waiting for the button to exist before tapping it (rather than tapping on faith)
        // is what makes this reliable at the largest accessibility size, where the bar's layout
        // pass takes longer.
        _ = profile.waitForExistence(timeout: timeout)
        profile.tap()
        var settings = app.buttons["Settings"].firstMatch
        if !settings.waitForExistence(timeout: timeout) {
            // One retry: a mistimed first tap at the largest content size can land short of the
            // bar before its layout settles, in which case nothing happened and Profile is still
            // reachable to try again — cheaper than chasing the exact settle time.
            profile.tap()
            settings = app.buttons["Settings"].firstMatch
        }
        guard settings.waitForExistence(timeout: timeout) else { return }
        settings.tap()

        let deleteAction = app.buttons["Delete all local data"]
        guard deleteAction.waitForExistence(timeout: timeout) else { return }
        deleteAction.tap()
        let confirm = app.buttons["Delete"]
        if confirm.waitForExistence(timeout: timeout) { confirm.tap() }

        app.buttons["Quests"].firstMatch.tap()
    }

    /// Settings is no longer a tab: the flow reaches it as Profile → App preferences.
    private func openSettings(_ app: XCUIApplication, timeout: TimeInterval = 10) {
        app.buttons["Profile"].firstMatch.tap()
        let preferences = app.buttons["Settings"].firstMatch
        XCTAssertTrue(preferences.waitForExistence(timeout: timeout),
                      "Profile did not offer a way into the app preferences")

        // `exists` is not `isHittable`. At the largest accessibility size the profile's two
        // controls run past the fold and the lower one lands under the floating tab bar, so the
        // centre tap XCUITest always performs hits the tab bar and the screen never changes — the
        // same failure `tapQuestCard` documents, and the reason this test was red. A person scrolls
        // the control into view first, so this does too. Bounded, because a swipe that never makes
        // it hittable is a finding rather than something to retry forever.
        for _ in 0..<4 where !preferences.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(preferences.isHittable,
                      "The app-preferences control never scrolled into reach — \(preferences.frame) in \(app.windows.firstMatch.frame)")
        preferences.tap()
    }

    /// Taps the quest's card. The card is one accessibility element — a single button that reads as
    /// one thing — so the title inside it is a label, not a control: at accessibility sizes the
    /// static text reports as not hittable and tapping it throws. The button is what a user taps.
    private func tapQuestCard(_ app: XCUIApplication, titled title: String) {
        let card = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No card for \(title)")
        // Tapped near the top of the card rather than at its centre. At the largest accessibility
        // size a card is most of the screen tall, and its centre point lands underneath the
        // floating tab bar — which XCUITest hits instead, because it always taps the centre. A
        // person taps the part of the card they can see.
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let screenshot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    // MARK: - The flow at default size

    /// The catalogue card and the app preferences. Settings is checked from here, before any quest
    /// card is tapped: a tapped card now goes straight into its run (`startOrResumeRun`), and the
    /// run hides the tab bar for its whole length (`KultaraRootView.hidesTabBar`) — so once inside
    /// there is no way back to Profile without relaunching. Reachability of the run itself is
    /// `testTappingAQuestCardOpensTheStoryFlow`.
    func testQuestListAndSettingsAreReachable() {
        let app = launch()

        // Quest list
        let questTitle = app.staticTexts[questTitleEN]
        XCTAssertTrue(questTitle.waitForExistence(timeout: 10), "Quest list did not show the quest")
        // FR-DISC-05 and FR-DISC-02: the Home design's card shows neither cost nor distance. Both
        // survived the restyle, and this is what keeps them there.
        //
        // The card is one accessibility element — it is a single button, and VoiceOver should read
        // it as one thing rather than as eight fragments — so the fields are asserted against its
        // combined label rather than as separate static texts.
        let cardLabel = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", questTitleEN))
            .allElementsBoundByIndex
            .map(\.label)
            .joined(separator: " | ")
        XCTAssertTrue(cardLabel.contains("Estimated cost"), "FR-DISC-05: cost missing from the card — \(cardLabel)")
        XCTAssertTrue(cardLabel.contains("Distance"), "FR-DISC-02: distance missing from the card — \(cardLabel)")
        XCTAssertTrue(cardLabel.contains("checkpoint"), "the card counts checkpoints, not quests — \(cardLabel)")
        XCTAssertTrue(cardLabel.contains("Walking time") && cardLabel.contains("Total time"),
                      "NFR-CONT-06: walking time and total time must be separate figures — \(cardLabel)")
        attach(app, named: "quest-list")

        // The app preferences, reached through Profile.
        openSettings(app)
        XCTAssertTrue(app.staticTexts["Language"].waitForExistence(timeout: 10),
                      "Settings did not open")
        attach(app, named: "settings")
    }

    /// A quest tapped from the catalogue goes straight into its run — there is no browsing screen
    /// in front of it any more (`KultaraRootView.startOrResumeRun`). What the story flow opens on is
    /// the Hisplora Story Preview: the quest's hook, its distance and duration, and the "Ready to
    /// Explore" action.
    func testTappingAQuestCardOpensTheStoryFlow() {
        let app = launch()
        XCTAssertTrue(app.staticTexts[questTitleEN].waitForExistence(timeout: 10))

        tapQuestCard(app, titled: questTitleEN)
        XCTAssertTrue(app.buttons[readyToExploreEN].waitForExistence(timeout: 10),
                      "Tapping the quest card did not open the story flow")
        attach(app, named: "story-preview")
    }

    func testTheMapSurfaceShowsAMarkerPerQuestAndOpensTheStoryFlow() {
        let app = launch()
        XCTAssertTrue(app.staticTexts[questTitleEN].waitForExistence(timeout: 10))

        app.buttons["Map"].firstMatch.tap()
        let marker = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", questTitleEN)).firstMatch
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
            $0.exists && $0.label.contains(questTitleEN) && $0.frame.width > 0
        }
        // The bundle ships one quest, so one pin. The overlap loop below is vacuous at one marker
        // — it stays because it is the assertion that matters the moment a second region lands.
        XCTAssertEqual(markers.count, 1, "Expected one marker per quest, got \(markers.map(\.label))")
        for i in markers.indices {
            for j in markers.indices where j > i {
                XCTAssertFalse(markers[i].frame.intersects(markers[j].frame),
                               "Markers overlap: \(markers[i].label) \(markers[i].frame) vs \(markers[j].label) \(markers[j].frame)")
            }
        }

        marker.tap()
        XCTAssertTrue(app.buttons[readyToExploreEN].waitForExistence(timeout: 10),
                      "A map marker did not open the story flow")
    }

    /// `FR-DISC-04`, verified against the rendered screen rather than a view model. The screen this
    /// guarantee is checked against moved from the standalone preview to the Story Preview: the
    /// quest's own hook is shown there, but nothing that belongs to a checkpoint the walker has not
    /// reached yet.
    func testStoryPreviewWithholdsEveryCheckpointStoryAndClue() {
        let app = launch()
        let questTitle = app.staticTexts[questTitleEN]
        XCTAssertTrue(questTitle.waitForExistence(timeout: 10))
        tapQuestCard(app, titled: questTitleEN)
        XCTAssertTrue(app.buttons[readyToExploreEN].waitForExistence(timeout: 10))

        // Phrases that exist only in checkpoint lore or in clues, from the shipped quest. Matched
        // with a CONTAINS predicate rather than by exact identifier: XCUITest caps a string
        // identifier at 128 characters, and lore blocks are longer than that.
        let forbidden = [
            "The first face is power.",
            "The second face is faith.",
            "Look for red brick walls and a red brick gateway",
            "The market building is four storeys tall.",
        ]
        for phrase in forbidden {
            let leaked = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", phrase))
                .firstMatch
            XCTAssertFalse(leaked.exists, "The story flow leaked checkpoint content: \(phrase)")
        }
    }

    // MARK: - NFR-A11Y-01, the largest accessibility size

    func testTheWholeFlowSurvivesTheLargestDynamicTypeSize() {
        let app = launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")

        let questTitle = app.staticTexts[questTitleEN]
        XCTAssertTrue(questTitle.waitForExistence(timeout: 15),
                      "Quest list unusable at the largest accessibility size")
        attach(app, named: "a11y-quest-list")
        reportTruncation(in: app, screen: "quest list")

        // Settings, before any quest card is tapped — the run flow hides the tab bar for its whole
        // length, so Profile is unreachable once the story flow has opened.
        openSettings(app, timeout: 15)
        XCTAssertTrue(app.staticTexts["Language"].waitForExistence(timeout: 15),
                      "Settings unreachable at the largest accessibility size")
        attach(app, named: "a11y-settings")
        reportTruncation(in: app, screen: "settings")

        app.buttons["Quests"].firstMatch.tap()
        XCTAssertTrue(questTitle.waitForExistence(timeout: 15))
        tapQuestCard(app, titled: questTitleEN)
        XCTAssertTrue(app.buttons[readyToExploreEN].waitForExistence(timeout: 15),
                      "The story flow unreachable at the largest accessibility size")
        attach(app, named: "a11y-story-preview")
        reportTruncation(in: app, screen: "story preview")
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
