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
    case onboardingWelcomeTitle
    case onboardingWelcomeBody
    case onboardingPocketTitle
    case onboardingPocketBody
    case onboardingAccuracyTitle
    case onboardingAccuracyBody
    case onboardingRespectTitle
    case onboardingRespectBody

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
    /// `293:1595` — the only words on the transition screen.
    case transitionTapToReveal
    // The place notice — `50:137` ("Quest") — and the checkpoint's task menu — `51:201`
    // ("Detail Quest").
    case placeNoticeBeforeExplore
    case checkpointDetailContinue
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
    case summarySnapshotNote
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
}
