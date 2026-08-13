import ContentKit
import Foundation

/// Every interface string in the app, in both languages (`NFR-I18N-01`, `NFR-I18N-02`).
///
/// These are `LocalizedText` — the same type content uses — rather than a `.strings` catalogue,
/// for one reason: the app's language is chosen in Settings and may differ from the device's
/// (`FR-ONB-05`), so string resolution has to follow the app's own language, not the bundle's.
/// It also inherits the no-fallback rule, so an untranslated label cannot appear mid-screen in
/// the other language (`NFR-I18N-03`).
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
    case questListSubtitle
    case questListEmpty
    case questListSearchPlaceholder
    case questListSearchClear
    case questListSearchEmpty
    case questListMapTab
    case questListListTab
    case mapUnavailable
    case mapPinHint
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
    case arrivalManualAction
    case arrivalManualNote
    case arrivalManualPending
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

public enum UIStrings {

    public static func string(_ key: UIStringKey, _ language: ContentLanguage) -> String {
        // A missing entry is a programming error caught by `UIStringsTests.everyKeyHasAnEntry`,
        // not something to paper over with the key name at runtime.
        table[key]?.value(for: language) ?? key.rawValue
    }

    public static func text(_ key: UIStringKey) -> LocalizedText {
        table[key] ?? LocalizedText(id: key.rawValue, en: key.rawValue)
    }

    public static let table: [UIStringKey: LocalizedText] = [
        .appName: LocalizedText(id: "Kultara", en: "Kultara"),

        // MARK: Onboarding
        .onboardingSkip: LocalizedText(id: "Lewati", en: "Skip"),
        .onboardingNext: LocalizedText(id: "Lanjut", en: "Next"),
        .onboardingStart: LocalizedText(id: "Mulai menjelajah", en: "Start exploring"),
        .onboardingWelcomeTitle: LocalizedText(
            id: "Jalan kaki, bukan gulir layar",
            en: "A walk, not a feed"),
        .onboardingWelcomeBody: LocalizedText(
            id: "Setiap kuis adalah satu rute berjalan kaki dengan cerita yang bersambung dari satu titik ke titik berikutnya. Tidak perlu akun, tidak perlu email.",
            en: "Each quest is one walking route with a story that carries from one stop to the next. No account, no email."),
        .onboardingPocketTitle: LocalizedText(
            id: "Simpan ponsel saat berjalan",
            en: "Pocket the phone while you walk"),
        .onboardingPocketBody: LocalizedText(
            id: "Petunjuk dibaca sekali saat berhenti, lalu ponsel masuk kantong. Aplikasi ini dibuka di titik pemberhentian, bukan dibawa terbuka sepanjang jalan.",
            en: "You read the clue once while standing still, then the phone goes away. This app is opened at checkpoints, not carried open along the street."),
        .onboardingAccuracyTitle: LocalizedText(
            id: "Tercatat atau tutur, selalu ditandai",
            en: "Documented or oral, always labelled"),
        .onboardingAccuracyBody: LocalizedText(
            id: "Setiap klaim membawa label sumbernya: catatan tertulis atau cerita yang diwariskan. Sumbernya bisa dibuka dari layar cerita.",
            en: "Every claim carries its provenance: a written record, or a story handed down. The sources are reachable from the story screen."),
        .onboardingRespectTitle: LocalizedText(
            id: "Tempat ini masih dipakai",
            en: "These places are still in use"),
        .onboardingRespectBody: LocalizedText(
            id: "Beberapa titik adalah tempat ibadah aktif. Aturan pakaian dan aturan foto ditampilkan sebelum kamu sampai, dan tidak ada permainan di dalamnya.",
            en: "Some stops are active places of worship. Dress and photography rules are shown before you arrive, and no game mechanics are used inside them."),

        // MARK: Discovery
        .questListTitle: LocalizedText(id: "Kuis", en: "Quests"),
        .questListSubtitle: LocalizedText(
            id: "Bisa dijelajahi dari mana saja, tanpa jaringan.",
            en: "Browsable from anywhere, with no network."),
        .questListEmpty: LocalizedText(
            id: "Belum ada kuis yang tersedia.",
            en: "No quests are available yet."),
        .questListSearchPlaceholder: LocalizedText(
            id: "Cari warisan budaya", en: "Find cultural heritage"),
        .questListSearchClear: LocalizedText(id: "Hapus pencarian", en: "Clear search"),
        .questListSearchEmpty: LocalizedText(
            id: "Tidak ada kuis yang cocok dengan pencarian itu.",
            en: "No quest matches that search."),
        .questListMapTab: LocalizedText(id: "Peta", en: "Map"),
        .questListListTab: LocalizedText(id: "Daftar", en: "List"),
        .mapUnavailable: LocalizedText(
            id: "Peta wilayah belum ikut di versi konten ini.",
            en: "This content version ships no region map."),
        .mapPinHint: LocalizedText(
            id: "Ketuk penanda untuk melihat pratinjau kuis.",
            en: "Tap a marker to see the quest preview."),
        .labelRegion: LocalizedText(id: "Wilayah", en: "Region"),
        .labelDistance: LocalizedText(id: "Jarak", en: "Distance"),
        .labelWalkingTime: LocalizedText(id: "Waktu jalan", en: "Walking time"),
        .labelTotalDuration: LocalizedText(id: "Total waktu", en: "Total time"),
        .labelEstimatedCost: LocalizedText(id: "Perkiraan biaya", en: "Estimated cost"),
        .costFree: LocalizedText(id: "Gratis", en: "Free"),
        .unitMetres: LocalizedText(id: "m", en: "m"),
        .unitKilometres: LocalizedText(id: "km", en: "km"),
        .unitMinutes: LocalizedText(id: "menit", en: "min"),
        .unitCheckpointSingular: LocalizedText(id: "titik", en: "checkpoint"),
        .unitCheckpointPlural: LocalizedText(id: "titik", en: "checkpoints"),

        // MARK: Preview
        .previewHookHeading: LocalizedText(id: "Pembuka", en: "The opening"),
        .previewAboutHeading: LocalizedText(id: "Tentang rute ini", en: "About this route"),
        .previewRouteHeading: LocalizedText(id: "Rute", en: "Route"),
        .previewCheckpointsHeading: LocalizedText(id: "Titik pemberhentian", en: "Checkpoints"),
        .previewCostHeading: LocalizedText(id: "Rincian biaya", en: "Cost breakdown"),
        .previewTerrainHeading: LocalizedText(id: "Medan dan akses", en: "Terrain and access"),
        .previewTimingHeading: LocalizedText(id: "Waktu mulai", en: "When to start"),
        .previewSafetyHeading: LocalizedText(id: "Keselamatan", en: "Safety"),
        .previewStoryWithheld: LocalizedText(
            id: "Ceritanya dibuka di tempat, bukan di sini.",
            en: "The story opens on site, not here."),
        .previewRecommendedWindow: LocalizedText(id: "Disarankan", en: "Recommended"),
        .previewLatestStart: LocalizedText(id: "Mulai paling lambat", en: "Latest start"),
        .previewLateWarning: LocalizedText(
            id: "Sudah lewat jam mulai paling lambat hari ini. %@ tutup pukul %@, jadi rute ini kemungkinan tidak selesai. Kamu masih boleh melihat semuanya di sini.",
            en: "It is past today's latest start. %@ closes at %@, so this route probably will not finish. You can still read everything here."),
        .previewRouteImageAlt: LocalizedText(
            id: "Sketsa rute dengan lima titik pemberhentian berurutan.",
            en: "A sketch of the route with five checkpoints in order."),
        .previewStepsPresent: LocalizedText(id: "Ada undakan", en: "Has steps"),
        .previewStepsAbsent: LocalizedText(id: "Tanpa undakan", en: "No steps"),
        .previewSurface: LocalizedText(id: "Permukaan", en: "Surface"),
        .previewDressCode: LocalizedText(id: "Aturan pakaian", en: "Dress code"),
        .previewPhotoPolicy: LocalizedText(id: "Aturan foto", en: "Photography"),
        .photoPolicyAllowed: LocalizedText(id: "Boleh memotret", en: "Photography allowed"),
        .photoPolicyRestricted: LocalizedText(id: "Terbatas", en: "Restricted"),
        .photoPolicyProhibited: LocalizedText(id: "Dilarang memotret", en: "Photography prohibited"),
        .previewSacredNotice: LocalizedText(
            id: "Tempat ibadah aktif.",
            en: "An active place of worship."),
        .previewStartUnavailable: LocalizedText(
            id: "Mulai di titik pertama",
            en: "Start at the first checkpoint"),
        .previewStartUnavailableDetail: LocalizedText(
            id: "Kuis dimulai saat kamu berada di titik pertama. Dari sini kamu bisa membaca semuanya kecuali ceritanya.",
            en: "A quest begins when you are at its first checkpoint. From here you can read everything except the story."),

        // MARK: Starting a run
        .runStartAction: LocalizedText(id: "Mulai dari titik pertama", en: "Start at the first checkpoint"),
        .runStartSafetyTitle: LocalizedText(id: "Sebelum berangkat", en: "Before you set off"),
        .runStartSafetyAck: LocalizedText(id: "Saya mengerti", en: "I understand"),
        .runStartLocationTitle: LocalizedText(
            id: "Kenapa lokasi diperlukan", en: "Why location is needed"),
        .runStartLocationBody: LocalizedText(
            id: "Lokasi dipakai hanya untuk memastikan kamu benar-benar berdiri di sebuah titik, dan hanya saat aplikasi terbuka. Tidak ada pelacakan saat kamu berjalan, dan lokasi tidak pernah keluar dari perangkat ini.",
            en: "Location is used only to confirm you are standing at a checkpoint, and only while the app is open. Nothing is tracked while you walk, and your location never leaves this device."),
        .runStartLocationContinue: LocalizedText(id: "Lanjut", en: "Continue"),
        .runStartLocationDeniedTitle: LocalizedText(
            id: "Izin lokasi ditolak", en: "Location permission denied"),
        .runStartLocationDeniedBody: LocalizedText(
            id: "Tanpa izin lokasi, kedatangan tidak bisa dipastikan sendiri oleh aplikasi. Kamu tetap bisa membaca seluruh pratinjau, dan tetap bisa menandai kedatangan sendiri di layar titik.",
            en: "Without location permission the app cannot confirm arrival on its own. You can still read the whole preview, and you can still mark your arrival yourself on the checkpoint screen."),
        .runResumeHeading: LocalizedText(
            id: "Perjalanan yang belum selesai", en: "An unfinished walk"),
        .runResumeAction: LocalizedText(id: "Lanjutkan", en: "Resume"),
        .runRestartAction: LocalizedText(id: "Mulai ulang", en: "Start over"),
        .runRestartWarning: LocalizedText(
            id: "Mulai ulang akan menghapus foto dan catatan refleksi dari perjalanan yang belum selesai itu. Stempel yang sudah didapat ikut hilang.",
            en: "Starting over discards the photos and reflections from that unfinished walk. The stamps earned go with them."),
        .runStartConfirmTitle: LocalizedText(
            id: "Kamu sedang berdiri di %@?", en: "Are you standing at %@?"),
        .runStartConfirmBody: LocalizedText(
            id: "Sinyal lokasi kadang gagal di gang sempit dan di dalam pasar. Konfirmasi ini ada untuk keadaan itu — bukan untuk memulai rute dari jauh, karena ceritanya dibuat untuk dibaca di tempatnya.",
            en: "Location fixes fail in narrow lanes and inside markets. This confirmation exists for that — not for starting the route from elsewhere, because the story is written to be read where it happened."),
        .runStartConfirmYes: LocalizedText(id: "Ya, saya di sini", en: "Yes, I am here"),
        .runCancel: LocalizedText(id: "Batal", en: "Cancel"),

        // MARK: Arrival
        .arrivalHeading: LocalizedText(id: "Menuju %@", en: "Heading to %@"),
        .arrivalStep: LocalizedText(id: "Titik %d dari %d", en: "Checkpoint %d of %d"),
        .arrivalSearching: LocalizedText(
            id: "Mencari sinyal lokasi…", en: "Looking for a location fix…"),
        .arrivalDistanceRemaining: LocalizedText(id: "Sisa jarak", en: "Distance remaining"),
        .arrivalAccuracy: LocalizedText(id: "Ketelitian sinyal", en: "Fix accuracy"),
        .arrivalAccuracyInsufficient: LocalizedText(
            id: "Kamu terlihat sudah dekat, tetapi sinyalnya terlalu kasar untuk memastikannya.",
            en: "You look close, but the fix is too coarse to prove it."),
        .arrivalNoFix: LocalizedText(
            id: "Belum ada sinyal lokasi yang bisa dipakai.",
            en: "No usable location fix yet."),
        .arrivalManualAction: LocalizedText(
            id: "Saya sudah sampai di sini", en: "I have arrived here"),
        .arrivalManualNote: LocalizedText(
            id: "Menandai sendiri tidak mengurangi apa pun: stempel, cerita, dan ringkasannya sama persis.",
            en: "Marking it yourself costs nothing: the stamp, the story and the summary are identical."),
        .arrivalManualPending: LocalizedText(
            id: "Kalau sinyal tidak juga datang, pilihan menandai sendiri muncul setelah satu menit.",
            en: "If no fix arrives, the option to mark it yourself appears after a minute."),
        .arrivalClueHeading: LocalizedText(id: "Petunjuk", en: "The clue"),
        .arrivalNoClue: LocalizedText(
            id: "Titik pertama. Alamatnya ada di pratinjau rute.",
            en: "The first checkpoint. Its address is in the route preview."),
        .arrivalOutOfSequence: LocalizedText(
            id: "Titik yang ditunggu sekarang adalah %@.",
            en: "The checkpoint expected right now is %@."),

        // MARK: Checkpoint
        .checkpointArrivedHeading: LocalizedText(id: "Kamu sampai", en: "You have arrived"),
        .checkpointStampAwarded: LocalizedText(id: "Stempel didapat", en: "Stamp earned"),
        .checkpointLoreHeading: LocalizedText(id: "Ceritanya", en: "The story"),
        .checkpointSourcesHeading: LocalizedText(id: "Sumber", en: "Sources"),
        .checkpointSourcesEmpty: LocalizedText(
            id: "Tidak ada sumber yang tercatat untuk bagian ini.",
            en: "No source is recorded for this passage."),
        .checkpointTasksHeading: LocalizedText(id: "Kegiatan", en: "Things to do"),
        .checkpointClueHeading: LocalizedText(
            id: "Petunjuk ke titik berikutnya", en: "The clue to the next stop"),
        .checkpointAdvanceAction: LocalizedText(
            id: "Berangkat ke titik berikutnya", en: "Set off for the next stop"),
        .checkpointProgress: LocalizedText(id: "%d dari %d titik", en: "%d of %d checkpoints"),
        .taskOptionalNote: LocalizedText(
            id: "Semuanya boleh dilewati. Tidak ada yang terkunci karenanya.",
            en: "Every one of these is skippable. Nothing is locked behind them."),
        .taskSkipAction: LocalizedText(id: "Lewati", en: "Skip"),
        .taskSaveAction: LocalizedText(id: "Simpan", en: "Save"),
        .taskAnswerPlaceholder: LocalizedText(id: "Tulis di sini…", en: "Write here…"),
        .taskSkippedNote: LocalizedText(id: "Dilewati", en: "Skipped"),
        .taskAnsweredNote: LocalizedText(id: "Tersimpan", en: "Saved"),
        .taskPhotoNotInThisBuild: LocalizedText(
            id: "Kegiatan foto belum ada di versi ini. Titik ini tetap selesai tanpa foto.",
            en: "Photo activities are not in this build yet. This checkpoint completes without one."),

        // MARK: Completion and summary
        .runCompletedHeading: LocalizedText(id: "Rute selesai", en: "Route complete"),
        .runCompletedBody: LocalizedText(
            id: "Kamu sampai di titik terakhir. Ringkasannya tersimpan di perangkat ini dan bisa dibuka kapan saja, tanpa jaringan.",
            en: "You reached the final checkpoint. The summary is saved on this device and opens any time, with no network."),
        .runBadgeAwarded: LocalizedText(id: "Lencana didapat: %@", en: "Badge earned: %@"),
        .summaryHeading: LocalizedText(id: "Ringkasan perjalanan", en: "Trip summary"),
        .summaryOpenAction: LocalizedText(id: "Buka ringkasan", en: "Open the summary"),
        .summaryStampsHeading: LocalizedText(id: "Stempel dan lencana", en: "Stamps and badges"),
        .summaryReflectionHeading: LocalizedText(id: "Catatanmu", en: "What you wrote"),
        .summarySnapshotNote: LocalizedText(
            id: "Ringkasan ini menyimpan teks yang kamu baca saat itu, versi konten %@. Perbaikan konten setelahnya tidak mengubahnya.",
            en: "This summary holds the text you read at the time, content version %@. Later corrections do not rewrite it."),
        .runAbandonAction: LocalizedText(id: "Hentikan perjalanan", en: "End this walk"),
        .runAbandonConfirmTitle: LocalizedText(
            id: "Hentikan perjalanan ini?", en: "End this walk?"),
        .runAbandonConfirmBody: LocalizedText(
            id: "Titik yang sudah kamu capai tetap tersimpan beserta ceritanya. Yang berhenti hanyalah sisa rutenya.",
            en: "The checkpoints you reached stay, with their stories. Only the rest of the route stops."),
        .runAbandonConfirmAction: LocalizedText(id: "Hentikan", en: "End it"),
        .runAbandonedNote: LocalizedText(id: "Dihentikan", en: "Ended early"),

        // MARK: Home
        .homeActiveRunHeading: LocalizedText(id: "Sedang berjalan", en: "In progress"),
        .homeActiveRunAction: LocalizedText(id: "Lanjutkan", en: "Resume"),
        .homeCompletedHeading: LocalizedText(id: "Sudah selesai", en: "Finished"),

        // MARK: Developer build only
        .devHeading: LocalizedText(id: "Alat pengembang", en: "Developer tools"),
        .devSimulateArrivalTitle: LocalizedText(
            id: "Simulasikan kedatangan di mana saja", en: "Simulate arrival anywhere"),
        .devSimulateArrivalNote: LocalizedText(
            id: "Menempatkan posisimu tepat di titik berikutnya supaya rute bisa dites dari meja. Hanya ada di build debug; aturan FR-START-08 tetap berlaku di build rilis, yang bahkan tidak memuat kode ini.",
            en: "Places you exactly at the next checkpoint so the route can be walked from a desk. Debug builds only; FR-START-08 still holds in a release build, which does not contain this code at all."),

        // MARK: Accuracy labels
        .accuracyDocumented: LocalizedText(id: "Tercatat", en: "Documented"),
        .accuracyOral: LocalizedText(id: "Babad/Cerita rakyat", en: "Oral tradition"),

        // MARK: Settings
        .settingsTitle: LocalizedText(id: "Pengaturan", en: "Settings"),
        .settingsLanguageHeading: LocalizedText(id: "Bahasa", en: "Language"),
        .settingsLanguageIndonesian: LocalizedText(id: "Bahasa Indonesia", en: "Indonesian"),
        .settingsLanguageEnglish: LocalizedText(id: "Inggris", en: "English"),
        .settingsLocationHeading: LocalizedText(id: "Lokasi", en: "Location"),
        .settingsLocationStatusNotRequested: LocalizedText(id: "Belum diminta", en: "Not requested yet"),
        .settingsLocationStatusDenied: LocalizedText(id: "Ditolak", en: "Denied"),
        .settingsLocationStatusWhenInUse: LocalizedText(id: "Saat aplikasi dipakai", en: "While using the app"),
        .settingsLocationStatusAlways: LocalizedText(id: "Selalu", en: "Always"),
        .settingsLocationStatusRestricted: LocalizedText(id: "Dibatasi perangkat", en: "Restricted by the device"),
        .settingsLocationExplanation: LocalizedText(
            id: "Lokasi hanya dipakai untuk memastikan kamu sampai di sebuah titik, dan hanya saat aplikasi terbuka. Menjelajah dan melihat pratinjau tidak memerlukan izin lokasi.",
            en: "Location is used only to confirm you have reached a checkpoint, and only while the app is open. Browsing and preview need no location permission at all."),
        .settingsOpenSystemSettings: LocalizedText(id: "Buka Pengaturan iOS", en: "Open iOS Settings"),
        .settingsStorageHeading: LocalizedText(id: "Penyimpanan", en: "Storage"),
        .settingsStorageUsed: LocalizedText(id: "Terpakai di perangkat", en: "Used on this device"),
        .settingsDeleteHeading: LocalizedText(id: "Data di perangkat", en: "Data on this device"),
        .settingsDeleteAction: LocalizedText(id: "Hapus semua data lokal", en: "Delete all local data"),
        .settingsDeleteConfirmTitle: LocalizedText(id: "Hapus semua data lokal?", en: "Delete all local data?"),
        .settingsDeleteConfirmBody: LocalizedText(
            id: "Tindakan ini tidak bisa dibatalkan. Konten kuis tetap ada karena ikut di dalam aplikasi.",
            en: "This cannot be undone. Quest content stays, because it ships inside the app."),
        .settingsDeleteConfirmAction: LocalizedText(id: "Hapus", en: "Delete"),
        .settingsDeleteCancel: LocalizedText(id: "Batal", en: "Cancel"),
        .settingsDeleteDone: LocalizedText(id: "Data lokal sudah dihapus.", en: "Local data deleted."),
        .settingsDeleteScopeNote: LocalizedText(
            id: "Yang terhapus: preferensi, seluruh perjalanan beserta stempel dan lencananya, dan catatan refleksi yang kamu tulis. Foto belum ada di versi ini karena kegiatan foto belum dirilis.",
            en: "This removes your preferences, every walk with its stamps and badges, and the reflections you wrote. There are no photos yet in this build, because photo activities have not shipped."),
        .settingsAttributionHeading: LocalizedText(id: "Sumber dan penghargaan", en: "Sources and credits"),
        .settingsAttributionBody: LocalizedText(
            id: "Cerita di aplikasi ini berdiri di atas catatan dan tutur dari komunitas pengelola setiap tempat. Setiap klaim membawa sumbernya.",
            en: "The stories here rest on records and oral accounts from the communities that care for each place. Every claim carries its source."),
        .settingsReportHeading: LocalizedText(id: "Laporkan masalah", en: "Report a problem"),
        .settingsReportAction: LocalizedText(id: "Laporkan kekeliruan fakta", en: "Report a factual error"),
        .settingsReportBody: LocalizedText(
            id: "Kalau ada fakta yang salah, atau kalau kamu mewakili pengelola sebuah tempat dan tidak ingin tempat itu ada di sini, beri tahu kami. Perbaikan pada versi ini memerlukan rilis aplikasi baru, jadi perkiraan waktunya beberapa hari, bukan beberapa jam.",
            en: "If a fact is wrong, or if you speak for the community that cares for a place and do not want it included, tell us. In this build a correction needs an app release, so the honest turnaround is days, not hours."),
        .settingsContentVersion: LocalizedText(id: "Versi konten", en: "Content version"),
        .settingsPlaceholderContentNotice: LocalizedText(
            id: "Konten pada versi ini adalah data contoh dengan tempat fiktif. Belum divalidasi di lapangan dan belum untuk dipakai berjalan.",
            en: "The content in this build is example data with fictional places. It has not been field-validated and is not yet something to walk."),
    ]
}
