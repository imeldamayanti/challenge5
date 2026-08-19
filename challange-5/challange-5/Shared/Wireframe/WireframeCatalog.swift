import ContentKit
import Foundation

/// What one not-yet-built screen has to say for itself: its name, why the flow has it, the blocks
/// the flowchart draws inside it, and where it sits in the flow.
///
/// Held as `LocalizedText` rather than as `UIStringKey`s, in one file, for one reason: these are
/// placeholders. When a screen is built for real its copy moves into `UIStrings` with the rest of
/// the interface, and its entry here is deleted. Keeping them out of the shared table means the
/// deletion is a single hunk and the real string table never carries copy for screens that do not
/// exist. Both languages are still present, so `NFR-I18N-01`/`NFR-I18N-03` hold on these screens
/// exactly as they do everywhere else.
struct WireframeSpec: Sendable {
    let title: LocalizedText
    let purpose: LocalizedText
    /// The boxes the flowchart puts on this screen, drawn as empty placeholders.
    let blocks: [LocalizedText]
    /// Where this sits in the flow, and what has to exist before it can be built for real.
    let flowNote: LocalizedText
}

enum WireframeCatalog {

    // MARK: Shared furniture

    static let stamp = LocalizedText(id: "Wireframe // Belum dibangun", en: "Wireframe // Not built")
    static let notBuiltNote = LocalizedText(
        id: "Layar ini belum ada. Yang tampil di bawah adalah kotak kosong sesuai alur, bukan fitur yang jalan.",
        en: "This screen does not exist yet. What is below is empty boxes following the flow, not a working feature.")

    static let continueAction = LocalizedText(id: "Lanjut", en: "Continue")
    static let backAction = LocalizedText(id: "Kembali", en: "Back")
    static let skipAction = LocalizedText(id: "Lewati dulu", en: "Skip for now")
    static let yesAction = LocalizedText(id: "Ya", en: "Yes")
    static let noAction = LocalizedText(id: "Tidak", en: "No")

    // MARK: Entry — splash, login, register

    static let splash = WireframeSpec(
        title: LocalizedText(id: "Splash screen", en: "Splash screen"),
        purpose: LocalizedText(
            id: "Layar pembuka saat aplikasi dijalankan, sebelum onboarding.",
            en: "The opening screen at launch, before onboarding."),
        blocks: [
            LocalizedText(id: "Logo / wordmark aplikasi", en: "App logo / wordmark"),
            LocalizedText(id: "Tagline satu baris", en: "One-line tagline"),
            LocalizedText(id: "Indikator pemuatan konten", en: "Content loading indicator"),
        ],
        flowNote: LocalizedText(
            id: "Splash → Onboarding → Login/Register → Home. Nama aplikasi belum diputuskan, jadi wordmark-nya masih kosong.",
            en: "Splash → Onboarding → Login/Register → Home. The app has no name yet, so the wordmark is deliberately empty."))

    static let login = WireframeSpec(
        title: LocalizedText(id: "Login", en: "Login"),
        purpose: LocalizedText(
            id: "Masuk ke akun sebelum masuk Home.",
            en: "Sign in to an account before reaching Home."),
        blocks: [
            LocalizedText(id: "Kolom email", en: "Email field"),
            LocalizedText(id: "Kolom kata sandi", en: "Password field"),
            LocalizedText(id: "Tombol masuk", en: "Sign-in button"),
            LocalizedText(id: "Tautan ke Register", en: "Link to Register"),
        ],
        flowNote: LocalizedText(
            id: "Belum ada backend akun, dan seluruh alur inti dirancang jalan tanpa jaringan (AD-3). Layar ini butuh keputusan produk dulu: data apa yang disimpan di server, dan apa yang tetap bisa dipakai offline.",
            en: "There is no account backend, and every core flow is designed to work with no network (AD-3). This screen needs a product decision first: what is stored on a server, and what still has to work offline."))

    static let register = WireframeSpec(
        title: LocalizedText(id: "Register", en: "Register"),
        purpose: LocalizedText(
            id: "Membuat akun baru.",
            en: "Create a new account."),
        blocks: [
            LocalizedText(id: "Nama tampilan", en: "Display name"),
            LocalizedText(id: "Email", en: "Email"),
            LocalizedText(id: "Kata sandi dan konfirmasi", en: "Password and confirmation"),
            LocalizedText(id: "Persetujuan syarat dan privasi", en: "Terms and privacy consent"),
        ],
        flowNote: LocalizedText(
            id: "Sama seperti Login: butuh backend, dan butuh keputusan soal data pribadi sebelum dibangun.",
            en: "Same as Login: needs a backend, and needs a personal-data decision before it is built."))

    // MARK: Journal branch

    static let createJournal = WireframeSpec(
        title: LocalizedText(id: "Create Journal", en: "Create Journal"),
        purpose: LocalizedText(
            id: "Menulis catatan perjalanan sesudah quest selesai, lalu menyimpannya.",
            en: "Write a journal entry after a quest is finished, then save it."),
        blocks: [
            LocalizedText(id: "Judul catatan", en: "Entry title"),
            LocalizedText(id: "Isi catatan bebas", en: "Free-text body"),
            LocalizedText(id: "Lampiran foto perjalanan", en: "Attached trip photos"),
            LocalizedText(id: "Tombol Save Journal", en: "Save Journal button"),
        ],
        flowNote: LocalizedText(
            id: "Completion screen → mau bikin journal? → Create Journal → Save Journal → Trip Summary. Kegiatan foto sendiri belum dirilis, jadi lampiran foto menunggu itu dulu.",
            en: "Completion screen → want to create a journal? → Create Journal → Save Journal → Trip Summary. Photo activities have not shipped, so the photo attachment waits on those."))

    static let tripSummary = WireframeSpec(
        title: LocalizedText(id: "Trip Summary", en: "Trip Summary"),
        purpose: LocalizedText(
            id: "Satu perjalanan, dirangkum: catatan, detail, foto, stempel.",
            en: "One trip, gathered: the journal, the detail, the photos, the stamps."),
        blocks: [
            LocalizedText(id: "Catatan journal (kalau ada)", en: "Journal entry (if any)"),
            LocalizedText(id: "Detail perjalanan: tanggal, durasi, jarak, langkah", en: "Trip detail: date, duration, distance, steps"),
            LocalizedText(id: "Foto", en: "Photos"),
            LocalizedText(id: "Stempel dan lencana", en: "Stamps and badges"),
            LocalizedText(id: "Tokoh sejarah yang ditemui", en: "The legends met along the way"),
        ],
        flowNote: LocalizedText(
            id: "Ringkasan yang sudah jalan ada di layar Summary bawaan quest — dirender dari snapshot perjalanan, jadi tetap benar walau kontennya berubah. Layar ini menumpuk catatan, foto, dan koleksi di atasnya.",
            en: "The working summary is the quest's own Summary screen — rendered from the walk's snapshots, so it stays correct after content changes. This screen stacks the journal, photos and collection on top of it."))

    static let shareTemplate = WireframeSpec(
        title: LocalizedText(id: "Template preview", en: "Template preview"),
        purpose: LocalizedText(
            id: "Kartu untuk dibagikan ke media sosial.",
            en: "The card that gets shared to social media."),
        blocks: [
            LocalizedText(id: "Judul cerita dan konteksnya", en: "Story title and context"),
            LocalizedText(id: "Foto perjalanan", en: "Trip photos"),
            LocalizedText(id: "Rute", en: "Route"),
            LocalizedText(id: "Jarak jalan kaki / jumlah langkah", en: "Walking distance / steps"),
            LocalizedText(id: "Pilihan latar", en: "Background choice"),
        ],
        flowNote: LocalizedText(
            id: "Trip Summary → mau berbagi? → Template preview. Kartu ini harus dibangun dari snapshot perjalanan, bukan dari konten yang bisa berubah, dan tetap jalan tanpa jaringan sampai titik berbagi.",
            en: "Trip Summary → want to share? → Template preview. The card has to be built from the walk's snapshots rather than from content that can change, and it must work offline right up to the share sheet."))

    static let recommendation = WireframeSpec(
        title: LocalizedText(id: "Petualangan berikutnya", en: "Next adventure"),
        purpose: LocalizedText(
            id: "Rekomendasi quest berikutnya sesudah satu perjalanan ditutup.",
            en: "Recommended quests once a trip is closed out."),
        blocks: [
            LocalizedText(id: "Kartu quest yang disarankan", en: "Suggested quest cards"),
            LocalizedText(id: "Alasan rekomendasi", en: "Why this is suggested"),
            LocalizedText(id: "Tautan kembali ke Home", en: "Way back to Home"),
        ],
        flowNote: LocalizedText(
            id: "Cabang \"tidak\" dari pertanyaan berbagi berakhir di sini. Dasar rekomendasinya belum diputuskan — wilayah, tema, atau apa yang belum pernah dijalani.",
            en: "The \"no\" branch of the share question ends here. What the recommendation is based on has not been decided — region, theme, or simply what has not been walked yet."))

    // MARK: Profile branch
    //
    // `profile` and `accountSettings` were drawings of the Profile tab and the account screen
    // behind it. `profile` is **deleted** in the commit that shipped `ExplorerCardView` — this
    // file's own rule. `accountSettings` went with it rather than outliving it: it was reachable
    // only from `profile`, and the Explorer's Card that replaces it carries one control, to the
    // App preferences that are real. An account screen still needs the decision Login needs, and
    // when that decision is taken the node comes back with its own entry point.

    // MARK: Passing-by notification branch
    //
    // `nearbyNotice` and `nearbyStory` were drawings of the sidequest flow. Both are **deleted**,
    // in the same commit that shipped their real screens — `SideQuestNoticeView` and
    // `SideQuestStoryView` (`s0` D12, and this file's own rule at the top). Their copy moved into
    // `UIStrings` with the rest of the interface.
    //
    // The notification itself is still unbuilt (`s3`), but a wireframe of a notification is not a
    // screen — the entry point that exists today is "Places nearby" in the Quests tab.
}
