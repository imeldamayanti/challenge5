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
/// else. As of 2026-08-26 the owner supplies that copy per **Place** instead —
/// `QuestExplanationText`, a table in the app target, one passage shared by the checkpoint's three
/// tasks until somebody authors fifteen. That passage is what this screen prints where it exists.
///
/// Where it does not, the screen falls back to the Place's own `loreStandalone` — the documented
/// description, separate from the walk's narrative `loreSegment` — rendered as *claims*, with the
/// accuracy label and the citation `FR-CP-05` asks for, which the frame itself does not draw. That
/// path is the one that is properly sourced, and it is the one a sixth place gets for free.
///
/// **The passage path prints no provenance, and that is a decision with an owner rather than an
/// oversight.** `QuestExplanationText`'s sentences went through nobody's `sources`, so there is no
/// citation to print and no accuracy to label; inventing either would be worse than printing
/// neither. It ships on the same footing as `QuestHistoryText`'s nine paragraphs, and that type's
/// doc comment carries the full record and what has to happen before anything public. This screen
/// does not *extend* the Story Reveal's unsigned `FR-CP-05` exception by inference (`s0` D6) — it
/// inherits the History page's separate, equally unsigned one.
///
/// The cost the fallback path carries, named rather than buried: at a **sacred** Place,
/// `PlaceNoticeScreen` prints the same `loreStandalone` before the first task, so a walker there
/// reads those sentences twice. The five shipped places all have a passage now, so nothing on the
/// shipped quests hits it.
///
/// **The portrait is the quest's hero, not the frame's sitter.** `1:4623` frames a generated likeness
/// of a named historical person, which `FR-CP-05` wants a source and a consent record for and the
/// content tree ships neither. Same substitution `PlaceNoticeScreen`, `TaskDetailScreen` and the two
/// cutscenes already make.
struct QuestExplanationScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    /// `1:4621`'s opening line — the Place's own hook, or the generic lead where it has none.
    let lead: String
    /// The Place's own passage from `QuestExplanationText`. When it is there it is the whole of the
    /// printed matter and `claims` goes unread; when it is nil the claims are what print.
    let passage: String?
    /// The Place's own documented lore, as claims rather than prose — the accuracy label and the
    /// citations come with them. The fallback for a Place `QuestExplanationText` does not name.
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
    /// The inset the printed matter is set inside the plate — so a *larger* number is a *narrower*
    /// column. Set 20 tighter than the place notice's 44 at the owner's instruction of 2026-08-26:
    /// this screen prints whole paragraphs rather than a name and a line, and at the frame's measure
    /// the prose ran nearly to the plate's engraved border. The two screens still share a plate and
    /// deliberately no longer share this one number — the note above is what that costs, and it is
    /// paid for the one screen carrying a passage.
    private static let plaqueColumn: CGFloat = 64
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
            prose(lead)
            if let passage {
                prose(passage)
            } else {
                ForEach(claims) { claim in
                    citedPassage(claim)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One paragraph, set the way `1:4621` sets its lines.
    private func prose(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .tracking(-0.3)
            .lineSpacing(15 * 0.4)
            .foregroundStyle(palette.inkBody.color)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// One claim: the sentences as the frame sets them, then the label and the citation the frame
    /// leaves off.
    ///
    /// Drawn here rather than by `LoreClaimList` because that component reads `\.kultaraPalette` —
    /// the museum theme — and this plate is a Hisplora surface. Dropping a museum-inked component
    /// onto a Hisplora ground is the specific mistake `RunRouteMapView`'s `showsChrome:` exists to
    /// prevent, and `JournalLetterView` already redraws its claims for the same reason.
    private func citedPassage(_ claim: LoreClaimPresentation) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
            prose(claim.block.text)
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
