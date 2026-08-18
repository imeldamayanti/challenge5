import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

/// The letter itself, opened — a full-screen page the reader scrolls, not a screen the Journal
/// pushes them out to.
///
/// **This replaces a redirect.** Unsealing an envelope used to hand the reader to `QuestRunView`,
/// which for a finished walk lands on the museum-catalogue summary: a second visual direction, a
/// navigation bar and a back button, reached by an animation that had just spent four seconds
/// saying *this is a letter*. The letter now simply opens. Same snapshots, same requirements — one
/// object.
///
/// **It renders the Run's own snapshots and nothing else** (`FR-DONE-04`, `FR-DONE-05`). Every word
/// on this page was copied into the Run when each checkpoint completed, which is why it is still
/// right after a content correction and still there in airplane mode. `RunSummaryViewModel` is
/// deliberately built without a `ContentRepository`; the only thing reached for by id is the hero
/// picture, which is decoration and is simply absent when the quest is gone.
///
/// **Hisplora throughout, and the seam still falls between whole screens.** The page is a sheet of
/// paper on the printed brown ground, so every ink on it is measured against paper — no museum
/// component is dropped onto the brown, which is the contrast bug `RunRouteMapView.showsChrome`
/// exists to prevent. The lore claims are drawn here rather than by `LoreClaimList` for exactly
/// that reason: that component reads `\.kultaraPalette`, which is not the palette of this screen.
struct JournalLetterView: View {
    @Environment(\.hisploraPalette) private var palette

    private let model: RunSummaryViewModel
    /// The shelf's own record of this walk — the hero picture and the franked stamps, which the
    /// summary model has no repository to look up.
    private let letter: SealedLetterPresentation
    private let onClose: () -> Void

    init(model: RunSummaryViewModel,
         letter: SealedLetterPresentation,
         onClose: @escaping () -> Void) {
        self.model = model
        self.letter = letter
        self.onClose = onClose
    }

    /// The Run's language, never the app's. Switching the interface to English after finishing an
    /// Indonesian walk must not half-translate the page (`NFR-I18N-03`), and the snapshot only
    /// holds the one language anyway.
    private var language: ContentLanguage { model.language }

    var body: some View {
        // Edge to edge, top to bottom. The page *is* the screen here — a sheet floating in a brown
        // margin reads as a card on a shelf, which is the thing the reader has just left.
        // `HisploraStage` stays the wrapper rather than a hand-rolled `ZStack`: it is what registers
        // the packaged fonts and puts the palette in the environment.
        HisploraStage(ground: \.brownMid, grain: true) {
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    sheet
                        .padding(.bottom, KultaraMetrics.xxl)
                }
                .scrollIndicators(.hidden)
                // The paper runs under the status bar rather than stopping below it: a sheet that
                // stops short of the top of the screen reads as a modal that failed to present.
                // The sheet's own top padding is what keeps the words clear of the clock.
                .ignoresSafeArea(edges: .top)

                closeControl
            }
        }
    }

    // MARK: - The sheet

    private var sheet: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xl) {
            masthead
            if letter.heroImageURL != nil { hero }
            divider
            ForEach(model.stops) { stop in
                stopSection(stop)
                divider
            }
            stampsSection
            colophon
        }
        .padding(.horizontal, KultaraMetrics.xl)
        .padding(.bottom, KultaraMetrics.xxl)
        // Clear of the status bar and of the close control, both of which sit over this edge.
        .padding(.top, 76)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paperCream.color)
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            Text(UIStrings.string(.journalSealedHeading, language).uppercased())
                .kultaraFont(.eyebrow)
                .foregroundStyle(palette.inkMuted.color)
            Text(model.title)
                .kultaraFont(.storyDisplay)
                .foregroundStyle(palette.inkDark.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(model.progressText)
                .kultaraFont(.metadata)
                .foregroundStyle(palette.inkMuted.color)
            if model.wasAbandoned {
                // A walk that was put down says so. A page that quietly printed it as finished
                // would be the journal claiming something the reader did not do.
                Text(UIStrings.string(.runAbandonedNote, language))
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.mapMarker.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The quest's picture, taped to the page the way the envelope tapes its own.
    @ViewBuilder private var hero: some View {
        if let url = letter.heroImageURL, let image = BundledImage.load(url) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipped()
                .border(palette.paperLight.color, width: 6)
                .overlay(alignment: .topLeading) { tape.offset(x: -10, y: -12).rotationEffect(.degrees(-8)) }
                .overlay(alignment: .bottomTrailing) { tape.offset(x: 10, y: 12).rotationEffect(.degrees(-8)) }
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var tape: some View {
        if let image = HisploraEnvelopeMetrics.tapeImage {
            image.resizable().aspectRatio(contentMode: .fit).frame(width: 54)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.inkMuted.color.opacity(0.28))
            .frame(height: KultaraMetrics.hairline)
    }

    // MARK: - One stop

    private func stopSection(_ stop: RunSummaryViewModel.Stop) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            Text("\(UIStrings.string(.previewCheckpointsHeading, language).uppercased()) \(stop.orderIndex + 1)")
                .kultaraFont(.eyebrow)
                .foregroundStyle(palette.inkMuted.color)
            Text(stop.placeName)
                .kultaraFont(.questTitle)
                .foregroundStyle(palette.inkDark.color)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(stop.claims) { claim in
                claimBlock(claim)
            }

            if !stop.writtenAnswers.isEmpty {
                VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                    Text(UIStrings.string(.summaryReflectionHeading, language))
                        .kultaraFont(.eyebrow)
                        .foregroundStyle(palette.inkMuted.color)
                    ForEach(Array(stop.writtenAnswers.enumerated()), id: \.offset) { _, answer in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(answer.prompt)
                                .kultaraFont(.metadata)
                                .foregroundStyle(palette.inkMuted.color)
                                .fixedSize(horizontal: false, vertical: true)
                            // The walker's own hand. Set apart from the lore because it is the one
                            // thing on this page nobody authored.
                            Text(answer.text)
                                .kultaraFont(.body)
                                .foregroundStyle(palette.inkDark.color)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(KultaraMetrics.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.paperLight.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One claim with its accuracy label and its sources, both as text.
    ///
    /// `FR-CP-05` puts the epistemic status of every claim in front of the reader and `FR-CP-06`
    /// keeps the sources with it. The Story Reveal's documented exception does not reach here —
    /// this is the record of the walk, and the record carries its provenance.
    private func claimBlock(_ claim: LoreClaimPresentation) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
            Text(claim.block.text)
                .kultaraFont(.body)
                .foregroundStyle(palette.inkBody.color)
                .fixedSize(horizontal: false, vertical: true)
            Text(claim.block.accuracyLabel)
                .kultaraFont(.metadata)
                .foregroundStyle(palette.inkMuted.color)
            ForEach(Array(claim.citations.enumerated()), id: \.offset) { _, citation in
                Text(citation)
                    .kultaraFont(.caption)
                    .foregroundStyle(palette.inkMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - What the walk earned

    @ViewBuilder private var stampsSection: some View {
        if !letter.stamps.isEmpty {
            VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                Text(UIStrings.string(.summaryStampsHeading, language))
                    .kultaraFont(.eyebrow)
                    .foregroundStyle(palette.inkMuted.color)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 108), spacing: KultaraMetrics.lg)],
                    spacing: KultaraMetrics.lg
                ) {
                    ForEach(letter.stamps) { stamp in
                        HisploraStampCard(
                            title: stamp.placeName,
                            subtitle: stamp.region,
                            artworkName: stamp.artworkName)
                    }
                }
            }
        }
    }

    /// Which content version this page was written from. A page that silently disagreed with the
    /// current app would be worse than one that says why (`AD-4`).
    private var colophon: some View {
        Text(model.snapshotNote)
            .kultaraFont(.caption)
            .foregroundStyle(palette.inkMuted.color)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Out

    /// The way out, floating over the page rather than sitting in a bar — a navigation bar here
    /// would be the museum chrome this screen exists without.
    ///
    /// **Dark on paper, not paper on paper.** It used to be a cream disc, which is the colour of
    /// the sheet it sits on: at the top of a full-bleed page that is an invisible control. The disc
    /// is `brownDeep` with `inkCream` on it — 9.63:1, the pairing `HisploraThemeTests` already
    /// measures — and it reads on the sheet and on the ground behind it alike. It is a fixed 44
    /// points, the tap target `NFR-A11Y-06` asks for, rather than padding that happens to add up.
    private var closeControl: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.inkCream.color)
                .frame(width: 44, height: 44)
                .background(palette.brownDeep.color, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(UIStrings.string(.siteMapClose, language))
        .padding(.trailing, KultaraMetrics.lg)
        .padding(.top, KultaraMetrics.sm)
    }
}
