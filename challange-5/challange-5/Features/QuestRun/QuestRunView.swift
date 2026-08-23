import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

/// The whole walking loop on one screen, changing what it shows as the Run moves through its
/// stages: the two notices that precede the first step, the arrival screen, the checkpoint, and the
/// summary at the end.
///
/// One screen rather than four pushed views, because the walker's position in the quest is the
/// navigation. A stack would let them back out of a checkpoint into an arrival screen for a place
/// they are already standing at.
struct QuestRunView: View {
    @Environment(\.kultaraPalette) private var palette
    /// `223:2004` draws a back arrow and a "Back to Homepage" text button. Both pop this screen;
    /// they do not abandon the walk — the draft Run stays on disk and the quest list resumes it.
    /// `FR-RUN-04`'s confirmed abandon is a separate model-level action
    /// (`QuestRunViewModel.requestAbandon`/`confirmAbandon`) with no UI control on this screen any
    /// more — the museum checkpoint screen it lived on is gone by request.
    @Environment(\.dismiss) private var dismiss
    /// `FR-MAP-04`'s handoff. `openURL` rather than `MKMapItem`, because `import MapKit` is banned
    /// in this target (`FR-MAP-01`, `PermissionCallBoundaryTests`).
    @Environment(\.openURL) private var openURL
    @Bindable private var model: QuestRunViewModel
    /// Opens the finished walk's real Trip Summary from the journal-saved confirmation
    /// (`JourneySavedScreen`). A root-level concern — switching to the Journal tab and opening the
    /// journal-letter overlay — so `KultaraRootView` supplies it rather than this screen reaching
    /// for app state several layers above it.
    private let onOpenRecap: (Run) -> Void
    /// `1:4458` — the confirmed-arrival screen holds for a minimum 3 s once reached, so a walk that
    /// arrives the instant sampling starts does not flash past "Location Verified" before the
    /// walker can read it. This only gates what `content` draws; `model.stage` still flips the
    /// moment arrival is recorded, so `RunEngine`'s timestamp and every ViewModel test are
    /// unaffected. There is no equivalent timer for `.awaitingArrival` itself — see `content`'s
    /// `.awaitingArrival` case: that one is gated purely on `model.locationState`, because a fixed
    /// hold there means showing a *wrong* result (a stale or absent one) once the clock runs out
    /// but the sampler is still genuinely checking.
    @State private var isLocationVerifiedRevealed = false

    init(model: QuestRunViewModel, onOpenRecap: @escaping (Run) -> Void) {
        self.model = model
        self.onOpenRecap = onOpenRecap
    }

    private var language: ContentLanguage { model.language }

    /// The story-flow stages carry their own heading and their own back control, on their own
    /// ground. The museum navigation bar over them is cream on brown and it clips the eyebrow
    /// underneath it, so on those stages it goes away entirely.
    private var isOnStoryFlow: Bool { QuestRunViewModel.isStoryFlow(model.stage) }

    var body: some View {
        content
            // One screen swaps for the next in place, so without this the change is a hard cut —
            // most visible leaving the cutscene, where the walker has just uncovered a picture and
            // the frame vanishes mid-look. A cross-fade rather than a slide: these stages are not
            // a stack and nothing here moves in a direction (`isOnStoryFlow` even hides the
            // navigation bar), so a push would claim a spatial relationship the flow does not have.
            //
            // Each stage still runs its own entrance — the typewriter, the scroll, the reveal's own
            // fade — on top of this.
            // Asymmetric rather than a plain cross-fade, and the asymmetry is the whole point: with
            // both halves fading over the same window the compositor shows a quarter of the ground
            // through the middle of the change, so two screens that draw the *same* parchment still
            // dipped darker at the seam. Holding the outgoing screen at full opacity for the first
            // 0.24 s keeps the stack opaque the whole way across, and the incoming one arrives on
            // top of a page that never dimmed.
            .transition(.asymmetric(
                insertion: .opacity.animation(.easeOut(duration: 0.32)),
                removal: .opacity.animation(.easeIn(duration: 0.26).delay(0.24))))
            .animation(.easeInOut(duration: 0.5), value: model.stage)
            // **The ground under the cross-fade has to be the ground of the screens crossing it.**
            // `palette.paper` is the museum's cream, and on the story flow — brown on both sides of
            // most stage changes — it printed a bright flash for as long as the fade lasted. That
            // was the most visible fault in the hand-over out of the transition screen.
            .kultaraSpeckledGround(isOnStoryFlow ? hisplora.brownStone : palette.paper)
            .navigationTitle(isOnStoryFlow ? "" : model.quest.title.value(for: language))
            .kultaraInlineNavigationTitle()
            .toolbar(isOnStoryFlow ? .hidden : .visible, for: .navigationBar)
            .onAppear { model.screenAppeared() }
            .onDisappear { model.screenDisappeared() }
            // `FR-START-09` — the named presence confirmation.
            .kultaraDialog(
                isPresented: Binding(get: { model.isConfirmingPresence },
                                     set: { if !$0 { model.cancelPresenceConfirmation() } }),
                title: model.presenceConfirmationTitle,
                message: UIStrings.string(.runStartConfirmBody, language),
                actions: [
                    KultaraDialogAction(
                        title: UIStrings.string(.runStartConfirmYes, language),
                        kind: .confirm) { model.confirmPresence() },
                    KultaraDialogAction(
                        title: UIStrings.string(.runCancel, language),
                        kind: .cancel) { model.cancelPresenceConfirmation() },
                ])
            // `FR-RUN-04` — the confirmation names what is kept and what is lost.
            .kultaraDialog(
                isPresented: Binding(get: { model.isConfirmingAbandon },
                                     set: { if !$0 { model.cancelAbandon() } }),
                title: UIStrings.string(.runAbandonConfirmTitle, language),
                message: UIStrings.string(.runAbandonConfirmBody, language),
                actions: [
                    KultaraDialogAction(
                        title: UIStrings.string(.runAbandonConfirmAction, language),
                        kind: .destructive) { model.confirmAbandon() },
                    KultaraDialogAction(
                        title: UIStrings.string(.runCancel, language),
                        kind: .cancel) { model.cancelAbandon() },
                ])
            .sheet(isPresented: Binding(get: { model.isPresentingManualOverride },
                                        set: { if !$0 { model.dismissManualOverride() } })) {
                KultaraThemeProvider { manualOverrideSheet }
                    .kultaraManualOverrideSheetPresentation()
            }
            // `921:3851` — a sheet over whichever explanation (place notice or story reveal) it was
            // reached from, dismissal treated the same as Continue (`AD-2`: nothing here gates
            // progression, so there is no dead end to guard against).
            .sheet(isPresented: Binding(get: { model.isPresentingQuestAvailability },
                                        set: { if !$0 { model.advanceFromQuestAvailability() } })) {
                questAvailability
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .task(id: model.stage) {
                switch model.stage {
                case .locationVerified:
                    isLocationVerifiedRevealed = false
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    isLocationVerifiedRevealed = true
                default:
                    isLocationVerifiedRevealed = false
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch model.stage {
        case .storyPreview: storyPreview
        case .awaitingArrival:
            // No timer here, deliberately: `arrivalScreen` only draws settled results
            // (`.notThere`/`.denied`), never `.checking` itself, so the light checking screen has
            // to stay up for exactly as long as the sampler is genuinely still checking — a fixed
            // hold would either flash a screen shorter than the real wait or, worse, expire before
            // a fix has landed and print "Location Checking…." over the brown map screen.
            if model.locationState == .checking {
                locationCheckingScreen
            } else {
                arrivalScreen
            }
        case .locationVerified:
            // Never `arrivalScreen` as the fallback here: `arriveAtCurrentCheckpoint()` calls
            // `sampling.finish()`, which resets `status` to `.idle` — so `model.locationState`
            // reads `.checking` again the instant arrival is confirmed, and `arrivalScreen` would
            // print "Location Checking…." for a beat on an arrival that already succeeded.
            // `locationCheckingScreen` has no such dependency, so it is the correct hold here too.
            if isLocationVerifiedRevealed { locationVerified } else { locationCheckingScreen }
        case .cutsceneIntro: cutsceneIntro
        case .cutscenePortrait: cutscenePortrait
        case .approachTransition: approachTransition
        case .storyReveal: storyReveal
        case .placeNotice: placeNotice
        case .checkpointDetail: checkpointDetail
        case .taskDetail: taskDetail
        case .questExplanation: questExplanation
        case .stampAward: stampAward
        case .transition: transition
        // `.atCheckpoint` renders the same "All Quest" screen `.checkpointDetail` does — the
        // dark museum screen it used to render (lore, tasks, clue, an advance button and "End
        // this walk") is gone by request, in favour of showing this one screen everywhere a
        // checkpoint's task menu is reached, resumed walk included.
        case .atCheckpoint: checkpointDetail
        case .finished: finishedScreen
        }
    }

    // MARK: The Hisplora story stages
    //
    // Each is a `HisploraStage` of its own, so the story flow carries the new visual direction
    // while the quest list, settings and summary stay on the museum theme until frames exist for
    // them. A seam at a screen boundary is survivable; a half-restyled screen is not.

    private var storyPreview: some View {
        StoryPreviewScreen(
            language: language,
            title: model.questTitle,
            hook: model.hookText,
            distanceText: model.routeDistanceText,
            durationText: model.routeDurationText,
            portraitURL: model.cutsceneImageURL,
            onReady: { model.advanceFromStoryPreview() },
            // Leaves the screen; it does not advance the walk. It was wired to
            // `advanceFromStoryPreview()`, which made the chevron a second Ready to Explore — the
            // one thing a back control must not be. The draft Run stays on disk and the quest list
            // resumes it, which is what every other back control on this flow does.
            onBack: { dismiss() })
    }

    /// `1:4458` — the fix confirmed on its own screen before the story starts. The arrival is
    /// already recorded when this draws; the back chevron leaves the screen rather than undoing it,
    /// which is what every other back control on this flow does.
    private var locationVerified: some View {
        LocationVerifiedScreen(
            language: language,
            questTitle: model.questTitle,
            onContinue: { model.advanceFromLocationVerified() },
            onBack: { dismiss() },
            map: { locationVerifiedMap })
    }

    /// What fills the parchment on `1:4458`: the checkpoint's own authored approach map where the
    /// content tree ships one, and the run's projected route everywhere else.
    ///
    /// The fallback is not a placeholder — `RunRouteMapView` is what this slot drew before any Place
    /// carried an approach map, and only `badung-puri-agung-pemecutan` carries one today. A drawing
    /// of one checkpoint's streets shown at every checkpoint would be the screen asserting the walker
    /// is somewhere they are not.
    @ViewBuilder private var locationVerifiedMap: some View {
        if let checkpoint = model.checkpoint, let approachMap = checkpoint.approachMap {
            ApproachMapView(language: language,
                            placeName: checkpoint.placeName,
                            approachMap: approachMap)
        } else {
            routeMap
        }
    }

    private var cutsceneIntro: some View {
        CutsceneIntroScreen(
            language: language,
            questTitle: model.questTitle,
            portraitURL: model.cutsceneImageURL,
            portraitLabel: model.questTitle,
            onAdvance: { model.advanceFromCutsceneIntro() },
            onBack: { model.retreatFromStoryStage() })
    }

    private var cutscenePortrait: some View {
        CutscenePortraitScreen(
            language: language,
            portraitURL: model.cutsceneImageURL,
            portraitLabel: model.questTitle,
            // The quest's name goes in the bar, as `447:1870` draws it; the name under the picture
            // is the picture's *subject*. The frame's subject is a person the content tree does not
            // hold, so the place being walked to stands in — it is what the hero image shows. The
            // two must not both be the quest's title: `187:866` would then print it twice.
            questTitle: model.questTitle,
            title: model.currentPlaceName,
            subtitle: nil,
            hook: model.hookText,
            onStart: { model.advanceFromCutscenePortrait() },
            onBack: { model.retreatFromStoryStage() })
    }

    /// `187:1103` — the approach map with a dot beating over the first place, between the cutscene
    /// and the reveal. It moves itself on; the chevron is what leaves it early.
    private var approachTransition: some View {
        ApproachTransitionScreen(
            language: language,
            questTitle: model.questTitle,
            region: model.quest.region,
            placeName: model.currentPlaceName,
            approachMap: model.checkpoint?.approachMap,
            onAdvance: { model.advanceFromApproachTransition() },
            onBack: { model.retreatFromStoryStage() })
    }

    private var storyReveal: some View {
        StoryRevealScreen(
            language: language,
            text: model.storyRevealText,
            // `447:1878` centres the quest's own title over the picture, and `293:1652` ends its
            // lead on the place being walked to. Both come from content (`AD-4`, `FR-RUN-06`).
            title: model.questTitle,
            placeName: model.currentPlaceName,
            // The content tree ships no per-place illustration, so this stays nil — the screen
            // falls back to its own packaged art (`StoryIllustrationMetrics`). See the note atop
            // `StoryRevealScreen`.
            illustrationURL: nil,
            onFinish: { model.advanceFromStoryReveal() },
            onBack: { model.retreatFromStoryStage() })
    }

    @ViewBuilder private var placeNotice: some View {
        if let checkpoint = model.checkpoint {
            PlaceNoticeScreen(
                language: language,
                placeName: checkpoint.placeName,
                description: checkpoint.placeDescription,
                isSacred: checkpoint.isSacred,
                dressCodeText: checkpoint.dressCodeText,
                photoPolicyText: checkpoint.photoPolicyText,
                portraitURL: model.cutsceneImageURL,
                onAcknowledge: { model.advanceFromPlaceNotice() },
                onBack: { model.retreatFromStoryStage() })
        } else {
            EmptyView()
        }
    }

    private var questAvailability: some View {
        QuestAvailabilityScreen(
            language: language,
            title: model.questAvailabilityTitle,
            onContinue: { model.advanceFromQuestAvailability() })
    }

    @ViewBuilder private var checkpointDetail: some View {
        if let checkpoint = model.checkpoint {
            CheckpointDetailScreen(
                language: language,
                placeName: checkpoint.placeName,
                tasks: checkpoint.tasks,
                taskPrompts: checkpoint.taskPrompts,
                resolutions: resolutions(for: checkpoint),
                // `452:3142` fills the stamp with a generated temple sketch. The quest's own hero
                // image goes in instead — content with provenance, rather than a picture introduced
                // here (`FR-CP-05`), the same substitution `PlaceNoticeScreen` makes.
                stampImageURL: model.cutsceneImageURL,
                isFinal: checkpoint.isFinal,
                nextPlaceName: model.nextPlaceName,
                onSelectTask: { model.openTaskDetail(taskID: $0.id) },
                onContinue: { model.advanceFromCheckpointDetail() },
                onBack: { model.retreatFromStoryStage() })
        } else {
            EmptyView()
        }
    }

    @ViewBuilder private var taskDetail: some View {
        if let checkpoint = model.checkpoint, let task = model.detailTask {
            TaskDetailScreen(
                language: language,
                questTitle: model.questTitle,
                placeName: checkpoint.placeName,
                task: task,
                prompt: checkpoint.taskPrompts[task.id] ?? "",
                resolution: model.resolution(for: task),
                draft: Binding(
                    get: { model.taskDrafts[task.id] ?? "" },
                    set: { model.taskDrafts[task.id] = $0 }),
                portraitURL: model.cutsceneImageURL,
                photoDraft: model.photoDraft(for: task).map { Image(uiImage: $0) },
                isCameraAvailable: model.isCameraAvailable,
                hasSiteMap: checkpoint.siteMap != nil,
                // Saving and skipping both write through the view model and both land on the task
                // menu — the sheet is the checkpoint's first screen, so it has to be able to finish
                // what it opens (`FR-TASK-02`, `AD-2`).
                onSave: { model.saveTaskFromDetail(task) },
                onSkip: { model.skipTaskFromDetail(task) },
                onTakePhoto: { model.presentCamera() },
                onRemovePhoto: { model.removePhotoDraft(task) },
                onContinue: { model.advanceFromTaskDetail() },
                onOpenSiteMap: { model.presentSiteMap() },
                onBack: { model.retreatFromStoryStage() },
                onMeasureSheetHeight: { model.recordTaskSheetHeight($0) })
                // `1:4681`, over the sheet. A cover rather than a stage for the same reason the site
                // plan is one: the camera is opened and dismissed back to the same task.
                .fullScreenCover(
                    isPresented: Binding(get: { model.isPresentingCamera },
                                         set: { if !$0 { model.dismissCamera() } })
                ) {
                    QuestPhotoCaptureScreen(
                        language: language,
                        onCapture: { model.capturedPhoto($0) },
                        onCancel: { model.dismissCamera() },
                        onSkip: {
                            model.dismissCamera()
                            model.skipTaskFromDetail(task)
                        })
                }
                // A cover rather than a stage: the plan is glanced at and dismissed back to the same
                // task, so backing out of it must not be ambiguous with backing out of the task.
                .fullScreenCover(
                    isPresented: Binding(get: { model.isPresentingSiteMap },
                                         set: { if !$0 { model.dismissSiteMap() } })
                ) {
                    PlaceSiteMapScreen(
                        language: language,
                        placeName: checkpoint.placeName,
                        siteMap: checkpoint.siteMap,
                        onClose: { model.dismissSiteMap() })
                }
        } else {
            EmptyView()
        }
    }

    /// `1:4609` — the story behind the task just resolved.
    private var questExplanation: some View {
        QuestExplanationScreen(
            language: language,
            claims: model.explanationClaims,
            // The frame's sitter is a generated likeness of a named historical person, which the
            // content tree carries neither a source nor a consent record for (`FR-CP-05`). The
            // quest's own hero image stands in, the same substitution every other framed picture on
            // this flow makes.
            portraitURL: model.cutsceneImageURL,
            portraitLabel: model.currentPlaceName,
            onContinue: { model.advanceFromQuestExplanation() },
            onBack: { model.retreatFromStoryStage() })
    }

    /// `1:4641` — the checkpoint's stamp, presented rather than granted (`FR-CP-07` awarded it on
    /// arrival).
    private var stampAward: some View {
        StampAwardScreen(
            language: language,
            placeName: model.currentPlaceName,
            region: model.quest.region,
            artworkName: model.stampArtworkName,
            stampNumber: model.stampNumber,
            totalStamps: model.stampTotal,
            remainingTasks: model.unresolvedTaskCount,
            onMoreQuests: { model.stampAwardMoreQuests() },
            onNextLocation: { model.stampAwardNextLocation() })
    }

    /// This checkpoint's resolved tasks, keyed by task id — what fills the segmented bar and picks
    /// each row's trailing glyph.
    private func resolutions(for checkpoint: CheckpointPresentation) -> [String: TaskResult] {
        Dictionary(uniqueKeysWithValues: checkpoint.tasks.compactMap { task in
            model.resolution(for: task).map { (task.id, $0) }
        })
    }

    private var transition: some View {
        // `293:1595` draws a sealed scroll and two words. The quest name, the route map and the
        // five-second timer `187:1103` carried are gone with that frame — see the note on
        // `StoryTransitionScreen` for where each of them still lives.
        StoryTransitionScreen(
            language: language,
            placeName: model.currentPlaceName,
            destinationSheetHeight: model.taskSheetHeight,
            onContinue: { model.advanceFromTransition() })
    }

    // MARK: Arrival

    /// `178:675` — shown for as long as `model.locationState == .checking`, before `arrivalScreen`
    /// takes over with whatever the sampler actually found.
    private var locationCheckingScreen: some View {
        LocationCheckingScreen(language: language, onBack: { dismiss() })
    }

    /// The arrival screen, rebuilt to match frame `223:2004` ("Not Quite There") element for
    /// element: back arrow, title, lead, the map slot, and the two actions. Nothing else.
    ///
    /// **This screen no longer draws four things three P0 requirements ask for**, and that is a
    /// product decision taken on 2026-08-17, not an oversight. The frame carries no clue
    /// (`FR-CP-03`), no distance or fix quality (`FR-ARR-05`), no manual override
    /// (`FR-START-10`) and no abandon control (`FR-RUN-04`); the instruction was that the screen
    /// match the frame exactly, so the requirement yields here rather than the design. The
    /// consequence worth naming: with the override gone, a walker whose GPS never resolves — inside
    /// a covered market, which is the case `FR-START-10` was written for — has no way to reach the
    /// checkpoint at all. `manualOverride`, `manualOverrideSheet`, `arrivalNumbers` and
    /// `LocationClueCard` are all still built and still wired to the view model; restoring any of
    /// them is putting its line back in this stack.
    ///
    /// The spacings below are the frame's own gaps at default text size, so on an iPhone 17 this
    /// lays out pixel for pixel. It is a `ScrollView` rather than absolute placement because a
    /// layout that only works at one size fails `NFR-A11Y-04` at AX5 — at large sizes it scrolls
    /// instead of clipping.
    ///
    /// Only reached once `model.locationState != .checking` — `locationCheckingScreen` covers the
    /// checking moment, so `model.locationState` here is always a settled result (`.notThere`,
    /// `.denied`, or `.verified` in passing), never `.checking` itself.
    private var arrivalScreen: some View {
        HisploraStage(ground: \.brownStone) {
            ScrollView {
                VStack(spacing: 0) {
                    // The glyph is drawn at `20, 82`, 28 × 24 — 20 points below the status bar.
                    // The row is 44 tall because the tap target is (`NFR-A11Y-06`), so the padding
                    // is 13 rather than 20: it is the *glyph* that has to land at 82, not the box
                    // around it.
                    HStack {
                        HisploraBackButton(
                            accessibilityLabel: UIStrings.string(.locationNotThereBack, language),
                            size: 24
                        ) { dismiss() }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 13)

                    Spacer(minLength: 40)
                    LocationStateHeading(state: model.locationState, language: language)

                    // The frame's `Maps` rectangle at `20, 328`, 362 × 218.89. What fills it is
                    // the live basemap the frame pastes in — `ArrivalRouteMap`, which falls back to
                    // the drawn canvas on a load that actually failed. See that type for how far
                    // the `FR-MAP-01` deviation reaches and what still holds `FR-OFF-03`.
                    // The frame's gap is 100, measured off a lead it draws on one line. SF Pro Text
                    // is set a touch wider than the SF Pro Display the frame specifies, so the same
                    // sentence wraps to two here and 59 is what puts the map back at the drawn 328.
                    Spacer(minLength: 59)
                    routeMap
                        .frame(height: 218.89)

                    Spacer(minLength: 24)
                }
                // 20 each side, which is what leaves the frame's 362-point content column on a
                // 402-point screen.
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Pinned rather than stacked after a 163-point gap, and that is deliberate: the frame
            // puts the actions at a fixed distance from the home indicator, so anchoring them there
            // keeps them where they are drawn no matter how many lines the lead above wraps to.
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 18) {
                    navigateThereButton
                    backToHomeButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }

    /// `FR-ARR-05` — the distance and the fix quality, as numbers that move. Present in every state
    /// that has a fix; the frames show neither, and a walk without them is a walk with no idea how
    /// far is left.
    @ViewBuilder private var arrivalNumbers: some View {
        switch model.arrival {
        case .approaching(let distance, let accuracy),
             .accuracyInsufficient(let distance, let accuracy):
            VStack(spacing: KultaraMetrics.xs) {
                Text(distance)
                    .font(KultaraTypography.font(.questTitle))
                    .foregroundStyle(hisplora.inkCream.color)
                    .monospacedDigit()
                Text("\(UIStrings.string(.arrivalAccuracy, language)) · \(accuracy)")
                    .font(.system(size: 13))
                    .foregroundStyle(hisplora.inkDusty.color)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        case .idle, .searching, .permissionDenied:
            EmptyView()
        }
    }

    private var hisplora: HisploraPalette { .standard }

    /// `FR-MAP-02`. Shown whether or not there is a fix: with one it carries the walker's position
    /// and the straight-line distance, without one it is still the route and the stops, which is
    /// the location preview the walk between checkpoints otherwise lacks.
    @ViewBuilder private var routeMap: some View {
        if let route = model.routeMap {
            // No chrome either way: this screen is on the story flow's brown ground, and the drawn
            // map's own heading and distance row are inked for paper. The heading above and
            // `arrivalNumbers` below carry both, in inks the Hisplora palette measures.
            ArrivalRouteMap(route: route,
                            language: language,
                            totalCheckpoints: model.totalCheckpoints)
        }
    }

    /// `FR-CP-03`, `NFR-SAFE-02` — the clue stays re-readable for the whole walk, at rest, without
    /// re-triggering anything.
    private var clueCard: some View {
        KultaraCard {
            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                KultaraSectionHeading(UIStrings.string(.arrivalClueHeading, language))
                Text(model.clueToCurrentCheckpoint
                     ?? UIStrings.string(.arrivalNoClue, language))
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// `FR-ARR-05`, `FR-ERR-01` — a distance and a fix quality that move, never an indefinite
    /// spinner.
    ///
    /// The searching state is where "no spinner" used to read as "no feedback". What it gets
    /// instead is a bounded wait: the elapsed time, and a determinate bar counting down to the
    /// moment the manual override appears — which genuinely happens, at 60 s, because `FR-ARR-03`
    /// says so. That is the difference between a progress indicator and a pretence of one.
    private var arrivalStatusCard: some View {
        KultaraCard {
            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                KultaraSectionHeading(UIStrings.string(.arrivalStatusHeading, language))
                switch model.arrival {
                case .idle, .searching:
                    Text(UIStrings.string(.arrivalSearching, language))
                        .kultaraFont(.sectionHeading)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(UIStrings.string(.arrivalNoFix, language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                    searchingCountdown
                case .approaching(let distance, let accuracy):
                    LabelledValue(label: UIStrings.string(.arrivalDistanceRemaining, language),
                                  value: distance, emphasised: true)
                    LabelledValue(label: UIStrings.string(.arrivalAccuracy, language),
                                  value: accuracy)
                case .accuracyInsufficient(let distance, let accuracy):
                    LabelledValue(label: UIStrings.string(.arrivalDistanceRemaining, language),
                                  value: distance, emphasised: true)
                    LabelledValue(label: UIStrings.string(.arrivalAccuracy, language),
                                  value: accuracy)
                    Text(UIStrings.string(.arrivalAccuracyInsufficient, language))
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.warning.color)
                        .fixedSize(horizontal: false, vertical: true)
                case .permissionDenied:
                    Text(UIStrings.string(.runStartLocationDeniedTitle, language))
                        .kultaraFont(.sectionHeading)
                        .foregroundStyle(palette.seal.color)
                    // `FR-START-03`, `FR-ERR-02` — say what is blocked, offer the way out, and do
                    // not end the Run over it.
                    Text(UIStrings.string(.runStartLocationDeniedBody, language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                    SystemSettingsLink(language: language)
                }
            }
        }
    }

    /// The bounded part of the wait, written out. Elapsed time so the screen is visibly doing
    /// something, and a determinate bar for the countdown — determinate because the wait ends.
    @ViewBuilder private var searchingCountdown: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
            Text(String(format: UIStrings.string(.arrivalSearchingElapsed, language),
                        model.searchingElapsedText))
                .kultaraFont(.metadata)
                .foregroundStyle(palette.inkMuted.color)
                .monospacedDigit()
            if let countdown = model.manualOverrideCountdownText {
                ProgressView(value: model.manualOverrideProgress, total: 1)
                    .tint(palette.seal.color)
                    .accessibilityHidden(true)
                Text(String(format: UIStrings.string(.arrivalManualCountdown, language), countdown))
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `FR-MAP-04` — the frame's "Navigate There" pill, handing off to Apple Maps walking
    /// directions for the checkpoint the walk is waiting at.
    ///
    /// Two things the frame does not say, and both are requirements rather than taste. The arrow
    /// glyph and the accessibility hint are what make this "presented as leaving the app"; and the
    /// control disappears when there is no resolvable place, because a pill that opens nothing is
    /// worse on a walk than no pill. Nothing else on this screen needs it — the clue, the drawn
    /// route, the distance and the manual override all work with the radio off (`AD-3`).
    @ViewBuilder private var navigateThereButton: some View {
        if let url = model.externalMapsURL {
            Button {
                openURL(url)
            } label: {
                // The frame draws the label alone, so the arrow glyph that used to sit beside it
                // is gone and the accessibility hint is now the only thing saying this leaves the
                // app. `FR-MAP-04` asks for the handoff to be presented as such; the hint carries
                // that for VoiceOver, and sighted walkers get Apple Maps' own back-to-Hisplora
                // chip instead.
                Text(UIStrings.string(.locationNavigateThere, language))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.hisploraLightPill)
            .accessibilityHint(UIStrings.string(.locationNavigateThereHint, language))
        }
    }

    /// The frame's quieter second action. It leaves the *screen*, not the walk: the draft Run is
    /// already on disk and the quest list resumes it — this is not confirmed, because nothing is
    /// lost. `FR-RUN-04`'s confirmed abandon used to sit further into the walk (the museum
    /// checkpoint screen's own control); that screen is gone by request, and nothing replaces it,
    /// so `QuestRunViewModel.requestAbandon`/`confirmAbandon` are reachable from tests only now.
    private var backToHomeButton: some View {
        Button(UIStrings.string(.locationNotThereBack, language)) { dismiss() }
            .buttonStyle(.hisploraPlain(ink: \.inkOnButton))
    }

    /// `FR-START-10` — always visible, always at readable weight, and always a real control.
    ///
    /// It used to be a line of muted caption text until 60 s had passed, which is the least
    /// prominent styling the design system has, applied to the one thing that keeps the product
    /// usable when GPS fails. Now it is a button from the start: before availability it carries the
    /// countdown, after it reads `arrivalManualAction`, and either way it opens the sheet where the
    /// explanation and the confirm live.
    private var manualOverride: some View {
        Button {
            model.presentManualOverride()
        } label: {
            Text(manualOverrideLabel)
                .fixedSize(horizontal: false, vertical: true)
                .monospacedDigit()
        }
        .buttonStyle(.hisploraPill)
    }

    private var manualOverrideLabel: String {
        if model.manualOverrideAvailable {
            return UIStrings.string(.arrivalManualAction, language)
        }
        if let countdown = model.manualOverrideCountdownText {
            return String(format: UIStrings.string(.arrivalManualCountdown, language), countdown)
        }
        return UIStrings.string(.arrivalManualPending, language)
    }

    /// `FR-ARR-04`, `FR-ERR-02` — the explanation at body size, the confirm, and, when permission
    /// was refused, the way to Settings. A sheet rather than more rows on the arrival screen: the
    /// clue has to stay readable behind it (`FR-CP-03`, `NFR-SAFE-02`), which is why the *status*
    /// is not a modal and this is.
    private var manualOverrideSheet: some View {
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
                Text(UIStrings.string(.arrivalManualNote, language))
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)

                if model.arrival == .permissionDenied {
                    Text(UIStrings.string(.runStartLocationDeniedBody, language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                    SystemSettingsLink(language: language)
                }

                if model.manualOverrideAvailable {
                    Button(UIStrings.string(.arrivalManualAction, language)) {
                        model.confirmManualOverrideFromSheet()
                    }
                    .buttonStyle(.seal)
                } else {
                    // Not yet offerable (`FR-ARR-03`). The sheet still explains what it is and when
                    // it arrives, rather than being a control that does nothing.
                    Text(UIStrings.string(.arrivalManualPending, language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.inkMuted.color)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(UIStrings.string(.runCancel, language)) {
                    model.dismissManualOverride()
                }
                .buttonStyle(.ruled)
            }
            .padding(KultaraMetrics.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.paperRaised.color)
    }

    // MARK: Finished

    /// The walk's own end: straight onto the journal-writing screen rather than a summary the
    /// walker has to scroll past to find it. `WriteJournalScreen` → `JourneySavedScreen` → "See
    /// Journey Recap" is now where the fuller summary (the walk's real Trip Summary) lives.
    @ViewBuilder private var finishedScreen: some View {
        if model.run != nil {
            WriteJournalScreen(
                language: language,
                onSave: { text, placePhoto, selfiePhoto in
                    model.saveJournalEntry(
                        text: text, placePhoto: placePhoto, selfiePhoto: selfiePhoto)
                },
                onOpenRecap: onOpenRecap)
        } else {
            EmptyView()
        }
    }
}

private extension View {
    /// A medium detent, so the arrival screen — and the clue on it — stays visible behind the
    /// sheet. `.large` is offered as well because at the largest accessibility text sizes the
    /// explanation does not fit in half a screen.
    func kultaraManualOverrideSheetPresentation() -> some View {
        presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }
}
