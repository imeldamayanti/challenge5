import SwiftUI

/// The furniture of the Home design: the search field, the button that swaps the list for the map,
/// the floating tab bar, and the label style the illustrated map draws over its own artwork.
///
/// They are here rather than in the screen because each one has a measured contrast claim or a tap
/// target attached to it, and both are properties of the component rather than of the layout that
/// happens to use it.

// MARK: - Search

/// The pill search field. A `TextField` on a raised surface with a hairline, not a system search
/// bar: the system bar brings its own font, its own fill and its own cancel button, none of which
/// belong to this theme.
public struct KultaraSearchField: View {
    @Environment(\.kultaraPalette) private var palette

    private let placeholder: String
    /// Supplied by the caller, like every other string here: `DesignSystem` has no localisation
    /// table, and a hardcoded English "Clear" is exactly the leak `NFR-I18N-01` forbids.
    private let clearLabel: String
    @Binding private var text: String

    public init(placeholder: String, clearLabel: String, text: Binding<String>) {
        self.placeholder = placeholder
        self.clearLabel = clearLabel
        _text = text
    }

    public var body: some View {
        HStack(spacing: KultaraMetrics.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(palette.inkMuted.color)
                .accessibilityHidden(true)

            // The placeholder is drawn rather than left to `TextField`'s own, which renders in the
            // system's secondary grey — a colour this theme has never measured.
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(palette.inkMuted.color)
                }
                // `textInputAutocapitalization` is iOS-only and the package builds for macOS in
                // test, so the capitalisation setting is conditional rather than the field.
                textField
                    .foregroundStyle(palette.ink.color)
                    .autocorrectionDisabled()
            }
            .kultaraFont(.body)

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(palette.inkMuted.color)
                        .kultaraTapTarget()
                }
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, KultaraMetrics.lg)
        .frame(minHeight: KultaraMetrics.minimumTapTarget)
        // The Ngalcer frame draws the pill as a clean white shape lifted off the sheet rather than
        // ruled onto it (`28:168`), so the hairline gives way to the same soft shadow the masthead
        // button carries. The fill is still a measured token; only the edge treatment changed.
        .background(palette.paperRaised.color, in: Capsule())
        .shadow(color: palette.photoScrim.color.opacity(0.10), radius: 6, y: 2)
        .accessibilityLabel(placeholder)
    }

    @ViewBuilder private var textField: some View {
        #if os(iOS)
        TextField("", text: $text)
            .textInputAutocapitalization(.never)
        #else
        TextField("", text: $text)
        #endif
    }
}

/// The round button the Home masthead carries beside the title (`28:173`) — the one that swaps the
/// list for the illustrated region map.
///
/// The frame draws it as Apple's Liquid Glass symbol button. There is no glass here: the deployment
/// floor is iOS 18, and a material over an opaque cream sheet reads as the sheet anyway. What it is
/// instead is the theme's raised stock, a hairline, and a soft lift — which is what the frame's
/// glass resolves to visually on this ground, and which keeps the glyph measured against a token
/// rather than against whatever the blur happens to pick up (`NFR-A11Y-03`).
///
/// The caller decides whether it appears at all: when content ships no region map the button is
/// simply absent rather than present and inert.
public struct MapSurfaceButton: View {
    @Environment(\.kultaraPalette) private var palette

    private let symbolName: String
    private let label: String
    private let action: () -> Void

    public init(symbolName: String = "map.fill", label: String, action: @escaping () -> Void) {
        self.symbolName = symbolName
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(palette.seal.color)
                .frame(width: KultaraMetrics.circleButtonSize,
                       height: KultaraMetrics.circleButtonSize)
                .background(palette.paperRaised.color, in: Circle())
                .overlay(Circle().stroke(palette.rule.color, lineWidth: KultaraMetrics.hairline))
                .shadow(color: palette.photoScrim.color.opacity(0.12), radius: 6, y: 2)
                .contentShape(Circle())
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Tab bar

/// One destination in the floating bar.
public struct KultaraTab: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let symbolName: String

    public init(id: String, title: String, symbolName: String) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
    }
}

/// The floating pill from the Home design, drawn rather than taken from `TabView`.
///
/// Two things make it worth the hand-rolling: the system bar cannot be given this theme's face or
/// its raised stock, and a floating bar hides content underneath itself unless the scroll view
/// knows about it — so the bar publishes its own height and the list pads its last card by that
/// much. Selection is carried by the label's weight and its symbol fill as well as by the seal
/// red, because `NFR-A11Y-05` forbids colour carrying it alone.
public struct KultaraTabBar: View {
    @Environment(\.kultaraPalette) private var palette

    private let tabs: [KultaraTab]
    @Binding private var selection: String

    public init(tabs: [KultaraTab], selection: Binding<String>) {
        self.tabs = tabs
        _selection = selection
    }

    public var body: some View {
        HStack(spacing: KultaraMetrics.xs) {
            ForEach(tabs) { tab in
                let isSelected = tab.id == selection
                Button { selection = tab.id } label: {
                    VStack(spacing: 2) {
                        Image(systemName: isSelected ? "\(tab.symbolName).fill" : tab.symbolName)
                            .imageScale(.medium)
                        Text(tab.title)
                            .kultaraFont(.chipLabel)
                            .fontWeight(isSelected ? .semibold : .regular)
                    }
                    .foregroundStyle(isSelected ? palette.seal.color : palette.inkMuted.color)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: KultaraMetrics.minimumTapTarget)
                    .contentShape(Rectangle())
                }
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, KultaraMetrics.sm)
        // A minimum rather than a height: at an accessibility size the labels are taller than 64
        // points, and a fixed frame would clip them or push them out of the capsule.
        .frame(minHeight: 64)
        .background(palette.paperRaised.color, in: Capsule())
        .overlay(Capsule().stroke(palette.rule.color, lineWidth: KultaraMetrics.hairline))
        .padding(.horizontal, KultaraMetrics.xxl)
        .padding(.bottom, KultaraMetrics.sm)
    }
}

// MARK: - Map labels

/// A place's name written on the map itself, as the reference draws it: the display serif in the
/// light ink, with a dark outline behind it.
///
/// The outline is four offset copies rather than a shadow. A shadow is soft and its contrast
/// against a parchment coastline is not a number anyone can state; a hard outline in the scrim
/// colour means the ink is measured against the outline it always sits on, which is what
/// `NFR-A11Y-03` asks for over an arbitrary background.
public struct MapPlaceLabel: View {
    @Environment(\.kultaraPalette) private var palette

    private let text: String
    private let width: CGFloat

    public init(_ text: String, width: CGFloat = 150) {
        self.text = text
        self.width = width
    }

    public var body: some View {
        let outline = palette.photoScrim.color
        ZStack {
            ForEach(Array(offsets.enumerated()), id: \.offset) { _, offset in
                label
                    .foregroundStyle(outline)
                    .offset(x: offset.x, y: offset.y)
            }
            label.foregroundStyle(palette.inkOnPhoto.color)
        }
        .frame(maxWidth: width)
        .accessibilityHidden(true)
    }

    private var offsets: [CGPoint] {
        [CGPoint(x: -1.5, y: 0), CGPoint(x: 1.5, y: 0),
         CGPoint(x: 0, y: -1.5), CGPoint(x: 0, y: 1.5),
         CGPoint(x: -1.5, y: -1.5), CGPoint(x: 1.5, y: -1.5),
         CGPoint(x: -1.5, y: 1.5), CGPoint(x: 1.5, y: 1.5)]
    }

    private var label: some View {
        Text(text)
            .kultaraFont(.questTitle)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
