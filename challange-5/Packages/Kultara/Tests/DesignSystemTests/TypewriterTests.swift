import CoreGraphics
import Foundation
import ImageIO
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
        // Long enough that the cut falls a couple of words into the second paragraph — measured off
        // the limit rather than written against one, because the limit moves when the sheet does.
        let first = String(repeating: "satu ", count: (TypewriterMetrics.maximumSheetCharacters - 12) / 5)
        let hook = first + "\n\n" + "At the fourth stop you will be standing there."
        let cut = TypewriterMetrics.sheetText(hook)
        #expect(!cut.contains("At the"))
        #expect(cut.hasSuffix("…"))
    }

    /// A cut that lands on a full stop keeps the full stop and takes no ellipsis: "kept.…" reads
    /// as a typing fault, not as a passage that goes on elsewhere.
    @Test func aCutThatEndsASentenceTakesNoEllipsis() {
        // Filler up to a few characters short of the limit, then a sentence that ends just before
        // the cut. Sized off the limit so it stays a test of the rule and not of one page length.
        let filler = String(repeating: "kata ", count: (TypewriterMetrics.maximumSheetCharacters - 5) / 5)
        let hook = filler + "ya." + " lanjutan kalimat berikutnya"
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
    ///
    /// The ceiling is the typing, not a round number. The paper has to have stopped moving while
    /// the passage is still being typed onto it — the other way round leaves the sheet crawling
    /// after the last character has landed, which is dead time a tap on the passage cannot
    /// shorten. `maximumSheetCharacters` at `charactersPerSecond` is the longest a full sheet ever
    /// takes to type, so it is the longest the feed may ever run.
    ///
    /// It read `< 1` while the feed was a 0.55-second ease-out, and that bound was the old
    /// behaviour restated rather than a rule: the whole page arrived in one movement, which is a
    /// card sliding into place rather than paper wound out of a machine.
    @Test func thePageRisesInReadableTime() {
        let typingASheet = TypewriterProgress(
            characterCount: TypewriterMetrics.maximumSheetCharacters,
            elapsed: .zero,
            rendersImmediately: false,
            charactersPerSecond: TypewriterMetrics.sheetCharactersPerSecond
        ).totalDuration
        let seconds = Double(typingASheet.components.seconds)
            + Double(typingASheet.components.attoseconds) / 1e18

        #expect(TypewriterMetrics.riseDuration > 0)
        #expect(TypewriterMetrics.riseDuration < seconds)
    }

    /// The sheet is *typed*, not revealed. It runs at less than half the rate a passage appears at
    /// on the story reveal, which is the difference between a machine printing a page and a wipe
    /// passing over one — and it is a number, so it drifts back silently unless something holds it.
    @Test func theSheetIsTypedSlowerThanAPassageIsRevealed() {
        #expect(TypewriterMetrics.sheetCharactersPerSecond * 2 < TypewriterProgress.charactersPerSecond)
        #expect(TypewriterMetrics.sheetCharactersPerSecond > 0)
    }

    /// A ceiling, not a gate: the action below the machine is live from the first frame and a tap on
    /// the passage finishes it. Still — a full sheet that took half a minute to type would be a
    /// screen a reader waits out rather than reads along with.
    @Test func aFullSheetTypesInsideAReadersPatience() {
        let sheet = TypewriterProgress(
            characterCount: TypewriterMetrics.maximumSheetCharacters,
            elapsed: .zero,
            rendersImmediately: false,
            charactersPerSecond: TypewriterMetrics.sheetCharactersPerSecond)
        #expect(sheet.totalDuration <= .seconds(15), "\(sheet.totalDuration)")
    }

    // MARK: The drawn sheet against the photographed one
    //
    // Half of this screen's sheet is drawn and half of it is a photograph, and the two have to be
    // the same piece of paper. Every number that makes them one — the fill, the width, the centre
    // line, and where the drawn half stops — was read off `typewriter.png`, so all four go stale
    // silently if the file is ever re-exported. These re-read it.

    /// The shipped photograph, decoded the way the component decodes it.
    private var machine: CGImage? {
        guard let url = TypewriterMetrics.machineURL,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// The measurements are only true of a 720 × 573 file. A re-export at another size is the
    /// realistic way they go stale, and it would move the sheet on top of the machine.
    @Test func theShippedFileIsTheOneTheMetricsWereMeasuredFrom() throws {
        let image = try #require(machine, "typewriter.png did not decode")
        #expect(image.width == 720)
        #expect(image.height == 573)
    }

    /// The fill is the photograph's own paper, not the palette's cream. Ten levels of lightness
    /// between them is the difference between one sheet and two, and it is invisible in code —
    /// `paperCream` reads like the obvious token to reach for, and reaching for it is the bug.
    ///
    /// Read straight off the bytes, because the file carries no colour profile: those bytes are
    /// what the screen is handed. A converting reader answers ten levels lighter and would agree
    /// with the wrong constant.
    @Test func theDrawnSheetIsFilledWithThePhotographsOwnPaper() throws {
        let image = try #require(machine, "typewriter.png did not decode")
        let pixels = try #require(readPixels(image), "typewriter.png did not rasterise")
        let sampled = mean(of: pixels, width: image.width, x: 165...575, y: 5...60)
        #expect(abs(sampled.red - TypewriterMetrics.paperTone.red) < 0.01)
        #expect(abs(sampled.green - TypewriterMetrics.paperTone.green) < 0.01)
        #expect(abs(sampled.blue - TypewriterMetrics.paperTone.blue) < 0.01,
                "the photograph's paper (\(sampled.hex)) has drifted from paperTone (\(TypewriterMetrics.paperTone.hex))")
    }

    /// It is still paper, whatever the file says: the two inks the sheet is typed in are measured
    /// against it rather than against the token the contrast suite covers.
    @Test func theTypedInksClearWCAGOnTheDrawnSheet() {
        let palette = HisploraPalette.standard
        #expect(contrastRatio(palette.inkDark, TypewriterMetrics.paperTone)
                >= ContrastRequirement.bodyText.minimumRatio)
        #expect(contrastRatio(palette.inkMuted, TypewriterMetrics.paperTone)
                >= ContrastRequirement.bodyText.minimumRatio)
    }

    /// Where the drawn sheet is cut, and where it is centred, against the photographed paper's own
    /// edges — read out of the file rather than trusted. A re-crop moves the paper in the frame and
    /// nothing else would notice.
    @Test func theDrawnSheetIsCutToThePhotographedPaper() throws {
        let image = try #require(machine, "typewriter.png did not decode")
        let pixels = try #require(readPixels(image), "typewriter.png did not rasterise")
        // Row 0 is the one row where the paper is the only opaque thing in the picture: the
        // carriage begins a few rows below it.
        let opaque = (0..<image.width).filter { pixels[$0].alpha > 0.8 }
        let left = try #require(opaque.first), right = try #require(opaque.last)
        let width = CGFloat(right - left + 1) / CGFloat(image.width)
        let centre = (CGFloat(left + right) / 2 - CGFloat(image.width) / 2) / CGFloat(image.width)
        #expect(abs(width - TypewriterMetrics.paperWidthFraction) < 0.003,
                "the photographed paper spans \(left)…\(right)")
        #expect(abs(centre - TypewriterMetrics.paperCentreOffsetFraction) < 0.003,
                "the photographed paper is centred at \((left + right) / 2)")
    }

    /// And where it stops: on a row of the photograph that is already the colour the drawn sheet is
    /// filled with. That is the whole join — no gradient, no overlap trick, just two halves of one
    /// tone meeting. A sheet that ends lower lands on the photograph's falloff and steps; one that
    /// ends lower still lands on the machine's paper guide and paints paper over hardware.
    @Test func theDrawnSheetHandsOverInsideThePhotographsFlatField() throws {
        let image = try #require(machine, "typewriter.png did not decode")
        let pixels = try #require(readPixels(image), "typewriter.png did not rasterise")
        let row = Int((TypewriterMetrics.rollerInsetFraction * CGFloat(image.height)).rounded())
        let atJoin = mean(of: pixels, width: image.width, x: 200...540, y: (row - 2)...row)
        let tone = TypewriterMetrics.paperTone
        #expect(abs(atJoin.red - tone.red) < 0.006)
        #expect(abs(atJoin.green - tone.green) < 0.006)
        #expect(abs(atJoin.blue - tone.blue) < 0.006,
                "row \(row) reads \(atJoin.hex) against paperTone \(tone.hex); the join would step")
    }

    /// The band the join has to land in, measured rather than assumed — the sheet's bottom moves
    /// with the reader's text size, and the tolerance for that is however many rows of the
    /// photograph are flat. If a re-export shortens the flat field, the join stops being safe
    /// before it starts being visible.
    @Test func thePhotographsFlatFieldIsDeepEnoughToLandIn() throws {
        let image = try #require(machine, "typewriter.png did not decode")
        let pixels = try #require(readPixels(image), "typewriter.png did not rasterise")
        let tone = TypewriterMetrics.paperTone
        let flat = (0..<image.height).prefix { row in
            let mean = mean(of: pixels, width: image.width, x: 200...540, y: row...row)
            return abs(mean.relativeLuminance - tone.relativeLuminance) < 0.006
        }
        #expect(flat.count >= 60, "the photograph's paper is flat for only \(flat.count) rows")
        let join = Int((TypewriterMetrics.rollerInsetFraction * CGFloat(image.height)).rounded())
        #expect(flat.contains(join))
    }

    private struct Sample {
        let color: SRGBColor
        let alpha: Double
    }

    private func mean(
        of pixels: [Sample], width: Int, x: ClosedRange<Int>, y: ClosedRange<Int>
    ) -> SRGBColor {
        var r = 0.0, g = 0.0, b = 0.0, n = 0.0
        for row in y {
            for column in x {
                let sample = pixels[row * width + column]
                r += sample.color.red; g += sample.color.green; b += sample.color.blue; n += 1
            }
        }
        return SRGBColor(red: r / n, green: g / n, blue: b / n)
    }

    /// Straight RGBA, top row first — the same orientation the metrics were measured in.
    private func readPixels(_ image: CGImage) -> [Sample]? {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 0, to: bytes.count, by: 4).map { i in
            let alpha = Double(bytes[i + 3]) / 255
            guard alpha > 0 else { return Sample(color: SRGBColor(hex: "#FFFFFF"), alpha: 0) }
            return Sample(
                color: SRGBColor(red: Double(bytes[i]) / 255 / alpha,
                                 green: Double(bytes[i + 1]) / 255 / alpha,
                                 blue: Double(bytes[i + 2]) / 255 / alpha),
                alpha: alpha)
        }
    }
}
