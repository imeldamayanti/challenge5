import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// One walk drawn as a sealed letter: the packaged envelope from `DesignSystem`, franked with what
/// this particular walk actually earned (Figma `511:1421`).
///
/// **The franking is decoration and says so.** Every mark on the paper — the picture taped to it,
/// the stamps down the right, the title along the pocket — is set at the size the frame photographs
/// it, which is too small to be read at an accessibility size and would wreck the object if it
/// grew. It is therefore `accessibilityHidden`, and the same information is carried at full size by
/// the title under the envelope and by the card's own spoken label. Nothing here is the only place
/// something is said (`NFR-A11Y-01`).
struct SealedLetterEnvelope: View {
    @Environment(\.hisploraPalette) private var palette

    let letter: SealedLetterPresentation
    let language: ContentLanguage
    var stage: HisploraEnvelopeStage = .sealed
    var wiggles: Bool = false
    /// Passed through so Reduce Motion reaches the page's own reveal, which is the one beat the
    /// envelope times for itself rather than taking from the caller.
    var sequence: HisploraEnvelopeSequence = HisploraEnvelopeSequence(rendersImmediately: false)

    var body: some View {
        HisploraEnvelope(stage: stage, wiggles: wiggles, sequence: sequence) {
            franking
        } contents: {
            SealedLetterPage(letter: letter, language: language)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(letter.accessibilityLabel)
    }

    /// Everything stuck to the paper, laid out against the frame's own proportions.
    private var franking: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                picture(size: size)
                stamps(size: size)
                title(size: size)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .accessibilityHidden(true)
    }

    /// The photograph taped to the pocket. The quest's hero picture when it ships one, and an aged
    /// blank when it does not — the frame's own slot, left honest rather than filled.
    private func picture(size: CGSize) -> some View {
        ZStack {
            if let url = letter.heroImageURL, let image = BundledImage.load(url) {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(palette.paperWarm.color)
            }
        }
        .frame(width: size.width * 0.2008, height: size.height * 0.4122)
        .clipped()
        .border(palette.paperLight.color, width: 1.5)
        .shadow(color: .black.opacity(0.25), radius: 0.8, x: 0.8, y: 0.8)
        .rotationEffect(.degrees(-2))
        .overlay(alignment: .top) {
            if let tape = HisploraEnvelopeMetrics.tapeImage {
                tape
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width * 0.1042)
                    .offset(y: -size.height * 0.03)
            }
        }
        .offset(x: size.width * 0.0299, y: size.height * 0.312)
    }

    /// Up to six stamps, in the two columns of three the frame franks the envelope with. A seventh
    /// checkpoint is not drawn — the Explorer's Card is where the whole set is listed.
    private func stamps(size: CGSize) -> some View {
        let columns = [0.7655, 0.8759]
        let rows = [0.3103, 0.5287, 0.7471]
        return ForEach(Array(letter.stamps.prefix(6).enumerated()), id: \.element.id) { index, stamp in
            // The drawing, but no franking. At 26 points the frame's own caption is 2.3 points
            // high — texture, not words — so the names are printed on the Explorer's Card, where
            // the same stamp is set six times larger. The picture survives the shrink; the words
            // do not.
            HisploraStampCard(
                title: stamp.placeName,
                subtitle: stamp.region,
                showsFranking: false,
                artworkName: stamp.artworkName)
                .frame(width: size.width * 0.0889, height: size.height * 0.2011)
                .offset(x: size.width * columns[index % 2],
                        y: size.height * rows[index / 2])
        }
    }

    /// The quest's name written along the pocket, in the frame's hand.
    private func title(size: CGSize) -> some View {
        Text(letter.title.lowercased())
            .font(.system(size: max(8, size.height * 0.115), design: .serif))
            .foregroundStyle(palette.brownMid.color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: size.width * 0.65, alignment: .leading)
            .offset(x: size.width * 0.0294, y: size.height * 0.8082)
    }
}

/// The page that comes out of the envelope — `332:1252`, the frame the designer's note describes as
/// *"the detail page comes out of the envelope and zooming in slowly."*
///
/// It is a cover, not the walk: the screen hands over to the run summary the moment the zoom ends,
/// and this exists so that hand-off has something to happen *to*. What it prints is the walk's own
/// snapshots.
struct SealedLetterPage: View {
    @Environment(\.hisploraPalette) private var palette

    let letter: SealedLetterPresentation
    let language: ContentLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(letter.title)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(palette.inkDark.color)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 8)
                .padding(.top, 10)

            ZStack {
                Rectangle().fill(palette.paperWarm.color)
                if let url = letter.heroImageURL, let image = BundledImage.load(url) {
                    image.resizable().aspectRatio(contentMode: .fill)
                }
            }
            .frame(height: 96)
            .clipped()
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Text(letter.progressText)
                .font(.system(size: 9))
                .foregroundStyle(palette.inkMuted.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paperLight.color)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}
