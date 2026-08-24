import SwiftUI

/// Chrome for the trip-completion carousel — the "Strava-style" recap `WriteJournalScreen` →
/// `JourneySavedScreen` hands off into (Figma `205:121`, `205:151`, `205:205`, the "Ngalcer" file).
///
/// Set at the frames' own point sizes and literal colours rather than through `KultaraTypography`'s
/// roles or new palette tokens, the same trade `TripPageChrome.swift` records for the Journal's two
/// pages: the carousel reproduces three specific frames, and a handful of its colours (the stat
/// tiles' fills, the flat progress bar's two states) exist on this screen alone rather than as a
/// design decision that generalises. The ground itself is the exception — `HisploraPalette
/// .completionGroundTop`/`.completionGroundBottom` — because every page of the carousel stands on
/// it.

/// Paints the carousel's ground: a top-to-bottom gradient (unlike every other `HisploraStage`
/// caller, which stands on one flat token) with the same procedural grain the rest of the story
/// flow carries.
public struct HisploraCompletionStage<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let palette = HisploraPalette.standard
        _ = KultaraFonts.isAvailable
        return content
            .environment(\.hisploraPalette, palette)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    // The frame's gradient reaches its end colour at 86% of the height and
                    // holds it, rather than darkening all the way to the bottom edge.
                    LinearGradient(
                        stops: [
                            .init(color: palette.completionGroundTop.color, location: 0),
                            .init(color: palette.completionGroundBottom.color, location: 0.86),
                        ],
                        startPoint: .top, endPoint: .bottom)
                    // The lightest fleck, the same one every dark Hisplora ground picks — the
                    // gradient never rises above `KultaraSpeckle`'s 0.35 luminance split.
                    KultaraSpeckleField(fleck: KultaraSpeckle.lightFleck)
                }
                .ignoresSafeArea()
            }
    }
}

/// The carousel's page indicator (`205:144`, `205:198`, `205:248`) — five flat pill segments with no
/// well or border, unlike `HisploraSegmentedProgress`'s bordered task bar. A different object on a
/// different ground, so it is a second, smaller component rather than a parameter added to the
/// first: the task bar's well and border are load-bearing on `brownStone`, and drawing them here
/// would put a frame around something the design leaves bare.
///
/// **Story-style, not a flat step indicator.** Every segment before `currentPage` reads full, every
/// segment after reads empty, and `currentPage`'s own segment fills by `currentFill` — the caller
/// drives that from 0 to 1 over the page's on-screen duration, so the bar reads as counting down the
/// way Instagram's or WhatsApp's does, rather than jumping between two fixed states on each swipe.
public struct HisploraCompletionProgress: View {
    private let currentPage: Int
    private let total: Int
    private let currentFill: CGFloat
    private let accessibilityLabel: String

    /// `#AA9B8E` filled, `#41302A` unfilled — as drawn. Neither reader is used anywhere else in the
    /// story flow, so they stay literal here rather than becoming palette tokens two frames would
    /// have to share a meaning for.
    private static let filled = SRGBColor(hex: "#AA9B8E")
    private static let unfilled = SRGBColor(hex: "#41302A")

    public init(currentPage: Int, total: Int, currentFill: CGFloat, accessibilityLabel: String) {
        self.currentPage = currentPage
        self.total = total
        self.currentFill = currentFill
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                GeometryReader { geometry in
                    Capsule()
                        .fill(Self.unfilled.color)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Self.filled.color)
                                .frame(width: geometry.size.width * fraction(for: index))
                        }
                }
                .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func fraction(for index: Int) -> CGFloat {
        if index < currentPage { return 1 }
        if index == currentPage { return min(max(currentFill, 0), 1) }
        return 0
    }
}

/// One counter card on "Your Journey at A Glance" (`205:170`, `205:177`, `205:184`, `205:191`) — a
/// coloured tile with a grain overlay, an icon, a divider, and a label over a bold figure.
///
/// **Four fills, one per card, and none of them reused.** `TripStatTile` (the app target's Trip
/// Summary tile) is a single warm neutral repeated four times; this design instead colours each
/// card differently, so — unlike that tile — there is no one token to lean on and each fill stays a
/// literal `SRGBColor`, named for the frame it came from.
public struct HisploraCompletionStatTile: View {
    let systemImage: String
    let label: String
    let value: String
    let unit: String?
    let fill: SRGBColor
    let border: SRGBColor
    let ink: SRGBColor
    /// The frame draws tile 1's *text* a step darker (`#61301A`) than its icon (`#69311E`);
    /// `nil` keeps the icon's ink for everything, which is what the other three tiles do.
    let textInk: SRGBColor?

    public init(
        systemImage: String, label: String, value: String, unit: String? = nil,
        fill: SRGBColor, border: SRGBColor, ink: SRGBColor, textInk: SRGBColor? = nil
    ) {
        self.systemImage = systemImage
        self.label = label
        self.value = value
        self.unit = unit
        self.fill = fill
        self.border = border
        self.ink = ink
        self.textInk = textInk
    }

    public var body: some View {
        let text = textInk ?? ink
        return VStack(spacing: 0) {
            Image(systemName: systemImage)
                .font(.system(size: 45))
                .tracking(-1.36)
                .foregroundStyle(ink.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)

            Rectangle()
                .fill(border.color)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 15))
                    .tracking(-0.3)
                    .foregroundStyle(text.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 31, weight: .black, design: .serif))
                        .tracking(-0.93)
                        .foregroundStyle(text.color)
                    if let unit {
                        Text(unit)
                            .font(.system(size: 25))
                            .tracking(-0.93)
                            .foregroundStyle(text.color)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
        }
        .frame(height: 209)
        .background(fill.color)
        .overlay {
            // The `riso_texture` grain the frame washes every tile with — `mix-blend-multiply` over
            // a flat fill — reproduced with the same procedural field every other Hisplora ground
            // carries rather than a second bitmap import for one screen.
            KultaraSpeckleField(over: fill)
                .blendMode(.multiply)
                .opacity(0.6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(border.color, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unit.map { "\(label): \(value) \($0)" } ?? "\(label): \(value)")
    }
}
