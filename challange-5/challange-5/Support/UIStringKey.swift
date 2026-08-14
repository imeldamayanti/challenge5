import Foundation

/// Every interface string in the app, in both languages (`NFR-I18N-01`, `NFR-I18N-02`).
///
/// These are `LocalizedText` — the same type content uses — rather than a `.strings` catalogue,
/// for one reason: the app's language is chosen in Settings and may differ from the device's
/// (`FR-ONB-05`), so string resolution has to follow the app's own language, not the bundle's.
/// It also inherits the no-fallback rule, so an untranslated label cannot appear mid-screen in
/// the other language (`NFR-I18N-03`).
enum UIStringKey: String, Sendable, CaseIterable {
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
    case cutsceneLegendTitle
    case cutsceneSwipeHint
    case cutsceneStartAction
    case storyRevealPager
    case storyRevealNext
    case storyRevealBack
    case storyRevealSkip
    case transitionSteppingInto
    case transitionContinue
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

    // Developer build only
    case devHeading
    case devSimulateArrivalTitle
    case devSimulateArrivalNote

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
