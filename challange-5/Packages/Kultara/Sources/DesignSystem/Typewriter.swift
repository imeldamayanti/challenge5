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

    private let crest: Crest
    private let hasCrest: Bool
    private let sheet: Sheet

    /// How tall the crest came out. Read back so the overlap can be a *proportion* of it rather
    /// than a point value that only holds at one text size and one screen width.
    @State private var crestHeight: CGFloat = 0

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
        // No `GeometryReader`. It has no intrinsic height, so a stack inside one cannot be sized by
        // its own content — the sheet grows with the reader's text size, and the machine has to be
        // pushed down by exactly that much. `containerRelativeFrame` gives the sheet its width as a
        // fraction without taking the height away from the content.
        VStack(spacing: 0) {
            // Drawn first, so the paper draws over it. That is the order the frame has: the
            // ornament's lower half is behind the sheet, not in front of it.
            crestBlock
            sheet
                .padding(.horizontal, KultaraMetrics.lg)
                .padding(.vertical, KultaraMetrics.lg)
                .containerRelativeFrame(.horizontal, alignment: .center) { width, _ in
                    width * TypewriterMetrics.paperWidthFraction
                }
                .background(paper)
            machine
        }
        .frame(maxWidth: .infinity)
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

    /// The sheet: the paper's own cream, closing into the tone the photograph's paper actually has
    /// where the two meet, so the join reads as one sheet in changing light rather than as two
    /// rectangles. The darker end is the photograph's `#E4D8CC`, reached by shading the token
    /// rather than by adding a second paper colour nothing else would use.
    private var paper: some View {
        palette.paperCream.color
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, .black.opacity(TypewriterMetrics.joinShade)],
                    startPoint: .top, endPoint: .bottom)
                    .frame(height: TypewriterMetrics.joinHeight)
            }
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: TypewriterMetrics.paperCornerRadius,
                topTrailingRadius: TypewriterMetrics.paperCornerRadius))
    }

    @ViewBuilder private var machine: some View {
        if let image = TypewriterMetrics.machineImage {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .accessibilityHidden(true)
        } else {
            // A missing photograph must not take the hook with it — the same rule the portrait
            // frame and the route map follow. The paper simply ends.
            Color.clear.frame(height: 0)
        }
    }
}

public enum TypewriterMetrics {

    /// How wide the sheet is against the machine, measured off the photograph: the paper spans
    /// roughly 0.17…0.86 of the image's width, and the frame's own text column sits inside that.
    public static let paperWidthFraction: CGFloat = 0.66
    public static let paperCornerRadius: CGFloat = 6

    /// How wide the crest is against the same container, from `35:431`: the framed portrait is
    /// drawn 180 pt wide over a machine photographed 302.4 pt wide. Narrower than the paper, which
    /// is what makes it read as standing *on* the page rather than as a header above it.
    public static let crestWidthFraction: CGFloat = 180.0 / 302.376

    /// How much of the crest is behind the paper. On `35:431` the frame is drawn from y 226.5 to
    /// y 451.5 and the sheet's top edge falls at y ≈ 325, so a little over half of it is hidden.
    /// Held as a proportion rather than as points because the sheet's own top moves with the
    /// reader's text size, and a fixed offset would slide off it at the first size up.
    public static let crestOverlapFraction: CGFloat = (451.5 - 325.0) / 224.93
    /// The photograph's paper reads `#E4D8CC` at the join against the token's `#EEE7D2` — about a
    /// 4.5% shade, applied as a short gradient rather than as a hard edge.
    static let joinShade: CGFloat = 0.045
    static let joinHeight: CGFloat = 28

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
