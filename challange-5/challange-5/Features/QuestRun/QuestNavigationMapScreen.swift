import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// `5:1608` — the walking map, and the screen a walk stands on between one checkpoint and the
/// next once its first checkpoint is behind it.
///
/// **It replaces two screens, and only after the first checkpoint.** Until this existed every
/// checkpoint waited on `223:2004` ("Not Quite There") and confirmed on `1:4458` ("Location
/// Verified"): a screen that says *you are not there* and a screen that says *you are*. Both are
/// explanations, and an explanation is worth a screen the first time. From the second checkpoint on
/// the walker already knows what the app does with their position, and what they need instead is
/// the map — live, with the place on it and themselves on it — followed by the story they walked
/// for. `QuestRunViewModel.usesNavigationMap` is the rule; the first checkpoint keeps both frames.
///
/// The arrival is announced by `CheckpointArrivedPopup` over this map rather than by a screen of
/// its own, which is why the card is a parameter here rather than a stage boundary: the map does
/// not change when the walker arrives on it, so redrawing it as a second screen would be a
/// cross-fade between two pictures of one thing — the mistake `CutsceneSequenceScreen` was rebuilt
/// to stop making.
///
/// **The frame itself could not be read.** The Figma MCP server is unauthenticated in this
/// environment, so `5:1608` was described rather than sampled: what ships is composed out of the
/// story flow's existing vocabulary (`ArrivalRouteMap`'s live basemap, `HisploraBackButton`,
/// `paperCream`, the light pill) at this file's own measurements. Nothing here introduces a colour,
/// a type role or an asset, so matching the frame later is a layout change and not a re-sample.
struct QuestNavigationMapScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    /// The quest's name for the header. Content, never a literal (`AD-4`, `FR-RUN-06`).
    let questTitle: String
    /// The place being walked to.
    let placeName: String
    /// The route, the stops and the walker's last fix. `nil` only when the checkpoint's coordinate
    /// cannot be resolved, in which case there is no map to draw and the card carries the walk on
    /// its own.
    let route: RunRoutePresentation?
    let totalCheckpoints: Int
    /// `FR-MAP-04`'s handoff target, or `nil` when there is no resolvable place — the pill is then
    /// not drawn at all rather than drawn opening nothing.
    let externalMapsURL: URL?
    /// Whether the arrival card is over the map. It is the one thing that changes when the walker
    /// arrives; the map underneath does not.
    let showsArrivalCard: Bool
    let onBack: () -> Void
    let onOpenExternalMaps: (URL) -> Void
    /// The arrival card's only control — into the story (`stageAfterArrivalConfirmed`).
    let onContinueFromArrival: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            HisploraStage(ground: \.brownStone) {
                ZStack(alignment: .top) {
                    map
                    header
                }
            }
            walkingCard
            if showsArrivalCard {
                CheckpointArrivedPopup(
                    language: language,
                    placeName: placeName,
                    onContinue: onContinueFromArrival)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.28), value: showsArrivalCard)
    }

    /// Full-bleed rather than the 362 × 218.89 slot `223:2004` pastes a map into: this screen *is*
    /// the map, and the walking card sits on it rather than beside it.
    ///
    /// `drawsRoute: true` — the opposite of the arrival screen's choice, and for the same reason.
    /// That screen is about the walker not being somewhere yet; this one is about the walk between
    /// two points, so the line, the bearing and the arrival ring are the subject.
    @ViewBuilder private var map: some View {
        if let route {
            ArrivalRouteMap(route: route,
                            language: language,
                            totalCheckpoints: totalCheckpoints,
                            cornerRadius: 0)
                .ignoresSafeArea()
        }
    }

    /// The chevron over the map, on a dimmed disc so it stays legible over whatever tile is under
    /// it. It leaves the *screen*, not the walk — the draft Run is on disk and the quest list
    /// resumes it, which is what every back control on this flow does.
    private var header: some View {
        HStack(spacing: KultaraMetrics.sm) {
            HisploraBackButton(
                accessibilityLabel: UIStrings.string(.locationNotThereBack, language),
                size: 20,
                action: onBack)
                .background(Circle().fill(palette.brownDeep.color.opacity(0.72)))
            Text(questTitle)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.inkCream.color)
                .lineLimit(1)
                .padding(.horizontal, KultaraMetrics.md)
                .frame(minHeight: KultaraMetrics.minimumTapTarget)
                .background(Capsule().fill(palette.brownDeep.color.opacity(0.72)))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// What the walker reads without stopping: where they are going, how far is left, and the way
    /// into Apple Maps if they want turn-by-turn (`FR-MAP-04`).
    ///
    /// The distance is `FR-ARR-05`'s, stated as text rather than left to the picture — a dot and a
    /// pin say *roughly*, and a walk needs the number.
    private var walkingCard: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            // "Heading to <place>" rather than `223:2004`'s "Not Quite There": that screen is
            // about a walker who is not somewhere yet, and this one is about the walk there.
            Text(String(format: UIStrings.string(.arrivalHeading, language), placeName))
                .font(KultaraTypography.font(.questTitle))
                .foregroundStyle(palette.inkDark.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let distance = route?.distanceRemainingText {
                Text("\(UIStrings.string(.arrivalDistanceRemaining, language)): \(distance)")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.inkBody.color)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let externalMapsURL {
                Button(UIStrings.string(.locationNavigateThere, language)) {
                    onOpenExternalMaps(externalMapsURL)
                }
                .buttonStyle(.hisploraLightPill)
                .accessibilityHint(UIStrings.string(.locationNavigateThereHint, language))
                .padding(.top, KultaraMetrics.xs)
            }
        }
        .padding(KultaraMetrics.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kultaraSpeckledGround(palette.paperCream)
        .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.cardCornerRadius,
                                    style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        // The card is one thing to read; the map above it states the same three facts in its own
        // accessibility label, so this is not a second copy of them for VoiceOver to wade through.
        .accessibilityElement(children: .contain)
    }
}
