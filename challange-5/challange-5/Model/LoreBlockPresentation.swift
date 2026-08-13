import DesignSystem

/// A labelled claim, ready to render. `FR-CP-05` — the accuracy label is visible, as text, never
/// behind a tap.
struct LoreBlockPresentation: Sendable, Identifiable, Equatable {
    /// Which palette ink the chip uses. An enum rather than a `KeyPath`, so the presentation
    /// stays `Sendable` and the palette lookup happens where the palette actually is — in the view.
    enum Ink: Sendable, Equatable {
        case documented, oral

        var path: KeyPath<KultaraPalette, SRGBColor> {
            switch self {
            case .documented: \.documentedInk
            case .oral: \.oralInk
            }
        }
    }

    let id: Int
    let text: String
    let accuracyLabel: String
    let appearance: ChipAppearance
    let ink: Ink
}
