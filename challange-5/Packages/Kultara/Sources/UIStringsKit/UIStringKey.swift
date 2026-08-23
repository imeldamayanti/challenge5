import Foundation

/// Every interface string in the app, in both languages (`NFR-I18N-01`, `NFR-I18N-02`).
///
/// These are `LocalizedText` — the same type content uses — rather than a `.strings` catalogue,
/// for one reason: the app's language is chosen in Settings and may differ from the device's
/// (`FR-ONB-05`), so string resolution has to follow the app's own language, not the bundle's.
/// It also inherits the no-fallback rule, so an untranslated label cannot appear mid-screen in
/// the other language (`NFR-I18N-03`).
///
/// This lives in a package target rather than in the app target because the app target has no
/// unit-test bundle, and `NFR-I18N-01/02` need one: see `UIStringsTests` and the note on the
/// `UIStringsKit` target in `Package.swift`.
public enum UIStringKey: String, Sendable, CaseIterable {
    case appName

    // Onboarding — FR-ONB-02/03
    case onboardingSkip
    case onboardingNext
    case onboardingStart
    /// The spoken position of the segmented bar (`523:2053`). `%d of %d`.
    case onboardingProgress
    case onboardingExploreTitle
    case onboardingExploreBody
    /// The pocket-the-phone paragraph (`AD-1`).
    ///
    /// It was `onboardingPocketTitle`/`onboardingPocketBody` and belonged to an onboarding screen
    /// until 2026-08-20, when that screen was removed for frame parity. Only the body had a second
    /// caller — the `FR-START-04` safety notice, which prints it under the quest's own
    /// `safetyNotes` — so the title went and this was renamed to say where it is now read.
    case safetyPocketBody
    case onboardingQuestTitle
    case onboardingQuestBody
    case onboardingCollectionTitle
    case onboardingCollectionBody

    // MARK: Entry — sign up, sign in, guest
    //
    // Figma `791:5145`, `791:5109` and `822:2235`. The screens the app-flow chart drew between
    // onboarding and Home, which stood as wireframes until they were built.
    //
    // **There is no account backend behind any of this.** The credential screens keep a local
    // profile and nothing else, and the two identity providers are drawn and disabled — see
    // `AuthViewModel` for the whole account of what is and is not connected.
    case authSignUpTitle
    case authSignInTitle
    case authGuestTitle
    /// The line under the guest title, which is the one place the app says where a name is used.
    case authGuestBody
    case authNamePlaceholder
    case authGuestNamePlaceholder
    case authEmailPlaceholder
    case authPasswordPlaceholder
    case authSignUpAction
    case authSignInAction
    case authGuestAction
    /// The ruled divider's own word (`791:5166`), and separately what it is announced as — "OR"
    /// alone tells a reader who cannot see the two rules nothing about what it divides.
    case authOr
    case authOrSpoken
    case authContinueWithApple
    case authContinueWithGoogle
    case authContinueAsGuest
    case authHaveAccount
    case authSignInLink
    case authNoAccount
    case authSignUpLink
    case authBack
    /// Why the two provider rows are drawn but cannot be used. Not in the frames: a disabled
    /// control with no stated reason is the accessibility failure disabling it was meant to avoid.
    case authProvidersUnavailable
    /// The three things a form can be wrong about, shown under the field they belong to rather
    /// than as an alert.
    case authInvalidEmail
    case authShortPassword
    /// An empty password box, which is a different mistake from a short one — telling a walker
    /// their blank field is under eight characters is technically true and useless.
    case authMissingPassword
    case authMissingName

    // Discovery — FR-DISC-02/05
    case questListTitle
    /// The Home masthead (`28:172`). Separate from `questListTitle`, which names the *tab* and the
    /// navigation title: the page's own heading is a piece of copy, not a screen name.
    case homeMasthead
    case questListSubtitle
    case questListEmpty
    case questListSearchPlaceholder
    case questListSearchClear
    case questListSearchEmpty
    case questListMapTab
    case questListListTab
    case mapUnavailable
    case questMapShowIllustrated
    case questMapShowReal
    case questMapOfflineNotice
    case questMapUserLocation
    /// `298:988` — the liquid-glass stack button that now stands where the chevron did, and goes
    /// back to the list surface.
    case questMapBackToList
    /// The popover a marker tap opens (`1026:3514`). The rows are one line each, so the count and
    /// the minutes ride inside their own format strings rather than beside separate unit keys.
    case questPopoverDurationFormat
    case questPopoverStopsFormat
    case labelRegion
    case labelDistance
    case labelWalkingTime
    case labelTotalDuration
    case labelEstimatedCost
    case costFree
    case unitMetres
    case unitKilometres
    case unitMinutes
    case unitCheckpointSingular
    case unitCheckpointPlural

    // Preview — FR-DISC-03/04/06
    case previewHookHeading
    case previewAboutHeading
    case previewRouteHeading
    case previewCheckpointsHeading
    case previewCostHeading
    case previewTerrainHeading
    case previewTimingHeading
    case previewSafetyHeading
    case previewStoryWithheld
    case previewRecommendedWindow
    case previewLatestStart
    case previewLateWarning
    case previewRouteImageAlt
    case previewStepsPresent
    case previewStepsAbsent
    case previewSurface
    case previewDressCode
    case previewPhotoPolicy
    case photoPolicyAllowed
    case photoPolicyRestricted
    case photoPolicyProhibited
    case previewSacredNotice
    case previewStartUnavailable
    case previewStartUnavailableDetail

    // Starting a run — FR-START-01..10
    case runStartAction
    case runStartSafetyTitle
    case runStartSafetyAck
    case runStartLocationTitle
    case runStartLocationBody
    case runStartLocationContinue
    case runStartLocationDeniedTitle
    case runStartLocationDeniedBody
    case runResumeHeading
    case runResumeAction
    case runRestartAction
    case runRestartWarning
    case runStartConfirmTitle
    case runStartConfirmBody
    case runStartConfirmYes
    case runCancel

    // Arrival — FR-ARR-01..07, FR-ERR-01
    case arrivalHeading
    case arrivalStep
    case arrivalSearching
    case arrivalDistanceRemaining
    case arrivalAccuracy
    case arrivalAccuracyInsufficient
    case arrivalNoFix
    case arrivalStatusHeading
    case arrivalSearchingElapsed
    case arrivalManualAction
    case arrivalManualNote
    case arrivalManualPending
    case arrivalManualCountdown
    case arrivalManualSheetTitle
    case runMapHeading
    case runMapAccessibility
    case runMapNoPosition

    // Hisplora story flow — the Figma board `13:128`. The copy on those frames is English-only
    // and hardcodes one quest; these are the localised, content-agnostic versions.
    case storyPreviewReady
    case locationCheckingTitle
    case locationCheckingBody
    case locationVerifiedTitle
    case locationVerifiedBody
    case locationVerifiedContinue
    /// The approach map's accessibility label. One `%@`: the place's name.
    case locationVerifiedMapAccessibility
    case locationNotThereTitle
    case locationNotThereBody
    case locationNotThereBack
    case locationNavigateThere
    case locationNavigateThereHint
    case cutsceneLegendTitle
    case cutsceneSwipeHint
    case cutsceneRevealAction
    case cutsceneStartAction
    case storyRevealPager
    case storyRevealNext
    case storyRevealBack
    case storyRevealSkip
    /// `293:1643` — the sentence the place name closes, and the words the marker loop rings. Two
    /// halves rather than one string because the second half is content (`AD-4`): the lead is the
    /// app's, the place is the quest's.
    case storyRevealJourneyLead
    case transitionSteppingInto
    case transitionContinue
    /// `187:1103`'s map, when the beating dot is over it. A separate label from
    /// `locationVerifiedMapAccessibility` because the dot is the difference between the two
    /// screens' maps and it must not be the colour and the motion that say so (`NFR-A11Y-05`).
    case approachTransitionMapAccessibility
    /// `293:1595` — the only words on the transition screen.
    case transitionTapToReveal
    // The place notice — `50:137` ("Quest") — and the checkpoint's task menu — `452:3132`
    // ("Quest 1/3"), which replaced the earlier `51:201` ("Detail Quest") treatment.
    case placeNoticeBeforeExplore
    /// `921:3851` ("Quest - Card") — the sheet between a checkpoint's first explanation (the place
    /// notice at a sacred Place, the story reveal everywhere else) and the sealed-scroll transition.
    /// `%d` is the checkpoint's own task count and `%@` is the place name.
    case questAvailabilityTitle
    case questAvailabilitySubtitle
    case questAvailabilityContinue
    case checkpointDetailContinue
    /// `452:3174` — the heading over the task list.
    case checkpointDetailAllTasks
    /// `197:148`'s footer caption over the exit pill — replaces `452:3194`'s single "Continue to
    /// Next Location" button. Read before `checkpointDetailNextPlace` when there is a next place to
    /// name, or before `checkpointDetailFinishAction` at the final checkpoint.
    case checkpointDetailOrGoTo
    /// `197:148` — `%@` is the next checkpoint's place name. The frame's own copy ("Next Place:
    /// Pura Pemecutan") names a place absent from the content tree (`AD-4`), so this reads the next
    /// checkpoint's real name instead. Unused at the final checkpoint, which reuses
    /// `runCompletedHeading`/`summaryOpenAction` instead — there is no next place to name, and the
    /// walk is already `.completed` by the time this screen can show (`FR-DONE-01`).
    case checkpointDetailNextPlace
    /// `452:3142` — what the stamp over the progress bar is.
    case checkpointDetailStampLabel
    /// `452:3138` — the segmented bar, read out. `%1$d` resolved of `%2$d`.
    case checkpointDetailProgressLabel
    /// The state each row's trailing glyph carries: `checkmark.seal.fill` or `chevron.forward`.
    case checkpointDetailTaskDone
    case checkpointDetailTaskOpen

    // The task sheet — `447:1880` ("Quest_Filled") — and the site plan it opens — `452:3028`
    // ("Site Map").
    /// `447:1900` — the frame's own label, offered only where the task is a photo task.
    case taskDetailTakePhoto
    /// What the primary control reads for a written task, which is what the shipped content
    /// actually carries at four of five checkpoints.
    case taskDetailAnswerAction
    /// `447:1910` — the hint under the small scroll at the foot of the sheet.
    case taskDetailSeeMap
    case taskDetailSeeMapHint

    // The camera — `1:4681` — and the sheet once it holds a photograph — `1:4827`
    // ("Quest_Filled" with an image in it).
    /// `1:4690` — the camera screen's own title.
    case cameraTitle
    /// `1:4692` — the cross that leaves the camera without taking anything.
    case cameraClose
    /// `1:4699` — the shutter, which has no label in the frame and needs one spoken.
    case cameraShutter
    /// `1:4702` — the flash control, read out as the state it will move to.
    case cameraFlashOn
    case cameraFlashOff
    /// `1:4697` — the 2× badge, read out as the magnification it will move to.
    case cameraZoomIn
    case cameraZoomOut
    /// No capture device — the Simulator, and an iPad with the camera disabled by policy. Not an
    /// error: the task is still resolvable, because nothing here gates progression (`AD-2`).
    case cameraUnavailable
    /// Camera access refused. Names what is lost and where the switch is, rather than re-asking:
    /// iOS only ever shows the system prompt once.
    case cameraDenied
    /// `1:4852` — the cross on the thumbnail, which discards the photograph and re-offers the
    /// camera.
    case taskPhotoRemove
    /// `1:4855` — the one action on the filled sheet.
    case taskPhotoSubmit
    /// Read out in place of the walker's own photograph, which cannot describe itself.
    case taskPhotoThumbnail
    /// What the sheet says once a photo task has been resolved with a photograph.
    case taskPhotoSavedNote

    // The story behind a task — `1:4609` ("Explanation per Quest") — and the stamp it hands over
    // to — `1:4641` ("Quest").
    /// `1:4621` — the storyteller's opening, which is the app's words rather than the quest's.
    case questExplanationLead
    /// `1:4613` — the whole screen is the control.
    case questExplanationContinue
    case questExplanationBack
    /// `1:4645` — what the walker has just done.
    case stampAwardHeading
    /// `1:4648` — which of the walk's stamps this is. `%1$d` of `%2$d`.
    case stampAwardCaption
    /// `1:4649` — what is left at this place, and the way on.
    case stampAwardBody
    /// The same, for the last task at this checkpoint: nothing is left here.
    case stampAwardBodyAllDone
    /// `15:2799` — leaves the checkpoint for the walk to the next place.
    case stampAwardNextLocation
    /// `1:4654` — back to this checkpoint's task menu. `%d` is how many are still unresolved.
    case stampAwardMoreQuests
    /// `452:3050`'s screen, closed.
    case siteMapClose
    /// `452:3038` — the gesture hint.
    case siteMapGestureHint
    /// Read out in place of the plan itself: how many marked points it carries.
    case siteMapAccessibility
    /// The plan's citation, printed under it. `FR-CP-05`: a drawn plan asserts a layout, so its
    /// provenance is on the screen rather than in a file.
    case siteMapSourceHeading
    /// Shown when the Place ships no plan. Not an error — most Places never will.
    case siteMapUnavailable
    case arrivalClueHeading
    case arrivalNoClue
    case arrivalOutOfSequence

    // Checkpoint — FR-CP-01..08, FR-TASK-01..07
    case checkpointArrivedHeading
    case checkpointStampAwarded
    case checkpointLoreHeading
    case checkpointSourcesHeading
    case checkpointSourcesEmpty
    case checkpointTasksHeading
    case checkpointClueHeading
    case checkpointAdvanceAction
    case checkpointProgress
    case taskOptionalNote
    case taskSkipAction
    case taskSaveAction
    case taskAnswerPlaceholder
    case taskSkippedNote
    case taskAnsweredNote
    case taskPhotoNotInThisBuild
    // Short names for `TaskType`, used as a row's title on the checkpoint task menu (`51:201`) —
    // the content has no title field of its own, only a `type` and a `prompt`.
    case taskTypeReflection
    case taskTypePhoto
    case taskTypeQuestion

    // Completion and summary — FR-DONE-01..06
    case runCompletedHeading
    case runCompletedBody
    case runBadgeAwarded
    case summaryHeading
    case summaryOpenAction
    case summaryStampsHeading
    case summaryReflectionHeading
    case runAbandonAction
    case runAbandonConfirmTitle
    case runAbandonConfirmBody
    case runAbandonConfirmAction
    case runAbandonedNote

    // Home — FR-RUN-03, FR-DONE-06
    case homeActiveRunHeading
    case homeActiveRunAction
    case homeCompletedHeading
    /// What the filler cards are, said on the page and again to VoiceOver on each one. See
    /// `PlaceholderQuestCatalog`.
    case homePlaceholderCardsNotice
    case homePlaceholderCardHint
    /// The hanging tag on a quest card whose walk is still open (`850:2289`). The words are baked
    /// into the artwork; this is what VoiceOver reads instead of them.
    case questCardOngoing

    // Sidequests — PRD §5.15 `FR-SIDE-01`…`FR-SIDE-16`. The story flow outside a Run: a notice, an
    // arrival gate, the place's history, one challenge, one letter.
    case sideQuestNoticeTitle
    case sideQuestNoticeQuestion
    case sideQuestNoticeYes
    case sideQuestNoticeNo
    case sideQuestNearbyHeading
    case sideQuestNearbyEmpty
    case sideQuestDistanceAway
    case sideQuestStoryHeading
    case sideQuestChallengeHeading
    case sideQuestQuizSubmit
    case sideQuestQuizWrong
    case sideQuestQuizCorrect
    case sideQuestQuizRevealed
    case sideQuestQuizExplanation
    case sideQuestPhotoPrompt
    case sideQuestPhotoTake
    case sideQuestPhotoChoose
    case sideQuestLetterAwarded
    case sideQuestLetterProgress
    case sideQuestCollectionOpen
    /// `FR-SIDE-07` — the way back into an unfinished sidequest, from its own screens.
    case sideQuestKeepExploring

    // Letter collections — FR-SIDE-08/09
    case collectionHeading
    case collectionProgress
    case collectionSlotLocked
    case collectionComplete
    case collectionBadgeAwarded
    /// `NFR-A11Y-01` — VoiceOver reading a row of underscores says nothing useful, so an unearned
    /// slot is named rather than spelled.
    case collectionBlankLetter
    case collectionPhraseAccessibility

    // Nearby alerts in Settings — the opt-in half of `FR-SIDE-11`. The toggle and its authorization
    // reporting are `s3`'s screens; the copy is here so the string table is complete in one pass.
    case settingsNearbyAlertsHeading
    case settingsNearbyAlertsToggle
    case settingsNearbyAlertsExplanation
    case settingsNearbyAlertsNeedsAlways
    case settingsNearbyAlertsNeedsNotifications

    // The floating tab bar. Journal and Profile used to borrow their names from
    // `WireframeCatalog`, which was fine while they *were* wireframes; both are built screens now
    // and a built screen's name belongs in the string table with every other one.
    case tabJournal
    case tabProfile

    // Journal — the Sealed Letters screen (Figma `332:1607`)
    case journalSealedHeading
    /// `c2` phase 7. Shown when a restore was attempted and the read did not land — the second
    /// place `01-architecture.md` R4's silence is wrong, after a failed account deletion. A walker
    /// looking at an empty Journal cannot tell "you had nothing" from "we could not fetch it".
    /// `c2` phase 6 — the credential screen. Not "log in": nothing is gated behind it, and a
    /// walker who never signs in loses nothing except the ability to find their walks again on a
    /// different phone. The copy has to say that rather than imply an account is required.
    /// `c2` phase 5 — the recap card's own words. Short: the card is a picture somebody scrolls
    /// past, and the quest's title is the thing that has to survive that.
    case shareCardEyebrow
    case shareCardStampCount
    case shareIncludeAnswersLabel
    case shareRevokeAction

    case credentialTitle
    case credentialBody
    case credentialSkipAction
    case credentialSignOutAction
    case credentialFailedMessage
    case credentialMergedMessage
    case credentialNotMergedMessage

    /// `c2` phase 5's second pass: minting is lazy (nothing uploads until the walker taps share),
    /// an opt-in for including written answers, and a way to turn a link back off.
    case tripSharePreparing
    case tripShareReflectionsToggle
    case tripShareReflectionsHint
    case tripShareStopSharing
    case tripShareStopSharingConfirm
    case tripShareStoppedConfirmation
    case tripShareCancel

    case restoreFailedTitle
    case restoreFailedBody
    case restoreRetryAction
    case restoreDismissAction

    case journalUnsealAction
    case journalSealedEmptyTitle
    case journalSealedEmptyBody
    /// The swipe the carousel affords, said in words as well as drawn as a nudge — a wiggle is
    /// not something VoiceOver can read (`NFR-A11Y-05`).
    case journalSwipeHint
    /// What to do with the envelope, printed under the letter's title (`791:5627`). The frame
    /// removes the "Unseal the Journey" pill and makes the card itself the target, so the words
    /// that were on a button are the instruction above it — and `journalUnsealAction` stays as the
    /// card's spoken name, because a picture with a tap gesture is not a control VoiceOver can
    /// announce on its own (`NFR-A11Y-05`).
    case journalTapToOpen
    case journalCollectionsAction
    /// What is written on the back of the envelope (`791:5657`), above the walk's own title, place
    /// and date — the only line of the address that is not the walk's own data.
    case journalEnvelopeSalutation

    // Journal — the two papers inside the envelope (Figma `791:5568`, `791:5814`, `791:5551`)
    case journalPaperSummaryEyebrow
    /// Takes the quest's region: "Your journey through Badung".
    case journalPaperSummaryTitle
    case journalPaperSummaryAction
    case journalPaperHistoryEyebrow
    /// Takes the quest's region: "The Last Tales of Badung".
    case journalPaperHistoryTitle
    case journalPaperHistoryAction
    /// The modal's close control, which is drawn as a cross and therefore has to be named
    /// (`NFR-A11Y-05`).
    case journalPapersClose

    // The two pages a paper opens — Trip Summary (`791:6414`) and History (`791:6537`).
    /// Both pages' back control, which is a chevron and therefore has to be named
    /// (`NFR-A11Y-05`). Its own key rather than a reuse of `storyRevealBack`: that one is a
    /// labelled control inside the run, and its Indonesian reads "Sebelumnya" — "previous" — which
    /// is what a story page's back means and not what leaving a finished letter means.
    case tripPageBack
    /// `791:6493` — the heading over the three counts.
    case tripJourneyHeading
    /// `791:6501` — how many checkpoints the walk actually reached.
    case tripPlacesExplored
    /// `791:6521` — how many tasks the walker resolved with something of their own: a written
    /// answer or a photograph. A skip is a resolution and not a memory (`AD-2`), so it is not
    /// counted.
    case tripMemories
    /// `791:6524` — the word after that count.
    case tripMemoriesUnit
    /// `791:6530` — how long the walk took, start to finish.
    case tripDuration
    /// `791:6533` — the unit after that count. Minutes, because the walks are 45 of them.
    case tripDurationUnit
    /// `791:6418` — the brown band's heading, over one card per place reached.
    case tripPiecesHeading
    /// `791:6485` — the italic serif line over the featured medallion's name.
    case tripCollectionLegend
    /// The share control in both pages' bars (`791:6490`, `791:6542`), which is a glyph and
    /// therefore has to be named (`NFR-A11Y-05`).
    case tripShare
    /// `791:6453` — the tan band's heading, over the stamps the walk earned.
    case tripCollectionHeading
    /// A checkpoint the walk reached without its lore ever being opened. The History page says so
    /// rather than printing a place name over an empty chapter.
    case tripHistoryNoLore
    /// `791:6593` — the last line of the History page, under which the walk's own seal is stamped.
    case tripHistoryClosing

    // Journal — writing one, from the Summary screen (Figma `921-2256`, `921-2932`). Replaces the
    // `createJournal` wireframe entry, which is deleted with these keys added.
    case writeJournalTitle
    case writeJournalHeading
    case writeJournalExperienceLabel
    case writeJournalExperiencePlaceholder
    case writeJournalMemoriesLabel
    case writeJournalAddPlacePhoto
    case writeJournalAddSelfie
    case writeJournalSaveAction
    case writeJournalKeyboardDone
    case journeySavedTitle
    case journeySavedRecapAction

    // The trip-completion carousel "See Journey Recap" opens into, before the walk's real Trip
    // Summary (Figma `205:121`, `205:151`, `205:205`, the "Ngalcer" file).
    case tripRecapHeadlineTitle
    case tripRecapHeadlineBody
    case tripRecapGlanceTitle
    case tripRecapStatExploredPlaces
    case tripRecapStatTripDuration
    case tripRecapStatCompletedQuests
    case tripRecapStatMemories
    case tripRecapDurationUnit
    /// "You explored %d historic places in %@." — the quest's region fills the second placeholder,
    /// and drops the whole sentence when a withdrawn quest leaves it empty, the same rule
    /// `ExplorerCardViewModel`'s finished-row detail already follows.
    case tripRecapExploredTitle
    case tripRecapExploredTitleNoRegion
    /// `205:2823`, `205:2867` — shared by both the memory-grid and the postcard page.
    case tripRecapMemoriesTitle
    case tripRecapMemoLabel
    /// "%d Places" — the postcard's "Memo" fact, spelled out rather than abbreviated like the
    /// glance page's tiles are.
    case tripRecapPlacesUnit
    /// "%d Minutes" — the postcard's "Duration" fact.
    case tripRecapMinutesUnit
    case tripRecapPostcardTitle
    /// "from %@" — the postcard's byline, under `tripRecapPostcardTitle`.
    case tripRecapPostcardFrom
    case tripRecapShareAction
    case tripRecapCloseAction

    // Profile — the Explorer's Card (Figma `547:2724`)
    case profileHeading
    /// What the card is headed with. There is no account in this build and no name to print, so
    /// the card names the reader by what they are rather than inventing one (`FR-ONB-01`).
    case profileExplorerName
    case profileExplorerNameNote
    case profileStatQuests
    case profileStatStamps
    case profileStatBadges
    case profileTabQuests
    case profileTabStamps
    case profileTabBadges
    case profileActivityComplete
    /// The head of a finished row's line — "You completed this quest at", with the region set a
    /// weight up after it (`705:2833`). Two halves rather than a format string so no entry in this
    /// table has to carry a trailing space.
    case profileQuestCompletedAt
    /// The three-way filter over the Quests tab: everything, the walks still open, the walks done.
    case profileQuestFilterAll
    case profileQuestFilterUnfinished
    case profileQuestFilterDone
    case profileQuestsEmpty
    /// Shown under the Done filter, where `profileQuestsEmpty` would describe the wrong list.
    case profileQuestsDoneEmpty
    /// ...and under All, where neither of the other two is true yet.
    case profileQuestsAllEmpty
    /// Spoken on a Quests-tab row, which resumes the walk it names.
    case profileQuestResumeHint
    case profileStampsEmpty
    case profileBadgesEmpty

    // Developer build only
    case devHeading
    case devSimulateArrivalTitle
    case devSimulateArrivalNote
    /// `s3`'s debug trigger — walking past a sidequest place from a desk. Copy only for now.
    case devSimulatePassingTitle
    case devSimulatePassingNote

    // Accuracy labels — FR-CP-05
    case accuracyDocumented
    case accuracyOral

    // Settings — FR-SET-01..04
    case settingsTitle
    case settingsLanguageHeading
    case settingsLanguageIndonesian
    case settingsLanguageEnglish
    case settingsLocationHeading
    case settingsLocationStatusNotRequested
    case settingsLocationStatusDenied
    case settingsLocationStatusWhenInUse
    case settingsLocationStatusAlways
    case settingsLocationStatusRestricted
    case settingsLocationExplanation
    case settingsOpenSystemSettings
    case settingsStorageHeading
    case settingsStorageUsed
    case settingsDeleteHeading
    case settingsDeleteAction
    case settingsDeleteConfirmTitle
    case settingsDeleteConfirmBody
    case settingsDeleteConfirmAction
    case settingsDeleteCancel
    case settingsDeleteDone
    case settingsDeleteScopeNote
    case settingsAttributionHeading
    case settingsAttributionBody
    case settingsReportHeading
    case settingsReportAction
    case settingsReportBody
    case settingsContentVersion
    case settingsPlaceholderContentNotice

    // Sidequest proximity notifications — FR-WATCH-07
    /// The "Open in App" action title on the `sidequest-nearby` notification category, registered
    /// by `SideQuestNotificationCategory.register(language:)` in the phone target.
    case sideQuestNotificationOpenInApp
}
