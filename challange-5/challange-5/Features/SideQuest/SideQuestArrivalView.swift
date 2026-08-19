import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The sidequest's arrival gate — `FR-SIDE-02`, which is `FR-ARR-01` unchanged.
///
/// It reuses `LocationStatusScreens` wholesale: the same three Hisplora frames, the same bounded
/// wait, the same "inside the radius but the fix is too coarse" reading of the rule. What it does
/// not carry is the run screen's clue card and its abandon control — a sidequest has one stop, no
/// route to be clued along, and nothing to abandon.
///
/// The manual override is a real control from the first second (`FR-START-10`): before it is
/// offerable it shows the countdown, and either way it opens the sheet where the explanation and
/// the confirm live. A control the walker needs when GPS has failed cannot be the quietest line on
/// a scrolling screen.
struct SideQuestArrivalView: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let placeName: String
    let sampling: ArrivalSampling
    let onBack: () -> Void

    var body: some View {
        HisploraStage(ground: \.brownMid) {
            VStack(spacing: 0) {
                HStack {
                    HisploraBackButton(
                        accessibilityLabel: UIStrings.string(.storyRevealBack, language),
                        action: onBack)
                    Spacer()
                }
                .padding(.horizontal, KultaraMetrics.lg)
                .padding(.top, KultaraMetrics.lg)

                ScrollView {
                    VStack(spacing: KultaraMetrics.xl) {
                        Text(placeName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.inkDusty.color)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        LocationStateHeading(state: sampling.locationState, language: language)

                        if sampling.locationState == .checking {
                            LocationWaitingDetail(
                                language: language,
                                elapsedText: sampling.searchingElapsedText,
                                countdownText: sampling.manualOverrideCountdownText,
                                progress: sampling.manualOverrideProgress)
                        }

                        arrivalNumbers

                        // `FR-ERR-02` — say what is blocked and offer the way out, without ending
                        // anything over it.
                        if sampling.status == .permissionDenied {
                            SystemSettingsLink(language: language)
                        }

                        manualOverride
                    }
                    .padding(.vertical, KultaraMetrics.xl)
                    .padding(.horizontal, KultaraMetrics.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    /// `FR-ARR-05` — the distance and the fix quality, as numbers that move. Present in every state
    /// that has a fix; a wait without them is a wait with no idea how far is left.
    @ViewBuilder private var arrivalNumbers: some View {
        switch sampling.status {
        case .approaching(let distance, let accuracy),
             .accuracyInsufficient(let distance, let accuracy):
            VStack(spacing: KultaraMetrics.xs) {
                Text(distance)
                    .font(KultaraTypography.font(.questTitle))
                    .foregroundStyle(palette.inkCream.color)
                    .monospacedDigit()
                Text("\(UIStrings.string(.arrivalAccuracy, language)) · \(accuracy)")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.inkDusty.color)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        case .idle, .searching, .permissionDenied:
            EmptyView()
        }
    }

    private var manualOverride: some View {
        Button {
            sampling.presentManualOverride()
        } label: {
            Text(manualOverrideLabel)
                .fixedSize(horizontal: false, vertical: true)
                .monospacedDigit()
        }
        .buttonStyle(.hisploraPill)
    }

    private var manualOverrideLabel: String {
        if sampling.manualOverrideAvailable {
            return UIStrings.string(.arrivalManualAction, language)
        }
        if let countdown = sampling.manualOverrideCountdownText {
            return String(format: UIStrings.string(.arrivalManualCountdown, language), countdown)
        }
        return UIStrings.string(.arrivalManualPending, language)
    }
}

/// The override sheet, on the museum theme because a sheet is chrome rather than a story stage —
/// the same treatment `QuestRunView` gives its own.
///
/// `FR-ARR-04` — the explanation at body size, the confirm, and, when permission was refused, the
/// way to Settings. There is no named presence confirmation behind it: `FR-START-09` exists because
/// starting a five-stop route from the wrong place ruins the route, and a sidequest has one stop
/// (`s0` D3).
struct SideQuestManualOverrideSheet: View {
    @Environment(\.kultaraPalette) private var palette

    let language: ContentLanguage
    let isPermissionDenied: Bool
    let isAvailable: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                    Text(UIStrings.string(.arrivalManualSheetTitle, language))
                        .kultaraFont(.questTitle)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    KultaraRule()
                }
                // `FR-SIDE-03` — a manual entry is not a lesser one, and the copy says so.
                Text(UIStrings.string(.arrivalManualNote, language))
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)

                if isPermissionDenied {
                    Text(UIStrings.string(.runStartLocationDeniedBody, language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                    SystemSettingsLink(language: language)
                }

                if isAvailable {
                    Button(UIStrings.string(.arrivalManualAction, language), action: onConfirm)
                        .buttonStyle(.seal)
                } else {
                    Text(UIStrings.string(.arrivalManualPending, language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.inkMuted.color)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(UIStrings.string(.runCancel, language), action: onCancel)
                    .buttonStyle(.ruled)
            }
            .padding(KultaraMetrics.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.paperRaised.color)
    }
}
