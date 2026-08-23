import ContentKit
import Foundation

/// The prose the Discovery page prints, per sidequest (Figma `949:2461`).
///
/// **The same shape and the same debt as `QuestHistoryText`, and the argument is identical.** A
/// sidequest absent from this table gets no drawn page and falls back to its own authored lore,
/// with the accuracy labels and citations `FR-CP-05` and `FR-CP-06` ask for. Encoding the drawn
/// page in content would be encoding a *layout* in content: the paragraphs sit at coordinates the
/// frame chose, around photographs the frame chose, in an order and a count the frame fixed.
///
/// > **What is in here is unverified and unsourced.** The Majapahit landing at Tuban, the date, the
/// > name of the forest, Gajah Mada leading the fleet, the etymology of "Tuban" — none of it
/// > carries a citation and none of it went through `sources`. It ships on the same footing as
/// > `QuestHistoryText`: the owner asked for `949:2461` reproduced, and the page is the place's own
/// > story rather than something the walker collects. Before anything public this needs a citation
/// > per sentence and a licence record for the two photographs (`HisploraTripArtwork.discoveryGate`
/// > and `.discoveryGrove`), which is written down in `docs/hisplora-tokens.md` beside the same
/// > problem on the History page.
struct SideQuestDiscoveryText: Sendable, Equatable {

    /// One line of the page, in both languages — `LocalizedText`'s no-fallback rule applied to a
    /// table that lives in the app target rather than in content (`NFR-I18N-03`).
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

    /// `949:2466` — the masthead, set solid over two lines.
    let headline: Line
    /// `949:2472` — the line in seal red under the two photographs.
    let caption: Line
    /// `949:2476` — where the reader is standing.
    let here: Line
    /// `949:2481` — what was here first.
    let before: Line
    /// `949:2482` — the arrival, ending on the phrase the highlighter picks out.
    let arrival: Line
    /// The words inside `arrival` the marker stroke is drawn under (`949:2477`).
    ///
    /// A substring of `arrival` rather than a separate run, so the paragraph still wraps as one
    /// paragraph. A phrase that is not found simply gets no mark — the stroke is decoration, and
    /// `NFR-A11Y-05` is met by the sentence, never by the yellow.
    let arrivalMarkedPhrase: Line
    /// `949:2487` — the justified paragraph on its own band.
    let strategy: Line
    /// `949:2491` — the closing paragraph over dark paper, and the name set in gilt italic inside
    /// it. `landingLead` runs before the name and `landingTail` after it.
    let landingLead: Line
    let landingName: Line
    let landingTail: Line

    /// The pages that exist. Keyed by **sidequest** id, because a Discovery page is what a walker
    /// gets for passing one place, not for finishing a quest.
    static let bySideQuestID: [String: SideQuestDiscoveryText] = [
        "sq-park23": majapahitLanding
    ]

    /// `949:2461` — the landing at Tuban, which is where `park23` stands (−8.7368, 115.1759, a few
    /// hundred metres off the end of Ngurah Rai's runway). That is why the page opens on a split
    /// gate with an aircraft behind it.
    static let majapahitLanding = SideQuestDiscoveryText(
        headline: Line(
            id: "Pendaratan Agung Majapahit",
            en: "The Great Majapahit Landing"),
        caption: Line(
            id: "hari ketika kekaisaran itu tiba",
            en: "the day the empire arrived"),
        here: Line(
            id: "Kamu sedang berdiri di pusat kreatif yang ramai, beberapa menit saja dari deru pesawat. Tapi 600 tahun lalu, satu-satunya deru di sini datang dari laut.",
            en: "You are standing in a bustling creative hub, just minutes away from roaring airplanes. But 600 years ago, the only roar here came from the sea."),
        before: Line(
            id: "Jauh sebelum aspal dihamparkan, pesisir ini adalah hutan liar dan keramat yang dikenal warga sebagai Mataeb.",
            en: "Long before the tarmac was laid, this coastline was a wild, mystical forest known to locals as Mataeb."),
        arrival: Line(
            id: "Pada abad ke-14, sunyi pantai ini dipecah oleh datangnya armada besar dari Kekaisaran Majapahit.",
            en: "In the 14th century, the silence of this shore was broken by the arrival of a massive armada from the Majapahit Empire."),
        arrivalMarkedPhrase: Line(id: "Kekaisaran Majapahit.", en: "Majapahit Empire."),
        strategy: Line(
            id: "Pesisir selatan menawarkan titik masuk yang sangat strategis, dipilih untuk melewati kerajaan-kerajaan utara yang berbenteng. Ekspedisi besar ini menandai awal penaklukan terakhir Majapahit atas pulau ini.",
            en: "The southern coast offered a highly strategic entry point, chosen to bypass the fortified northern kingdoms of the island. This massive expedition marked the beginning of Majapahit's final conquest over the island."),
        landingLead: Line(
            id: "Dipimpin oleh ", en: "Led by the legendary "),
        landingName: Line(id: "Gajah Mada,", en: "Gajah Mada,"),
        landingTail: Line(
            id: " mereka mendarat tepat di pesisir ini untuk membawa Bali ke bawah kekuasaan mereka. Untuk menghormati pelabuhan asal mereka di Jawa, tanah ini mereka namai Tuban — nama yang bertahan lebih lama daripada kekaisaran dan tetap dipakai sampai hari ini.",
            en: " they landed on this exact coastline to bring Bali under their rule. In honor of their home port in Java, they named this land Tuban — a name that outlived empires and remains to this day."))

    /// Every word on the canvas, in reading order, for a reader who cannot see it. The page is one
    /// picture to the layout engine (`TripFramePage`), so this is its whole text.
    func spoken(for language: ContentLanguage) -> String {
        [headline, caption, here, before, arrival, strategy]
            .map { $0.value(for: language) }
            .joined(separator: "\n\n")
            + "\n\n"
            + landingLead.value(for: language)
            + landingName.value(for: language)
            + landingTail.value(for: language)
    }
}
