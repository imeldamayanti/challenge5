import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The cutscene — `98:1588` and `187:866`.
///
/// The plan settles what this is: a *presentation* of data that already exists, not a new content
/// type. It shows the quest's `hookLore` and a place image, once, before the walk. Adding a
/// `cutscene` object to the schema would mean a validator rule, a consent question and a migration,
/// for something `hookLore` already holds.
///
/// **On the portrait.** The frames show a generated likeness of I Gusti Ngurah Made Agung. That
/// image is not shipped here, and the reason is not squeamishness: a portrait of a named historical
/// person is a claim, `FR-CP-05` requires every claim to carry its accuracy label and its source,
/// and the sample content ships no such person, no consent record for one, and no citation. The
/// frame is built to take *whatever image the content supplies* — `KultaraPortraitFrame` was
/// written that way deliberately — so when a licensed or properly-labelled image exists it drops in
/// without this file changing. Until then the frame carries the quest's own hero image, which is
/// content with provenance behind it.


/// `98:1588` into `187:866` — the covered frame the walker rubs clear, and the subject named once
/// it is. **One view, two phases, deliberately.**
///
/// They were two screens (`CutsceneIntroScreen` and `CutscenePortraitScreen`) swapped by the run's
/// stage, which meant the hand-over was a cross-fade between two pictures of the *same* framed
/// portrait drawn ~100 points apart and at slightly different widths. Two nearly-identical frames
/// dissolving into each other does not read as one object moving; it reads as a cut, and it was the
/// most visible seam on the story flow. Drawn as one view whose layout depends on `phase`, the
/// frame keeps its identity across the change and SwiftUI moves it — so the object the walker just
/// uncovered with their thumb travels to where the next page wants it, and only the words around it
/// cross-fade.
///
/// The two stages are unchanged: `QuestRunViewModel` still has `.cutsceneIntro` and
/// `.cutscenePortrait`, and the back chevron still steps between them. What changed is that
/// `QuestRunView` routes both to this one branch, so the stage change is a layout change rather
/// than a view replacement.
///
/// **What the phases carry.** `.legend`: "A Legend Will Guide Your Journey", the covered frame, and
/// the hint that says how to uncover it. Nothing is tapped in the drawn design — the picture coming
/// out from under the hand *is* the transition. `.portrait`: the subject named, the quest's hook
/// beneath it, and the action to begin.
///
/// Two things the frames do not draw and this screen has anyway, both of them requirements:
///
/// - Under Reduce Motion or VoiceOver the picture is uncovered from the first frame, because a rub
///   is not an animation anyone can opt out of and it is not a control a screen reader can find
///   (`NFR-A11Y-04`, `NFR-A11Y-05`). **That is the only case that draws a button on `.legend`**,
///   and it has to stay: with the cover already gone there is no gesture left to make, so without
///   it those readers reach a screen with no way out of it. Reduce Motion also drops the morph to a
///   plain short fade — the whole point of moving the frame is motion.
/// - The quest's own title sits in the header on both phases, as `447:1870` draws it — from
///   content, never the name the frames bake in (`AD-4`, `FR-RUN-06`).
///
/// **Two titles, and they are not the same title.** The quest's name is in the bar. `subjectName`
/// below the picture stays what the frame uses it for: the *subject* of the portrait. The call site
/// must not pass the quest's name to both, or the page prints it twice.
///
/// The rub used to grow a fallback button after ten seconds, for whoever did not think to try the
/// gesture. It is gone at the designer's instruction — the drawn design has no such control and the
/// hint under the frame is what tells the walker what to do. The cost is real and is theirs to
/// carry: a walker who never swipes has no other way forward.
struct CutsceneSequenceScreen: View {

    /// Which of the two frames is being drawn. Named for what is on the page rather than for the
    /// stage, because the stage names are the run's vocabulary and this view only knows about
    /// pictures and words.
    enum Phase: Equatable { case legend, portrait }

    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    let language: ContentLanguage
    let phase: Phase
    /// The quest's title, for the header. Content, not a literal.
    let questTitle: String
    let portraitURL: URL?
    let portraitLabel: String
    /// The subject of the portrait, from content. Never a baked-in name (`AD-4`).
    let subjectName: String
    let subjectSubtitle: String?
    /// `quest.hookLore`, already resolved to the run's language. Cut to `CutsceneLeadMetrics` for
    /// display: the frame draws a lead here, not the passage.
    let hook: String
    let onAdvance: () -> Void
    let onStart: () -> Void
    let onBack: () -> Void

    @State private var hasAdvanced = false
    /// Bumped when the walker steps *back* to `.legend`, which resets the reveal to covered.
    ///
    /// Load-bearing rather than tidy. When these were two screens, backing out of `187:866` threw
    /// the intro screen away and built a fresh one, so the frame was covered again and the rub was
    /// there to be made. One view keeps its state, so without this the walker returns to a page
    /// whose picture is already clear, whose gesture can never complete again, and which therefore
    /// has no way forward at all.
    @State private var revealGeneration = 0

    /// The rub is skipped outright for the same two settings `HisploraScratchReveal` reads, so the
    /// action has to be there from the start rather than after the wait.
    private var rubIsAvailable: Bool { !(reduceMotion || voiceOverEnabled) }

    private var isLegend: Bool { phase == .legend }

    /// What carries the frame from one page to the other. A spring rather than a curve, because the
    /// frame is a physical object on this screen and the walker has just had a thumb on it; it
    /// overdamped (0.88) so the gold does not wobble at the end of its travel.
    ///
    /// Under Reduce Motion the frame must not travel at all, so the change becomes the short fade
    /// it was before.
    private var morph: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.52, dampingFraction: 0.88)
    }

    /// The words step out quickly and the next set arrives after them, rather than the two of them
    /// dissolving through each other in the middle. The delay is a little under the frame's travel,
    /// so the page settles and *then* reads.
    private var wordsSwap: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: reduceMotion ? 0 : 12))
                .animation(.easeOut(duration: 0.30).delay(reduceMotion ? 0 : 0.16)),
            removal: .opacity.animation(.easeIn(duration: 0.16)))
    }

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: isLegend ? KultaraMetrics.xl : KultaraMetrics.lg) {
                        if isLegend { legendTitle }
                        revealableFrame
                            // `98:1588` sets the frame wider than `187:866` does. Both numbers are
                            // the frames' own; the change between them is part of what travels.
                            .padding(.horizontal,
                                     isLegend ? KultaraMetrics.xl : KultaraMetrics.xxl)
                        if isLegend { swipeHint } else { subject }
                    }
                    .padding(.top, isLegend ? KultaraMetrics.xl : KultaraMetrics.lg)
                    .padding(.bottom, KultaraMetrics.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
                footAction
            }
            .padding(KultaraMetrics.lg)
            // Attached here rather than left to `QuestRunView`'s stage animation, which is the
            // cross-fade curve every *other* stage change runs on. This one is not a cross-fade.
            .animation(morph, value: phase)
        }
        .onChange(of: phase) { previous, current in
            guard previous == .portrait, current == .legend else { return }
            hasAdvanced = false
            revealGeneration += 1
        }
    }

    /// `447:1870` and `187:1093` — the quest's name centred, the back chevron over it on the left.
    /// A `ZStack` rather than a three-column `HStack`, so a long title stays centred on the screen
    /// instead of being pushed off it by the chevron's width.
    ///
    /// Identical on both phases, which is why it is outside the part that changes: the bar is the
    /// one thing on this screen that must not move when the page does.
    private var header: some View {
        ZStack {
            Text(questTitle)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.inkCream.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, KultaraMetrics.minimumTapTarget)
                .accessibilityAddTraits(.isHeader)
            HStack {
                HisploraBackButton(
                    accessibilityLabel: UIStrings.string(.storyRevealBack, language),
                    action: onBack)
                Spacer()
            }
        }
    }

    private var legendTitle: some View {
        Text(UIStrings.string(.cutsceneLegendTitle, language))
            .kultaraFont(.storyDisplay)
            .foregroundStyle(palette.inkCream.color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .transition(wordsSwap)
    }

    private var swipeHint: some View {
        Text(UIStrings.string(.cutsceneSwipeHint, language))
            .font(.system(size: 15))
            .foregroundStyle(palette.inkDusty.color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            // Sits further under the frame than the stack's own rhythm puts it: the hint is an
            // instruction about the picture above it, and with no control beneath it any more, the
            // gap is what separates the two.
            .padding(.top, KultaraMetrics.xl)
            .transition(wordsSwap)
    }

    /// `187:866`'s half of the page — the subject named, then the hook.
    private var subject: some View {
        VStack(spacing: KultaraMetrics.lg) {
            VStack(spacing: KultaraMetrics.sm) {
                Text(subjectName)
                    .kultaraFont(.storyDisplay)
                    .foregroundStyle(palette.inkCream.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let subjectSubtitle {
                    Text(subjectSubtitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.inkCream.color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(CutsceneLeadMetrics.leadText(hook))
                .font(.system(size: 15))
                .foregroundStyle(palette.inkDusty.color)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, KultaraMetrics.lg)
        }
        .transition(wordsSwap)
    }

    /// `.portrait` always carries its action. `.legend` carries one only where the rub cannot
    /// happen at all — under Reduce Motion or VoiceOver the picture is uncovered from the first
    /// frame and there is no gesture to make, so without this the screen has no way out for those
    /// readers (`NFR-A11Y-04`, `NFR-A11Y-05`).
    @ViewBuilder private var footAction: some View {
        if !isLegend {
            Button(UIStrings.string(.cutsceneStartAction, language), action: onStart)
                .buttonStyle(.hisploraPill)
                .transition(wordsSwap)
        } else if !rubIsAvailable {
            Button(UIStrings.string(.cutsceneRevealAction, language), action: advanceOnce)
                .buttonStyle(.hisploraPill)
                .transition(wordsSwap)
        }
    }

    /// The gilded frame with the picture under a cover. The reveal wraps only the *picture*, not
    /// the ornament: rubbing the carved gold away would say the frame is what is being uncovered.
    ///
    /// The reveal stays mounted on `.portrait` as well, and that is what makes the frame one object
    /// across the change rather than two. It costs nothing there — by the time this page is reached
    /// the cover has either been rubbed off or was never drawn — but it must not keep the gesture,
    /// or a drag over the picture is swallowed instead of scrolling the page.
    private var revealableFrame: some View {
        KultaraPortraitFrame(accessibilityLabel: portraitLabel) {
            HisploraScratchReveal(
                onComplete: advanceAfterReveal,
                content: { HisploraPortraitContent(url: portraitURL) },
                // The cover is the same photograph with its resolution destroyed, not a wash over
                // it: the walker is meant to see that there is a picture there and that it is not
                // legible yet. A flat grey plate reads as an empty frame, which is what shipped.
                cover: { HisploraPortraitCover(url: portraitURL) })
                .id(revealGeneration)
        }
        .allowsHitTesting(isLegend)
        // The reveal is a gesture on a picture, and VoiceOver reaches it as the button below.
        .accessibilityHint(isLegend ? UIStrings.string(.cutsceneSwipeHint, language) : "")
    }

    /// A beat after the last stroke, so the picture is seen whole before the page changes. The
    /// walker rubbed it clear; showing them nothing of what they uncovered wastes the moment. The
    /// cover's own fade out is 0.35 s, so this also lets it finish before the frame starts moving.
    private func advanceAfterReveal() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            advanceOnce()
        }
    }

    /// The rub finishing and the button being tapped are the same act, and both can happen — the
    /// button is on screen while the frame is still rubbable. Advancing twice would skip `187:866`
    /// entirely.
    private func advanceOnce() {
        guard !hasAdvanced, isLegend else { return }
        hasAdvanced = true
        onAdvance()
    }
}

/// The gilded frame with whatever picture the content supplies, or the frame's own fallback when
/// there is none. Kept here rather than inside `KultaraPortraitFrame` because loading a bundled
/// content asset is an app concern — `DesignSystem` knows nothing about `ContentRepository`.
struct HisploraFramedImage: View {
    let url: URL?
    let label: String

    var body: some View {
        KultaraPortraitFrame(accessibilityLabel: label) {
            HisploraPortraitContent(url: url)
        }
    }
}

/// What goes *inside* the frame's opening, on its own so the cutscene can wrap it in the reveal
/// while every other screen sets it straight into the frame.
struct HisploraPortraitContent: View {
    let url: URL?

    var body: some View {
        if let url, let image = BundledImage.load(url) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // No picture is a legitimate state, not an error: the sample content ships no
            // portrait, and the frame is still the design's object. The reveal over an empty
            // opening is a wash lifting off a flat ground — undramatic, but not broken.
            Rectangle().fill(Color.black.opacity(0.18))
        }
    }
}

/// The same picture at a resolution the eye cannot resolve — `98:1588`'s covered frame, which the
/// walker rubs off to reach `223:1987`.
///
/// It is deliberately *the photograph*, not a curtain over it. The composition, the colour and the
/// light all stay where they are and only the detail goes, so the frame reads as holding something
/// before a finger has touched it, and the rub reads as bringing that same thing into focus.
///
/// `.interpolation(.none)` is load-bearing: the picture is decoded at a couple of dozen pixels
/// across and drawn at frame size, and SwiftUI's default smoothing would blend the blocks straight
/// back into the blur this replaces.
struct HisploraPortraitCover: View {
    let url: URL?

    var body: some View {
        if let url, let image = BundledImage.pixelated(url) {
            image
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // Nothing to spoil. Matches `HisploraPortraitContent`'s own empty state, so an
            // absent picture does not turn the cover into the only thing on the screen.
            Rectangle().fill(Color.black.opacity(0.18))
        }
    }
}
