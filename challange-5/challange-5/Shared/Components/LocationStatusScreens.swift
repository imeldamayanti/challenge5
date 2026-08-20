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
///
/// **`LocationCheckingScreen` is a fourth, later addition** — `178:675` on the separate Ngalcer
/// board, replacing `81:617`'s brown checking state with its own quiet paper screen for the
/// checking moment specifically. `paperLight`/`inkDark`/`inkMuted` were sampled and measured for
/// this frame before the screen itself was built, which is why they were already sitting in
/// `HisploraPalette` unused. `LocationState.checking` and this file's brown `LocationStateHeading`
/// rendering of it stay — `SideQuestArrivalView` still shows `.checking` inline on the brown
/// ground, and nothing asked for that flow to change too.

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

/// `178:675` ("Location Checking" on the Ngalcer board) — the arrival screen's checking moment,
/// as its own quiet paper screen rather than a state folded into the brown `arrivalScreen`.
/// `QuestRunView` shows this for the fixed 3 s hold before `arrivalScreen` reveals whatever the
/// sampler actually found; nothing here reads `LocationState` because there is only one thing to
/// say while checking, and no map or actions belong on a screen that never resolves anything.
///
/// **The blue location glyph is rebuilt from SF Symbols, not shipped as art.** The frame's icon is
/// Apple's own Location Services badge — the same rounded-square-and-arrow iOS already draws in
/// Settings and in the system permission prompt this screen appears right after
/// (`Services/LocationService.swift`'s `requestWhenInUseAuthorization`) — so reproducing it as
/// `location.fill` on a blue ground keeps it resolution-independent rather than shipping a fourth
/// copy of an icon iOS already owns.
struct LocationCheckingScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let onBack: () -> Void

    var body: some View {
        HisploraStage(ground: \.paperLight) {
            VStack(spacing: 0) {
                HStack {
                    HisploraBackButton(
                        accessibilityLabel: UIStrings.string(.locationNotThereBack, language),
                        ink: \.inkDark,
                        action: onBack)
                    Spacer(minLength: 0)
                }
                .padding(.top, 13)

                // `178:679`'s title sits at y = 437 of an 874-tall frame; 292 is what remains once
                // the back row's own 57 points (13 padding + the 44-point tap target) come out.
                Spacer(minLength: 292)
                glyph
                // 437 − (349 + 63.19): the title starts 25 under the glyph's own box.
                Spacer(minLength: 25)
                VStack(spacing: 8) {
                    Text(UIStrings.string(.locationCheckingTitle, language))
                        .font(.system(size: 25))
                        .tracking(-0.5)
                        .foregroundStyle(palette.inkDark.color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(UIStrings.string(.locationCheckingBody, language))
                        .font(.system(size: 17))
                        .tracking(-0.51)
                        .foregroundStyle(palette.inkMuted.color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
        }
    }

    /// `178:681` — a 63-point rounded square, reproduced in SF Symbols rather than shipped as a
    /// PNG (see the type doc above).
    private var glyph: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(
                colors: [Color(red: 0.36, green: 0.68, blue: 0.98),
                         Color(red: 0.09, green: 0.48, blue: 0.98)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 63.19, height: 63.19)
            .overlay {
                Image(systemName: "location.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            // Decoration: the header right below already says what is happening.
            .accessibilityHidden(true)
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
/// - **The map is drawn, not photographed.** The frame pastes a street-map screenshot with three
///   pins on it. `FR-MAP-01`/`FR-OFF-03` rule out map imagery, so what fills the slot is the same
///   `RunRouteMapView` canvas the arrival screen uses — the caller passes it in, so this file keeps
///   knowing nothing about routes.
/// - **The scroll is the packaged parchment**, `HisploraParchmentSheet`. The frame draws a rod-and-
///   sheet scroll that ships nowhere in this project; the parchment is the same object drawn the
///   way the design system already draws it, and swapping in a real export is a change to that one
///   component rather than to this screen.
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
                        Spacer(minLength: 40)
                        LocationStateHeading(state: .verified, language: language)
                        // 84 as drawn, between the lead's baseline and the top of the scroll.
                        Spacer(minLength: 40)
                        HisploraParchmentSheet { map }
                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
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
