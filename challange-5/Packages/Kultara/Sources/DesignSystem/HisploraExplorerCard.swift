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
                                .foregroundStyle(palette.inkCream.color)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            // 49 × 3.945 in the frame, under the label rather than under the cell.
                            Capsule()
                                .fill(isSelected
                                      ? palette.inkCream.color
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
                .fill(palette.inkCream.color.opacity(0.25))
                .frame(height: KultaraMetrics.hairline)
        }
    }
}

// MARK: - The activity card

/// One completed activity on the Quests tab: a mark, a name, what it asked for, and a seal saying
/// it is done (`547:2727`).
public struct HisploraActivityCard<Mark: View>: View {
    @Environment(\.hisploraPalette) private var palette

    private let title: String
    private let detail: String
    private let isComplete: Bool
    private let completeLabel: String
    private let mark: Mark

    /// - Parameter completeLabel: what VoiceOver says for the seal. `DesignSystem` carries no
    ///   string table (`NFR-I18N-01`), so the caller localises it.
    public init(
        title: String,
        detail: String,
        isComplete: Bool,
        completeLabel: String,
        @ViewBuilder mark: () -> Mark
    ) {
        self.title = title
        self.detail = detail
        self.isComplete = isComplete
        self.completeLabel = completeLabel
        self.mark = mark()
    }

    public var body: some View {
        HStack(spacing: KultaraMetrics.md) {
            mark
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.inkDark.color)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(palette.inkBody.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isComplete {
                // Shape and text, never colour on its own (`NFR-A11Y-05`) — the seal is named to
                // VoiceOver by the label the caller supplies.
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(palette.brownDeep.color)
                    .accessibilityLabel(completeLabel)
            }
        }
        .padding(KultaraMetrics.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paperCream.color, in: RoundedRectangle(cornerRadius: 12))
    }
}

public extension HisploraActivityCard where Mark == EmptyView {
    init(title: String, detail: String, isComplete: Bool, completeLabel: String) {
        self.init(title: title, detail: detail, isComplete: isComplete,
                  completeLabel: completeLabel) { EmptyView() }
    }
}
