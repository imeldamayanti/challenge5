import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The Discovery page — a literal reproduction of Figma `949:2461`.
///
/// It is what "Read Story" on the New Discovery popup opens, which is what a proximity
/// notification opens (`670:1826` → `1108:2780` → here). One place, one story, one control at the
/// foot.
///
/// **Drawn, not composed**, on exactly the terms `TripFrameLayout.swift` sets out for the two
/// Journal pages: laid out at the frame's own 402-point width and scaled, so the photographs, the
/// cut-outs tucked over the right margin and the band of dark paper the closing paragraph sits
/// inside land where somebody put them. The cost is the same one, stated the same way — **the
/// canvas does not respond to Dynamic Type** — and it is paid for the same way, with a spoken label
/// carrying every word in reading order. The bar above the canvas and the button inside it are
/// ordinary controls and behave normally.
///
/// **Its prose is per sidequest and it is not sourced.** `SideQuestDiscoveryText` holds the frame's
/// paragraphs for `sq-park23`; a sidequest with no entry falls back to `SideQuestDiscoveryLore`,
/// which is that sidequest's own authored lore with the accuracy labels and citations `FR-CP-05`
/// and `FR-CP-06` ask for. The drawn page does not carry them, and that is a recorded decision with
/// an owner — see the note on `SideQuestDiscoveryText`.
struct SideQuestDiscoveryScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let presentation: SideQuestDiscoveryPresentation
    let onClose: () -> Void

    private var language: ContentLanguage { presentation.language }

    private var page: SideQuestDiscoveryText? {
        SideQuestDiscoveryText.bySideQuestID[presentation.sideQuestID]
    }

    var body: some View {
        HisploraStage(ground: \.paperTrip, grain: false) {
            VStack(spacing: 0) {
                TripPageBar(
                    title: UIStrings.string(.discoveryPageTitle, language),
                    backLabel: UIStrings.string(.tripPageBack, language),
                    onBack: onClose)

                if let page {
                    framePage(page)
                } else {
                    SideQuestDiscoveryLore(presentation: presentation, onShare: nil)
                }
            }
        }
    }

    // MARK: - The frame, band by band

    /// How much of the frame's top the canvas drops: the 62-point status bar the frame draws and
    /// the device supplies, plus the 46 points of the frame's own title row, which `TripPageBar`
    /// replaces with a real control. The same trim `TripHistoryScreen` uses, so the two pages open
    /// their mastheads at the same distance below the bar.
    private static let topTrim: CGFloat = TripFrame.statusBar + 46

    /// `949:2461` ends at y 1866.
    private static let pageHeight: CGFloat = 1866 - topTrim

    private func framePage(_ page: SideQuestDiscoveryText) -> some View {
        TripFramePage(height: Self.pageHeight,
                      accessibilityText: page.spoken(for: language),
                      topGround: palette.paperTrip,
                      // `949:2490`'s dark block runs to the foot of the last band, so an
                      // overscroll at the bottom shows brown rather than a strip of cream.
                      bottomGround: palette.brownSmoke) {
            masthead(page)
            plates(page).framePlaced(x: 0, y: 245 - Self.topTrim)
            arrivalBand(page).framePlaced(x: 0, y: 783 - Self.topTrim)
            strategyBand(page).framePlaced(x: 0, y: 1168 - Self.topTrim)
            landingBand(page).framePlaced(x: 0, y: 1389 - Self.topTrim)
        }
    }

    /// `949:2466` — New York Medium 35, tracked in, set solid over two lines.
    ///
    /// The frame breaks it as "The Great / Majapahit Landing" with an explicit line break rather
    /// than by wrapping. Reproduced as a wrap at the available width: a hard break belongs to one
    /// string in one language, and this table carries two.
    private func masthead(_ page: SideQuestDiscoveryText) -> some View {
        TripFrameText(text: page.headline.value(for: language),
                      size: 35, weight: .medium, design: .serif,
                      tracking: -1.05, lineHeight: 1.0,
                      color: palette.inkDark.color, alignment: .center)
            .lineSpacing(-8)
            .framePlaced(x: 20, y: 146 - Self.topTrim, width: 362, alignment: .top)
    }

    /// `949:2468` — the two photographs, the binoculars over their seam, and the caption.
    private func plates(_ page: SideQuestDiscoveryText) -> some View {
        TripFrameBand(height: 538, background: palette.paperTrip) {
            // The upper plate is a square photograph shown in a 362 × 239 window, top-aligned and
            // cropped — the frame's own `h-[151.46%]`, which is 362/239. `.fill` on a square in a
            // wider box crops top and bottom equally, so the window is filled by a square laid
            // over it and clipped instead, which crops from the bottom the way the frame does.
            Color.clear
                .overlay(alignment: .top) {
                    HisploraTripArtworkImage(HisploraTripArtwork.discoveryGate, contentMode: .fill)
                        .frame(width: 362, height: 362)
                }
                .clipped()
                .framePlaced(x: 20, y: 26, width: 362, height: 239)

            Color.clear
                .overlay {
                    HisploraTripArtworkImage(HisploraTripArtwork.discoveryGrove, contentMode: .fill)
                }
                .clipped()
                .framePlaced(x: 20, y: 270, width: 362, height: 203)

            TripFrameText(text: page.caption.value(for: language),
                          size: 19, tracking: -0.38, lineHeight: 1.0,
                          color: palette.brownDeep.color, alignment: .center)
                .framePlaced(x: 20, y: 493, width: 362, alignment: .top)

            HisploraStickerImage(name: "sticker-3-26")
                .framePlaced(x: 6, y: 436, width: 90, height: 65.2)
        }
    }

    /// `949:2474` — three paragraphs, the highlighter stroke under the last phrase of the third,
    /// and two cut-outs over the right margin.
    private func arrivalBand(_ page: SideQuestDiscoveryText) -> some View {
        TripFrameBand(height: 385, background: palette.paperTrip) {
            paragraph(page.here).framePlaced(x: 22, y: 27, width: 362)
            paragraph(page.before).framePlaced(x: 22, y: 117, width: 334)

            // Drawn before the paragraph so the stroke sits *under* the words, which is what a
            // highlighter does and what `949:2477`'s z-order has.
            HisploraTripArtworkImage(HisploraTripArtwork.marker)
                .framePlaced(x: 16, y: 317, width: 133, height: 15)
            paragraph(page.arrival).framePlaced(x: 22, y: 205, width: 199)

            HisploraStickerImage(name: "sticker-1-21")
                .framePlaced(x: 247, y: 173, width: 214, height: 159)
            HisploraStickerImage(name: "sticker-2-28")
                .framePlaced(x: 208, y: 211, width: 166, height: 144)
        }
    }

    /// `949:2485` — one justified paragraph on its own.
    private func strategyBand(_ page: SideQuestDiscoveryText) -> some View {
        TripFrameBand(height: 221, background: palette.paperTrip) {
            paragraph(page.strategy)
                .framePlaced(x: 20, y: 37, width: 362)
        }
    }

    /// `949:2488` — the procession over dark paper, the name in gilt italic, and the one control.
    private func landingBand(_ page: SideQuestDiscoveryText) -> some View {
        TripFrameBand(height: 477, background: palette.paperTrip) {
            TripFrameGround(token: palette.brownSmoke)
                .framePlaced(x: 0, y: 120, width: 402, height: 357)

            landingText(page)
                .tracking(-0.34)
                .lineSpacing(17 * 1.4 - 17 * 1.19)
                .fixedSize(horizontal: false, vertical: true)
                .framePlaced(x: 20, y: 208, width: 362)

            HisploraStickerImage(name: "sticker-3-24")
                .framePlaced(x: -14, y: -20, width: 442, height: 212)
            HisploraStickerImage(name: "sticker-3-27")
                .framePlaced(x: 291, y: 6, width: 62, height: 61)

            // Last, so nothing declared above it can take a tap meant for the control. A
            // decorative layer over a button is the exact defect `HisploraJournalCard`'s torn
            // sheet shipped with, and `.clipped()` clips drawing rather than touches.
            saveAndShare(page)
                .framePlaced(x: 20, y: 374, width: 362, height: 58)
        }
    }

    /// `949:2492` — a real `ShareLink` handing over plain text.
    ///
    /// The recap card (`FR-DONE-06`) is still unbuilt, so the label says what the control does:
    /// "Save and Share" hands the system sheet the page's own words, which every share target can
    /// keep. When the card exists it replaces the `item` and nothing else here changes — the same
    /// arrangement `TripPageBar.shareState` already documents.
    private func saveAndShare(_ page: SideQuestDiscoveryText) -> some View {
        ShareLink(item: page.spoken(for: language)) {
            Text(UIStrings.string(.discoverySaveAndShare, language))
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.34)
                .foregroundStyle(palette.inkOnButton.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.buttonFill.color, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// `949:2491` — one paragraph with the name set larger, in serif italic and in gilt.
    private func landingText(_ page: SideQuestDiscoveryText) -> Text {
        let body = Font.system(size: 17)
        let name = Font.system(size: 21, design: .serif).italic()
        return Text(page.landingLead.value(for: language))
            .font(body).foregroundColor(palette.inkCreamWhite.color)
            + Text(page.landingName.value(for: language))
                .font(name).foregroundColor(palette.inkGiltDeep.color)
            + Text(page.landingTail.value(for: language))
                .font(body).foregroundColor(palette.inkCreamWhite.color)
    }

    /// The body cut every paragraph on this page is set in: SF Pro 17, tracked in, 1.4 line height.
    private func paragraph(_ line: SideQuestDiscoveryText.Line) -> TripFrameText {
        TripFrameText(text: line.value(for: language),
                      size: 17, tracking: -0.34, lineHeight: 1.4,
                      color: palette.inkBody.color)
    }
}

// MARK: - What a sidequest with no drawn page gets

/// The sidequest's own authored lore, in the shape `SideQuestStoryView` already prints it: each
/// block with its accuracy label and its citations.
///
/// It reflows and it scales with Dynamic Type, which the drawn page does not. Same trade
/// `TripHistoryChapters` records for the History page — the drawn one is exact and rigid, this one
/// is honest and flexible, and a place gets the drawn one only once somebody has written its words
/// down.
struct SideQuestDiscoveryLore: View {
    @Environment(\.hisploraPalette) private var palette

    let presentation: SideQuestDiscoveryPresentation
    /// `nil` on the Discovery page, which has its own bar; a closure where a caller wants the
    /// closing control.
    let onShare: (() -> Void)?

    private var language: ContentLanguage { presentation.language }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                Text(presentation.title)
                    .font(.system(size: 35, weight: .medium, design: .serif))
                    .tracking(-1.05)
                    .foregroundStyle(palette.inkDark.color)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(presentation.placeName)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.brownDeep.color)
                    .frame(maxWidth: .infinity, alignment: .center)

                ForEach(presentation.claims) { claim in
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

                if let onShare {
                    Button(UIStrings.string(.discoverySaveAndShare, language), action: onShare)
                        .buttonStyle(HisploraPillButtonStyle(ring: nil))
                }
            }
            .padding(.horizontal, KultaraMetrics.xl)
            .padding(.vertical, KultaraMetrics.xl)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview("Discovery — the drawn page") {
    SideQuestDiscoveryScreen(
        presentation: SideQuestDiscoveryPresentation(
            sideQuestID: "sq-park23",
            title: "Four Directions (test)",
            placeName: "Park 23 XXI",
            synopsis: "You're on a battlefield. The last tale of Badung.",
            claims: [],
            language: .en),
        onClose: {})
}

#Preview("Discovery — the lore fallback") {
    SideQuestDiscoveryScreen(
        presentation: SideQuestDiscoveryPresentation(
            sideQuestID: "sq-badung-catur-muka",
            title: "Four Directions",
            placeName: "Catur Muka",
            synopsis: "Catur Muka faces every direction at once.",
            claims: [LoreClaimPresentation(
                id: 0,
                block: LoreBlockPresentation(
                    id: 0,
                    text: "Each of the statue's four faces looks straight down one arm of the junction.",
                    accuracyLabel: "Documented",
                    appearance: .documented,
                    ink: .documented),
                citations: ["BELUM DIVERIFIKASI — placeholder citation"])],
            language: .en),
        onClose: {})
}
