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
public struct KultaraTypewriter<Sheet: View>: View {
    @Environment(\.hisploraPalette) private var palette

    private let sheet: Sheet

    /// No accessibility label: the machine is decoration and is hidden, and the sheet is real text
    /// that names itself. A label here would make VoiceOver read the furniture before the story.
    public init(@ViewBuilder sheet: () -> Sheet) {
        self.sheet = sheet()
    }

    public var body: some View {
        // No `GeometryReader`. It has no intrinsic height, so a stack inside one cannot be sized by
        // its own content — the sheet grows with the reader's text size, and the machine has to be
        // pushed down by exactly that much. `containerRelativeFrame` gives the sheet its width as a
        // fraction without taking the height away from the content.
        VStack(spacing: 0) {
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
