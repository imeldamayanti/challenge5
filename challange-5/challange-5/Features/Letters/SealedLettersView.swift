import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The Journal tab — "Sealed Letters" (Figma `332:1607` → `332:1691` → `332:1252`).
///
/// **Hisplora, not the museum theme.** The Journal is now a story surface rather than a catalogue
/// one: a shelf of paper objects on a brown ground, in the same fixed editorial pairing the run's
/// story flow uses. The seam still falls between whole screens — the letter *collection* pushed
/// from here stays museum, because it is a catalogue and is drawn as one.
///
/// The three frames are three beats of one screen, not three screens: the envelope opens where it
/// stands, holds for the designer's two-to-three seconds, and the page rises out of it and grows.
/// `SealedLettersViewModel` owns that sequence; this view draws whichever beat it is on.
struct SealedLettersView: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private let model: SealedLettersViewModel
    let language: ContentLanguage
    /// The letter whose papers an unsealed envelope hands over to — the modal `791:5551` draws.
    /// Presented by the root rather than here, because the floating tab bar sits above this tab's
    /// own content and a modal underneath it is not a modal.
    let onOpenPapers: (UUID) -> Void
    /// The letter collections, which live in this tab (`FR-SIDE-08`) and are a museum screen.
    var collections: [(id: String, title: String)] = []
    var onOpenCollection: (String) -> Void = { _ in }

    init(
        model: SealedLettersViewModel,
        language: ContentLanguage,
        collections: [(id: String, title: String)] = [],
        onOpenPapers: @escaping (UUID) -> Void,
        onOpenCollection: @escaping (String) -> Void = { _ in }
    ) {
        self.model = model
        self.language = language
        self.collections = collections
        self.onOpenPapers = onOpenPapers
        self.onOpenCollection = onOpenCollection
    }

    var body: some View {
        // `547:2953`'s printed ground, the same sheet the Explorer's Card sits on.
        HisploraStage(ground: \.paperSheet, grain: true) {
            VStack(spacing: 0) {
                header
                if model.isEmpty {
                    emptyShelf
                } else {
                    shelf
                }
            }
            .padding(.bottom, KultaraMetrics.floatingTabBarClearance)
        }
        .onAppear {
            model.reload()
            // The sealed card turns itself over on a loop to show what is written on its back
            // (`791:5637`). Never under Reduce Motion or VoiceOver — see `startFlipCycle`.
            model.startFlipCycle(rendersImmediately: reduceMotion || voiceOverEnabled)
        }
        .onDisappear {
            model.cancelOpening()
        }
    }

    // MARK: - Header

    /// The frame's header row is a `justify-between` with one child in it. The second slot is where
    /// the collections go: they have to be reachable from this tab (`FR-SIDE-08`) and the design
    /// leaves exactly one place for them — `791:5630` is a hidden instance sitting in exactly that
    /// slot, so the row is drawn for two children whether or not the frame fills the second.
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(UIStrings.string(.journalSealedHeading, language))
                // Sans at `.title2`, not the display serif: `791:5601` gives the serif to the
                // letter's own title over the envelope, and this steps back to being the screen's
                // label. See `journalShelfHeading`.
                .kultaraFont(.journalShelfHeading)
                .foregroundStyle(palette.inkDark.color)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: KultaraMetrics.sm)
            if let collection = collections.first {
                Button(UIStrings.string(.journalCollectionsAction, language)) {
                    onOpenCollection(collection.id)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.inkDark.color)
                .kultaraTapTarget()
            }
        }
        .padding(.horizontal, KultaraMetrics.xl)
        .padding(.top, KultaraMetrics.lg)
    }

    /// The curve the words travel on as the envelope opens — the same one the flap swings on, so
    /// the title going and the flap coming up are one movement rather than two that happened to
    /// start together.
    private var openingCurve: Animation? {
        sequence.animation(of: .opening)
    }

    // MARK: - The shelf

    /// `791:5601`'s order, which is not the order this screen shipped with: the letter's title and
    /// what to do with it stand *above* the envelope, the shelf's position is a row of dots below
    /// it, and there is no button at all.
    ///
    /// **The pill is gone because the envelope is the control now.** That is a real accessibility
    /// decision rather than a layout one: a picture with a tap gesture is not something VoiceOver
    /// announces, so the card is a `Button` carrying the pill's own label
    /// (`journalUnsealAction`), and the words that were printed on the pill are printed above it
    /// for everyone else (`NFR-A11Y-05`).
    private var shelf: some View {
        VStack(spacing: 0) {
            // `791:5601` puts 115 points between the header and the title and 187 between the dots
            // and the tab bar, which is what the one-against-two split below approximates: two
            // spacers under the group, one over it. Spacers rather than the frame's literal
            // offsets because every one of these blocks grows with the reader's text size.
            Spacer(minLength: KultaraMetrics.xl)

            // The title and the hint step back the moment the envelope opens. The flap swings up
            // over the words — past the fold it stands 118 of its 120 points above the card — and a
            // title read through a flap is worse than no title. `791:5585` solves the same problem
            // by moving both the card and the title; moving the card turned out to read as a lurch
            // under the reader's finger, so what moves here is nothing, and the words yield.
            VStack(spacing: KultaraMetrics.lg) {
                Text(model.selectedLetter?.title ?? "")
                    .kultaraFont(.journalLetterTitle)
                    // `#151311` — the frame's own ink, which the palette already holds. A shade off
                    // `inkDark`, and the frame is what is written down.
                    .foregroundStyle(palette.buttonFill.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    // The title belongs to whichever envelope is centred, so it changes with it
                    // rather than cross-fading into itself.
                    .id(model.selectedLetter?.id)

                Text(UIStrings.string(.journalTapToOpen, language))
                    .kultaraFont(.journalTapHint)
                    // `#6E2717`, which is `brownDeep` exactly.
                    .foregroundStyle(palette.brownDeep.color)
                    .multilineTextAlignment(.center)
            }
            // 332 of the frame's 402, which is what wraps a long title onto the two lines
            // `791:5626` sets it in rather than running it to both edges.
            .frame(maxWidth: 332)
            .padding(.horizontal, KultaraMetrics.lg)
            .opacity(model.stage == .sealed ? 1 : 0)
            .animation(openingCurve, value: model.stage)

            // 375 − 341 on the frame.
            Spacer(minLength: 0).frame(height: 34)

            carousel

            // 584 − 549.
            Spacer(minLength: 0).frame(height: 35)

            shelfPosition
                .opacity(model.stage == .sealed ? 1 : 0)
                .animation(openingCurve, value: model.stage)

            Spacer(minLength: KultaraMetrics.xl)
            Spacer(minLength: 0)
        }
    }

    /// `791:5632` — one 8-point dot per letter, the centred one inked.
    ///
    /// Decoration, and hidden from VoiceOver: it says the same thing the swipe hint says in words,
    /// and a row of four unlabelled circles is not information anyone can hear.
    private var shelfPosition: some View {
        HStack(spacing: KultaraMetrics.xs) {
            ForEach(model.letters.indices, id: \.self) { index in
                Circle()
                    .fill(index == model.selectedIndex
                          ? palette.inkBody.color
                          // `#D9D9D9` on the frame. Drawn as the same ink at a quarter rather than
                          // as a token of its own: a grey pip is decoration, and a palette token
                          // is a colour something has to be measured against.
                          : palette.inkBody.color.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.selectedIndex)
        .accessibilityHidden(true)
    }

    /// The shelf itself. Neighbours are drawn at three-quarters and half opacity, as the frame
    /// draws them, and scrolling is locked once an envelope is opening — the sequence belongs to
    /// the centred card and swiping mid-zoom would strand it.
    private var carousel: some View {
        GeometryReader { proxy in
            let cardWidth = proxy.size.width * 0.72
            let inset = (proxy.size.width - cardWidth) / 2
            ZStack {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: KultaraMetrics.sm) {
                        ForEach(Array(model.letters.enumerated()), id: \.element.id) { index, letter in
                            SealedLetterEnvelope(
                                letter: letter,
                                language: language,
                                flip: index == model.selectedIndex ? model.flip : .front,
                                // **The nudge runs on every sealed card, not only on a shelf worth
                                // swiping.** It used to be gated on `showsSwipeHint`, which is
                                // false while there is one letter — so the one walk a reader
                                // finishes first sat perfectly still. The wiggle says *this is a
                                // held object* as much as it says *swipe*, and it rides on top of
                                // the turn rather than replacing it: the rock is the card's own
                                // 2D lean, the turn is about its vertical axis.
                                wiggles: index == model.selectedIndex && model.stage == .sealed
                                    && !reduceMotion && !voiceOverEnabled)
                                .frame(width: cardWidth)
                                // **The card is the control now** (`791:5627`, "Tap envelope to
                                // open"): the pill is gone from the frame, so the envelope is a
                                // real `Button` rather than a picture with a tap gesture on it —
                                // which is what gives VoiceOver something to announce and something
                                // to activate (`NFR-A11Y-05`). Its spoken name is the pill's old
                                // label; the card's own description is on the envelope inside.
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityLabel(
                                    "\(letter.accessibilityLabel). "
                                    + UIStrings.string(.journalUnsealAction, language))
                                // The swipe survives here and nowhere else. `791:5601` draws it as
                                // a row of dots, and a row of unlabelled circles is not something
                                // anyone can hear (`NFR-A11Y-05`) — so the words the shelf used to
                                // print under the title are spoken instead, whenever there is in
                                // fact more than one letter to swipe between.
                                .accessibilityHint(tapHint)
                                .onTapGesture {
                                    if index == model.selectedIndex { unseal() }
                                }
                                .accessibilityAction { if index == model.selectedIndex { unseal() } }
                                // The centred card steps aside for the opening drawn over it, so
                                // there is never a second copy of the same envelope on screen. Both
                                // are the same envelope at the same size in the same place, so the
                                // swap is invisible — which is the whole reason the opening can be
                                // drawn somewhere the scroll view is not clipping it.
                                .opacity(index == model.selectedIndex && isOpening ? 0 : 1)
                                .scrollTransition { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0.5)
                                        .scaleEffect(phase.isIdentity ? 1 : 0.75)
                                }
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                    // **The half-card gutter is padding, not a content margin.** As a
                    // `contentMargins(_:for: .scrollContent)` the shelf drew its one envelope 42
                    // points left of the middle — the margin moves the content but the resting
                    // scroll offset is still taken from the content's own origin, so a shelf that
                    // cannot scroll at all sat off-centre. Padding is part of the layout, so a
                    // single card is centred by arithmetic rather than by where a scroll view
                    // happens to come to rest.
                    .padding(.horizontal, inset)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                // **A scroll view clips, and this card moves outside itself.** The turn is a
                // `rotation3DEffect` with perspective: the near edge of a card at 90° is drawn
                // wider than the card's own frame, and the shelf's content is exactly the width of
                // its viewport — so the addressed side lost a vertical strip off its right-hand
                // edge every time it came round. The nudge does the same thing to the corners.
                // Nothing here needs the clip: the neighbours it would cut are off-screen anyway.
                .scrollClipDisabled()
                .scrollDisabled(model.stage != .sealed)
                .scrollPosition(id: Binding(
                    get: { model.letters.indices.contains(model.selectedIndex) ? model.selectedIndex : nil },
                    set: { if let index = $0 { model.select(index) } }))

                // **The opening is drawn outside the ScrollView, and it plays where the card
                // stands.** Outside, because a scroll view clips and the sheets leave the band.
                // *In place*, because the alternative was tried and is worse: `791:5585` draws the
                // open envelope 1.172× the sealed one and 73.8 points lower, and animating the card
                // into that reads as the envelope lurching sideways out from under the reader's
                // finger at the exact moment they tap it. The frame is a still of an open envelope
                // laid out for a screen with no header, not a keyframe of this movement — the
                // opening the shelf shipped with holds the card still and swings the flap, and that
                // is what it goes on doing.
                if isOpening, let letter = model.selectedLetter {
                    SealedLetterEnvelope(
                        letter: letter,
                        language: language,
                        stage: model.stage,
                        flip: model.flip,
                        sequence: sequence)
                        .frame(width: cardWidth)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // The band is the frame's own: 402 × 174, which is exactly the card at 0.72 of the width
        // with nothing above or below it. A fixed 260 was a guess that left the dots and the title
        // further from the envelope than `791:5601` puts them, and it did not follow the width.
        .aspectRatio(402.0 / 174.0, contentMode: .fit)
        // Each beat carries its own curve and its own length: `.animation(_:value:)` resolves the
        // animation against the stage being moved *to*, so the flap, the rise and the slow zoom no
        // longer share one 900ms ease.
        .animation(sequence.animation(of: model.stage), value: model.stage)
        // The turn is its own sequence with its own beats, and it moves the whole card rather than
        // anything inside it.
        .animation(sequence.animation(ofFlip: model.flip), value: model.flip)
    }

    /// What the card's own control says it does, and — on a shelf with more than one letter — that
    /// the shelf can be swiped.
    private var tapHint: String {
        let tap = UIStrings.string(.journalTapToOpen, language)
        guard model.showsSwipeHint else { return tap }
        return tap + ". " + UIStrings.string(.journalSwipeHint, language)
    }

    /// Whether the centred envelope is anywhere past closed.
    ///
    /// The turn is deliberately not part of this: a card turning over is still a sealed card on the
    /// shelf, drawn by the carousel like every other one.
    private var isOpening: Bool { model.stage != .sealed }

    /// The timings this reader gets. Zero-length throughout under Reduce Motion or VoiceOver, where
    /// the opening is a cut rather than a skipped animation.
    private var sequence: HisploraEnvelopeSequence {
        HisploraEnvelopeSequence(rendersImmediately: reduceMotion || voiceOverEnabled)
    }

    private func unseal() {
        // Shape and sound both: the seal breaking is a physical event, and a haptic is what the
        // frame's "visual or sound effects" note buys on a device with no packaged audio.
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
        model.unseal(rendersImmediately: reduceMotion || voiceOverEnabled, onFinish: onOpenPapers)
    }

    // MARK: - Nothing on the shelf yet

    private var emptyShelf: some View {
        VStack(spacing: KultaraMetrics.lg) {
            Spacer()
            HisploraEnvelope {
                EmptyView()
            }
            .frame(maxWidth: 240)
            .opacity(0.45)
            .accessibilityHidden(true)
            Text(UIStrings.string(.journalSealedEmptyTitle, language))
                .kultaraFont(.questTitle)
                .foregroundStyle(palette.inkDark.color)
            Text(UIStrings.string(.journalSealedEmptyBody, language))
                .kultaraFont(.body)
                .foregroundStyle(palette.inkMuted.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, KultaraMetrics.xl)
        .frame(maxWidth: .infinity)
    }
}
