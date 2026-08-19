import SwiftUI

/// The typewriter on the story preview (Figma `81:588`): a sheet of paper standing out of a
/// machine, with the quest's hook typed onto it.
///
/// **How it is composed, and why not as the frame composes it.** The frame is one photograph with
/// an 8.5 pt text box positioned on top of it at fixed coordinates. Reproduced that way the hook is
/// unreadable at the default text size and runs off the paper at the first size above it, which is
/// exactly what `NFR-A11Y-01` and `NFR-A11Y-04` are about. So the photograph is cropped to the
/// *machine*, the sheet is drawn in code above it, and the two are stacked: the paper is then as
/// tall as its text needs, and the machine stays the size it is. At default size the join is where
/// the frame puts it; at AX5 the sheet has simply grown, which is what a longer page would do.
///
/// **Provenance.** The photograph is a generated image exported from the design file, where it is
/// named `ChatGPT Image Aug 10, 2026 at 11_49_39 AM`. It depicts an object and makes no claim about
/// anyone, so — like the gilded frame in `PortraitFrame.swift` — it is a licence question to answer
/// rather than an editorial one, recorded here so it stays answerable.
///
/// **The crest.** `35:431` on the Ngalcer board stands an object — there, the gilded portrait frame
/// — above the sheet so that its lower part disappears behind the paper. That is optional and takes
/// whatever the caller passes: the machine does not know a portrait from a seal, and the screen that
/// wants nothing above the page uses `init(sheet:)` and gets the layout it had.
public struct KultaraTypewriter<Crest: View, Sheet: View>: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let crest: Crest
    private let hasCrest: Bool
    private let sheet: Sheet

    /// How tall the crest came out. Read back so the overlap can be a *proportion* of it rather
    /// than a point value that only holds at one text size and one screen width.
    @State private var crestHeight: CGFloat = 0

    /// How tall the paper came out, and whether it has fed in yet. The machine is the fixed object
    /// on this screen and the paper is the moving one, so the rise is measured off the page rather
    /// than off a point value that would only be right at one text size.
    @State private var paperHeight: CGFloat = 0
    @State private var hasRisen = false

    /// The height of the window the page lives in — the space left once the machine has taken its
    /// own. Read back so a short page can rest on the roller instead of floating above it.
    @State private var windowHeight: CGFloat = 0

    /// How large the photograph came out. The roller line and the paper's centre are both fixed
    /// proportions of the image, so the two places that have to meet it — how far the page reaches
    /// down into the machine, and where its centre falls — are measured off this rather than
    /// guessed in points.
    @State private var machineHeight: CGFloat = 0
    @State private var machineWidth: CGFloat = 0

    /// No accessibility label: the machine is decoration and is hidden, and the sheet is real text
    /// that names itself. A label here would make VoiceOver read the furniture before the story.
    public init(@ViewBuilder sheet: () -> Sheet) where Crest == EmptyView {
        self.crest = EmptyView()
        self.hasCrest = false
        self.sheet = sheet()
    }

    /// With something standing over the top of the page. The crest names itself — it is real
    /// content, not furniture — so this initializer takes no label either.
    public init(@ViewBuilder crest: () -> Crest, @ViewBuilder sheet: () -> Sheet) {
        self.crest = crest()
        self.hasCrest = true
        self.sheet = sheet()
    }

    public var body: some View {
        // The machine is furniture bolted to the floor: it keeps its intrinsic height at the foot
        // of the stack, and everything that gives or takes space is above it. The page is the only
        // moving part — it feeds in on appear, and if it is taller than the window left for it, it
        // scrolls *inside* that window instead of pushing the machine off the screen.
        //
        // Still no `GeometryReader` around the stack: it has no intrinsic height, so a stack inside
        // one cannot be sized by its own content. `containerRelativeFrame` gives the sheet its
        // width as a fraction without taking the height away from the content.
        VStack(spacing: 0) {
            // Outside the scroll view, and drawn before it, so it stays where it is put while the
            // page moves past it — the crest is an object standing on the desk, not something
            // printed on the paper. Its negative bottom padding pulls the window up over its lower
            // half, which is the overlap `35:431` draws.
            crestBlock
            ScrollView(.vertical) {
                page
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onChange(of: proxy.size.height, initial: true) { _, height in
                                paperHeight = height
                                rise()
                            }
                    }
                }
                // Offset, not padding: the rise must not change what the scroll view thinks the
                // page measures, or feeding the paper in would jog the scroll position.
                .offset(y: riseOffset)
                // One frame at the resting position before the height is known would read as the
                // page blinking into place and then rising, which is the opposite of the motion.
                .opacity(paperWidth != nil && (paperHeight > 0 || reduceMotion) ? 1 : 0)
                // A page shorter than its window rests on the roller rather than floating at the
                // top of it. Written as a minimum height against the *window* — not
                // `defaultScrollAnchor`, which needs macOS 15 and would take the package's floor
                // up with it — so a page longer than the window still opens at its first line.
                .frame(maxWidth: .infinity, minHeight: windowHeight, alignment: .bottom)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: proxy.size.height, initial: true) { _, height in
                            windowHeight = height
                        }
                }
            }
            .clipped()
            // Pulled down onto the photographed paper, and drawn above it, so the two are one
            // sheet rather than two meeting at a seam. The inset is a proportion of the
            // photograph's height — it lands inside the flat field at rows 0…62 of 573, where the
            // photographed paper is exactly the colour the drawn one is filled with — so it holds
            // at every size the machine is drawn at.
            .padding(.bottom, -machineHeight * TypewriterMetrics.rollerInsetFraction)
            .zIndex(1)
            machine
        }
        .frame(maxWidth: .infinity)
    }

    /// The sheet itself, cut to the width of the paper standing in the photograph's roller and
    /// nudged onto its centre — the machine is photographed a few pixels off-centre, and a sheet
    /// centred on the *screen* meets it with a step down one edge.
    private var page: some View {
        sheet
            .padding(.top, TypewriterMetrics.paperTopMargin)
            .padding(.bottom, TypewriterMetrics.paperBottomMargin)
            .padding(.horizontal, TypewriterMetrics.paperSideMargin)
            // Measured off the machine, not off the container. The two are not the same width —
            // the stage insets the typewriter — and a sheet cut to a fraction of the *screen*
            // overhangs the paper it is supposed to be by exactly that inset.
            .frame(width: paperWidth ?? 0)
            .background(paper)
            // After the background, not before it. `.offset` shifts what it is applied to and
            // leaves the layout frame where it was, and `.background` places its content in that
            // *unshifted* frame — so with the offset on the inside the typed text moved onto the
            // photograph's centre line while the sheet it is typed on stayed on the screen's, and
            // the page sat about 4 pt left of the paper in the roller with its own margins uneven.
            .offset(x: machineWidth * TypewriterMetrics.paperCentreOffsetFraction)
    }

    /// The sheet's width: the width of the paper standing in the photograph's roller. `nil` until
    /// the machine has been measured, which is one frame, and the page is held invisible for it.
    private var paperWidth: CGFloat? {
        machineWidth > 0 ? machineWidth * TypewriterMetrics.paperWidthFraction : nil
    }

    /// How far below its resting place the page currently sits. Its own height, so it starts
    /// wholly out of sight behind the machine and arrives level — a sheet fed through a roller,
    /// not a card sliding in from off-screen.
    private var riseOffset: CGFloat {
        guard !reduceMotion, !hasRisen else { return 0 }
        return paperHeight
    }

    /// Feed the page in, once, and never under Reduce Motion — there the paper is simply already
    /// in the machine (`NFR-A11Y-05`). Nothing here gates content: the hook is legible at every
    /// point of the animation and complete before it starts.
    private func rise() {
        guard !hasRisen, paperHeight > 0 else { return }
        guard !reduceMotion else {
            hasRisen = true
            return
        }
        withAnimation(.easeOut(duration: TypewriterMetrics.riseDuration)) { hasRisen = true }
    }

    /// The crest, sized against the container the way the sheet is, then pulled down into the paper
    /// by its own measured height.
    ///
    /// The measurement is a `GeometryReader` in a `.background`, which participates in no layout
    /// decision — the note above is about *sizing the stack* from one, and this does not. The width
    /// comes from `containerRelativeFrame` and the height from the crest's own aspect ratio, so the
    /// negative padding cannot feed back into either.
    @ViewBuilder private var crestBlock: some View {
        if hasCrest {
            crest
                // Against the container, not against the measured machine. Feeding a measured
                // width back into a child of the same stack is a loop: with nothing measured yet
                // the crest takes its intrinsic width, that widens the stack, the wider stack
                // widens the machine, and the new measurement resizes the crest. It span the CPU
                // at 100% and froze the screen. Only the sheet — which sits inside a scroll view
                // and cannot widen anything — is sized off the photograph.
                .containerRelativeFrame(.horizontal, alignment: .center) { width, _ in
                    width * TypewriterMetrics.crestWidthFraction
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onChange(of: proxy.size.height, initial: true) { _, height in
                                crestHeight = height
                            }
                    }
                }
                .padding(.bottom, -crestHeight * TypewriterMetrics.crestOverlapFraction)
        }
    }

    /// The sheet: the photograph's own paper tone, flat.
    ///
    /// No shading at the foot any more. There used to be a short black gradient there, faking the
    /// falloff the photographed paper has as it runs into the machine — necessary while the drawn
    /// sheet was a different cream that had to be talked into meeting a different one. It is the
    /// same cream now, and the sheet hands over inside the photograph's *flat* field, so the
    /// falloff below the join is the photograph's own. Painting a second one on top of it only
    /// darkened the page twice.
    private var paper: some View {
        TypewriterMetrics.paperTone.color
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: TypewriterMetrics.paperCornerRadius,
                topTrailingRadius: TypewriterMetrics.paperCornerRadius))
    }

    @ViewBuilder private var machine: some View {
        if let image = TypewriterMetrics.machineImage {
            // Whole, and never cropped. It was cropped from the bottom for a while to buy the page
            // room, and a typewriter with its front lip off the screen reads as a mistake rather
            // than as a close crop. The room comes from the overlap instead: the sheet now runs
            // down over the machine's own paper stub, so those points are spent twice.
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onChange(of: proxy.size, initial: true) { _, size in
                                machineWidth = size.width
                                machineHeight = size.height
                            }
                    }
                }
                // The photograph carries about 9% of its own height as empty space under the
                // machine's feet. Most of that is given back to the page — the layout cannot see
                // that those points are blank, and a page that clips its own figures to hold empty
                // pixels is the wrong trade. What is left is the clearance over the action.
                .padding(.bottom, -machineHeight * TypewriterMetrics.machineFootReclaimed)
                .accessibilityHidden(true)
        } else {
            // A missing photograph must not take the hook with it — the same rule the portrait
            // frame and the route map follow. The paper simply ends.
            Color.clear.frame(height: 0)
        }
    }
}

public enum TypewriterMetrics {

    /// How wide the sheet is against the machine — the width of the paper actually standing in the
    /// photograph's roller, sampled off `typewriter.png` (720 × 573): its lit edges fall at x 143
    /// and x 594, so 452 of 720. The drawn sheet and the photographed one are the same sheet, and any other number puts
    /// a step down one edge of it.
    public static let paperWidthFraction: CGFloat = 452.0 / 720.0
    public static let paperCornerRadius: CGFloat = 6

    /// The margins typed onto the sheet. The top one is the deep one, because it is the head of a
    /// page: text starting a hair under the paper's edge reads as a label, not as something typed
    /// into a machine. The bottom is shallow — the page continues into the roller rather than
    /// ending, so a deep margin there is just a gap before the platen.
    ///
    /// **These four values and the three below are the whole geometry of the sheet.** Its size is
    /// `paperWidthFraction` (× the machine's width) and its height is whatever the margins plus the
    /// content come to; where it sits is `paperCentreOffsetFraction` across and
    /// `rollerInsetFraction` down.
    public static let paperTopMargin: CGFloat = 28
    public static let paperBottomMargin: CGFloat = 10
    public static let paperSideMargin: CGFloat = 12

    /// The photographed paper's centre is x 368.5 of 720 — eight and a half pixels right of the
    /// image's own centre. A sheet centred on the screen therefore meets it off by that much, so
    /// the drawn one is nudged the same way.
    public static let paperCentreOffsetFraction: CGFloat = (368.5 - 360.0) / 720.0

    /// Where the drawn sheet hands over to the photographed one: inside the photograph's flat
    /// field, which runs from row 0 to row 62 of 573 without moving a level. The drawn sheet is
    /// pulled down by this much of the machine's height and drawn over it, so the two meet at a
    /// row where they are the same colour — the seam is invisible because there is nothing to see,
    /// not because something is drawn over it. Below the join the paper shades into the machine's
    /// paper guide (rows 63…88) in the photograph's own light.
    ///
    /// Landing inside a 62-row flat field rather than on one exact row is the point: the sheet's
    /// bottom moves a little with the text size and the screen, and anywhere in that band the join
    /// still disappears.
    ///
    /// It was 105, which is *past* the guide and into the lit strip below it — so a band of
    /// photographed paper stood under the drawn sheet, in a different cream, which is what read as
    /// two sheets rather than one.
    public static let rollerInsetFraction: CGFloat = 62.0 / 573.0

    /// The transparent margin under the machine's feet — the art ends at y 523 of 573. It is the
    /// clearance between the machine and the action below, which is why nothing adds padding there.
    public static let machineTransparentFootFraction: CGFloat = (573.0 - 523.0) / 573.0

    /// How much of that margin is given back to the page. Two thirds: the rest is the gap that
    /// keeps the machine from growing out of the action below it.
    public static let machineFootReclaimed: CGFloat = machineTransparentFootFraction * 2.0 / 3.0

    /// How wide the crest is against the same container. `35:431` draws the framed portrait 180 pt
    /// wide over a machine photographed 302.4 pt wide; it is drawn at 150 here, because the crest's
    /// height is what it costs — every point of frame above the page is a point the page does not
    /// have, and the page has a sheet's worth of hook and two figures to hold. Still narrower than
    /// the paper, which is what makes it read as standing *on* the page rather than as a header
    /// above it.
    public static let crestWidthFraction: CGFloat = 150.0 / 302.376

    /// How much of the crest is behind the paper. On `35:431` the frame is drawn from y 226.5 to
    /// y 451.5 and the sheet's top edge falls at y ≈ 325, so a little over half of it is hidden.
    /// Held as a proportion rather than as points because the sheet's own top moves with the
    /// reader's text size, and a fixed offset would slide off it at the first size up.
    /// Deepened from the frame's own 0.56 on 2026-08-18: the machine is drawn whole now, and the
    /// height it takes back has to come from somewhere the page can spare it. The crest still
    /// stands above the paper — this is the proportion hidden, not the object shrunk.
    public static let crestOverlapFraction: CGFloat = 0.70
    /// The photograph's own paper, and what the drawn sheet is filled with. Sampled as the mean of
    /// the flat field in `typewriter.png` — x 165…575, y 5…60 — which reads `#E4D8CD` and does not
    /// move by a level anywhere from row 0 to row 62.
    ///
    /// The file carries no colour profile, so its bytes *are* sRGB and this is the number the
    /// screen shows. (Reading it through a converting API answers `#E9DFD6`, which is a
    /// measurement of the conversion rather than of the picture.)
    ///
    /// Deliberately not `paperCream`. The token is `#EEE7D2` — ten levels lighter and a step
    /// yellower: close enough to look like the obvious token to reach for, and far enough that the
    /// drawn half of the sheet and the photographed half read as two different papers. Every other
    /// Hisplora surface keeps the token; this one is matching a photograph, so it matches the
    /// photograph. `TypewriterTests` re-samples the file and fails if the two drift apart.
    public static let paperTone = SRGBColor(hex: "#E4D8CD")


    /// How long the page takes to feed in. Long enough to read as paper moving through a roller,
    /// short enough that it is over before the first typed character lands.
    public static let riseDuration: Double = 0.55

    /// How much of the screen the machine is allowed to take, top-cropped.
    ///
    /// Uncropped the photograph is about a third of a 402 × 874 screen, and the window left over
    /// for the page is then shorter than a full sheet — the distance and the duration end up behind
    /// the roller, which is the one thing on the page that must not be hidden. The roller, the
    /// carriage and most of the keyboard are above this line; what leaves the frame is the front
    /// lip.


    /// How much text one sheet holds.
    ///
    /// The machine no longer moves, so the page is a window rather than a column that can grow
    /// without limit — a passage that overruns it becomes a scroll inside a photograph, which is
    /// neither the frame's picture nor a good read. Content longer than this is trimmed for
    /// display only: nothing is edited, and every screen that shows the whole passage still does.
    public static let maximumSheetCharacters = 210

    /// A tail this short after the last paragraph break is dropped rather than kept — two or three
    /// words of a paragraph that goes nowhere read as damage, not as an ending.
    static let orphanParagraphCharacters = 48

    /// The passage as it is typed onto the sheet, cut to `maximumSheetCharacters`.
    ///
    /// Pure, so the rule is testable without a running view. The cut falls on a word boundary and
    /// takes an ellipsis, because a page that stops mid-word reads as a bug rather than as a
    /// deliberate ending — and if it lands a few words into a fresh paragraph, that stub goes too.
    public static func sheetText(_ text: String) -> String {
        guard text.count > maximumSheetCharacters else { return text }
        let head = text.prefix(maximumSheetCharacters - 1)
        var body = head.lastIndex(where: \.isWhitespace).map { head[..<$0] } ?? head
        if let paragraph = body.range(of: "\n\n", options: .backwards),
           body[paragraph.upperBound...].count <= orphanParagraphCharacters {
            body = body[..<paragraph.lowerBound]
        }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        // A cut that happens to land on a full stop needs no ellipsis: the page ends on a sentence,
        // and "kept.…" reads as a typing fault rather than as a passage continuing elsewhere.
        guard let last = trimmed.last, !".!?…".contains(last) else { return trimmed }
        return trimmed + "…"
    }

    static let machineImage: Image? = {
        #if canImport(UIKit)
        guard let url = machineURL,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)
        else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }()

    static var machineURL: URL? {
        Bundle.module.url(forResource: "typewriter", withExtension: "png", subdirectory: "Images")
    }

    /// Whether the packaged photograph resolved. Exposed for the same reason
    /// `PortraitFrameMetrics.ornamentIsAvailable` is: so a dropped resource fails a test rather
    /// than silently becoming a blank screen.
    public static var machineIsAvailable: Bool { machineURL != nil }
}
