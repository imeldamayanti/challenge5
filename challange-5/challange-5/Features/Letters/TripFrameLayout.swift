import DesignSystem
import SwiftUI

/// The two Journal pages are laid out in their Figma frame's own coordinates and scaled to the
/// screen, rather than composed out of stacks and spacers.
///
/// **That is a deliberate exception, and it is worth naming.** Every other screen in this app is
/// built to reflow: a `VStack` with tokens for spacing, type roles that scale with Dynamic Type,
/// and no absolute positions anywhere. `791:6414` and `791:6537` are not that kind of screen. They
/// are editorial pages — cut-outs tucked behind paragraphs at chosen angles, a portrait bleeding
/// off the left margin, an arrow drawn pointing at it, a band of dark paper the text sits inside.
/// Rebuilt as stacks they become *a* layout, not *this* layout, and the owner asked for this one.
///
/// So the page is drawn at the frame's 402-point width and scaled by `width / 402`. The trade is
/// explicit: **the page does not respond to Dynamic Type.** It scales as a picture does. The two
/// controls on it — the back chevron and the scroll itself — are outside the canvas and behave
/// normally, and the whole canvas carries a spoken description so a reader who cannot see it still
/// gets the text. If that trade ever stops being acceptable, the fix is not to patch this file: it
/// is to go back to the reflowing version in this file's history.
enum TripFrame {
    /// The frames' own width. Every coordinate in the two pages is in these points.
    static let width: CGFloat = 402
    /// The frames draw their own status bar at the top; the app has a real one, so the canvas is
    /// shifted up by its height and every `y` below is the frame's own minus this.
    static let statusBar: CGFloat = 62
}

extension View {
    /// Place a view at the frame's own coordinates, inside a `ZStack(alignment: .topLeading)`.
    ///
    /// A rotated layer is placed by the box Figma reports for it — which is the box the rotation
    /// swept out, not the drawing — so the caller passes that box with `.center` alignment and
    /// rotates the child inside it.
    func framePlaced(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        alignment: Alignment = .topLeading
    ) -> some View {
        frame(width: width, height: height, alignment: alignment)
            .offset(x: x, y: y)
    }
}

/// One band of a page: a fixed-height box in frame coordinates that clips whatever overhangs it.
///
/// The frames are built this way — each section is an `overflow-clip` frame with cut-outs hanging
/// off both edges — and reproducing the clip is what stops a sticker drawn at `x: -64` from
/// widening the page.
struct TripFrameBand<Content: View>: View {
    private let height: CGFloat
    private let background: SRGBColor?
    private let content: Content

    /// - Parameter background: the band's ground **as a token, not a `Color`**, because the ground
    ///   is the token *plus* its speckle — `kultaraSpeckledGround` is the one place that ordering
    ///   is decided, and a band that painted the flat colour instead would be the one rectangle on
    ///   the page without the grain every other Hisplora screen has. `nil` for a band the artwork
    ///   covers edge to edge.
    init(height: CGFloat, background: SRGBColor? = nil, @ViewBuilder content: () -> Content) {
        self.height = height
        self.background = background
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let background {
                Color.clear
                    .frame(width: TripFrame.width, height: height)
                    .kultaraSpeckledGround(background)
            } else {
                Color.clear.frame(width: TripFrame.width, height: height)
            }
            content
        }
        .frame(width: TripFrame.width, height: height, alignment: .topLeading)
        .clipped()
    }
}

/// A speckled block of one token, for the parts of a page that are a flat ground rather than a
/// band — the dark rectangle inside `791:6564`, and each half of `TripPageGround`.
struct TripFrameGround: View {
    let token: SRGBColor

    var body: some View {
        Color.clear.kultaraSpeckledGround(token)
    }
}

/// A run of text set exactly as the frame sets it: point size, weight, face, tracking and line
/// height, with no Dynamic Type scaling.
///
/// `lineHeight` is the frame's own multiple. SwiftUI's `lineSpacing` is *added* to the font's
/// natural line height, so the multiple is converted here rather than at every call site — and
/// `leading-none` comes out negative, which is what the frames' mastheads are set solid at.
struct TripFrameText: View {
    let text: String
    var size: CGFloat
    var weight: Font.Weight = .regular
    var design: Font.Design = .default
    var italic: Bool = false
    var tracking: CGFloat = 0
    /// The frame's line-height multiple. `1.0` is Figma's `leading-none`.
    var lineHeight: CGFloat = 1.0
    var color: Color
    var alignment: TextAlignment = .leading

    /// SF Pro and New York both sit at roughly 1.19 × point size of natural line height at these
    /// sizes, which is what the multiple has to be measured against.
    private var naturalLineHeight: CGFloat { size * 1.19 }

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight, design: design).italic(italic))
            .tracking(tracking)
            .lineSpacing(size * lineHeight - naturalLineHeight)
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension Font {
    func italic(_ isItalic: Bool) -> Font { isItalic ? self.italic() : self }
}

/// The whole page: a fixed-width canvas scaled to whatever width it is given, inside a scroll view.
struct TripFramePage<Content: View>: View {
    private let height: CGFloat
    private let accessibilityText: String
    private let topGround: SRGBColor
    private let bottomGround: SRGBColor
    private let content: Content

    /// - Parameters:
    ///   - topGround: the token the page's first band is on.
    ///   - bottomGround: the token its last band is on.
    ///
    ///   The two exist because **a scroll view overscrolls past its content and shows whatever is
    ///   behind it** — a rubber-band at the foot printed a cream strip under the closing band.
    ///   They are painted by `overscrollBleed`, which hangs them off the *content*, above and below
    ///   it. A half-and-half ground behind the scroll view was tried and is wrong for a reason
    ///   worth remembering: anything behind the viewport is fixed to the viewport, so it slides
    ///   under the page as the page scrolls, and every part of the content that is not itself
    ///   opaque changes colour mid-scroll.
    init(
        height: CGFloat,
        accessibilityText: String,
        topGround: SRGBColor,
        bottomGround: SRGBColor,
        @ViewBuilder content: () -> Content
    ) {
        self.height = height
        self.accessibilityText = accessibilityText
        self.topGround = topGround
        self.bottomGround = bottomGround
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / TripFrame.width
            ScrollView {
                ZStack(alignment: .topLeading) {
                    Color.clear.frame(width: TripFrame.width, height: height)
                    content
                }
                .frame(width: TripFrame.width, height: height, alignment: .topLeading)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: proxy.size.width, height: height * scale, alignment: .topLeading)
                .overscrollBleed(top: topGround, bottom: bottomGround)
                // The canvas is one picture to the layout engine and one passage to a reader who
                // cannot see it. Every word on the page is in this label, in reading order.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText)
            }
            .scrollIndicators(.hidden)
        }
    }
}

extension View {
    /// Hangs a ground above and below this view, outside its own bounds.
    ///
    /// **Attached to the scrolling content, never behind the scroll view.** A background on the
    /// scroll view is fixed to the viewport: it slides under the page as the page moves, so a
    /// two-tone one repaints whatever part of the content is not itself opaque — which on the Trip
    /// Summary meant the counters changed ground halfway down a scroll. Hung off the content, each
    /// bleed travels with the end it belongs to and is only ever seen while that end is being
    /// pulled away from.
    ///
    /// `.background` does not affect layout and does not clip, so neither rectangle adds scrollable
    /// height; the scroll view's own clip is what hides them until a rubber-band reveals one.
    func overscrollBleed(top: SRGBColor, bottom: SRGBColor, depth: CGFloat = 700) -> some View {
        background(alignment: .top) {
            TripFrameGround(token: top).frame(height: depth).offset(y: -depth)
        }
        .background(alignment: .bottom) {
            TripFrameGround(token: bottom).frame(height: depth).offset(y: depth)
        }
    }
}
