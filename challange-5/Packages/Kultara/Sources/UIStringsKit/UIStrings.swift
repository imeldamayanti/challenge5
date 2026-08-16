import ContentKit
import Foundation

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
        .homeMasthead: LocalizedText(id: "Telusuri Bali", en: "Uncover Bali"),
        .questListSubtitle: LocalizedText(
            id: "Bisa dijelajahi dari mana saja, tanpa jaringan.",
            en: "Browsable from anywhere, with no network."),
        .questListEmpty: LocalizedText(
            id: "Belum ada kuis yang tersedia.",
            en: "No quests are available yet."),
        // The Ngalcer frame's own copy (`28:170`). It asks where the reader is going rather than
        // naming what the field searches, which is what the field's accessibility label is for.
        .questListSearchPlaceholder: LocalizedText(
            id: "Mau ke mana?", en: "Where to next?"),
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
        .arrivalStatusHeading: LocalizedText(
            id: "Status lokasi", en: "Location status"),
        .arrivalSearchingElapsed: LocalizedText(
            id: "Sudah mencari %@", en: "Searching for %@"),
        .arrivalManualAction: LocalizedText(
            id: "Saya sudah sampai di sini", en: "I have arrived here"),
        .arrivalManualNote: LocalizedText(
            id: "Menandai sendiri tidak mengurangi apa pun: stempel, cerita, dan ringkasannya sama persis.",
            en: "Marking it yourself costs nothing: the stamp, the story and the summary are identical."),
        .arrivalManualPending: LocalizedText(
            id: "Kalau sinyal tidak juga datang, pilihan menandai sendiri muncul setelah satu menit.",
            en: "If no fix arrives, the option to mark it yourself appears after a minute."),
        .arrivalManualCountdown: LocalizedText(
            id: "Menandai sendiri tersedia dalam %@",
            en: "Marking it yourself becomes available in %@"),
        .arrivalManualSheetTitle: LocalizedText(
            id: "Tandai kedatanganmu sendiri", en: "Mark your arrival yourself"),
        // MARK: Hisplora story flow
        //
        // The Figma frames are written in English and name one real quest — I Gusti Ngurah Made
        // Agung, Puri Agung Pemecutan, the Puputan. Those are *content*, and content lives in
        // authored JSON keyed by ID (`AD-4`, `FR-RUN-06`). What is here is the frame around the
        // content: the labels, the chrome, the instructions. The Indonesian is authored, not
        // machine-translated, because `LocalizedText` has no fallback (`NFR-I18N-03`).
        .storyPreviewReady: LocalizedText(id: "Siap menjelajah", en: "Ready to Explore"),
        .locationCheckingTitle: LocalizedText(
            id: "Memeriksa lokasi….", en: "Location Checking…."),
        .locationCheckingBody: LocalizedText(
            id: "Memastikan kamu berada di tempat yang tepat",
            en: "Making sure you're at the right place"),
        .locationVerifiedTitle: LocalizedText(
            id: "Lokasi terverifikasi", en: "Location Verified"),
        .locationVerifiedBody: LocalizedText(
            id: "Kamu ada di tempat yang tepat. Ceritanya menunggu.",
            en: "You're at the right place. The story awaits."),
        .locationVerifiedContinue: LocalizedText(id: "Lanjutkan", en: "Continue"),
        .locationNotThereTitle: LocalizedText(
            id: "Belum sampai", en: "Not Quite There"),
        .locationNotThereBody: LocalizedText(
            id: "Kamu belum berada di tempat yang tepat. Mendekatlah untuk memulai ceritanya.",
            en: "You're not at the right place yet. Get closer to begin the story."),
        .locationNotThereBack: LocalizedText(id: "Kembali ke beranda", en: "Back to Homepage"),
        // `FR-MAP-04`. The label is the frame's; the hint is what makes it "presented as leaving
        // the app", which is the half of that requirement a label alone cannot carry.
        .locationNavigateThere: LocalizedText(id: "Arahkan ke sana", en: "Navigate There"),
        .locationNavigateThereHint: LocalizedText(
            id: "Membuka Apple Maps di luar aplikasi untuk rute berjalan kaki.",
            en: "Opens Apple Maps outside this app for walking directions."),
        .cutsceneLegendTitle: LocalizedText(
            id: "Sebuah legenda akan menuntun perjalananmu",
            en: "A Legend Will Guide Your Journey"),
        .cutsceneSwipeHint: LocalizedText(
            id: "Geser bingkai foto untuk membuka legendanya",
            en: "Swipe photo frame to reveal the legends"),
        // The way past the rub for anyone the rub does not work for — VoiceOver, Reduce Motion, or
        // simply not discovering an undrawn gesture. It says what it does rather than "Next",
        // because it is the same act as the swipe and not a way around it.
        .cutsceneRevealAction: LocalizedText(
            id: "Buka legendanya", en: "Reveal the legend"),
        .cutsceneStartAction: LocalizedText(id: "Mulai perjalanan", en: "Start the Journey"),
        .storyRevealPager: LocalizedText(
            id: "Halaman %1$d dari %2$d", en: "Page %1$d of %2$d"),
        .storyRevealNext: LocalizedText(id: "Berikutnya", en: "Next"),
        .storyRevealBack: LocalizedText(id: "Sebelumnya", en: "Back"),
        .storyRevealSkip: LocalizedText(id: "Lewati cerita", en: "Skip the story"),
        .transitionSteppingInto: LocalizedText(
            id: "Melangkah ke titik pertama %@", en: "Stepping into the first place of %@"),
        .transitionContinue: LocalizedText(id: "Lanjutkan", en: "Continue"),
        .placeNoticeBeforeExplore: LocalizedText(
            id: "Sebelum menjelajah:", en: "Before you explore:"),
        .checkpointDetailContinue: LocalizedText(id: "Lanjutkan", en: "Continue"),

        .runMapHeading: LocalizedText(id: "Rute", en: "The route"),
        .runMapAccessibility: LocalizedText(
            id: "Peta rute. Titik %1$d dari %2$d, %3$@ menuju %4$@.",
            en: "Route map. Checkpoint %1$d of %2$d, %3$@ to %4$@."),
        .runMapNoPosition: LocalizedText(
            id: "Peta rute. Titik %1$d dari %2$d, %3$@. Posisimu belum diketahui.",
            en: "Route map. Checkpoint %1$d of %2$d, %3$@. Your position is not known yet."),
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
        .taskTypeReflection: LocalizedText(id: "Refleksi", en: "Reflection"),
        .taskTypePhoto: LocalizedText(id: "Foto", en: "Photo"),
        .taskTypeQuestion: LocalizedText(id: "Pertanyaan", en: "Question"),

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
        .homePlaceholderCardsNotice: LocalizedText(
            id: "Tiga kartu terakhir adalah contoh tampilan dari rancangan, bukan kuis. Belum ada tempat, rute, maupun sumbernya, jadi kartu itu tidak bisa dibuka.",
            en: "The last three cards are sample artwork from the design, not quests. There is no place, route or source behind them, so they do not open."),
        .homePlaceholderCardHint: LocalizedText(
            id: "Contoh tampilan. Belum bisa dibuka.",
            en: "Sample card. Not openable."),

        // MARK: Sidequests
        //
        // The Indonesian is authored rather than machine-translated, for the same reason every
        // other block here is: `LocalizedText` has no fallback (`NFR-I18N-03`), so a lazy
        // translation is a lazy translation forever rather than a gap that shows up as English.
        .sideQuestNoticeTitle: LocalizedText(
            id: "Ada tempat bersejarah di dekatmu", en: "A historical place is near you"),
        .sideQuestNoticeQuestion: LocalizedText(
            id: "Mau baca ceritanya?", en: "Want to read its story?"),
        .sideQuestNoticeYes: LocalizedText(id: "Ya, ceritakan", en: "Yes, tell me"),
        .sideQuestNoticeNo: LocalizedText(id: "Lain kali", en: "Not now"),
        .sideQuestNearbyHeading: LocalizedText(id: "Tempat di sekitarmu", en: "Places near you"),
        .sideQuestNearbyEmpty: LocalizedText(
            id: "Belum ada tempat sampingan di versi konten ini.",
            en: "This content version ships no side places yet."),
        .sideQuestDistanceAway: LocalizedText(id: "%@ dari sini", en: "%@ from here"),
        .sideQuestStoryHeading: LocalizedText(id: "Cerita tempat ini", en: "The story of this place"),
        .sideQuestChallengeHeading: LocalizedText(id: "Satu pertanyaan", en: "One question"),
        .sideQuestQuizSubmit: LocalizedText(id: "Jawab", en: "Answer"),
        // `FR-SIDE-06`, `s0` D5 — a wrong answer costs nothing, and the copy has to say so plainly.
        // Someone standing in front of a temple gate who feels examined closes the app.
        .sideQuestQuizWrong: LocalizedText(
            id: "Belum tepat. Coba lagi — tidak ada yang berkurang.",
            en: "Not quite. Try again — nothing is lost."),
        .sideQuestQuizCorrect: LocalizedText(id: "Tepat.", en: "That's it."),
        .sideQuestQuizRevealed: LocalizedText(
            id: "Ini jawabannya. Hurufnya tetap kamu dapat.",
            en: "Here is the answer. The letter is yours anyway."),
        .sideQuestQuizExplanation: LocalizedText(id: "Kenapa", en: "Why"),
        .sideQuestPhotoPrompt: LocalizedText(id: "Ambil satu foto", en: "Take one photograph"),
        .sideQuestPhotoTake: LocalizedText(id: "Buka kamera", en: "Open the camera"),
        .sideQuestPhotoChoose: LocalizedText(id: "Pilih dari galeri", en: "Choose from the library"),
        .sideQuestLetterAwarded: LocalizedText(id: "Huruf didapat", en: "Letter earned"),
        .sideQuestLetterProgress: LocalizedText(id: "%1$d dari %2$d huruf", en: "%1$d of %2$d letters"),
        .sideQuestCollectionOpen: LocalizedText(id: "Lihat koleksinya", en: "See the collection"),
        .sideQuestKeepExploring: LocalizedText(id: "Lanjut menjelajah", en: "Keep exploring"),

        // MARK: Letter collections
        .collectionHeading: LocalizedText(id: "Koleksi huruf", en: "Letter collection"),
        .collectionProgress: LocalizedText(id: "%1$d / %2$d", en: "%1$d / %2$d"),
        // `FR-SIDE-08` — an unearned slot says only this. It still names its place, because the
        // requirement says a traveller must be able to plan a visit; what it never shows is the
        // letter.
        .collectionSlotLocked: LocalizedText(id: "Belum ditemukan", en: "Not yet found"),
        .collectionComplete: LocalizedText(
            id: "Kalimatnya lengkap.", en: "The phrase is complete."),
        .collectionBadgeAwarded: LocalizedText(id: "Lencana didapat: %@", en: "Badge earned: %@"),
        .collectionBlankLetter: LocalizedText(id: "kosong", en: "blank"),
        .collectionPhraseAccessibility: LocalizedText(
            id: "Kalimat yang dikumpulkan: %@", en: "The collected phrase: %@"),

        // MARK: Nearby alerts in Settings
        .settingsNearbyAlertsHeading: LocalizedText(
            id: "Pemberitahuan tempat terdekat", en: "Nearby place alerts"),
        .settingsNearbyAlertsToggle: LocalizedText(
            id: "Beri tahu saat saya melewati sebuah tempat",
            en: "Tell me when I pass a place"),
        // `FR-PROX-03`, `NFR-PRIV-10` — opt-in, default off, and the cost stated before the system
        // prompt rather than after it.
        .settingsNearbyAlertsExplanation: LocalizedText(
            id: "Mati secara bawaan. Kalau dinyalakan, aplikasi memantau wilayah di sekitar tempat yang sudah ditulis — bukan melacak perjalananmu — dan mengirim pemberitahuan lokal dari perangkat ini saja. Paling banyak tiga sehari, dan tidak antara pukul 22.00 dan 07.00.",
            en: "Off by default. When on, the app watches the regions around authored places — it does not track your journey — and sends a local notification from this device alone. At most three a day, and never between 22:00 and 07:00."),
        .settingsNearbyAlertsNeedsAlways: LocalizedText(
            id: "Fitur ini memerlukan izin lokasi \"Selalu\". Tanpa itu fitur ini mematikan dirinya sendiri, dan tidak ada bagian lain aplikasi yang terpengaruh.",
            en: "This needs \"Always\" location permission. Without it the feature disables itself, and nothing else in the app is affected."),
        .settingsNearbyAlertsNeedsNotifications: LocalizedText(
            id: "Izin notifikasi juga diperlukan. Kamu bisa memberikannya di Pengaturan iOS.",
            en: "Notification permission is needed too. You can grant it in iOS Settings."),

        // MARK: Developer build only
        .devHeading: LocalizedText(id: "Alat pengembang", en: "Developer tools"),
        .devSimulateArrivalTitle: LocalizedText(
            id: "Simulasikan kedatangan di mana saja", en: "Simulate arrival anywhere"),
        .devSimulateArrivalNote: LocalizedText(
            id: "Menempatkan posisimu tepat di titik berikutnya supaya rute bisa dites dari meja. Hanya ada di build debug; aturan FR-START-08 tetap berlaku di build rilis, yang bahkan tidak memuat kode ini.",
            en: "Places you exactly at the next checkpoint so the route can be walked from a desk. Debug builds only; FR-START-08 still holds in a release build, which does not contain this code at all."),
        .devSimulatePassingTitle: LocalizedText(
            id: "Simulasikan melewati sebuah tempat", en: "Simulate passing a place"),
        .devSimulatePassingNote: LocalizedText(
            id: "Memicu jalur pemberitahuan tempat terdekat tanpa berjalan ke sana. Hanya di build debug, dan aturan kedatangan FR-SIDE-02 tetap dijalankan apa adanya.",
            en: "Fires the nearby-place path without walking to it. Debug builds only, and FR-SIDE-02's arrival rule still runs unmodified."),

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
