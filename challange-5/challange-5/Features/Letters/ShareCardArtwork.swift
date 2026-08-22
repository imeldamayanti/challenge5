import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

/// The recap card a walker can send to somebody who does not have the app. `FR-DONE-06`, `c2` phase 5.
///
/// **Everything on it comes from the Run's own snapshots** (`AD-4`, `FR-RUN-06`). Not from live
/// content: a card is a record of a walk somebody took, and it must keep saying the same thing after
/// a content correction, after a place is withdrawn, and after the app stops shipping that quest.
///
/// What is deliberately **not** on it, and each is a privacy decision rather than a layout one:
///
/// - **No coordinates and no accuracy.** Neither ever leaves the device in a shareable form
///   (`NFR-PRIV-02`); a card is the one artefact designed to leave it entirely.
/// - **No timestamp finer than the day.** A time of day plus a named place is a statement about
///   where a person was and when, to the minute, forwarded to strangers.
/// - **No written answers unless the walker opts in, per share.** They are the one thing on a
///   summary nobody else authored, and consent to share once is not consent to share always.
struct ShareCardArtwork: View {

    let questTitle: String
    let placeNames: [String]
    let stampCount: Int
    let dayText: String
    /// Empty unless the walker chose to include them for this card.
    let reflections: [String]
    let language: ContentLanguage
    /// Passed in rather than read from the environment: an `ImageRenderer` draws outside the view
    /// tree, so a card rendered off-screen would otherwise get the palette's defaults instead of
    /// the app's.
    let palette: HisploraPalette

    /// A fixed canvas rather than a rendered screen. A share card is an image with one job, and
    /// letting it reflow with Dynamic Type would make every walker's card a different picture.
    static let size = CGSize(width: 1080, height: 1350)

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(UIStrings.text(.shareCardEyebrow).value(for: language))
                .kultaraFont(.metadata)
                .foregroundStyle(palette.inkQuiet.color)

            Text(questTitle)
                .kultaraFont(.questTitleLarge)
                .foregroundStyle(palette.inkDark.color)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(palette.trackDim.color)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(placeNames.enumerated()), id: \.offset) { _, name in
                    HStack(spacing: 14) {
                        Circle()
                            .fill(palette.mapMarker.color)
                            .frame(width: 10, height: 10)
                        Text(name)
                            .kultaraFont(.body)
                            .foregroundStyle(palette.inkDark.color)
                    }
                }
            }

            if !reflections.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(reflections.enumerated()), id: \.offset) { _, line in
                        Text("“\(line)”")
                            .kultaraFont(.body)
                            .italic()
                            .foregroundStyle(palette.inkQuiet.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Text(dayText)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkQuiet.color)
                Spacer()
                Text(UIStrings.text(.shareCardStampCount).value(for: language)
                    .replacingOccurrences(of: "{count}", with: "\(stampCount)"))
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkQuiet.color)
            }
        }
        .padding(72)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(palette.paperSheet.color)
    }

    /// Renders to PNG bytes at the fixed canvas size.
    ///
    /// `ImageRenderer` rather than a `UIGraphicsImageRenderer` over a hosting controller: this view
    /// has no interaction, no scroll and no environment beyond what it is handed, so the simpler
    /// path is also the correct one.
    @MainActor func pngData() -> Data? {
        let renderer = ImageRenderer(content: self)
        renderer.proposedSize = ProposedViewSize(Self.size)
        // 1× — the canvas is already 1080 points wide, and a 3× render would be a 9 MB card for no
        // visible gain past the 10 MiB bucket cap.
        renderer.scale = 1
        return renderer.uiImage?.pngData()
    }
}
