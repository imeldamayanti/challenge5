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

    /// One sheet holds one sheet's worth. The machine is fixed now, so the page is a window rather
    /// than a column that can grow — a passage that overruns it becomes a scroll inside a
    /// photograph.
    @Test func aLongPassageIsCutToOneSheet() {
        let long = String(repeating: "kata ", count: 200)
        let cut = TypewriterMetrics.sheetText(long)
        #expect(cut.count <= TypewriterMetrics.maximumSheetCharacters)
        #expect(cut.hasSuffix("…"))
    }

    /// A passage that fits is not touched — no ellipsis on a page that ended by itself.
    @Test func aPassageThatFitsIsLeftAlone() {
        let short = "Inti kota lama Denpasar tersusun di sekitar sebuah perempatan."
        #expect(TypewriterMetrics.sheetText(short) == short)
    }

    /// The cut falls between words. Mid-word it reads as a rendering fault rather than as an
    /// ending, which is the one thing a deliberate trim must not look like.
    @Test func theCutFallsOnAWordBoundary() {
        let long = String(repeating: "perempatan ", count: 60)
        let cut = TypewriterMetrics.sheetText(long)
        #expect(cut.hasSuffix("perempatan…"))
    }

    /// A cut that lands two words into a fresh paragraph drops the stub. On the shipped hook it
    /// used to leave "At the…" alone at the foot of the page, which reads as a rendering fault.
    @Test func aStubParagraphAtTheCutIsDroppedWithIt() {
        // Long enough that the cut falls a couple of words into the second paragraph.
        let first = String(repeating: "satu ", count: 56)
        let hook = first + "\n\n" + "At the fourth stop you will be standing there."
        let cut = TypewriterMetrics.sheetText(hook)
        #expect(!cut.contains("At the"))
        #expect(cut.hasSuffix("…"))
    }

    /// A cut that lands on a full stop keeps the full stop and takes no ellipsis: "kept.…" reads
    /// as a typing fault, not as a passage that goes on elsewhere.
    @Test func aCutThatEndsASentenceTakesNoEllipsis() {
        // 295 characters of filler, then a sentence that ends two characters short of the cut.
        let hook = String(repeating: "kata ", count: 59) + "ya." + " lanjutan kalimat berikutnya"
        let cut = TypewriterMetrics.sheetText(hook)
        #expect(cut.hasSuffix("."))
        #expect(!cut.hasSuffix(".…"))
    }

    /// A tail long enough to be a paragraph in its own right is kept — the rule drops stubs, not
    /// content.
    @Test func aFullParagraphAtTheCutIsKept() {
        // Short enough that the cut falls deep into the second paragraph, not at its head.
        let first = String(repeating: "satu ", count: 30)
        let second = String(repeating: "This walk starts on the western side. ", count: 6)
        let cut = TypewriterMetrics.sheetText(first + "\n\n" + second)
        #expect(cut.contains("This walk starts on the western side."))
    }

    /// The page feeds in; it does not appear. A zero here would silently delete the one piece of
    /// motion the screen has, and the code that produces it would still look like working code.
    @Test func thePageRisesInReadableTime() {
        #expect(TypewriterMetrics.riseDuration > 0)
        #expect(TypewriterMetrics.riseDuration < 1)
    }
}
