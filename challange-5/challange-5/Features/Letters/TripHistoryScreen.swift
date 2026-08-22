import ContentKit
import DesignSystem
import Foundation
import RunEngine
import SwiftUI
import UIStringsKit

/// The History page — a literal reproduction of Figma `791:6537`.
///
/// **This one is drawn, not composed.** Unlike every other screen in the app it is laid out at the
/// frame's own 402-point width and scaled to the device (`TripFrame`), because the page is an
/// editorial spread: cut-outs tucked behind paragraphs at chosen angles, a portrait bleeding off
/// the left margin with a hand-drawn arrow pointing at it, a band of dark paper the text sits
/// inside. Rebuilt as stacks it becomes *a* layout rather than *this* one. `TripFrameLayout.swift`
/// carries the full argument and the cost — chiefly that the canvas does not respond to Dynamic
/// Type, which is why the whole page also carries a spoken label with every word on it in order.
///
/// **Its prose is per quest and it is not sourced.** `QuestHistoryText` holds the frame's own
/// paragraphs for `badung-empat-wajah`; a quest with no entry falls back to `TripHistoryChapters`,
/// which is built from that walk's own lore snapshots and carries the accuracy labels and citations
/// `FR-CP-05` and `FR-CP-06` ask for. The Badung page does not, and that is a decision with an
/// owner recorded on `QuestHistoryText` and in `docs/hisplora-tokens.md`, not an oversight.
struct TripHistoryScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let model: RunSummaryViewModel
    let letter: SealedLetterPresentation
    let onClose: () -> Void

    private var language: ContentLanguage { model.language }

    private var history: QuestHistoryText? {
        QuestHistoryText.byQuestID[letter.questID]
    }

    /// "The Last Tales of Badung", already localized and interpolated by `SealedLettersViewModel`.
    private var headline: String {
        letter.papers.first { $0.kind == .history }?.title
            ?? String(format: UIStrings.string(.journalPaperHistoryTitle, language), letter.title)
    }

    private var region: String { letter.stamps.first?.region ?? "" }

    var body: some View {
        HisploraStage(ground: \.paperTrip, grain: false) {
            VStack(spacing: 0) {
                TripPageBar(
                    title: UIStrings.string(.journalPaperHistoryEyebrow, language),
                    backLabel: UIStrings.string(.tripPageBack, language),
                    shareText: history.map(spoken) ?? "\(model.title)\n\n\(model.progressText)",
                    shareLabel: UIStrings.string(.tripShare, language),
                    onBack: onClose)

                if let history {
                    framePage(history)
                } else {
                    TripHistoryChapters(model: model, letter: letter)
                }
            }
        }
    }

    // MARK: - The frame, band by band

    /// How much of the frame's top the canvas drops.
    ///
    /// 62 of it is the status bar the frame draws and the device supplies. The other 46 is air the
    /// frame needs and the app does not: on the frame the bar is a *graphic* with the masthead
    /// floating well clear of it, while here it is a real 44-point control sitting directly above
    /// the canvas. Trimming both puts the masthead 38 below the bar — where `TripSummaryScreen`
    /// sets its own, so the two pages open the same way.
    private static let topTrim: CGFloat = TripFrame.statusBar + 46

    /// `791:6537` ends at y 3682.
    private static let pageHeight: CGFloat = 3682 - topTrim

    private func framePage(_ history: QuestHistoryText) -> some View {
        TripFramePage(height: Self.pageHeight,
                      accessibilityText: spoken(history),
                      topGround: palette.paperTrip,
                      bottomGround: palette.brownSmoke) {
            masthead
            band1(history).framePlaced(x: 0, y: 245 - Self.topTrim)
            band2(history).framePlaced(x: 0, y: 783 - Self.topTrim)
            band3(history).framePlaced(x: 0, y: 1168 - Self.topTrim)
            band4(history).framePlaced(x: 0, y: 1389 - Self.topTrim)
            band5(history).framePlaced(x: 0, y: 1768 - Self.topTrim)
            band6(history).framePlaced(x: 0, y: 2268 - Self.topTrim)
            band7(history).framePlaced(x: 0, y: 2915 - Self.topTrim)
            band8.framePlaced(x: 0, y: 3349 - Self.topTrim)
        }
    }

    /// `791:6543` — "The Last Tales of" upright at 35, the place leaning at 45.
    ///
    /// The split is taken from the string's own format rather than from "the last word": the title
    /// is `journalPaperHistoryTitle` interpolated with the region, so where the region really is the
    /// tail the two halves are known. Any other title is set whole in the upright cut, because
    /// guessing at a word boundary in an arbitrary language leans a title on its preposition.
    private var masthead: some View {
        titleText
            .multilineTextAlignment(.center)
            .lineSpacing(-8)
            .fixedSize(horizontal: false, vertical: true)
            .framePlaced(x: 20, y: 146 - Self.topTrim, width: 362, alignment: .top)
    }

    private var titleText: Text {
        let upright = Font.system(size: 35, weight: .medium, design: .serif)
        let leaning = Font.system(size: 45, weight: .medium, design: .serif).italic()
        let ink = palette.inkDark.color
        guard !region.isEmpty, headline.hasSuffix(region), headline != region else {
            return Text(headline).font(upright).tracking(-1.05).foregroundColor(ink)
        }
        let head = Text(String(headline.dropLast(region.count)))
            .font(upright).tracking(-1.05).foregroundColor(ink)
        let tail = Text(region).font(leaning).tracking(-1.05).foregroundColor(ink)
        return Text("\(head)\(tail)")
    }

    /// `791:6545` — the plate, the caption under it, and a spray of frangipani over its corner.
    private func band1(_ history: QuestHistoryText) -> some View {
        TripFrameBand(height: 538, background: palette.paperTrip) {
            plate.framePlaced(x: 20, y: 26, width: 362, height: 447)
            TripFrameText(text: history.caption.value(for: language),
                          size: 19, tracking: -0.38, lineHeight: 1.0,
                          color: palette.brownDeep.color)
                .lineLimit(1)
                .framePlaced(x: 90, y: 493)
            HisploraStickerImage(name: "sticker-1-25")
                .framePlaced(x: 5, y: 417, width: 85, height: 97)
        }
    }

    /// The frame's own plate, cropped to whatever window it is given.
    ///
    /// **Not the quest's hero asset**, which was tried and is a different picture: the hero is the
    /// card art the quest list shows, and this page opens on and closes over a wide painting of a
    /// kingdom that the frame chose for it. Substituting one for the other is the page reading as
    /// a different design, which is the thing this screen exists not to do.
    private var plate: some View {
        Color.clear.overlay {
            HisploraTripArtworkImage(HisploraTripArtwork.plate, contentMode: .fill)
        }
        .clipped()
    }

    /// `791:6550` — three paragraphs, a pen rule, and two cut-outs over the right margin.
    private func band2(_ history: QuestHistoryText) -> some View {
        TripFrameBand(height: 385, background: palette.paperTrip) {
            paragraph(history.opening).framePlaced(x: 22, y: 27, width: 362)
            HisploraTripArtworkImage(HisploraTripArtwork.ornament)
                .framePlaced(x: 20, y: 180, width: 254, height: 17.7)
            paragraph(history.kingdoms).framePlaced(x: 22, y: 117, width: 362)
            paragraph(history.everydayLife).framePlaced(x: 22, y: 205, width: 213)
            HisploraStickerImage(name: "sticker-2-02")
                .framePlaced(x: 284, y: 180, width: 179, height: 156)
            HisploraStickerImage(name: "sticker-1-04")
                .framePlaced(x: 208, y: 205, width: 176, height: 160)
        }
    }

    /// `791:6561` — one paragraph on its own.
    private func band3(_ history: QuestHistoryText) -> some View {
        TripFrameBand(height: 221, background: palette.paperTrip) {
            paragraph(history.tension).framePlaced(x: 20, y: 37, width: 362)
        }
    }

    /// `791:6564` — the procession over a band of dark paper, and the one phrase set in gilt.
    private func band4(_ history: QuestHistoryText) -> some View {
        TripFrameBand(height: 379, background: palette.paperTrip) {
            TripFrameGround(token: palette.brownSmoke)
                .framePlaced(x: 0, y: 120, width: 402, height: 259)
            Text("\(Text(history.expedition.value(for: language)).font(.system(size: 17)).foregroundColor(palette.inkCreamWhite.color))\(Text(history.expeditionEmphasis.value(for: language)).font(.system(size: 21, design: .serif).italic()).foregroundColor(palette.inkGiltDeep.color))")
                .tracking(-0.34)
                .lineSpacing(17 * 1.4 - 17 * 1.19)
                .fixedSize(horizontal: false, vertical: true)
                .framePlaced(x: 20, y: 208, width: 362)
            HisploraStickerImage(name: "sticker-3-24")
                .framePlaced(x: -14, y: -20, width: 442, height: 212)
            HisploraStickerImage(name: "sticker-3-27")
                .framePlaced(x: 291, y: 6, width: 62, height: 61)
        }
    }

    /// `791:6570` — the portrait bleeding off the left margin, the arrow, and two paragraphs.
    private func band5(_ history: QuestHistoryText) -> some View {
        TripFrameBand(height: 500, background: palette.paperTrip) {
            HisploraTripArtworkImage(HisploraTripArtwork.king)
                .framePlaced(x: -34, y: 98, width: 222, height: 347)
            HisploraTripArtworkImage(HisploraTripArtwork.arrow)
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(.degrees(1.11))
                .framePlaced(x: 150, y: 191, width: 207.4, height: 35, alignment: .center)
            paragraph(history.lastKing).framePlaced(x: 155, y: 149, width: 227)
            paragraph(history.ruler).framePlaced(x: 210, y: 303, width: 172)
        }
    }

    /// `791:6576` — a full-bleed plate, the open book on it, and the line set on the book.
    private func band6(_ history: QuestHistoryText) -> some View {
        TripFrameBand(height: 647) {
            plate.framePlaced(x: -3.98, y: 92.8, width: 406, height: 611.3)
            HisploraTripArtworkImage(HisploraTripArtwork.torn, contentMode: .fill)
                .frame(width: 168, height: 328)
                .rotationEffect(.degrees(-90))
                .framePlaced(x: 37, y: 352, width: 328, height: 168, alignment: .center)
            TripFrameText(text: history.defeat.value(for: language),
                          size: 15, tracking: -0.3, lineHeight: 1.3,
                          color: palette.inkDark.color)
                .framePlaced(x: 90, y: 389, width: 238)
            HisploraStickerImage(name: "sticker-3-09")
                .framePlaced(x: -25, y: 15, width: 470, height: 321)
        }
    }

    /// `791:6580` — what survived, under a scatter of five cut-outs.
    private func band7(_ history: QuestHistoryText) -> some View {
        TripFrameBand(height: 434, background: palette.paperTrip) {
            paragraph(history.survival).framePlaced(x: 20, y: 69, width: 362)
            HisploraStickerImage(name: "sticker-2-09")
                .framePlaced(x: -64, y: 202, width: 359, height: 204)
            HisploraStickerImage(name: "sticker-1-08")
                .scaleEffect(x: -1, y: 1)
                .framePlaced(x: 286, y: 241.48, width: 96, height: 147)
            HisploraStickerImage(name: "sticker-3-18")
                .framePlaced(x: 371, y: 315.48, width: 46.4, height: 47.2)
            HisploraStickerImage(name: "sticker-2-16")
                .framePlaced(x: 175, y: 184, width: 88, height: 79)
            HisploraStickerImage(name: "sticker-2-18")
                .frame(width: 96, height: 89.2)
                .rotationEffect(.degrees(100.74))
                .framePlaced(x: 317.9, y: 176, width: 105.523, height: 110.937, alignment: .center)
        }
    }

    /// `791:6589` — the closing line, the plaque and the seal.
    private var band8: some View {
        TripFrameBand(height: 333, background: palette.brownSmoke) {
            TripFrameText(text: UIStrings.string(.tripHistoryClosing, language),
                          size: 15, tracking: -0.3, lineHeight: 1.4,
                          color: palette.inkFragments.color, alignment: .center)
                .framePlaced(x: 20, y: 34, width: 362)
            HisploraStickerImage(name: "sticker-3-32")
                .framePlaced(x: 98, y: 100, width: 206, height: 153.731)
            HisploraStickerImage(name: "sticker-2-03")
                .framePlaced(x: 172, y: 75, width: 60.933, height: 65.419)
        }
    }

    /// The body cut every paragraph on this page is set in: SF Pro 17, tracked in, 1.4 line height.
    private func paragraph(_ line: QuestHistoryText.Line) -> TripFrameText {
        TripFrameText(text: line.value(for: language),
                      size: 17, tracking: -0.34, lineHeight: 1.4,
                      color: palette.inkBody.color)
    }

    /// Every word on the canvas, in reading order, for a reader who cannot see it.
    private func spoken(_ history: QuestHistoryText) -> String {
        [headline,
         history.caption.value(for: language),
         history.opening.value(for: language),
         history.kingdoms.value(for: language),
         history.everydayLife.value(for: language),
         history.tension.value(for: language),
         history.expedition.value(for: language) + history.expeditionEmphasis.value(for: language),
         history.lastKing.value(for: language),
         history.ruler.value(for: language),
         history.defeat.value(for: language),
         history.survival.value(for: language),
         UIStrings.string(.tripHistoryClosing, language)]
            .joined(separator: "\n\n")
    }
}

// MARK: - The fallback

/// What a quest with no authored History page gets: its own lore snapshots, in chapters, with the
/// accuracy label and the citations `FR-CP-05` and `FR-CP-06` ask for.
///
/// It reflows and it scales with Dynamic Type, which the frame page does not. That is the trade
/// stated plainly: the drawn page is exact and rigid, this one is honest and flexible, and a quest
/// gets the drawn one only when somebody has written its words down.
private struct TripHistoryChapters: View {
    @Environment(\.hisploraPalette) private var palette

    let model: RunSummaryViewModel
    let letter: SealedLetterPresentation

    private var language: ContentLanguage { model.language }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: KultaraMetrics.md) {
                    Text(model.title)
                        .kultaraFont(.journalLetterTitle)
                        .foregroundStyle(palette.inkDark.color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(model.progressText)
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.brownDeep.color)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, KultaraMetrics.xl)
                .padding(.top, KultaraMetrics.xl)

                ForEach(Array(model.stops.enumerated()), id: \.element.id) { index, stop in
                    chapter(stop, isDark: index % 3 == 2)
                }

                VStack(spacing: KultaraMetrics.xl) {
                    Text(UIStrings.string(.tripHistoryClosing, language))
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.inkFragments.color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    HisploraWaxSeal()
                        .frame(width: 84, height: 84)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, KultaraMetrics.xl)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
                .kultaraSpeckledGround(palette.brownSmoke)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func chapter(_ stop: RunSummaryViewModel.Stop, isDark: Bool) -> some View {
        let heading = isDark ? palette.inkGilt.color : palette.inkDark.color
        let body = isDark ? palette.inkCreamWhite.color : palette.inkBody.color
        let quiet = isDark ? palette.inkFragments.color : palette.inkMuted.color

        return VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
            Text(stop.placeName)
                .kultaraFont(.storySection)
                .foregroundStyle(heading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            ForEach(stop.claims) { claim in
                VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                    Text(claim.block.text)
                        .kultaraFont(.body)
                        .foregroundStyle(body)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(claim.block.accuracyLabel)
                        .kultaraFont(.metadata)
                        .foregroundStyle(quiet)
                    ForEach(Array(claim.citations.enumerated()), id: \.offset) { _, citation in
                        Text(citation)
                            .kultaraFont(.caption)
                            .foregroundStyle(quiet)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if stop.claims.isEmpty {
                Text(UIStrings.string(.tripHistoryNoLore, language))
                    .kultaraFont(.metadata)
                    .foregroundStyle(quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, KultaraMetrics.xl)
        .padding(.vertical, isDark ? 40 : KultaraMetrics.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { if isDark { TripFrameGround(token: palette.brownSmoke) } }
    }
}

#Preview("Trip History") {
    let startedAt = Date(timeIntervalSince1970: 1_770_000_000)
    let run = Run(
        questID: "badung-empat-wajah",
        contentVersion: "2026.09.7",
        language: .en,
        snapshotQuestTitle: "The Last Traces of Badung",
        checkpointCount: 5,
        state: .completed,
        currentCheckpointIndex: 4,
        startedAt: startedAt,
        updatedAt: startedAt.addingTimeInterval(45 * 60),
        completedAt: startedAt.addingTimeInterval(45 * 60))
    let model = RunSummaryViewModel(run: run)
    let letter = SealedLetterPresentation(
        id: run.id,
        questID: run.questID,
        title: "Badung",
        progressText: "5 of 5 checkpoints",
        isComplete: true,
        stamps: [StampPresentation(
            id: "puri-agung-pemecutan",
            placeName: "Puri Agung Pemecutan",
            region: "Badung")],
        heroImageURL: nil,
        accessibilityLabel: "History of the walk through Badung")

    TripHistoryScreen(model: model, letter: letter, onClose: {})
}
