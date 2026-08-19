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
    /// The walk an unsealed letter opens.
    let onOpenRun: (UUID) -> Void
    /// The letter collections, which live in this tab (`FR-SIDE-08`) and are a museum screen.
    var collections: [(id: String, title: String)] = []
    var onOpenCollection: (String) -> Void = { _ in }

    init(
        model: SealedLettersViewModel,
        language: ContentLanguage,
        collections: [(id: String, title: String)] = [],
        onOpenRun: @escaping (UUID) -> Void,
        onOpenCollection: @escaping (String) -> Void = { _ in }
    ) {
        self.model = model
        self.language = language
        self.collections = collections
        self.onOpenRun = onOpenRun
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
        .onAppear { model.reload() }
        .onDisappear { model.cancelOpening() }
    }

    // MARK: - Header

    /// The frame's header row is a `justify-between` with one child in it. The second slot is where
    /// the collections go: they have to be reachable from this tab (`FR-SIDE-08`) and the design
    /// leaves exactly one place for them.
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(UIStrings.string(.journalSealedHeading, language))
                .kultaraFont(.storyDisplay)
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

    // MARK: - The shelf

    private var shelf: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            carousel
            Spacer(minLength: KultaraMetrics.lg)

            // The title and the hint step back once the page is on its way out. The zoom is the
            // last beat before the screen hands over, and a 40-point heading printed across the
            // page it is zooming is two things asking to be read at once.
            VStack(spacing: 0) {
                Text(model.selectedLetter?.title ?? "")
                    .kultaraFont(.storyDisplay)
                    .foregroundStyle(palette.inkDark.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, KultaraMetrics.xl)
                    // The title belongs to whichever envelope is centred, so it changes with it
                    // rather than cross-fading into itself.
                    .id(model.selectedLetter?.id)

                if model.showsSwipeHint {
                    Text(UIStrings.string(.journalSwipeHint, language))
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.inkMuted.color)
                        .padding(.top, KultaraMetrics.sm)
                }
            }
            .opacity(model.stage >= .rising ? 0 : 1)
            .animation(.easeOut(duration: 0.5), value: model.stage)

            Spacer(minLength: KultaraMetrics.lg)

            Button(UIStrings.string(.journalUnsealAction, language)) {
                unseal()
            }
            .buttonStyle(.hisploraPill)
            .disabled(model.stage != .sealed)
            .padding(.horizontal, KultaraMetrics.xl)
            .padding(.bottom, KultaraMetrics.lg)
        }
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
                                wiggles: index == model.selectedIndex && model.showsSwipeHint
                                    && !reduceMotion && !voiceOverEnabled)
                                .frame(width: cardWidth)
                                // The centred card steps aside for the opening drawn over it, so
                                // there is never a second copy of the same envelope on screen.
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
                }
                .contentMargins(.horizontal, inset, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .scrollDisabled(model.stage != .sealed)
                .scrollPosition(id: Binding(
                    get: { model.letters.indices.contains(model.selectedIndex) ? model.selectedIndex : nil },
                    set: { if let index = $0 { model.select(index) } }))

                // **The opening is drawn outside the ScrollView, and that is the whole point.**
                // A `ScrollView` clips its content. The page rises two thirds of a card above the
                // envelope and then grows to 2.1×, which put most of the last two beats outside a
                // 260-point band and cut the top off the page mid-zoom. Same envelope, same place
                // on screen, nothing clipping it.
                if isOpening, let letter = model.selectedLetter {
                    SealedLetterEnvelope(
                        letter: letter,
                        language: language,
                        stage: model.stage,
                        sequence: sequence)
                        .frame(width: cardWidth)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: 260)
        // Each beat carries its own curve and its own length: `.animation(_:value:)` resolves the
        // animation against the stage being moved *to*, so the flap, the rise and the slow zoom no
        // longer share one 900ms ease.
        .animation(sequence.animation(of: model.stage), value: model.stage)
    }

    /// Whether the centred envelope is anywhere past closed.
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
        model.unseal(rendersImmediately: reduceMotion || voiceOverEnabled, onFinish: onOpenRun)
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
