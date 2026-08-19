import ContentKit
import DesignSystem
import SwiftUI

/// A screen the flow calls for and the app does not have yet, drawn as a wireframe.
///
/// It is deliberately not styled to look finished: the boxes are dashed and empty, the stamp at the
/// top says so, and each one states what still has to be decided before it can be built. A
/// placeholder that looks shippable is worse than a gap, because it gets reviewed as a screen.
struct WireframeScreen<Existing: View, Actions: View>: View {
    @Environment(\.kultaraPalette) private var palette

    private let spec: WireframeSpec
    private let language: ContentLanguage
    /// Real, working content shown above the placeholder boxes — the journal's finished walks, the
    /// profile's way into the settings that do exist. Kept separate from the boxes so the line
    /// between what works and what is a drawing stays visible on the screen itself.
    private let existing: Existing
    private let actions: Actions

    init(
        _ spec: WireframeSpec,
        language: ContentLanguage,
        @ViewBuilder existing: () -> Existing,
        @ViewBuilder actions: () -> Actions
    ) {
        self.spec = spec
        self.language = language
        self.existing = existing()
        self.actions = actions()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.xl) {
                heading
                existing
                blocks
                note
                actions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(KultaraMetrics.lg)
            .kultaraFloatingTabBarClearance()
        }
        .kultaraGround()
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            KultaraEyebrow(WireframeCatalog.stamp.value(for: language), ink: \.warning)
            Text(spec.title.value(for: language))
                .kultaraFont(.questTitleLarge)
                .foregroundStyle(palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(spec.purpose.value(for: language))
                .kultaraFont(.body)
                .foregroundStyle(palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
            KultaraRule()
        }
    }

    private var blocks: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            Text(WireframeCatalog.notBuiltNote.value(for: language))
                .kultaraFont(.metadata)
                .foregroundStyle(palette.warning.color)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(spec.blocks.enumerated()), id: \.offset) { _, block in
                WireframeBlock(label: block.value(for: language))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var note: some View {
        Text(spec.flowNote.value(for: language))
            .kultaraFont(.metadata)
            .foregroundStyle(palette.inkMuted.color)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension WireframeScreen where Existing == EmptyView {
    init(
        _ spec: WireframeSpec,
        language: ContentLanguage,
        @ViewBuilder actions: () -> Actions
    ) {
        self.init(spec, language: language, existing: { EmptyView() }, actions: actions)
    }
}

/// One empty box: a dashed outline on the sunken stock, with the name of what belongs in it.
///
/// Dashed rather than ruled for the same reason the oral-tradition chip is dashed — a broken border
/// reads as provisional, and the theme already uses that vocabulary.
struct WireframeBlock: View {
    @Environment(\.kultaraPalette) private var palette

    let label: String

    var body: some View {
        Text(label)
            .kultaraFont(.body)
            .foregroundStyle(palette.inkMuted.color)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(KultaraMetrics.md)
            // A minimum, never a fixed height: at the largest accessibility size these labels wrap
            // to several lines and a fixed box would clip them.
            .frame(minHeight: KultaraMetrics.minimumTapTarget, alignment: .leading)
            .background(palette.paperSunken.color)
            .overlay(
                RoundedRectangle(cornerRadius: KultaraMetrics.cardCornerRadius)
                    .stroke(palette.rule.color,
                            style: StrokeStyle(lineWidth: KultaraMetrics.hairline, dash: [5, 4])))
    }
}
