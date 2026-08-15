import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The paged story reveal — `105:1699`, `187:954`, `187:1053`, restyled to the Ngalcer board's
/// `46:120` ("Story - Puri Maospahit").
///
/// **One page, not `loreSegment.count`.** The paged reveal (one screen per `LoreBlock`, a `1/3`
/// pager) is gone: `46:120` draws a single passage, so every claim at this checkpoint is joined into
/// one page the same way `QuestRunViewModel.hookText` joins the quest's hook — `\n\n` between blocks
/// — rather than one screen per block. Nothing is dropped, only un-paginated.
///
/// **What `46:120` changed.** The illustration moved from a small, inset, letterboxed picture to a
/// full-bleed hero across the top of the page — so `illustration` now fills and crops
/// (`contentMode: .fill`) instead of letterboxing (`.fit`), and only the text and chrome carry the
/// screen's horizontal padding, not the picture. The frame draws its back arrow floating directly on
/// the illustration; `topBar` stays on the page's own paper ground just above it instead, kept as its
/// own change rather than folded into this one. The frame's rich text — a bold name set inline
/// mid-sentence — is not reproduced: `LoreBlock.text` is a plain `LocalizedText`, with no span markup
/// to bold a piece of it, and inventing a name to bold would bake a quest-specific claim into a
/// generic screen (`AD-4`). The frame's own words (a specific, unverified claim about a named
/// historical figure and the Puputan) are not reproduced at all, for the same reason — see
/// `docs/consent-log.md` and the note in `CutsceneScreens.swift`. This screen still renders whatever
/// `text` the run's own content provides.
///
/// **The `FR-CP-05` deviation.** The frames render historical claims as unlabelled prose: no
/// accuracy chip, no citation. That is a knowing departure from `FR-CP-05`, taken by the product
/// owner on 2026-08-13 and recorded in `.claude/plans/m8-qa-fixes.plan.md` (Decisions taken, item
/// 2) — it is *not* an oversight in this file, and it must not be quietly reverted either way.
/// `LoreBlock` still carries `accuracy` and `sourceRefs`; what changes is that this screen does not
/// display them, and the checkpoint screen — which still does — remains where the labels live. The
/// PRD needs the amendment or the signed exception; until it has one, this comment is the record.
struct StoryRevealScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    /// Every lore block at this checkpoint, already joined into one passage and resolved to the
    /// run's language.
    let text: String
    /// The same passage split back into labelled claims, drawn only when `showsProvenance` is on.
    /// Empty for the run flow, which passes `text` alone.
    var claims: [LoreClaimPresentation] = []
    /// `FR-CP-05` / `FR-SIDE-04` — the accuracy label and the citations.
    ///
    /// **Defaults to false, and that default is the whole point.** The run flow's unlabelled
    /// treatment is a signed product decision (2026-08-13) that this parameter leaves untouched;
    /// the sidequest story turns it on, because `s0` D6 says an exception taken for one surface
    /// does not extend to a new one by inference. Flipping this default would silently re-open a
    /// decision that has an owner.
    var showsProvenance: Bool = false
    /// The illustration behind the page, when a specific one exists for this run. The content tree
    /// has no per-place illustration field, so this is `nil` in the shipped quest and the screen
    /// falls back to `StoryIllustrationMetrics.image` — the frame's own art (`46:120`), packaged
    /// with the design system as chrome rather than authored as content, the same way the
    /// typewriter's machine photograph is one picture for every quest rather than one per place.
    let illustrationURL: URL?
    let onFinish: () -> Void
    let onBack: () -> Void

    /// `46:120` draws the illustration at roughly 71% of the frame's height (623 of 874). Held here
    /// as a point value rather than that fraction: the picture is decoration, not text, so it does
    /// not participate in Dynamic Type, and a fixed height is what keeps it from fighting the
    /// `ScrollView` it sits in for space.
    private static let illustrationHeight: CGFloat = 380

    var body: some View {
        HisploraStage(ground: \.paperWarm) {
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, KultaraMetrics.lg)
                    .padding(.top, KultaraMetrics.lg)
                ScrollView {
                    VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                        // Full-bleed: the one element in this screen that does not carry the
                        // screen's own horizontal padding, so it spans edge to edge as the frame
                        // draws it rather than sitting in the same padded column as the words.
                        illustration
                        if showsProvenance {
                            provenanceClaims
                                .padding(.horizontal, KultaraMetrics.lg)
                        } else {
                            // Types itself in, character by character, which — because `Text` wraps
                            // and this reveals left to right — reads as line by line, per the
                            // designer's note. `HisploraTypewriterText` already does this; nothing
                            // new to build for it.
                            HisploraTypewriterText(text, font: .system(size: 17))
                                .padding(.horizontal, KultaraMetrics.lg)
                        }
                    }
                    .padding(.bottom, KultaraMetrics.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
                footer
                    .padding(.horizontal, KultaraMetrics.lg)
                    .padding(.bottom, KultaraMetrics.lg)
            }
        }
    }

    private var topBar: some View {
        HStack {
            HisploraBackButton(
                accessibilityLabel: UIStrings.string(.storyRevealBack, language),
                ink: \.inkDark,
                action: onBack)
            Spacer()
        }
    }

    @ViewBuilder private var illustration: some View {
        Group {
            if let illustrationURL, let image = BundledImage.load(illustrationURL) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let image = StoryIllustrationMetrics.image {
                // The frame's own art (`46:120`), packaged with the design system rather than
                // shipped as content — see the note on `illustrationURL` above.
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // No illustration is a legitimate state, not an error — the same rule the portrait
                // frame and the typewriter follow.
                palette.paperCream.color
            }
        }
        .frame(maxWidth: .infinity, minHeight: Self.illustrationHeight, maxHeight: Self.illustrationHeight)
        .clipped()
        .accessibilityHidden(true)
    }

    /// The labelled version of the same passage: each claim under its accuracy label, with its
    /// citations one tap away (`FR-CP-05`, `FR-CP-06`, `FR-SIDE-04`).
    ///
    /// Two deliberate differences from the unlabelled treatment above. There is no typewriter — a
    /// provenance label that arrives letter by letter is a label behind a delay, which is exactly
    /// what `FR-CP-05` forbids. And the inks are Hisplora's own (`inkMuted`, `inkDark`, `inkBody`
    /// on `paperWarm`), not `LoreClaimList`'s: that component is measured against museum paper and
    /// its `palette.seal` heading falls to about 2:1 on this ground.
    private var provenanceClaims: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xl) {
            ForEach(claims) { claim in
                VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                    // Text, not a tint — the label carries the meaning on its own
                    // (`NFR-A11Y-05`).
                    Text(claim.block.accuracyLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.inkMuted.color)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(claim.block.text)
                        .font(.system(size: 17))
                        .foregroundStyle(palette.inkDark.color)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 2) {
                            if claim.citations.isEmpty {
                                Text(UIStrings.string(.checkpointSourcesEmpty, language))
                                    .font(.system(size: 13))
                                    .foregroundStyle(palette.inkMuted.color)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            ForEach(claim.citations, id: \.self) { citation in
                                Text("· \(citation)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(palette.inkMuted.color)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } label: {
                        Text(UIStrings.string(.checkpointSourcesHeading, language))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.inkBody.color)
                            .frame(minHeight: KultaraMetrics.minimumTapTarget, alignment: .leading)
                    }
                    .tint(palette.inkBody.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var footer: some View {
        HStack {
            // `46:120` carries only the next control — no skip. `storyRevealSkip` stays in the
            // string table rather than being deleted along with its one call site: it names a real
            // affordance (finish the page early) that the frame simply does not draw, not a piece
            // of dead copy. With one page it would also have nothing left to skip past.
            Spacer()
            HisploraNextButton(
                accessibilityLabel: UIStrings.string(.transitionContinue, language),
                action: onFinish)
        }
    }
}

/// `187:1103` — the transition between the story and the walk.
///
/// The frame auto-advances after five seconds and blinks the place name. Both are honoured and both
/// are bounded: the timer does not run under Reduce Motion or VoiceOver, the blink never reaches
/// zero opacity, and a visible Continue control always exists — a screen that moves on by itself
/// while somebody is still reading it is a timing failure, not a transition (`NFR-A11Y-04/05`).
struct StoryTransitionScreen: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    let language: ContentLanguage
    /// The quest's region or title, from content.
    let questName: String
    /// The place being walked to, from content.
    let placeName: String
    let route: RunRoutePresentation?
    let totalCheckpoints: Int
    let onContinue: () -> Void

    static let autoAdvance: Duration = .seconds(5)

    private var advancesOnItsOwn: Bool { !reduceMotion && !voiceOverEnabled }

    var body: some View {
        HisploraStage(ground: \.brownMid) {
            VStack(spacing: KultaraMetrics.xl) {
                Spacer()
                if let route {
                    RunRouteMapView(route: route,
                                    language: language,
                                    totalCheckpoints: totalCheckpoints,
                                    showsChrome: false)
                        .padding(KultaraMetrics.md)
                        .background(palette.paperCream.color,
                                    in: RoundedRectangle(cornerRadius: KultaraMetrics.sm))
                }
                VStack(spacing: KultaraMetrics.xs) {
                    Text(String(format: UIStrings.string(.transitionSteppingInto, language), questName))
                        .font(.system(size: 17))
                        .foregroundStyle(palette.inkCream.color.opacity(0.48))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(placeName)
                        .font(KultaraTypography.font(.questTitle))
                        .foregroundStyle(palette.inkCream.color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .hisploraBlink()
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer()
                Button(UIStrings.string(.transitionContinue, language), action: onContinue)
                    .buttonStyle(.hisploraPill)
            }
            .padding(KultaraMetrics.lg)
            .task {
                guard advancesOnItsOwn else { return }
                try? await Task.sleep(for: Self.autoAdvance)
                guard !Task.isCancelled else { return }
                onContinue()
            }
        }
    }
}
