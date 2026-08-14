import Foundation
import Testing
@testable import DesignSystem

/// The plan's three motion rules, held as assertions rather than as intentions. Every one of these
/// is a case where the animation would still *look* right while failing somebody.
struct TypewriterProgressTests {

    private func progress(
        _ count: Int,
        after seconds: Double,
        immediate: Bool = false
    ) -> TypewriterProgress {
        TypewriterProgress(characterCount: count, elapsed: .seconds(seconds),
                           rendersImmediately: immediate)
    }

    @Test func nothingIsShownBeforeItStarts() {
        #expect(progress(100, after: 0).visibleCharacters == 0)
    }

    @Test func theRevealAdvancesWithTime() {
        #expect(progress(100, after: 1).visibleCharacters == 42)
        #expect(progress(100, after: 2).visibleCharacters == 84)
    }

    /// It stops at the end of the passage rather than running past it.
    @Test func theRevealStopsAtTheEnd() {
        #expect(progress(100, after: 60).visibleCharacters == 100)
        #expect(progress(100, after: 60).isComplete)
    }

    /// `NFR-A11Y-04`. Under Reduce Motion — and under VoiceOver, which shares the flag here — the
    /// passage is complete at time zero. A screen reader that received a character at a time would
    /// re-announce the same sentence forty times.
    @Test func reduceMotionRendersThePassageCompleteAtOnce() {
        let immediate = progress(250, after: 0, immediate: true)
        #expect(immediate.visibleCharacters == 250)
        #expect(immediate.isComplete)
        #expect(immediate.totalDuration == .zero)
    }

    /// A negative elapsed time — a clock that stepped backwards — must not show a negative slice
    /// of the string, which would crash `String.prefix`.
    @Test func aBackwardsClockShowsNothingRatherThanCrashing() {
        #expect(progress(100, after: -5).visibleCharacters == 0)
    }

    @Test func anEmptyPassageIsImmediatelyComplete() {
        #expect(progress(0, after: 0).isComplete)
    }

    /// The ceiling on patience. A three-line passage is roughly 200 characters, and nobody should
    /// be made to wait more than a few seconds — with a tap always available to skip it.
    @Test func aTypicalPassageDoesNotOutlastThereadersPatience() {
        let total = progress(200, after: 0).totalDuration
        #expect(total <= .seconds(6), "\(total)")
    }
}

struct HisploraBlinkTests {

    /// `NFR-A11Y-05` — the pulse never reaches zero. A name that vanishes is a name somebody
    /// misses, and the blink is decoration, never the carrier of meaning.
    @Test func theBlinkNeverReachesZeroOpacity() {
        #expect(HisploraBlink.minimumOpacity > 0.5)
        #expect(HisploraBlink.minimumOpacity < 1)
    }

    /// Fast enough to read as a pulse, slow enough not to strobe. Anything under 500 ms round trip
    /// approaches the flash threshold WCAG 2.3.1 is about.
    @Test func theBlinkIsSlowEnoughNotToStrobe() {
        #expect(HisploraBlink.period >= .milliseconds(1000))
    }
}
