import SwiftUI

/// The chrome of the Explorer's Card (Figma `547:2724`, `547:2848`, `547:2952`): the gilded
/// roundel the reader's portrait sits in, the three-way tab strip beneath it, and the cream card a
/// completed activity is listed on.

// MARK: - The roundel

/// The circular gilded frame at the head of the card.
///
/// A sibling of `KultaraPortraitFrame` rather than a reuse of it: that one is an *oval* frame cut
/// 360 × 450, and it is measured into the cutscene's sheet. This one is round, and the profile sets
/// it 150 × 150. The provenance note on `PortraitFrame.swift` applies here word for word — the
/// ornament is a generated image and depicts nothing, and what is placed inside it is the caller's
/// to justify.
public struct HisploraExplorerRoundel<Portrait: View>: View {
    @Environment(\.hisploraPalette) private var palette

    private let accessibilityLabel: String
    private let portrait: Portrait

    public init(accessibilityLabel: String, @ViewBuilder portrait: () -> Portrait) {
        self.accessibilityLabel = accessibilityLabel
        self.portrait = portrait()
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                portrait
                    .frame(width: size.width * HisploraExplorerRoundelMetrics.openingRatio,
                           height: size.height * HisploraExplorerRoundelMetrics.openingRatio)
                    .clipShape(Circle())
                ornament(size: size)
            }
            .frame(width: size.width, height: size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder private func ornament(size: CGSize) -> some View {
        if let image = HisploraExplorerRoundelMetrics.ornamentImage {
            // Fitted to the square the frame sets it in. The export is an oval frame 447 × 558 and
            // `547:2977` places it in a 150 × 150 box at 109.24% × 106.38% — the design fills the
            // square with it, and a version that preserved the export's ratio would leave the
            // roundel visibly narrower than the frame draws it.
            image
                .resizable()
                .frame(width: size.width, height: size.height)
                .accessibilityHidden(true)
        } else {
            Circle()
                .stroke(palette.buttonRing.color, lineWidth: 3)
                .frame(width: size.width * HisploraExplorerRoundelMetrics.openingRatio,
                       height: size.height * HisploraExplorerRoundelMetrics.openingRatio)
                .accessibilityHidden(true)
        }
    }
}

public enum HisploraExplorerRoundelMetrics {
    /// The opening is 117.273 across a 150 point frame.
    public static let openingRatio: CGFloat = 117.273 / 150.0

    public static let ornamentImage: Image? = HisploraWaxSealMetrics.image(named: "explorer-frame")

    public static var isAvailable: Bool {
        HisploraWaxSealMetrics.url(named: "explorer-frame") != nil
    }
}

// MARK: - The tab strip

/// The Quests / Stamps / Badges strip, ruled off from what it selects (`547:2787`).
///
/// The selected tab is set semibold *and* carries the cream underline: two signals, because colour
/// and rule alone would leave the state resting on one (`NFR-A11Y-05`). It is a real
/// `accessibilityElement` per tab with `.isSelected`, not three buttons a reader has to infer a
/// group from.
public struct HisploraTabStrip<Tab: Hashable & Identifiable>: View {
    @Environment(\.hisploraPalette) private var palette

    private let tabs: [Tab]
    private let title: (Tab) -> String
    @Binding private var selection: Tab

    public init(tabs: [Tab], selection: Binding<Tab>, title: @escaping (Tab) -> String) {
        self.tabs = tabs
        self._selection = selection
        self.title = title
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    let isSelected = tab == selection
                    Button {
                        selection = tab
                    } label: {
                        VStack(spacing: KultaraMetrics.sm) {
                            Text(title(tab))
                                .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(palette.inkDark.color)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            // 49 × 3.945 in the frame, under the label rather than under the cell.
                            Capsule()
                                .fill(isSelected
                                      ? palette.inkDark.color
                                      : Color.clear)
                                .frame(width: 49, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: KultaraMetrics.minimumTapTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            Rectangle()
                .fill(palette.inkDark.color.opacity(0.25))
                .frame(height: KultaraMetrics.hairline)
        }
    }
}

// MARK: - The filter chips

/// A one-line filter over the list beneath it — All / Unfinished / Done on the Quests tab.
///
/// **Not in any frame, and a sibling of `HisploraTabStrip` rather than a second one.** The strip
/// above switches *surfaces* and is drawn as ruled labels; this switches what one surface is
/// listing, so it is drawn as chips — two controls that look alike would say the two do the same
/// thing. Selected state is a fill *and* a weight, never colour alone (`NFR-A11Y-05`), and each
/// chip carries `.isSelected` rather than leaving a reader to infer the group.
public struct HisploraFilterChips<Option: Hashable & Identifiable>: View {
    @Environment(\.hisploraPalette) private var palette

    private let options: [Option]
    private let title: (Option) -> String
    @Binding private var selection: Option

    public init(options: [Option], selection: Binding<Option>, title: @escaping (Option) -> String) {
        self.options = options
        self._selection = selection
        self.title = title
    }

    public var body: some View {
        // Centred under the strip: the chips are a control for the list below them and not a
        // heading of it, and a short row of three pushed to one edge reads as the head of a column
        // that is not there.
        HStack(spacing: KultaraMetrics.sm) {
            Spacer(minLength: 0)
            ForEach(options) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected
                                         ? palette.inkOnButton.color
                                         : palette.inkBody.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, KultaraMetrics.md)
                        .padding(.vertical, KultaraMetrics.sm)
                        .background(isSelected ? palette.buttonFill.color : palette.paperRow.color,
                                    in: Capsule())
                        .overlay(
                            Capsule().stroke(palette.brownMid.color.opacity(isSelected ? 0 : 0.5),
                                             lineWidth: KultaraMetrics.hairline))
                        .frame(minHeight: KultaraMetrics.minimumTapTarget)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - The activity card

/// One walk on the Quests tab: what it was called, a line saying where it stands, and the mark that
/// stands for it (`705:2827`).
///
/// **A ruled row on white, not a rounded cream card.** `705:2824` redraws this object: the fill is
/// a white wash over the card's own sheet (`paperRow`), the boundary is a hairline of `brownMid`
/// rather than a corner radius, and the mark moves from the head of the row to its foot-right,
/// where the frame franks it with the wax seal a finished walk earns.
public struct HisploraActivityCard<Mark: View>: View {
    @Environment(\.hisploraPalette) private var palette

    private let title: String
    private let detail: String
    private let detailEmphasis: String?
    private let markLabel: String?
    private let mark: Mark

    /// - Parameter detailEmphasis: the tail of the detail line, set a weight up — the frame prints
    ///   "You completed this quest at **Badung**", and the place is the half of that sentence a
    ///   reader is actually scanning for. Joined with a space rather than interpolated, so no
    ///   string in the table has to carry a trailing one.
    /// - Parameter markLabel: what VoiceOver calls the mark. `nil` — the shipped case — hides it,
    ///   because the seal repeats what the detail line already says in words and the row is one
    ///   element. `DesignSystem` carries no string table (`NFR-I18N-01`), so a caller that does
    ///   have something else to say localises it.
    public init(
        title: String,
        detail: String,
        detailEmphasis: String? = nil,
        markLabel: String? = nil,
        @ViewBuilder mark: () -> Mark
    ) {
        self.title = title
        self.detail = detail
        self.detailEmphasis = detailEmphasis
        self.markLabel = markLabel
        self.mark = mark()
    }

    public var body: some View {
        HStack(spacing: KultaraMetrics.md) {
            VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.inkTicket.color)
                    .fixedSize(horizontal: false, vertical: true)
                detailLine
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(palette.inkBody.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, KultaraMetrics.xs)
            .frame(maxWidth: .infinity, alignment: .leading)

            markView
        }
        .padding(KultaraMetrics.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paperRow.color)
        // Square, and drawn as a boundary rather than a shadow — the frame rules these rows off
        // from a sheet they are only a shade lighter than, so losing the rule loses the row.
        .overlay(
            Rectangle()
                .stroke(palette.brownMid.color.opacity(0.5), lineWidth: KultaraMetrics.hairline))
    }

    private var detailLine: Text {
        guard let detailEmphasis, !detailEmphasis.isEmpty else { return Text(detail) }
        return Text(detail) + Text(" ") + Text(detailEmphasis).fontWeight(.medium)
    }

    @ViewBuilder private var markView: some View {
        let size = HisploraWaxSealMetrics.questSealSize
        mark
            .frame(width: size.width, height: size.height)
            .modifier(MarkLabel(label: markLabel))
    }
}

/// Names the mark to VoiceOver, or takes it out of the tree. A modifier rather than two branches in
/// the body so the mark is one view in both cases.
private struct MarkLabel: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label)
        } else {
            content.accessibilityHidden(true)
        }
    }
}

public extension HisploraActivityCard where Mark == EmptyView {
    init(title: String, detail: String, detailEmphasis: String? = nil) {
        self.init(title: title, detail: detail, detailEmphasis: detailEmphasis) { EmptyView() }
    }
}

/// The wax seal a finished walk is franked with (`737:3971`), or a ruled disc when the export is
/// not packaged — the fallback every drawn object in this module carries, so a dropped resource
/// costs the picture rather than the row.
public struct HisploraQuestSeal: View {
    @Environment(\.hisploraPalette) private var palette

    public init() {}

    public var body: some View {
        if let seal = HisploraWaxSealMetrics.questSeal {
            seal.resizable().aspectRatio(contentMode: .fit)
        } else {
            Circle()
                .fill(palette.brownDeep.color)
                .overlay(Circle().stroke(palette.buttonRing.color,
                                         lineWidth: KultaraMetrics.hairline))
        }
    }
}
