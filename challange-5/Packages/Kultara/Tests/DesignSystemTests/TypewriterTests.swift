import SwiftUI
import Testing
@testable import DesignSystem

/// The story preview's two shipped materials: the photograph of the machine, and the typebar face
/// the sheet is typed in. Both are resources, and a resource that stops shipping degrades silently
/// — the screen still lays out, it just stops being the design. These are the tests that notice.
@Suite("Typewriter")
struct TypewriterTests {

    @Test func machinePhotographIsPackaged() {
        #expect(TypewriterMetrics.machineIsAvailable)
    }

    /// The sheet is narrower than the machine, as the photograph has it — a sheet as wide as the
    /// carriage reads as a banner rather than as paper in a roller.
    @Test func theSheetIsNarrowerThanTheMachine() {
        #expect(TypewriterMetrics.paperWidthFraction > 0.5)
        #expect(TypewriterMetrics.paperWidthFraction < 0.8)
    }

    /// The crest stands *on* the page, so it has to be narrower than the page. Drawn wider it stops
    /// reading as an object resting on paper and becomes a header the sheet hangs from, which is a
    /// different picture from the one `35:431` draws.
    @Test func theCrestIsNarrowerThanTheSheet() {
        #expect(TypewriterMetrics.crestWidthFraction < TypewriterMetrics.paperWidthFraction)
        #expect(TypewriterMetrics.crestWidthFraction > 0.4)
    }

    /// Part of the crest is behind the paper and part of it stands above — both parts, or the
    /// overlap is not one. At 0 the frame sits on top of the page like a title; at 1 it vanishes
    /// behind it entirely, and either way the negative padding that produces the effect would still
    /// look like working code.
    @Test func theCrestOverlapsThePaperWithoutDisappearingBehindIt() {
        #expect(TypewriterMetrics.crestOverlapFraction > 0)
        #expect(TypewriterMetrics.crestOverlapFraction < 1)
    }

    /// Special Elite registers. The fallback is SF Pro's monospaced design, which is a legitimate
    /// state and also the state the app shipped in before the face was licensed — so without this
    /// test, dropping the resource is invisible.
    @Test func theTypewriterFaceRegisters() {
        #expect(KultaraFonts.typewriterIsAvailable,
                "Special Elite did not register; the sheet falls back to SF Pro monospaced")
    }

    /// The two roles that use it, and nothing else. A costume face on a body role is how a design
    /// system stops being one.
    @Test func onlyTheSheetRolesAreSetInTheTypewriterFace() {
        let typed = KultaraTypography.Role.allCases.filter { $0.face == .typewriter }
        #expect(Set(typed) == [.typedSheet, .typedFigure])
    }

    /// The frame types the sheet at 8.5 pt. That is a size inside a photograph, not a size to read
    /// at, and reproducing it literally would fail `NFR-A11Y-01` on the first line. The deviation
    /// is deliberate, so it is asserted rather than left to drift back.
    @Test func theSheetIsSetLargerThanTheFrameDrawsIt() {
        #expect(KultaraTypography.Role.typedSheet.basePointSize >= 12)
    }
}
