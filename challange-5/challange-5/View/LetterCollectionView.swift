import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The collection, in the Journal tab (`FR-SIDE-08`, `FR-SIDE-09`).
///
/// **Kultara, not Hisplora.** This is a catalogue surface and it sits inside chrome that is already
/// museum; the seam between the two directions falls at a screen boundary, never inside one.
///
/// The masked phrase is drawn as a grid of slots that reflows at large Dynamic Type
/// (`NFR-A11Y-02`), and it is read to VoiceOver as one spoken phrase with each gap named — a row of
/// underscores says nothing useful (`NFR-A11Y-01`).
struct LetterCollectionView: View {
    @Environment(\.kultaraPalette) private var palette

    private let model: LetterCollectionViewModel
    let language: ContentLanguage
    let onOpenSideQuest: (String) -> Void

    init(
        model: LetterCollectionViewModel,
        language: ContentLanguage,
        onOpenSideQuest: @escaping (String) -> Void
    ) {
        self.model = model
        self.language = language
        self.onOpenSideQuest = onOpenSideQuest
    }

    var body: some View {
        ScrollView {
            if let presentation = model.presentation {
                VStack(alignment: .leading, spacing: KultaraMetrics.xl) {
                    heading(presentation)
                    phrase(presentation)
                    places(presentation)
                }
                .padding(KultaraMetrics.lg)
                .padding(.bottom, KultaraMetrics.floatingTabBarClearance)
            } else {
                KultaraCard {
                    Text(UIStrings.string(.sideQuestNearbyEmpty, language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(KultaraMetrics.lg)
            }
        }
        .background(palette.paper.color)
        .navigationTitle(UIStrings.string(.collectionHeading, language))
        .kultaraInlineNavigationTitle()
        // A letter may have been earned since this screen was last looked at.
        .onAppear { model.reload() }
    }

    private func heading(_ presentation: LetterCollectionPresentation) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            KultaraEyebrow(UIStrings.string(.collectionHeading, language))
            Text(presentation.title)
                .kultaraFont(.questTitleLarge)
                .foregroundStyle(palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(presentation.progressText)
                .kultaraFont(.metadata)
                .foregroundStyle(palette.inkMuted.color)
                .monospacedDigit()
            if !presentation.caption.isEmpty {
                Text(presentation.caption)
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            KultaraRule()
        }
    }

    private func phrase(_ presentation: LetterCollectionPresentation) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            // The phrase itself, as slots. Not localized (`s0` D7, PRD §5.15 decision 2):
            // translating it changes the letter count, which changes the number of places.
            Text(presentation.maskedPhrase)
                .kultaraFont(.questTitle)
                .foregroundStyle(palette.ink.color)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(presentation.spokenPhrase)

            if presentation.isComplete {
                Text(UIStrings.string(.collectionComplete, language))
                    .kultaraFont(.sectionHeading)
                    .foregroundStyle(palette.seal.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // `FR-SIDE-09` — the badge, on the last letter and not before.
            if let badgeText = presentation.badgeText {
                Text(badgeText)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.seal.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func places(_ presentation: LetterCollectionPresentation) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            KultaraSectionHeading(UIStrings.string(.sideQuestNearbyHeading, language))
            ForEach(presentation.slots) { slot in
                slotRow(slot)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One row per slot. Earned rows open the read-back; unearned rows open the sidequest itself,
    /// which `FR-SIDE-07` requires to be reachable from here without waiting for a notification.
    ///
    /// An unearned row shows its place name and **never** its letter. That split is `FR-SIDE-08`
    /// as accepted on 2026-08-15 — `s4` §5 proposed hiding the name as well, and product overruled
    /// it in the requirement rather than leaving it to this view.
    private func slotRow(_ slot: LetterSlotPresentation) -> some View {
        Button {
            onOpenSideQuest(slot.sideQuestID)
        } label: {
            KultaraCard {
                HStack(alignment: .top, spacing: KultaraMetrics.md) {
                    // Shape and text, not colour alone (`NFR-A11Y-05`): an earned slot shows its
                    // letter, an unearned one shows a dash.
                    Text(slot.letter ?? "—")
                        .kultaraFont(.questTitle)
                        .foregroundStyle(slot.isEarned ? palette.seal.color : palette.inkMuted.color)
                        .frame(minWidth: KultaraMetrics.minimumTapTarget,
                               minHeight: KultaraMetrics.minimumTapTarget)
                    VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                        Text(slot.placeName ?? UIStrings.string(.collectionSlotLocked, language))
                            .kultaraFont(.sectionHeading)
                            .foregroundStyle(palette.ink.color)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(slot.isEarned
                             ? (slot.dateText ?? "")
                             : UIStrings.string(.collectionSlotLocked, language))
                            .kultaraFont(.metadata)
                            .foregroundStyle(palette.inkMuted.color)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(slot.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }
}
