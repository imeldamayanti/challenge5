import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The story behind a task, told once it has been resolved — Figma `1:4609` ("Explanation per
/// Quest").
///
/// **The plate is the one the place notice already prints on.** `1:4616` is the same stock
/// wedding-invitation plate as `293:1630`, names and all, hidden the same way — under three opaque
/// rectangles the frame lays over it. That problem is already solved in this repository:
/// `plaque-plate.png` is that file with the names erased from its pixels, and `HisploraPlaquePanel`
/// is the panel built on it, silhouette measured and held by `PlaqueGeometryTests`. So this screen
/// reuses it rather than shipping a second copy of the same picture. `PlaquePanel.swift` carries the
/// full record, including the licence question on the engraving, which erasing the names did not
/// settle.
///
/// **What fills it, and the honest problem with that.** The frame's copy ("The Iron Statue represents
/// Ratu Patih…") is lore about the *thing the task pointed at*, and the content tree has no such
/// field: `ContentTask` carries an `id`, a `type`, a `prompt` and `blocksProgression`, and nothing
/// else. What it does carry, on the Place rather than the task, is `loreStandalone` — the place's own
/// documented description, separate from the walk's narrative `loreSegment`. That is what this screen
/// renders, because it is authored, cited, and not the passage the story reveal already showed.
///
/// The cost, named rather than buried: at a **sacred** Place, `PlaceNoticeScreen` prints the same
/// `loreStandalone` before the first task, so a walker at Pura Maospahit or Puri Agung Pemecutan
/// reads those sentences twice. The fix is a per-task `explanation` on `ContentTask` — a schema
/// change, a validator rule, a `contentBundleVersion` bump and five newly authored passages about
/// real places, each needing a source. That is a content decision with an owner, not something to
/// invent here (`AD-4`, `FR-CP-05`).
///
/// **This screen carries the accuracy label and the citation, and the frame does not.** The Story
/// Reveal's unlabelled treatment is a `FR-CP-05` exception that is *still unsigned* — the PRD lists
/// it as outstanding in §10 with no owner named — and `s0` D6 is explicit that an exception taken for
/// one surface does not extend to a new one by inference. So the passage is set as the frame sets it
/// and its provenance is printed under it, quietly, in the plate's own muted ink.
///
/// **The portrait is the quest's hero, not the frame's sitter.** `1:4623` frames a generated likeness
/// of a named historical person, which `FR-CP-05` wants a source and a consent record for and the
/// content tree ships neither. Same substitution `PlaceNoticeScreen`, `TaskDetailScreen` and the two
/// cutscenes already make.
struct QuestExplanationScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    /// The Place's own documented lore, as claims rather than prose — the accuracy label and the
    /// citations come with them.
    let claims: [LoreClaimPresentation]
    let portraitURL: URL?
    /// Names the portrait for a reader who cannot see it. The place, not a person: the picture is the
    /// quest's hero image, and captioning it with a name would be the claim this screen avoids.
    let portraitLabel: String
    /// `1:4613` — the whole screen is the control.
    let onContinue: () -> Void
    let onBack: () -> Void

    // The frame's margins, in the same terms `PlaceNoticeScreen` measured them in — both screens
    // print on the same plate at the same size, and two sets of numbers for one object would drift.
    private static let margin: CGFloat = 20
    private static let plaqueInset: CGFloat = 22
    private static let plaqueColumn: CGFloat = 44
    private static let portraitWidth: CGFloat = 157
    private static let portraitTopOffset: CGFloat = HisploraPlaqueMetrics.crestHeight - 13
    /// The room the panel reserves above its first line: the oval's 196, plus the air `1:4620` leaves
    /// under it, less the head lobe the panel already reserves. `1:4621` begins at y 381 on a plate
    /// whose sheet starts at 138, which is 44 tighter than the place notice sets it — this screen
    /// has more to print and the frame gives it the room.
    private static let plaqueInteriorTop: CGFloat =
        portraitTopOffset + 196 + 10 - HisploraPlaqueMetrics.crestHeight

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            ZStack(alignment: .top) {
                ScrollView {
                    plaque
                        .padding(.horizontal, Self.plaqueInset)
                        // The plate's head lobe tips at y ≈ 105 of 874 on this screen too — see the
                        // note on `PlaceNoticeScreen`, which measured it. Cream under the back arrow
                        // is a cream arrow that disappears.
                        .padding(.top, 46)
                    continueHint
                        .padding(.top, KultaraMetrics.lg)
                        .padding(.bottom, 30)
                }
                .scrollBounceBehavior(.basedOnSize)
                backBar
            }
            // The frame has no button: tapping anywhere moves on. `contentShape` so the brown around
            // the plate is live too, and a gesture rather than a `Button` so the whole page does not
            // flash on press.
            .contentShape(Rectangle())
            .onTapGesture(perform: onContinue)
            .accessibilityAction(named: Text(UIStrings.string(.questExplanationContinue, language)),
                                 onContinue)
        }
    }

    /// `1:4612` — the back arrow alone, floating on the brown above the plate.
    private var backBar: some View {
        HStack {
            HisploraBackButton(
                accessibilityLabel: UIStrings.string(.questExplanationBack, language),
                size: 24,
                action: onBack)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Self.margin)
        .padding(.top, 13)
    }

    /// The plate, with the gilded oval standing over its head as `1:4622` draws it — an overlay
    /// rather than the panel's first row, because the oval hangs *past* the cream's top edge and a
    /// row inside the panel cannot.
    private var plaque: some View {
        HisploraPlaquePanel(interiorTop: Self.plaqueInteriorTop) {
            printedMatter
                .padding(.horizontal, Self.plaqueColumn)
                // The plate runs on past its last line rather than ending on it, the same way the
                // place notice's does.
                .padding(.bottom, 60)
        }
        .overlay(alignment: .top) {
            HisploraFramedImage(url: portraitURL, label: portraitLabel)
                .frame(width: Self.portraitWidth)
                .offset(y: Self.portraitTopOffset)
        }
    }

    private var printedMatter: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            Text(UIStrings.string(.questExplanationLead, language))
                .font(.system(size: 15))
                .tracking(-0.3)
                .lineSpacing(15 * 0.4)
                .foregroundStyle(palette.inkBody.color)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(claims) { claim in
                passage(claim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One claim: the sentences as the frame sets them, then the label and the citation the frame
    /// leaves off.
    ///
    /// Drawn here rather than by `LoreClaimList` because that component reads `\.kultaraPalette` —
    /// the museum theme — and this plate is a Hisplora surface. Dropping a museum-inked component
    /// onto a Hisplora ground is the specific mistake `RunRouteMapView`'s `showsChrome:` exists to
    /// prevent, and `JournalLetterView` already redraws its claims for the same reason.
    private func passage(_ claim: LoreClaimPresentation) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
            Text(claim.block.text)
                .font(.system(size: 15))
                .tracking(-0.3)
                .lineSpacing(15 * 0.4)
                .foregroundStyle(palette.inkBody.color)
                .fixedSize(horizontal: false, vertical: true)
            Text(claim.block.accuracyLabel)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(palette.inkMuted.color)
            ForEach(Array(claim.citations.enumerated()), id: \.offset) { _, citation in
                Text(citation)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.inkMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// `1:4613` — "Tap to Continue", in the dusty ink the frame sets it in.
    private var continueHint: some View {
        Text(UIStrings.string(.questExplanationContinue, language))
            .font(.system(size: 17))
            .tracking(-0.34)
            .foregroundStyle(palette.inkDusty.color)
            .frame(maxWidth: .infinity)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            // The gesture is on the whole page; this is the label for it, so it must not also be
            // something a screen reader announces as a control of its own.
            .accessibilityHidden(true)
    }
}
