import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The Story Line page — Figma `293:1643` ("Story - Puri Agung Pemecutan"), which replaces the
/// earlier `46:120` treatment this screen was built to.
///
/// **One page, not `loreSegment.count`.** The paged reveal (one screen per `LoreBlock`, a `1/3`
/// pager) is gone: the frame draws a single passage, so every claim at this checkpoint is joined
/// into one page the same way `QuestRunViewModel.hookText` joins the quest's hook — `\n\n` between
/// blocks — rather than one screen per block. Nothing is dropped, only un-paginated.
///
/// **What `293:1643` changed from `46:120`.** The illustration is a different drawing and it now
/// runs under the status bar — the frame lifts it 21 points above the screen's own top edge and
/// lets the words begin at 557, with the top bar's title floating on the blank paper at the top of
/// the picture. So the page scrolls from y 0 rather than from below a bar, and the bar is an
/// overlay. The passage also gained a lead: one sentence that ends in the place's name, with a
/// hand-drawn marker loop round it (`HisploraMarkedPhrase`).
///
/// **The lead is two halves for a reason.** `storyRevealJourneyLead` is the app's words and
/// `placeName` is the quest's, so the sentence reads as the frame's without this screen ever
/// carrying a claim about a particular place (`AD-4`, `FR-RUN-06`). The frame's own version — "the
/// old gates of Puri Agung Pemecutan" — asserts something about a specific site, and the content
/// tree is where an assertion like that has to come from.
///
/// **The order of the animation is the designer's note**, taken literally: the lead types, the
/// name it ends on arrives, the passage below types, and only then does the marker sweep in. See
/// `Reveal`.
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    let language: ContentLanguage
    /// Every lore block at this checkpoint, already joined into one passage and resolved to the
    /// run's language.
    let text: String
    /// The quest's title, centred in the top bar as `447:1878` draws it. Content, never a literal.
    /// Empty on the surfaces that draw no title — the sidequest letter among them.
    var title: String = ""
    /// The place the lead sentence ends on, and the words the marker rings. `nil` on any surface
    /// that has no single place to name, in which case the lead is not drawn at all.
    var placeName: String?
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
    /// falls back to `StoryIllustrationMetrics.image` — the frame's own art (`293:1646`), packaged
    /// with the design system as chrome rather than authored as content, the same way the
    /// typewriter's machine photograph is one picture for every quest rather than one per place.
    let illustrationURL: URL?
    let onFinish: () -> Void
    let onBack: () -> Void

    /// How far the page has got through the designer's sequence. A single enum rather than three
    /// booleans, because the states are ordered and only one of them is ever current.
    private enum Reveal: Int, Comparable {
        case lead, passage, marked
        static func < (a: Reveal, b: Reveal) -> Bool { a.rawValue < b.rawValue }
    }

    @State private var reveal: Reveal = .lead

    /// Reduce Motion and VoiceOver skip the sequence outright rather than running it faster: a
    /// screen reader must be handed the whole page, and a reader who has asked for less motion has
    /// not asked to wait for it (`NFR-A11Y-04`, `NFR-A11Y-05`). `HisploraTypewriterText` and
    /// `HisploraMarkedPhrase` each read the same settings themselves; this is the state that keeps
    /// the *ordering* from gating anything.
    private var revealsAtOnce: Bool { reduceMotion || voiceOverEnabled }

    /// The frame's 20-point margin, which is what leaves its 362-point column on a 402-point
    /// screen.
    private static let margin: CGFloat = 20

    var body: some View {
        HisploraStage(ground: \.paperWarm) {
            // The bar is a sibling rather than an overlay on the scroll: the scroll ignores the top
            // safe area so the picture runs under the status bar as `293:1646` does, and an overlay
            // on it would be pinned to the screen's physical top edge along with it. In a `ZStack`
            // the bar keeps the safe area the reader's status bar actually occupies.
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Full-bleed, and the one element that carries no horizontal margin: it
                        // spans edge to edge, and up under the status bar as the frame draws it.
                        illustration
                        if showsProvenance {
                            provenanceClaims
                                .padding(.horizontal, Self.margin)
                        } else {
                            passage
                                .padding(.horizontal, Self.margin)
                        }
                    }
                    .padding(.bottom, KultaraMetrics.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
                .ignoresSafeArea(edges: .top)
                .safeAreaInset(edge: .bottom) { footer }
                topBar
            }
        }
    }

    /// `447:1878` — the quest's name centred at 19 points, the back arrow floating over the
    /// picture's blank paper on the left. A `ZStack` rather than a three-column `HStack`, so a long
    /// title stays centred on the screen instead of being pushed off it by the arrow's width.
    private var topBar: some View {
        ZStack {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 19))
                    .foregroundStyle(palette.inkDark.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, KultaraMetrics.minimumTapTarget)
                    .accessibilityAddTraits(.isHeader)
            }
            HStack {
                HisploraBackButton(
                    accessibilityLabel: UIStrings.string(.storyRevealBack, language),
                    ink: \.inkDark,
                    action: onBack)
                Spacer()
            }
        }
        .padding(.horizontal, Self.margin)
    }

    /// The lead sentence, the name it ends on, and the passage — in that order, each waiting on the
    /// one before it.
    private var passage: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            if let placeName {
                VStack(alignment: .leading, spacing: 0) {
                    // Types itself in, character by character, which — because `Text` wraps and
                    // this reveals left to right — reads as line by line, per the designer's note.
                    HisploraTypewriterText(
                        UIStrings.string(.storyRevealJourneyLead, language),
                        font: .system(size: 17),
                        lineSpacing: 0,
                        onComplete: { advance(to: .passage) })
                    // The name is not typed. It is a proper noun a few characters long, and a
                    // marker loop cannot be laid over a phrase whose width is still growing — so it
                    // arrives whole, and the passage starts typing under it.
                    HisploraMarkedPhrase(
                        placeName,
                        font: .system(size: 17),
                        isMarked: reveal >= .marked)
                        .opacity(reveal >= .passage ? 1 : 0)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: reveal)
                }
            }
            if reveal >= .passage {
                HisploraTypewriterText(
                    text,
                    font: .system(size: 17),
                    onComplete: { advance(to: .marked) })
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            // Nothing waits on anything for a reader who has opted out of the sequence.
            if revealsAtOnce || placeName == nil { reveal = .marked }
        }
    }

    private func advance(to next: Reveal) {
        guard reveal < next else { return }
        reveal = next
    }

    /// `293:1646` — the drawing, laid against the top of the screen exactly as the frame lays it:
    /// the full width, its own height following from its aspect, lifted 21 points, and cut where
    /// the words begin. Below that cut the frame is blank paper of the ground's own colour, so the
    /// strip ends there rather than being drawn and covered.
    private var illustration: some View {
        // The strip's height comes from its own ratio — 557 of a 402-point width — rather than from
        // a point value or a `GeometryReader`, which has no intrinsic height and would collapse
        // inside this stack. Decoration, so it does not participate in Dynamic Type: what grows at
        // larger text sizes is the passage under it, which is the part anybody reads.
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(1 / StoryIllustrationMetrics.visibleHeightFraction, contentMode: .fit)
            .overlay { drawing }
            .clipped()
            .accessibilityHidden(true)
    }

    /// The picture inside the strip. `.fill` is what reproduces the frame's sizing exactly: the
    /// artwork is narrower in proportion than the strip, so filling matches its width and lets the
    /// height overflow — which is the 714 points the frame gives a 402-wide screen. The lift is the
    /// frame's own 21 points, held as a fraction of the width so it survives a different device.
    @ViewBuilder private var drawing: some View {
        GeometryReader { proxy in
            Group {
                if let illustrationURL, let image = BundledImage.load(illustrationURL) {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let image = StoryIllustrationMetrics.image {
                    // The frame's own art, packaged with the design system rather than shipped as
                    // content — see the note on `illustrationURL` above.
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .offset(y: proxy.size.width * StoryIllustrationMetrics.topOffsetFraction)
                } else {
                    // No illustration is a legitimate state, not an error — the same rule the
                    // portrait frame and the typewriter follow.
                    palette.paperWarm.color
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
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
            // `293:1643` carries only the next control — no skip. `storyRevealSkip` stays in the
            // string table rather than being deleted along with its one call site: it names a real
            // affordance (finish the page early) that the frame simply does not draw, not a piece
            // of dead copy. With one page it would also have nothing left to skip past.
            Spacer()
            HisploraNextButton(
                accessibilityLabel: UIStrings.string(.transitionContinue, language),
                action: onFinish)
        }
        // 24 to the right edge and 20 to the home indicator, as `293:1657` is drawn.
        .padding(.trailing, 24)
        .padding(.bottom, Self.margin)
    }
}

/// The transition between the story and the walk — Figma `293:1595`.
///
/// **This frame replaced a different screen, and it dropped things.** `187:1103` carried the route
/// map, the quest's name, the place being walked to and a Continue pill, and advanced itself after
/// five seconds. `293:1595` draws a sealed scroll on the flow's brown ground and two words. The
/// instruction was to build the frame, so the map, the names and the timer are gone; what they were
/// carrying has not vanished from the walk — the route map and the distance are on the arrival
/// screen, and the place is named on the notice that follows this one.
///
/// What the frame does not draw and this screen has anyway, both requirements rather than taste:
/// the whole screen is a real `Button` so VoiceOver reaches it as a control instead of as a picture
/// with a caption, and its accessibility label names the place being walked to, which is the one
/// thing the drawn screen leaves to the reader's memory.
struct StoryTransitionScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    /// The place being walked to, from content. Not drawn — it is what VoiceOver is told this
    /// control opens.
    let placeName: String
    let onContinue: () -> Void

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            Button(action: onContinue) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    scroll
                    Spacer(minLength: 0)
                    Text(UIStrings.string(.transitionTapToReveal, language))
                        .font(.system(size: 17))
                        .tracking(-0.34)
                        .foregroundStyle(palette.inkDusty.color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        // 788 of 874, which is 52 above the home indicator's own room.
                        .padding(.bottom, 52)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "\(UIStrings.string(.transitionTapToReveal, language)) · \(placeName)")
        }
    }

    /// `293:1599` — the scroll at its own size, then turned. See `TransitionScrollMetrics` for why
    /// the turn is applied here rather than baked into the PNG.
    ///
    /// `rotationEffect` does not resize what it turns, so the layout still reserves the upright
    /// picture's 264 × 252 rather than the turned 365 × 364 the frame draws. That is left alone
    /// deliberately: the screen centres the scroll between two `Spacer`s on a 874-point ground, the
    /// overflow is 56 points on each side, and there is far more slack than that above the caption.
    /// Reserving the turned box would mean laying out against a size that changes with the angle.
    @ViewBuilder private var scroll: some View {
        if let image = TransitionScrollMetrics.image {
            image
                .resizable()
                .aspectRatio(TransitionScrollMetrics.aspectRatio, contentMode: .fit)
                .containerRelativeFrame(.horizontal, alignment: .center) { width, _ in
                    width * TransitionScrollMetrics.widthFraction
                }
                .rotationEffect(.degrees(TransitionScrollMetrics.rotationDegrees))
                .accessibilityHidden(true)
        } else {
            // A missing picture must not take the way forward with it — the same rule the portrait
            // frame and the typewriter follow. The words below are still a control.
            Color.clear.frame(height: 0)
        }
    }
}
