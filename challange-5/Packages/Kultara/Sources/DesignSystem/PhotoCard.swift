import SwiftUI

/// A photograph with text laid over its lower edge — the discovery card from the Home design.
///
/// The text sits on `photoScrim` at full opacity and the gradient above it is decoration, because
/// `NFR-A11Y-03` cannot be satisfied against an arbitrary image: a ratio measured against "whatever
/// the photo happens to be" is not a measurement. This is what makes the numbers in
/// `PhotoScrimTests` true of the rendered card and not only of the palette.
public struct PhotoScrim: View {
    @Environment(\.kultaraPalette) private var palette

    /// How much of the card's height the gradient covers before reaching full opacity.
    private let height: CGFloat

    public init(height: CGFloat = 190) {
        self.height = height
    }

    public var body: some View {
        LinearGradient(
            stops: [
                .init(color: palette.photoScrim.color.opacity(0), location: 0),
                .init(color: palette.photoScrim.color.opacity(0.55), location: 0.45),
                .init(color: palette.photoScrim.color, location: 0.8),
                .init(color: palette.photoScrim.color, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom)
            .frame(height: height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The circular arrow the design puts on the corner of each card. Filled seal, so its label is
/// measured against `sealFill` rather than against the photograph behind it.
public struct SealArrowBadge: View {
    @Environment(\.kultaraPalette) private var palette

    private let systemName: String

    public init(systemName: String = "arrow.right") {
        self.systemName = systemName
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(palette.inkOnSeal.color)
            .frame(width: KultaraMetrics.minimumTapTarget, height: KultaraMetrics.minimumTapTarget)
            .background(palette.sealFill.color, in: Circle())
            .accessibilityHidden(true)
    }
}

/// One metadatum on a photo card: a symbol and a value, read out as one phrase.
public struct PhotoCardFact: View {
    @Environment(\.kultaraPalette) private var palette

    private let symbolName: String
    private let label: String
    private let value: String
    private let emphasised: Bool

    public init(symbolName: String, label: String, value: String, emphasised: Bool = false) {
        self.symbolName = symbolName
        self.label = label
        self.value = value
        self.emphasised = emphasised
    }

    public var body: some View {
        HStack(spacing: KultaraMetrics.xs) {
            Image(systemName: symbolName)
                .imageScale(.small)
            Text(value)
                .fontWeight(emphasised ? .semibold : .regular)
        }
        .kultaraFont(.metadata)
        // Emphasised facts use the full-strength ink rather than a different hue: on a photograph
        // the seal red is not measurable, and `NFR-A11Y-05` forbids colour carrying the meaning
        // alone in any case. Weight and the symbol carry it.
        .foregroundStyle(emphasised ? palette.inkOnPhoto.color : palette.inkMutedOnPhoto.color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}
