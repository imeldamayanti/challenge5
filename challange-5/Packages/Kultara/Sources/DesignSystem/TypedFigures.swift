import SwiftUI

/// One figure ruled onto the typed sheet: a value, and optionally the name of what it measures.
///
/// The label is a plain `String` and optional for the same reason every other `DesignSystem` type
/// takes plain strings — the package has no localisation table, and the caller is the only thing
/// that knows the reader's language (`NFR-I18N-01`). Optional because the board draws it both ways:
/// `35:431` names the two figures, `35:455` lets the units speak for themselves.
public struct KultaraTypedFigure: Sendable, Hashable, Identifiable {
    public let label: String?
    public let value: String

    /// Both halves, because two figures can share a label ("Distance") across screens and two can
    /// share a value ("2.2 km") within one.
    public var id: String { "\(label ?? "")\u{1F}\(value)" }

    public init(label: String? = nil, value: String) {
        self.label = label
        self.value = value
    }
}

/// The figures ruled off beneath the hook on the typed sheet — `35:431`'s "Distance / 2.2 Km" and
/// "Estimated Time / 1.5 Hours", and `177:801`'s unlabelled pair before it.
///
/// A rule across the page, then the figures in a row with a rule standing between each pair. Takes
/// any number of them: two is what both boards draw, but nothing here counts.
public struct KultaraTypedFigures: View {
    @Environment(\.hisploraPalette) private var palette

    private let figures: [KultaraTypedFigure]

    public init(_ figures: [KultaraTypedFigure]) {
        self.figures = figures
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            rule.frame(height: KultaraMetrics.hairline)
            // A row at the default size, a column once the figures no longer fit beside each
            // other. `ViewThatFits` rather than a fixed `HStack`, for the reason every other row
            // in this app uses it: at AX5 two figures side by side become two columns of letters.
            ViewThatFits(in: .horizontal) {
                row
                column
            }
        }
    }

    private var row: some View {
        // `md`, not `lg`: the sheet is cut to the width of the paper in the typewriter's roller,
        // and at `lg` the pair falls to `column` there — which is twice as tall and pushes the
        // second figure off the page.
        HStack(spacing: KultaraMetrics.md) {
            ForEach(Array(figures.enumerated()), id: \.element.id) { index, figure in
                if index > 0 {
                    // Not `Divider()`: that is a horizontal hairline in the separator colour, and
                    // this is a ruled pen line on paper standing between two columns.
                    rule
                        .frame(width: KultaraMetrics.hairline)
                        .frame(maxHeight: .infinity)
                }
                cell(figure)
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            ForEach(figures) { cell($0) }
        }
    }

    /// A figure and its name. The name is set in the sans at caption size, not in the typebar face:
    /// on the sheet it is apparatus rather than something typed, and the same split — serif names,
    /// sans informs — is what `KultaraTypography` applies everywhere else.
    private func cell(_ figure: KultaraTypedFigure) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
            if let label = figure.label {
                Text(label)
                    .kultaraFont(.caption)
                    // The frame sets this grey at `#727272`, which measures 3.5:1 on the paper and
                    // does not clear WCAG 1.4.3 for body text. `inkMuted` is the palette's measured
                    // stand-in — the deviation `docs/hisplora-tokens.md` records for this token.
                    .foregroundStyle(palette.inkMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(figure.value)
                .kultaraFont(.typedFigure)
                .foregroundStyle(palette.inkDark.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        // The label and its figure are one thing to a VoiceOver reader — "Distance, 2.2 km" — not
        // two stops that have to be held together by the reader.
        .accessibilityElement(children: .combine)
    }

    private var rule: some View {
        Rectangle()
            .fill(palette.inkDark.color.opacity(0.35))
            .accessibilityHidden(true)
    }
}
