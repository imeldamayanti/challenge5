import ContentKit
import Foundation

/// The prose the History page prints, per quest.
///
/// **A table in the app target, not a field on `Quest` — and that is debt, stated as such.** It is
/// the same shape and the same debt as `StampArtworkResolver.slugsByPlaceID` and
/// `JournalPaperPresentation.artworkName`: a second quest gets no History page until somebody edits
/// this file. The alternative — a `history` array on the authored quest — is the right long-term
/// home, and it is a schema change, a validator rule, a `contentBundleVersion` bump and a decode
/// path. It is not done here because the page's *layout* is `791:6537` and nothing else: the
/// paragraphs are placed at coordinates the frame chose, around illustrations the frame chose, so
/// an authored list of blocks would still have had to arrive in exactly this order and this count.
/// Encoding that in content would be encoding a layout in content.
///
/// > **What is in here is unverified and unsourced, and that is a decision with an owner.** The
/// > paragraphs below are the Figma frame's own words about the fall of Badung — the Dutch
/// > expedition, the date, the Puputan, the last king of Denpasar named and portrayed. None of it
/// > carries a citation, none of it went through `sources`, and it therefore breaks the rule every
/// > other passage in this app follows (`FR-CP-05`, `FR-CP-06`): a claim is shown with its
/// > provenance or it is not shown. It ships because the owner asked on 2026-08-20 for `791:6537`
/// > reproduced exactly, on the grounds that the History page is the quest's own story rather than
/// > something the walker collects. `docs/hisplora-tokens.md` records the decision and what has to
/// > happen before anything public: citations for every sentence here, and a consent or licence
/// > record for the portrait.
struct QuestHistoryText: Sendable, Equatable {

    /// One line of the page, in both languages. `LocalizedText`'s no-fallback rule applies here for
    /// the same reason it applies to content: a half-translated page is worse than a missing one
    /// (`NFR-I18N-03`), so every line carries both.
    struct Line: Sendable, Equatable {
        let id: String
        let en: String

        func value(for language: ContentLanguage) -> String {
            switch language {
            case .id: id
            case .en: en
            }
        }
    }

    /// `791:6548` — the line under the opening plate.
    let caption: Line
    /// `791:6552`, `791:6557`, `791:6558` — the three paragraphs of the second band.
    let opening: Line
    let kingdoms: Line
    let everydayLife: Line
    /// `791:6563` — the justified paragraph.
    let tension: Line
    /// `791:6567` — the dark band, and the phrase it ends on in gilt italic.
    let expedition: Line
    let expeditionEmphasis: Line
    /// `791:6575` and `791:6573` — the two paragraphs beside the portrait.
    let lastKing: Line
    let ruler: Line
    /// `791:6578` — the line set on the open book.
    let defeat: Line
    /// `791:6583` — what survived.
    let survival: Line
    /// Who the featured medallion on the Trip Collection is a portrait of (`791:6486`).
    let legend: Line

    /// The pages that exist. A quest absent from this table falls back to the lore-chapter page,
    /// which is built from that walk's own snapshots and needs nobody to author anything.
    static let byQuestID: [String: QuestHistoryText] = [
        "badung-empat-wajah": badungEmpatWajah
    ]

    static let badungEmpatWajah = QuestHistoryText(
        caption: Line(
            id: "sebuah kerajaan, sebuah kota, sebuah perlawanan terakhir",
            en: "a kingdom, a city, a final stand"),
        opening: Line(
            id: "Jauh sebelum Denpasar modern, Badung dibentuk oleh kerajaan-kerajaan, tradisi sakral, komunitas, dan pertukaran budaya selama berabad-abad.",
            en: "Long before modern Denpasar, Badung was shaped by kingdoms, sacred traditions, communities, and centuries of cultural exchange."),
        kingdoms: Line(
            id: "Kerajaan Badung tumbuh menjadi kerajaan yang kuat di Bali selatan, dengan pusat-pusat kerajaan seperti Kesiman, Denpasar, dan Pemecutan. ",
            en: "The Kingdom of Badung grew into a powerful kingdom in southern Bali, with royal centers including Kesiman, Denpasar, and Pemecutan. "),
        everydayLife: Line(
            id: "Di sekitar pusat-pusat itu, pura, puri, pasar, dan komunitas menjadi bagian dari keseharian.",
            en: "Around these centers, temples, palaces, markets, and communities became part of everyday life."),
        tension: Line(
            id: "Namun pada awal abad ke-20, hubungan Badung dengan pemerintah kolonial Belanda kian menegang. Perselisihan atas tuntutan Belanda dan penolakan kerajaan untuk tunduk akhirnya berujung pada satu ekspedisi militer.",
            en: "But in the early 20th century, Badung's relationship with the Dutch colonial government grew increasingly tense. Disputes over Dutch demands and the kingdom's refusal to submit eventually led to a military expedition."),
        expedition: Line(
            id: "Pada 20 September 1906, pasukan Belanda bergerak menuju pusat kerajaan Denpasar dan Pemecutan. Alih-alih menyerah, keluarga kerajaan dan para pengikutnya memilih melawan dalam peristiwa yang kemudian dikenal sebagai ",
            en: "On 20 September 1906, Dutch forces advanced toward the royal centers of Denpasar and Pemecutan. Rather than surrender, the royal families and their followers chose to resist in what became known as "),
        expeditionEmphasis: Line(id: "Puputan Badung.", en: "Puputan Badung."),
        lastKing: Line(
            id: "Di pusat babak terakhir ini berdiri raja terakhir Denpasar, I Gusti Ngurah Made Agung.",
            en: "At the center of this final chapter stood the last King of Denpasar, I Gusti Ngurah Made Agung."),
        ruler: Line(
            id: "Sebagai penguasa, cendekiawan, dan penyair, ia memilih mempertahankan kerajaan ketimbang menyerahkan kedaulatannya.",
            en: "As a ruler, scholar, and poet, he chose to defend the kingdom rather than surrender its sovereignty."),
        defeat: Line(
            id: "Menjelang akhir hari, perlawanan itu telah dipatahkan dan Kerajaan Badung jatuh ke bawah kendali Belanda. Namun runtuhnya kerajaan tidak menghapus sejarahnya.",
            en: "By the end of the day, the resistance had been defeated and the Kingdom of Badung fell under Dutch control. Yet the kingdom's fall did not erase its history."),
        survival: Line(
            id: "Pura, puri, pasar, artefak, tradisi, dan kenangannya terus bertahan — menjadi serpihan-serpihan kisah yang membentuk Denpasar modern.",
            en: "Its temples, palaces, markets, artifacts, traditions, and memories continued to survive — becoming fragments of the story that shaped modern Denpasar."),
        legend: Line(id: "I Gusti Ngurah Made Agung", en: "I Gusti Ngurah Made Agung"))
}
