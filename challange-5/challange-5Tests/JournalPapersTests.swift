import ContentKit
import DesignSystem
import Foundation
import RunEngine
import Testing
import UIStringsKit
@testable import challange_5

/// The Journal's two papers (`791:5585`, `791:5551`) and the sealed card's idle turn (`791:5637`).
///
/// Everything here reads the **fixture** repository rather than the shipped bundle, for the reason
/// `ContentFixtures.swift` exists: a guard that reads live content changes meaning every time an
/// author edits JSON, and these assert the shape of a presentation rather than the contents of a
/// quest.
@MainActor
struct JournalPapersTests {

    private func harness() throws -> (model: SealedLettersViewModel, store: any RunStore) {
        let repository = FixtureContentRepository()
        let store = InMemoryRunStore()
        let engine = RunEngine(repository: repository, store: store)
        _ = try engine.start(
            questID: ContentFixture.paidQuestID,
            language: ContentLanguage.en,
            method: .gps,
            accuracyM: 10)
        let model = SealedLettersViewModel(store: store, repository: repository, language: .en)
        return (model, store)
    }

    // MARK: - The two papers

    @Test func everyLetterCarriesTheTwoPapersTheEnvelopeHolds() throws {
        let (model, _) = try harness()
        let letter = try #require(model.selectedLetter)
        // Two, in the order the frame stacks them: the summary is the sheet that comes furthest
        // out, the history rises behind it.
        #expect(letter.papers.map(\.kind) == [.summary, .history])
    }

    @Test func eachPaperNamesTheWalksOwnRegionRatherThanAQuestTitle() throws {
        let (model, _) = try harness()
        let letter = try #require(model.selectedLetter)
        let summary = try #require(letter.papers.first)
        let history = try #require(letter.papers.last)
        // `791:5572` and `791:5818` both name the region. The fixture's is "Fiktif".
        #expect(summary.title.contains("Fiktif"))
        #expect(history.title.contains("Fiktif"))
        // And neither is a format string that never got its argument.
        #expect(!summary.title.contains("%@"))
        #expect(!history.title.contains("%@"))
    }

    @Test func thePapersAreSetAsTheFramesSetThem() throws {
        let (model, _) = try harness()
        let letter = try #require(model.selectedLetter)
        let summary = try #require(letter.papers.first)
        let history = try #require(letter.papers.last)
        // A disc on one, a landscape plate on the other. Swapping them would print the painting
        // as a roundel, which is a different object.
        #expect(summary.artworkStyle == .roundel)
        #expect(history.artworkStyle == .plate)
        // Named, never held: `JournalPaperPresentation` carries a resource name so a presentation
        // model cannot end up holding a piece of the theme.
        #expect(summary.artworkName != nil)
        #expect(history.artworkName != nil)
    }

    @Test func theBackOfTheEnvelopeIsAddressedFromTheWalksOwnSnapshots() throws {
        let (model, _) = try harness()
        let letter = try #require(model.selectedLetter)
        // `791:5657`: a salutation, the walk's title, where it was walked, and when.
        #expect(letter.addressLines.count == 4)
        #expect(letter.addressLines[0] == UIStrings.string(.journalEnvelopeSalutation, .en))
        #expect(letter.addressLines[1] == letter.title)
        #expect(letter.addressLines[2] == "Fiktif")
        #expect(!letter.addressLines[3].isEmpty)
    }

    // MARK: - The idle turn

    @Test func aFreshShelfStandsOnItsFront() throws {
        let (model, _) = try harness()
        #expect(model.flip == .front)
        #expect(model.stage == .sealed)
    }

    @Test func openingWhileTurnedReturnsTheCardToItsFrontFirst() async throws {
        let (model, _) = try harness()
        model.cancelFlipCycle()

        var finished: UUID?
        model.unseal(rendersImmediately: true) { finished = $0 }
        // The opening's own beats are zero-length under Reduce Motion, but the turn back is not —
        // it runs whatever the reader's motion setting is, because the flap and the wax are drawn
        // on the front and an opening that started on the back would swing a flap nobody can see.
        try await Task.sleep(for: .milliseconds(400))

        #expect(model.flip == .front)
        #expect(finished != nil)
    }

    @Test func leavingTheShelfStopsTheTurnAndReSealsTheCard() throws {
        let (model, _) = try harness()
        model.startFlipCycle(rendersImmediately: false)
        model.cancelOpening()
        #expect(model.flip == .front)
        #expect(model.stage == .sealed)
    }

    @Test func reduceMotionLeavesTheCardStillRatherThanSnappedToItsBack() throws {
        let (model, _) = try harness()
        model.startFlipCycle(rendersImmediately: true)
        // A cut is the right answer for an opening, which has somewhere to arrive. An idle turn
        // has nowhere to arrive, so it simply does not run.
        #expect(model.flip == .front)
    }
}
