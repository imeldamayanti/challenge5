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
        // `523:2051`. The last screen's action names the thing it starts rather than saying
        // "Done" — the frame's wording, and the one place onboarding promises what happens next.
        .onboardingStart: LocalizedText(
            id: "Mulai petualangan pertamamu",
            en: "Begin Your First Quest"),
        .onboardingProgress: LocalizedText(id: "Layar %d dari %d", en: "Screen %d of %d"),
        .onboardingExploreTitle: LocalizedText(
            id: "Menjelajah Lebih Dalam",
            en: "Explore Beyond The Surface"),
        .onboardingExploreBody: LocalizedText(
            id: "Susuri kerajaan kuno, pura yang terlupakan, dan kisah tersembunyi yang jarang didengar wisatawan.",
            en: "Walk through ancient kingdoms, forgotten temples, and hidden stories that most tourists never hear about."),
        // Printed by the `FR-START-04` safety notice, under the quest's authored `safetyNotes`.
        .safetyPocketBody: LocalizedText(
            id: "Petunjuk dibaca sekali saat berhenti, lalu ponsel masuk kantong. Aplikasi ini dibuka di titik pemberhentian, bukan dibawa terbuka sepanjang jalan.",
            en: "You read the clue once while standing still, then the phone goes away. This app is opened at checkpoints, not carried open along the street."),
        .onboardingQuestTitle: LocalizedText(
            id: "Sejarah Menjadi Petualangan",
            en: "History Becomes A Quest"),
        .onboardingQuestBody: LocalizedText(
            id: "Ikuti jalur jalan kaki nyata melewati situs bersejarah. Setiap perhentian membuka satu bab tersembunyi — pecahkan, potret, kumpulkan.",
            en: "Follow real walking trails through historical sites. Each stop reveals a hidden chapter — solve it, photograph it, collect it."),
        .onboardingCollectionTitle: LocalizedText(
            id: "Kisahmu, Koleksimu",
            en: "Your Story, Your Collection"),
        .onboardingCollectionBody: LocalizedText(
            id: "Kumpulkan prangko dari setiap situs yang kamu datangi, raih lencana bersegel untuk kuis yang tuntas, dan bangun jurnal pribadi berisi temuanmu.",
            en: "Collect stamps from every site you visit, earn sealed badges for completed quests, and build a personal journal of your discoveries."),

        // MARK: Entry — sign up, sign in, guest
        .authSignUpTitle: LocalizedText(id: "Ayo Mulai", en: "Get Started"),
        .authSignInTitle: LocalizedText(id: "Selamat Datang Kembali", en: "Welcome Back"),
        .authGuestTitle: LocalizedText(
            id: "Kami panggil kamu siapa?",
            en: "What should we call you?"),
        .authGuestBody: LocalizedText(
            id: "Nama ini akan muncul di Kartu Penjelajah dan jurnalmu.",
            en: "This name will appear on your Explorer's Card and journal."),
        .authNamePlaceholder: LocalizedText(id: "Nama kamu", en: "Your name"),
        .authGuestNamePlaceholder: LocalizedText(id: "Nama tampilan", en: "Display name"),
        .authEmailPlaceholder: LocalizedText(id: "Email", en: "Email"),
        .authPasswordPlaceholder: LocalizedText(id: "Kata sandi", en: "Password"),
        .authSignUpAction: LocalizedText(id: "Daftar", en: "Sign Up"),
        .authSignInAction: LocalizedText(id: "Masuk", en: "Sign in"),
        .authGuestAction: LocalizedText(id: "Mulai Menjelajah", en: "Start Exploring"),
        .authOr: LocalizedText(id: "ATAU", en: "OR"),
        .authOrSpoken: LocalizedText(id: "Atau lanjutkan dengan", en: "Or continue with"),
        .authContinueWithApple: LocalizedText(
            id: "Lanjut dengan Apple",
            en: "Continue with Apple"),
        .authContinueAsGuest: LocalizedText(
            id: "Lanjut sebagai tamu",
            en: "Continue as a guest"),
        .authHaveAccount: LocalizedText(id: "Sudah punya akun?", en: "Already have an account?"),
        .authSignInLink: LocalizedText(id: "Masuk", en: "Sign in"),
        .authNoAccount: LocalizedText(id: "Belum punya akun?", en: "Don't have an account?"),
        .authSignUpLink: LocalizedText(id: "Daftar", en: "Sign up"),
        .authBack: LocalizedText(id: "Kembali", en: "Back"),
        .authInvalidEmail: LocalizedText(
            id: "Masukkan alamat email yang benar.",
            en: "Enter a valid email address."),
        .authShortPassword: LocalizedText(
            id: "Kata sandi minimal 8 karakter.",
            en: "Use a password of at least 8 characters."),
        .authMissingPassword: LocalizedText(
            id: "Masukkan kata sandimu.",
            en: "Enter your password."),
        .authMissingName: LocalizedText(id: "Isi namamu dulu.", en: "Enter a name first."),

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
        .questMapShowIllustrated: LocalizedText(id: "Tampilkan peta bergambar",
                                                en: "Show the illustrated map"),
        .questMapShowReal: LocalizedText(id: "Tampilkan peta sebenarnya",
                                        en: "Show the real map"),
        .questMapOfflineNotice: LocalizedText(
            id: "Peta sebenarnya butuh koneksi. Yang tampil peta bergambar.",
            en: "The real map needs a connection. Showing the illustrated map."),
        .questMapUserLocation: LocalizedText(id: "Lokasi kamu", en: "Your location"),
        .questMapBackToList: LocalizedText(id: "Kembali ke daftar", en: "Back to the list"),
        .questPopoverDurationFormat: LocalizedText(id: "%d menit", en: "%d mins"),
        .questPopoverStopsFormat: LocalizedText(id: "%d titik", en: "%d stops"),
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
        .locationVerifiedMapAccessibility: LocalizedText(
            id: "Peta jalan di sekitar %@",
            en: "Street map of the area around %@"),
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
        .storyRevealJourneyLead: LocalizedText(
            id: "Perjalananmu dimulai di", en: "Your journey begins at"),
        .transitionSteppingInto: LocalizedText(
            id: "Melangkah ke titik pertama %@", en: "Stepping into the first place of %@"),
        .transitionContinue: LocalizedText(id: "Lanjutkan", en: "Continue"),
        .approachTransitionMapAccessibility: LocalizedText(
            id: "Peta jalan di sekitar %@, dengan titik yang menandai tempatnya",
            en: "Street map of the area around %@, with a dot marking the place"),
        .transitionTapToReveal: LocalizedText(id: "Ketuk untuk membuka", en: "Tap to reveal"),
        .placeNoticeBeforeExplore: LocalizedText(
            id: "Sebelum menjelajah:", en: "Before you explore:"),
        .questAvailabilityTitle: LocalizedText(
            id: "%d Kegiatan untuk Dijelajahi di %@", en: "%d Quest to Explore in %@"),
        .questAvailabilitySubtitle: LocalizedText(
            id: "Selesaikan kegiatan utama, lalu jelajahi lebih lanjut dengan santai.",
            en: "Complete the main quest, then explore more at your own pace."),
        .questAvailabilityContinue: LocalizedText(id: "Lanjutkan", en: "Continue"),
        .checkpointDetailContinue: LocalizedText(id: "Lanjutkan", en: "Continue"),
        .checkpointDetailAllTasks: LocalizedText(id: "Semua Kegiatan", en: "All Quest"),
        .checkpointDetailOrGoTo: LocalizedText(id: "Atau lanjut ke", en: "Or go to"),
        .checkpointDetailNextPlace: LocalizedText(
            id: "Tempat berikutnya: %@", en: "Next Place: %@"),
        .checkpointDetailStampLabel: LocalizedText(
            id: "Stempel titik ini", en: "This checkpoint's stamp"),
        .checkpointDetailProgressLabel: LocalizedText(
            id: "%1$d dari %2$d kegiatan selesai", en: "%1$d of %2$d activities done"),
        .checkpointDetailTaskDone: LocalizedText(id: "Selesai", en: "Done"),
        .checkpointDetailTaskOpen: LocalizedText(id: "Belum dikerjakan", en: "Not done yet"),

        .taskDetailTakePhoto: LocalizedText(id: "Ambil Foto", en: "Take Photo"),
        .taskDetailAnswerAction: LocalizedText(id: "Jawab di titik ini", en: "Answer at the stop"),
        .taskDetailSeeMap: LocalizedText(id: "Ketuk untuk lihat peta", en: "Tap to see the map"),
        .taskDetailSeeMapHint: LocalizedText(
            id: "Membuka denah tapak tempat ini.",
            en: "Opens the drawn plan of this place's grounds."),

        // MARK: The camera, and the sheet holding a photograph
        .cameraTitle: LocalizedText(id: "Kamera", en: "Camera"),
        .cameraClose: LocalizedText(id: "Tutup kamera", en: "Close the camera"),
        .cameraShutter: LocalizedText(id: "Ambil foto", en: "Take the photo"),
        .cameraFlashOn: LocalizedText(id: "Nyalakan lampu kilat", en: "Turn the flash on"),
        .cameraFlashOff: LocalizedText(id: "Matikan lampu kilat", en: "Turn the flash off"),
        .cameraZoomIn: LocalizedText(id: "Perbesar ke 2x", en: "Zoom to 2x"),
        .cameraZoomOut: LocalizedText(id: "Kembali ke 1x", en: "Back to 1x"),
        .cameraUnavailable: LocalizedText(
            id: "Perangkat ini tidak punya kamera yang bisa dipakai. Kegiatan ini tetap bisa dilewati.",
            en: "This device has no camera available. This activity can still be skipped."),
        .cameraDenied: LocalizedText(
            id: "Akses kamera ditolak, jadi foto tidak bisa diambil. Kamu bisa mengizinkannya lewat Pengaturan, atau lewati kegiatan ini.",
            en: "Camera access is off, so no photo can be taken. You can allow it in Settings, or skip this activity."),
        .taskPhotoRemove: LocalizedText(id: "Hapus foto", en: "Remove the photo"),
        .taskPhotoSubmit: LocalizedText(id: "Kirim", en: "Submit"),
        .taskPhotoThumbnail: LocalizedText(id: "Foto yang kamu ambil", en: "The photo you took"),
        .taskPhotoSavedNote: LocalizedText(
            id: "Foto tersimpan di perangkat ini", en: "Photo saved on this device"),

        // MARK: The story behind a task, and the stamp
        .questExplanationLead: LocalizedText(
            id: "Ada satu hal yang ingin kuceritakan…", en: "Let me tell you something…"),
        .questExplanationContinue: LocalizedText(
            id: "Ketuk untuk lanjut", en: "Tap to Continue"),
        .questExplanationBack: LocalizedText(id: "Kembali", en: "Back"),
        .stampAwardHeading: LocalizedText(
            id: "Satu keping ceritanya kamu buka lagi.",
            en: "You’ve uncovered another piece of the story."),
        .stampAwardCaption: LocalizedText(
            id: "Stempel jejak %1$d dari %2$d", en: "Trace Stamp %1$d of %2$d"),
        .stampAwardBody: LocalizedText(
            id: "Masih ada kegiatan lain di tempat ini. Kerjakan untuk menggali lebih dalam, atau lanjut ke titik berikutnya.",
            en: "There are more quests waiting here. Complete them to deepen your discovery, or continue to the next location."),
        .stampAwardBodyAllDone: LocalizedText(
            id: "Semua kegiatan di tempat ini sudah kamu kerjakan. Lanjut ke titik berikutnya kalau sudah siap.",
            en: "You have worked through everything at this place. Continue to the next location when you are ready."),
        .stampAwardNextLocation: LocalizedText(
            id: "Titik berikutnya", en: "Next Location"),
        .stampAwardMoreQuests: LocalizedText(
            id: "Kegiatan lain (%d)", en: "More Quests (%d)"),
        .siteMapClose: LocalizedText(id: "Tutup denah", en: "Close the plan"),
        .siteMapGestureHint: LocalizedText(
            id: "Cubit untuk memperbesar, geser untuk menjelajah",
            en: "Pinch to zoom, drag to explore"),
        .siteMapAccessibility: LocalizedText(
            id: "Denah tapak %1$@, dengan %2$d titik bertanda.",
            en: "Site plan of %1$@, with %2$d marked points."),
        .siteMapSourceHeading: LocalizedText(id: "Sumber denah", en: "Plan source"),
        .siteMapUnavailable: LocalizedText(
            id: "Tempat ini belum punya denah tapak di versi konten ini.",
            en: "This place ships no site plan in this content version."),

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
        .questCardOngoing: LocalizedText(id: "Sedang berjalan", en: "On going"),
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
        // MARK: The tab bar
        .tabJournal: LocalizedText(id: "Jurnal", en: "Journal"),
        .tabProfile: LocalizedText(id: "Profil", en: "Profile"),

        // MARK: Journal — Sealed Letters
        .journalSealedHeading: LocalizedText(id: "Surat Tersegel", en: "Sealed Letters"),
        .shareCardEyebrow: LocalizedText(id: "Sebuah perjalanan", en: "A walk taken"),
        .shareCardStampCount: LocalizedText(id: "{count} cap", en: "{count} stamps"),
        .shareIncludeAnswersLabel: LocalizedText(
            id: "Sertakan catatan yang kamu tulis",
            en: "Include the notes you wrote"),
        .shareRevokeAction: LocalizedText(id: "Matikan tautannya", en: "Turn the link off"),
        .credentialTitle: LocalizedText(
            id: "Simpan perjalananmu", en: "Keep your walks"),
        .credentialBody: LocalizedText(
            id: "Tanpa masuk pun semua tetap berjalan. Masuk hanya berarti perjalananmu bisa ditemukan lagi kalau kamu ganti ponsel.",
            en: "Everything works without signing in. Signing in only means your walks can be found again if you change phones."),
        .credentialSkipAction: LocalizedText(id: "Nanti saja", en: "Not now"),
        .credentialSignOutAction: LocalizedText(id: "Keluar", en: "Sign out"),
        .credentialFailedMessage: LocalizedText(
            id: "Belum berhasil masuk. Perjalananmu di ponsel ini tidak berubah.",
            en: "That did not sign you in. Nothing on this phone has changed."),
        .credentialMergedMessage: LocalizedText(
            id: "Sudah masuk. Perjalanan yang kamu buat sebelumnya ikut terbawa.",
            en: "Signed in. The walks you made before came with you."),
        .credentialNotMergedMessage: LocalizedText(
            id: "Sudah masuk, tapi perjalanan lamamu belum ikut terbawa. Perjalanan itu tidak hilang.",
            en: "Signed in, but your earlier walks did not come across. They are not lost."),
        .tripSharePreparing: LocalizedText(
            id: "Menyiapkan tautan…", en: "Preparing your link…"),
        .tripShareReflectionsToggle: LocalizedText(
            id: "Sertakan jawabanmu", en: "Include my written answers"),
        .tripShareReflectionsHint: LocalizedText(
            id: "Jawabanmu hanya ikut jika kamu menyalakan ini. Bisa dimatikan kapan saja.",
            en: "Your answers only go on the card if you turn this on. You can change it any time."),
        .tripShareStopSharing: LocalizedText(
            id: "Hentikan berbagi", en: "Stop sharing"),
        .tripShareStopSharingConfirm: LocalizedText(
            id: "Tautan ini akan berhenti bekerja untuk siapa pun yang menyimpannya.",
            en: "This link will stop working for anyone who saved it."),
        .tripShareStoppedConfirmation: LocalizedText(
            id: "Berbagi dihentikan.", en: "Sharing turned off."),
        .tripShareCancel: LocalizedText(id: "Batal", en: "Cancel"),
        .restoreFailedTitle: LocalizedText(
            id: "Belum bisa mengambil perjalananmu",
            en: "Could not fetch your walks"),
        .restoreFailedBody: LocalizedText(
            id: "Perjalanan yang pernah kamu simpan mungkin masih ada. Kami belum berhasil mengambilnya, bukan berarti tidak ada.",
            en: "Walks you saved before may still be there. We could not fetch them — that is not the same as you having none."),
        .restoreRetryAction: LocalizedText(id: "Coba lagi", en: "Try again"),
        .restoreDismissAction: LocalizedText(id: "Nanti saja", en: "Not now"),
        .journalUnsealAction: LocalizedText(id: "Buka Segelnya", en: "Unseal the Journey"),
        .journalSealedEmptyTitle: LocalizedText(
            id: "Belum ada surat", en: "No letters yet"),
        .journalSealedEmptyBody: LocalizedText(
            id: "Setiap perjalanan yang kamu mulai disimpan di sini sebagai satu surat. Selesaikan satu rute, lalu kembali untuk membukanya.",
            en: "Every walk you start is kept here as a letter. Finish a route, then come back and open it."),
        .journalSwipeHint: LocalizedText(
            id: "Geser untuk surat lainnya", en: "Swipe for other letters"),
        .journalTapToOpen: LocalizedText(
            id: "Ketuk amplop untuk membuka", en: "Tap envelope to open"),
        .journalCollectionsAction: LocalizedText(id: "Koleksi huruf", en: "Letter collections"),
        .journalEnvelopeSalutation: LocalizedText(id: "Sudah kamu jalani,", en: "Well walked,"),
        .journalPaperSummaryEyebrow: LocalizedText(
            id: "Ringkasan Perjalanan", en: "Trip Summary"),
        .journalPaperSummaryTitle: LocalizedText(
            id: "Perjalananmu menyusuri %@", en: "Your journey through %@"),
        .journalPaperSummaryAction: LocalizedText(id: "Baca Ringkasan", en: "Read Summary"),
        .journalPaperHistoryEyebrow: LocalizedText(id: "Sejarah", en: "History"),
        .journalPaperHistoryTitle: LocalizedText(
            id: "Kisah Terakhir %@", en: "The Last Tales of %@"),
        .journalPaperHistoryAction: LocalizedText(id: "Baca Sejarah", en: "Read History"),
        .journalPapersClose: LocalizedText(id: "Tutup", en: "Close"),

        // MARK: Journal — the two pages a paper opens
        .tripPageBack: LocalizedText(id: "Kembali", en: "Back"),
        .tripJourneyHeading: LocalizedText(id: "Perjalananmu", en: "Your Journey"),
        .tripPlacesExplored: LocalizedText(id: "Tempat Dijelajahi", en: "Places Explored"),
        .tripMemories: LocalizedText(id: "Kenangan", en: "Memories"),
        .tripMemoriesUnit: LocalizedText(id: "terkumpul", en: "collected"),
        .tripDuration: LocalizedText(id: "Durasi", en: "Duration"),
        .tripDurationUnit: LocalizedText(id: "menit", en: "mins"),
        .tripPiecesHeading: LocalizedText(
            id: "Serpihan yang Kamu Temukan", en: "The Pieces You Found"),
        .tripCollectionLegend: LocalizedText(id: "Sang Legenda", en: "The Legends"),
        .tripShare: LocalizedText(id: "Bagikan", en: "Share"),
        .tripCollectionHeading: LocalizedText(
            id: "Koleksi Perjalanan", en: "Trip Collection"),
        .tripHistoryNoLore: LocalizedText(
            id: "Kamu sampai di tempat ini, tapi ceritanya belum sempat dibuka.",
            en: "You reached this place, but its story was never opened."),
        .tripHistoryClosing: LocalizedText(
            id: "Kamu sudah mengumpulkan serpihan-serpihan itu.",
            en: "You have gathered those fragments."),

        // MARK: Journal — writing one, from the Summary screen (Figma `921-2256`, `921-2932`)
        .writeJournalTitle: LocalizedText(id: "Tulis Jurnalmu", en: "Write Your Journal"),
        .writeJournalHeading: LocalizedText(
            id: "Bagaimana Perjalananmu?", en: "How's Your Journey?"),
        .writeJournalExperienceLabel: LocalizedText(
            id: "Ceritakan Pengalamanmu*", en: "Tell us Your Experience*"),
        .writeJournalExperiencePlaceholder: LocalizedText(
            id: "Bagaimana pengalamanmu selama perjalanan ini?",
            en: "How your experience during this trip?"),
        .writeJournalMemoriesLabel: LocalizedText(
            id: "Kenangan Aktivitas*", en: "Activities Memories*"),
        .writeJournalAddPlacePhoto: LocalizedText(
            id: "Tambah Foto Tempat", en: "Add Place Photo"),
        .writeJournalAddSelfie: LocalizedText(id: "Tambah Swafotomu", en: "Add Your Selfie"),
        .writeJournalSaveAction: LocalizedText(id: "Simpan", en: "Save"),
        .journeySavedTitle: LocalizedText(
            id: "Perjalananmu Tersimpan!", en: "Your Journey is Saved!"),
        .journeySavedRecapAction: LocalizedText(
            id: "Lihat Rekap Perjalanan", en: "See Journey Recap"),

        // The trip-completion carousel (`205:121`, `205:151`, `205:205`)
        .tripRecapHeadlineTitle: LocalizedText(
            id: "Kamu Menghidupkan Kembali Sejarah!", en: "You Made History Come Alive!"),
        .tripRecapHeadlineBody: LocalizedText(
            id: "Kamu telah menyelesaikan kisah ini dan menyusuri setiap tempatnya, "
                + "menyingkap masa lalu, dan merasakan warisan hidup Bali.",
            en: "You’ve completed this story and walked through the places, uncovered the past, "
                + "and experienced a piece of Bali’s living heritage."),
        .tripRecapGlanceTitle: LocalizedText(
            id: "Perjalananmu Sekilas", en: "Your Journey at a Glance"),
        .tripRecapStatExploredPlaces: LocalizedText(id: "Tempat Dijelajahi", en: "Explored Places"),
        .tripRecapStatTripDuration: LocalizedText(id: "Durasi Perjalanan", en: "Trip Duration"),
        .tripRecapStatCompletedQuests: LocalizedText(id: "Quest Selesai", en: "Completed Quests"),
        .tripRecapStatMemories: LocalizedText(id: "Kenangan", en: "Memories"),
        .tripRecapDurationUnit: LocalizedText(id: "mnt", en: "m"),
        .tripRecapExploredTitle: LocalizedText(
            id: "Kamu menjelajahi %d tempat bersejarah di %@.",
            en: "You explored %d historic places in %@."),
        .tripRecapExploredTitleNoRegion: LocalizedText(
            id: "Kamu menjelajahi %d tempat bersejarah.",
            en: "You explored %d historic places."),
        .tripRecapMemoriesTitle: LocalizedText(
            id: "Kenangan dari Perjalananmu", en: "Memories From Your Journey"),
        .tripRecapMemoLabel: LocalizedText(id: "Catatan", en: "Memo"),
        .tripRecapPlacesUnit: LocalizedText(id: "%d Tempat", en: "%d Places"),
        .tripRecapMinutesUnit: LocalizedText(id: "%d Menit", en: "%d Minutes"),
        .tripRecapPostcardTitle: LocalizedText(id: "POSTCARD", en: "POSTCARD"),
        .tripRecapPostcardFrom: LocalizedText(id: "dari %@", en: "from %@"),
        .tripRecapShareAction: LocalizedText(id: "Bagikan", en: "Share"),
        .tripRecapCloseAction: LocalizedText(id: "Tutup Ringkasan", en: "Close Summary"),

        // MARK: Profile — the Explorer's Card
        .profileHeading: LocalizedText(id: "Kartu Penjelajah", en: "Explorer’s Card"),
        .profileExplorerName: LocalizedText(id: "Penjelajah", en: "Explorer"),
        .profileExplorerNameNote: LocalizedText(
            id: "Belum ada nama tampilan, jadi kartu ini memakai perannya.",
            en: "No display name yet, so the card is headed by role."),
        .profileStatQuests: LocalizedText(id: "Perjalanan", en: "Quests"),
        .profileStatStamps: LocalizedText(id: "Stempel", en: "Stamps"),
        .profileStatBadges: LocalizedText(id: "Lencana", en: "Badges"),
        .profileTabQuests: LocalizedText(id: "Perjalanan", en: "Quests"),
        .profileTabStamps: LocalizedText(id: "Stempel", en: "Stamps"),
        .profileTabBadges: LocalizedText(id: "Lencana", en: "Badges"),
        .profileActivityComplete: LocalizedText(id: "Selesai", en: "Completed"),
        .profileQuestCompletedAt: LocalizedText(
            id: "Kamu menyelesaikan perjalanan ini di",
            en: "You completed this quest at"),
        .profileQuestFilterAll: LocalizedText(id: "Semua", en: "All"),
        .profileQuestFilterUnfinished: LocalizedText(id: "Belum Selesai", en: "Unfinished"),
        .profileQuestFilterDone: LocalizedText(id: "Selesai", en: "Done"),
        .profileQuestsDoneEmpty: LocalizedText(
            id: "Perjalanan yang sudah kamu selesaikan muncul di sini.",
            en: "Walks you have finished show up here."),
        .profileQuestsAllEmpty: LocalizedText(
            id: "Perjalanan yang kamu mulai muncul di sini.",
            en: "Walks you start show up here."),
        .profileQuestsEmpty: LocalizedText(
            id: "Perjalanan yang sudah kamu mulai tapi belum selesai muncul di sini.",
            en: "Walks you have started but not finished show up here."),
        .profileQuestResumeHint: LocalizedText(
            id: "Lanjutkan perjalanan ini",
            en: "Resume this walk"),
        .profileStampsEmpty: LocalizedText(
            id: "Setiap titik yang kamu capai memberi satu stempel.",
            en: "Every checkpoint you reach gives one stamp."),
        .profileBadgesEmpty: LocalizedText(
            id: "Lencana diberikan saat sebuah perjalanan selesai seluruhnya.",
            en: "A badge is given when a whole walk is finished."),

        .settingsPlaceholderContentNotice: LocalizedText(
            id: "Konten pada versi ini adalah data contoh dengan tempat fiktif. Belum divalidasi di lapangan dan belum untuk dipakai berjalan.",
            en: "The content in this build is example data with fictional places. It has not been field-validated and is not yet something to walk."),

        // MARK: Sidequest proximity notifications — FR-WATCH-07
        .sideQuestNotificationOpenInApp: LocalizedText(id: "Buka di Aplikasi", en: "Open in App"),
    ]
}
