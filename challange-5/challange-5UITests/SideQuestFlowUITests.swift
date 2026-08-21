import XCTest

/// Walks a whole sidequest end to end on the simulator — the one thing `s6` §3's checklist asks
/// for that a unit test cannot reach, and the row `s6` §1's own table names as XCUITest's job:
/// "Navigating the flow end to end."
///
/// Driven with **Simulate arrival anywhere** on from launch (`kultara.debug.simulateArrivalAnywhere`
/// in the `UserDefaults` argument domain, the same override path `DiscoveryFlowUITests` already
/// uses for language) rather than by toggling it from Settings mid-test: the switch is debug-only
/// scaffolding for exactly this problem — `FR-START-08`'s gate cannot be reached from a desk
/// otherwise — and setting it before launch exercises the same `ArrivalEvaluator` path a walker
/// in the field takes, just with a supplied position instead of a GPS fix (`s0`'s note on the
/// simulator MCP not driving this toggle's live taps is a different, unrelated limitation — this
/// avoids it by never tapping the toggle at all).
///
/// Exercises `sq-badung-puri-agung-pemecutan` specifically: a quiz challenge, so the flow completes
/// without a system photo picker or camera sheet neither this harness nor the Simulator can drive.
final class SideQuestFlowUITests: XCTestCase {

    private let sideQuestTitleEN = "A House Still Lived In"
    private let correctOptionEN = "Ask, because it may be closed without notice"
    private let awardedLetter = "E"

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-kultara.preferredLanguage", "en",
            "-kultara.debug.simulateArrivalAnywhere", "YES",
        ]
        app.launch()

        let splashContinue = app.buttons["Continue"]
        if splashContinue.waitForExistence(timeout: 10) { splashContinue.tap() }
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 10) { skip.tap() }
        let skipAuth = app.buttons["Not now"]
        if skipAuth.waitForExistence(timeout: 10) { skipAuth.tap() }
        return app
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let screenshot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// `app.launch()` starts a fresh process but not a fresh sandbox — a sidequest record earned by
    /// one test method is still on disk for the next one, since XCUITest does not reinstall the app
    /// between test methods in the same run. Each test starts from Settings → "Delete all local
    /// data" instead of assuming an order, which doubles as `FR-SET-02`'s own acceptance check
    /// (`s6` §3's last row).
    private func resetAppData(_ app: XCUIApplication) {
        app.buttons["Profile"].firstMatch.tap()
        let settings = app.buttons["Settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "Profile did not offer a way into Settings")
        settings.tap()

        let deleteAction = app.buttons["Delete all local data"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 10), "Settings did not offer delete all local data")
        deleteAction.tap()
        let confirm = app.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "The delete confirmation dialog did not appear")
        confirm.tap()

        app.buttons["Quests"].firstMatch.tap()
    }

    /// Scrolls the quest list down until `element` is hittable, or gives up after a handful of
    /// swipes. The nearby list sits below the quest cards (`QuestListView`), and how far down
    /// depends on how many quests are shipped.
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 6) {
        var remaining = attempts
        while !element.isHittable && remaining > 0 {
            app.swipeUp()
            remaining -= 1
        }
    }

    func testWalkingAQuizSidequestEndToEndAwardsItsLetter() throws {
        let app = launch()
        resetAppData(app)

        // `FR-SIDE-07` — the nearby list is the way in before a notification exists.
        XCTAssertTrue(app.staticTexts["Places near you"].waitForExistence(timeout: 10),
                      "The nearby list did not render on the quest list screen")
        let card = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", sideQuestTitleEN)).firstMatch
        scrollUntilHittable(card, in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No nearby card for \(sideQuestTitleEN)")
        attach(app, named: "01-nearby-list")
        card.tap()

        // The notice — synopsis and the yes/no question.
        XCTAssertTrue(app.buttons["Yes, tell me"].waitForExistence(timeout: 10),
                      "The sidequest notice did not open")
        attach(app, named: "02-notice")
        app.buttons["Yes, tell me"].tap()

        // The arrival gate, then the story — one page, all lore joined (`s0` D6, `StoryRevealScreen`'s
        // comment on why it is not paginated). With the developer switch on, `SimulatedLocationProvider`
        // reports a fix at the target a beat after sampling starts, and `ArrivalEvaluator` —
        // unmodified — takes it from there (`s0` §6, `s3` §6): the story opens on its own, with no
        // tap required. `FR-CP-05`'s accuracy chip and citations render here, unlike the run flow's
        // signed exception.
        let storyContinue = app.buttons["Continue"]
        XCTAssertTrue(storyContinue.waitForExistence(timeout: 15), "The arrival gate did not resolve to a story")
        attach(app, named: "03-story")
        storyContinue.tap()

        // The challenge — answerable from the lore just read (`s5` §4's own authoring rule).
        let option = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", correctOptionEN)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 10), "The quiz options did not render")
        attach(app, named: "04-challenge")
        option.tap()
        let answer = app.buttons["Answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        answer.tap()

        // Right first time: `FR-SIDE-06`'s explanation appears, and the settled state's own
        // Continue button carries on to the letter — a wrong-then-retry path is
        // `SideQuestEngineTests.theAnswerIsRevealedOnTheThirdAttemptAndTheLetterIsStillAwarded`'s
        // job at the unit level, not this walk's.
        let challengeContinue = app.buttons["Continue"]
        XCTAssertTrue(challengeContinue.waitForExistence(timeout: 10),
                      "Answering correctly did not settle the challenge")
        attach(app, named: "05-challenge-settled")
        challengeContinue.tap()

        // The letter (`FR-SIDE-05`, `FR-SIDE-08`).
        let letter = app.staticTexts[awardedLetter]
        XCTAssertTrue(letter.waitForExistence(timeout: 10), "The letter screen did not show \"\(awardedLetter)\"")
        XCTAssertTrue(app.staticTexts["Puri Agung Pemecutan"].waitForExistence(timeout: 5),
                      "The letter screen did not name the place")
        attach(app, named: "06-letter")

        // Into the collection: the earned slot carries its letter, and — with four sidequests still
        // unearned in this run — the others stay masked (`FR-SIDE-08`).
        let seeCollection = app.buttons["See the collection"]
        XCTAssertTrue(seeCollection.waitForExistence(timeout: 5))
        seeCollection.tap()
        XCTAssertTrue(app.staticTexts["Traces of Badung"].waitForExistence(timeout: 10),
                      "Opening the collection from the letter screen did not open it")
        attach(app, named: "07-collection")
        // `FR-SIDE-08` as accepted on 2026-08-15: an unearned slot names its place (so a walker can
        // plan a visit) but never its letter — "Not yet found" is what stands in for the letter.
        XCTAssertTrue(app.staticTexts["Not yet found"].firstMatch.waitForExistence(timeout: 5),
                      "An unearned slot must say \"Not yet found\" in place of its letter")
    }

    /// Re-opening a completed sidequest from the nearby list must read back what was earned, not
    /// award a second time (`FR-SIDE-05`, `FR-SIDE-07`) — the read path a walker uses when they
    /// want to revisit a story they already finished.
    func testReopeningACompletedSidequestReplaysWithoutAwardingAgain() throws {
        let app = launch()
        resetAppData(app)
        XCTAssertTrue(app.staticTexts["Places near you"].waitForExistence(timeout: 10))

        func openAndComplete() {
            let card = app.buttons.containing(
                NSPredicate(format: "label CONTAINS %@", sideQuestTitleEN)).firstMatch
            scrollUntilHittable(card, in: app)
            card.tap()
            app.buttons["Yes, tell me"].tap()
            let storyContinue = app.buttons["Continue"]
            XCTAssertTrue(storyContinue.waitForExistence(timeout: 15))
            storyContinue.tap()
        }

        openAndComplete()
        let option = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", correctOptionEN)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()
        app.buttons["Answer"].tap()
        let challengeContinue = app.buttons["Continue"]
        XCTAssertTrue(challengeContinue.waitForExistence(timeout: 10))
        challengeContinue.tap()
        let firstLetterScreen = app.staticTexts[awardedLetter]
        XCTAssertTrue(firstLetterScreen.waitForExistence(timeout: 10))
        app.buttons["Keep exploring"].tap()

        // Re-open the same sidequest. `FR-SIDE-02` gates opening the story, not re-opening a
        // completed one — `SideQuestFlowViewModel.accept()` sends an already-discovered record
        // straight to its story rather than back through the arrival gate.
        XCTAssertTrue(app.staticTexts["Places near you"].waitForExistence(timeout: 10))
        let card = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", sideQuestTitleEN)).firstMatch
        scrollUntilHittable(card, in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        // `FR-SIDE-07` — a completed sidequest still lists, and says so.
        XCTAssertTrue(card.label.contains("Letter earned"), "A completed row must say it was earned: \(card.label)")
        card.tap()
        app.buttons["Yes, tell me"].tap()

        // Straight to the story — no arrival gate a second time.
        let storyContinue = app.buttons["Continue"]
        XCTAssertTrue(storyContinue.waitForExistence(timeout: 10),
                      "Re-opening a completed sidequest must go straight to its story")
        storyContinue.tap()

        // `advanceFromStory()` replays the stored outcome onto the challenge screen rather than
        // asking again — same screen, same settled Continue button, no new attempt recorded.
        let replayContinue = app.buttons["Continue"]
        XCTAssertTrue(replayContinue.waitForExistence(timeout: 10),
                      "Replaying a completed quiz did not land on its settled state")
        replayContinue.tap()

        let letterAgain = app.staticTexts[awardedLetter]
        XCTAssertTrue(letterAgain.waitForExistence(timeout: 10),
                      "Replaying a completed sidequest did not reach the letter screen")
        attach(app, named: "reopen-letter")
    }
}
