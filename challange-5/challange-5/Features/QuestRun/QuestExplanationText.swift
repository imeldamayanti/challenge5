import ContentKit

/// The passage `1:4609` prints once a task has been answered — one per Place, in both languages.
///
/// **Per Place, not per task, and that is the current state rather than the intent.** The frame
/// tells the story of *the thing the task pointed at*, so each of a checkpoint's tasks should
/// eventually carry its own topic. `ContentTask` has no field for one — it holds an `id`, a `type`,
/// a `prompt` and `blocksProgression`, and nothing else — and authoring fifteen separate passages
/// is a content decision with an owner. The owner's instruction of 2026-08-26 was to write one per
/// place and let the checkpoint's three tasks share it until then, which is what this table is.
/// Splitting it later means keying by task id and filling in the other two thirds; nothing else
/// about the screen changes.
///
/// **Same shape and same debt as `QuestHistoryText`, `StoryMarkedPhrases` and
/// `StampArtworkResolver.slugsByPlaceID`:** a table in the app target rather than a field on
/// `Place`. A sixth place gets the Place's own `loreStandalone` back — the honest fallback, and
/// also the debt.
///
/// > **These sentences are unsourced, and they are shown without the provenance every other
/// > authored passage in this app carries.** They are the owner's own words, supplied on
/// > 2026-08-26, and they make checkable claims — a nine-metre granite statue carved in 1973 by
/// > I Gusti Nyoman Lempad, a market trading since the royal era, a museum that is Bali's oldest.
/// > None of it went through `sources`, so none of it can print an accuracy label or a citation,
/// > which is the rule `FR-CP-05` and `FR-CP-06` hold everywhere else. It ships on the same footing
/// > as `QuestHistoryText`'s nine paragraphs and for the same stated reason: this page is the
/// > quest's own storytelling rather than something the walker collects. Before anything public,
/// > each sentence here needs a citation, or the screen goes back to rendering the Place's cited
/// > `loreStandalone`. The fallback path is still in `QuestExplanationScreen` and still works.
struct QuestExplanationText: Sendable, Equatable {

    /// One line, in both languages. `LocalizedText`'s no-fallback rule applies for the reason it
    /// applies to content: a half-translated page is worse than a missing one (`NFR-I18N-03`).
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

    /// The hook the passage opens on — what `1:4621`'s first line is for. It stands where
    /// `UIStrings.questExplanationLead` ("Let me tell you something…") stands on the fallback page,
    /// because a place that has something specific to say should say it rather than clear its
    /// throat first.
    let lead: Line
    /// The passage itself.
    let body: Line

    /// The places that have one. Anything absent falls back to the cited `loreStandalone`.
    static let byPlaceID: [String: QuestExplanationText] = [
        "badung-puri-agung-pemecutan": puriAgungPemecutan,
        "badung-pura-maospahit": puraMaospahit,
        "badung-pasar-badung": pasarBadung,
        "badung-catur-muka": caturMuka,
        "badung-museum-bali": museumBali,
    ]

    static let puriAgungPemecutan = QuestExplanationText(
        lead: Line(
            id: "Sekarang kamu tahu arti namanya.",
            en: "Now you know what the name means."),
        body: Line(
            id: "Nama Pemecutan berasal dari pecut, yang berarti cambuk. Lambang itu terhubung dengan kisah Arya Bebed, yang menerima sebuah pecut dan sebuah sumpit sebagai anugerah setelah bertapa di Gunung Batur.",
            en: "The name Pemecutan comes from pecut, meaning whip. The symbol is connected to the story of Arya Bebed, who received a whip and a blowpipe as divine gifts after his meditation on Mount Batur."))

    static let puraMaospahit = QuestExplanationText(
        lead: Line(
            id: "Sempat memperhatikan bata merahnya?",
            en: "Did you notice the red bricks?"),
        body: Line(
            id: "Berbeda dari kebanyakan pura di Bali, Pura Maospahit sangat dipengaruhi arsitektur Jawa Timur. Bangunan bata merah, arca terakota, dan reliefnya menjadikannya salah satu tetenger arsitektur yang khas di Denpasar.",
            en: "Unlike many Balinese temples, Pura Maospahit is strongly influenced by East Javanese architecture. Its red-brick structures, terracotta statues, and reliefs make it one of Denpasar's distinctive architectural landmarks."))

    static let pasarBadung = QuestExplanationText(
        lead: Line(
            id: "Ada lebih banyak hal di balik pasar ini daripada yang terlihat.",
            en: "There's more beneath the market than meets the eye."),
        body: Line(
            id: "Pasar Badung sudah menjadi pusat perdagangan sejak masa kerajaan. Kini pasar itu buka sepanjang hari, sementara Tukad Badung di sebelahnya telah diubah menjadi jalur tepi sungai yang dikenal sebagai \u{201C}Taman Korea\u{201D}.",
            en: "Pasar Badung has been a center of trade since the royal era. Today, the market operates around the clock, while Tukad Badung beside it has been transformed into a river walk known as \u{201C}Taman Korea\u{201D}."))

    static let caturMuka = QuestExplanationText(
        lead: Line(
            id: "Empat wajah, empat makna.",
            en: "Four faces, four meanings."),
        body: Line(
            id: "Keempat wajah Catur Muka melambangkan sifat yang berbeda: kebijaksanaan, welas asih, kekuatan dan penyucian, serta ketenangan. Patung granit setinggi sembilan meter itu dibuat pada 1973 oleh seniman Bali I Gusti Nyoman Lempad.",
            en: "The four faces of Catur Muka represent different qualities: wisdom, compassion, strength and purification, and tranquility. The nine-meter granite statue was created in 1973 by Balinese artist I Gusti Nyoman Lempad."))

    static let museumBali = QuestExplanationText(
        lead: Line(
            id: "Lihat lebih dari bangunannya \u{2014} ada cerita di setiap koleksi.",
            en: "Look beyond the buildings \u{2014} there's a story in every collection."),
        body: Line(
            id: "Museum Bali adalah museum tertua di Bali. Koleksinya membentang dari artefak prasejarah sampai kain tradisional, topeng, wayang, dan pusaka kerajaan, memberi pengunjung gambaran bagaimana budaya Bali berkembang lintas generasi.",
            en: "Museum Bali is the oldest museum in Bali. Its collections range from prehistoric artifacts to traditional textiles, masks, wayang, and royal heirlooms, giving visitors a glimpse into how Balinese culture evolved across generations."))
}
