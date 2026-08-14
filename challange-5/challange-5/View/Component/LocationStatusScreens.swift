import ContentKit
import DesignSystem
import SwiftUI

/// The three location states from the Hisplora board — `81:617` (Location Checking), `89:1402`
/// (Location Verified) and `223:2004` (Not Quite There) — as pieces the arrival screen composes.
///
/// They are pieces rather than whole screens because the frames draw less than the requirements
/// demand. Every one of those three frames is a title, a lead and one action, with no clue and no
/// manual override on it. `FR-CP-03` requires the clue to stay re-readable for the whole walk, and
/// `FR-START-10` makes the override mandatory rather than a nicety — so the arrival screen carries
/// the design's heading *and* the controls the design omits. The requirement wins; the discrepancy
/// is recorded here rather than resolved by dropping something.
///
/// The frames are 402 × 874 with every child placed by x/y. Rebuilt as stacks: a layout that only
/// works at one size fails `NFR-A11Y-04` at AX5 on a small device.

/// Which of the three the arrival screen is currently showing.
enum LocationState {
    /// No usable fix yet — `81:617`.
    case checking
    /// A fix, inside the radius and precise enough — `89:1402`. Reached only in passing, since
    /// arrival records immediately, but drawn for the moment it is on screen.
    case verified
    /// A fix, but outside the radius or too coarse to prove otherwise — `223:2004`.
    case notThere
    /// Permission refused. Not a frame on the board; it reuses `223:2004`'s shape because the
    /// walker's situation is the same — they cannot be placed — and the way out differs.
    case denied
}

/// The heading block the location frames share: serif title, muted lead, centred.
struct LocationStateHeading: View {
    @Environment(\.hisploraPalette) private var palette

    let state: LocationState
    let language: ContentLanguage

    var body: some View {
        VStack(spacing: KultaraMetrics.md) {
            Text(UIStrings.string(titleKey, language))
                .font(KultaraTypography.font(.questTitleLarge))
                .foregroundStyle(palette.inkCream.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(UIStrings.string(bodyKey, language))
                .font(.system(size: 15))
                .foregroundStyle(palette.inkDusty.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var titleKey: UIStringKey {
        switch state {
        case .checking: .locationCheckingTitle
        case .verified: .locationVerifiedTitle
        case .notThere: .locationNotThereTitle
        case .denied: .runStartLocationDeniedTitle
        }
    }

    private var bodyKey: UIStringKey {
        switch state {
        case .checking: .locationCheckingBody
        case .verified: .locationVerifiedBody
        case .notThere: .locationNotThereBody
        case .denied: .runStartLocationDeniedBody
        }
    }
}

/// The bounded wait, from Phase 1: elapsed time and a determinate countdown to the manual override.
///
/// The frame draws a static glyph and nothing else, which is exactly the quiet QA reported. What is
/// added is the honest version of a progress indicator — the wait genuinely ends at 60 s, because
/// `FR-ARR-03` says so, and `FR-ARR-05` forbids the indefinite spinner that would otherwise go here.
struct LocationWaitingDetail: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let elapsedText: String
    let countdownText: String?
    let progress: Double

    var body: some View {
        VStack(spacing: KultaraMetrics.xs) {
            Text(String(format: UIStrings.string(.arrivalSearchingElapsed, language), elapsedText))
                .font(.system(size: 13))
                .foregroundStyle(palette.inkDusty.color)
                .monospacedDigit()
            if let countdownText {
                ProgressView(value: progress, total: 1)
                    .tint(palette.inkDusty.color)
                    .frame(maxWidth: 220)
                    .accessibilityHidden(true)
                Text(String(format: UIStrings.string(.arrivalManualCountdown, language), countdownText))
                    .font(.system(size: 13))
                    .foregroundStyle(palette.inkDusty.color)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The clue, on the story flow's paper rather than the museum theme's card.
///
/// `FR-CP-03`, `NFR-SAFE-02` — re-readable for the whole walk, at rest, without re-triggering
/// anything. None of the three frames draws it; all three would be unusable on a real walk without
/// it.
struct LocationClueCard: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let clue: String

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            Text(UIStrings.string(.arrivalClueHeading, language))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.inkMuted.color)
                .textCase(.uppercase)
                .tracking(1.5)
            Text(clue)
                .font(.system(size: 17))
                .foregroundStyle(palette.inkDark.color)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(KultaraMetrics.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paperCream.color)
        .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.xs))
    }
}
