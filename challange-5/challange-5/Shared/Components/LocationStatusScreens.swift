import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

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
        // 12 points between the two, as `223:2004` sets them; the tracking is the frame's as well
        // — −0.8 on the 40-point serif, −0.45 on the 15-point lead.
        VStack(spacing: KultaraMetrics.md) {
            Text(UIStrings.string(titleKey, language))
                .font(KultaraTypography.font(.questTitleLarge))
                .tracking(-0.8)
                .foregroundStyle(palette.inkCream.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(UIStrings.string(bodyKey, language))
                .font(.system(size: 15))
                .tracking(-0.45)
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
        .kultaraSpeckledGround(palette.paperCream)
        .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.xs))
    }
}

/// `1:4458` ("Location Verified" on the New Hisplora board) — the screen the walk shows the moment
/// the fix lands, between the arrival screen and the story.
///
/// It is a whole screen rather than another piece of `arrivalScreen` because it is a *stage*: the
/// arrival has already been recorded when this draws, so the countdown, the override and the two
/// arrival actions no longer apply to anything. The pieces above stay pieces — `.verified` is still
/// one of `LocationState`'s cases, and `LocationStateHeading` draws this screen's heading, so the
/// four states cannot drift into four different typographies.
///
/// Two deviations from the frame, both recorded rather than resolved by dropping something:
///
/// - **The map is authored, not photographed.** The frame pastes a street-map screenshot with three
///   pins on it. `FR-MAP-01`/`FR-OFF-03` rule out live map imagery, not a bundled picture — so what
///   fills the slot is the checkpoint's own `Place.approachMap` where content ships one
///   (`ApproachMapView`, citation and all), and `RunRouteMapView`'s projected canvas everywhere
///   else. The caller passes whichever, so this file keeps knowing nothing about routes or places.
/// - **The scroll is `1:4467`'s own art**, by way of `HisploraMapScroll`. It stood in as
///   `HisploraParchmentSheet` — the vertical rolled sheet the task screens use — until the frame's
///   asset was pulled: the real one is a *horizontal* scroll on gold-capped rods, and it bleeds
///   19 points past each edge of the screen rather than sitting inside the content column. Both
///   differences are visible at a glance, which is why the stand-in did not survive.
struct LocationVerifiedScreen<MapContent: View>: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    /// The quest's title, for the header. Content, never a literal (`AD-4`, `FR-RUN-06`).
    let questTitle: String
    let onContinue: () -> Void
    /// The frame's back chevron. It leaves the walk's screen; it does not undo the arrival, which
    /// is already written (`FR-RUN-01`).
    let onBack: () -> Void
    @ViewBuilder let map: MapContent

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 0) {
                        // The frame sets the heading at y = 156 under a header ending at 108.
                        Spacer(minLength: 48)
                        LocationStateHeading(state: .verified, language: language)
                        // The frame starts the scroll at y = 205, which is 21 points *above* where
                        // the lead's box ends — the two overlap, because the scroll's top edge dips
                        // in the middle and the lead sits in the dip. Reproduced as a small
                        // positive gap instead: the overlap is with the text's box and not its ink,
                        // and a negative one would collide at the accessibility sizes where the
                        // lead genuinely wraps to three lines — so the gap closes to nothing and
                        // no further.
                        Spacer(minLength: 0)
                        HisploraMapScroll { map }
                            // The scroll runs x −19…420 on a 402-point screen while this column is
                            // the frame's 362. Escaping by the column's margin plus the bleed is
                            // what gets it to its drawn width; clipping it to the column would put
                            // both rods inside the screen and make it a different object.
                            .padding(.horizontal, -(20 + HisploraMapScrollMetrics.screenBleed))
                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                // The scroll is drawn wider than this view, so the scroll view must not crop it.
                .scrollClipDisabled()
            }
            // 20 each side, which leaves the frame's 362-point content column on a 402-point screen.
            .padding(.horizontal, 20)
            // Pinned rather than stacked, for the reason the arrival screen's actions are: the frame
            // holds the action a fixed distance off the home indicator however the lead above wraps.
            .safeAreaInset(edge: .bottom) {
                Button(UIStrings.string(.locationVerifiedContinue, language), action: onContinue)
                    .buttonStyle(.hisploraLightPill)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
            }
        }
    }

    /// The quest's name centred with the chevron over it on the left — `1:4476`/`1:4477`, the same
    /// header the cutscene draws, and a `ZStack` for the same reason: a long title stays centred
    /// instead of being pushed off by the chevron's width.
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
                    accessibilityLabel: UIStrings.string(.locationNotThereBack, language),
                    size: 24,
                    action: onBack)
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 13)
    }
}
