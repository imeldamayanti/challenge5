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
            id: "Pada versi ini yang tersimpan di perangkat baru berupa preferensi. Perjalanan, foto, refleksi, dan penghargaan belum ada karena fitur menjalankan kuis belum dirilis.",
            en: "In this build the only thing stored on the device is your preferences. Runs, photos, reflections and awards do not exist yet, because walking a quest has not shipped."),
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
