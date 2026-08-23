import ContentKit

/// Which phrases the four Story frames (`964:3212` and its siblings) ring with the hand-drawn
/// yellow mark, per Place and per language.
///
/// Same shape and same debt as `StampArtworkResolver.slugsByPlaceID` and `QuestHistoryText`: a
/// second quest gets no marks until somebody edits this table, and falls back to an unmarked
/// passage — the honest fallback, and also the debt. The phrases are matched against the joined
/// `loreSegment` text at the run's language; a phrase whose wording drifts simply stops matching,
/// which is why `HisploraMarkedPassage` treats a missing phrase as nothing rather than as an error.
///
/// They live in the app target rather than on content because the marks are how the frames *draw*
/// emphasis, not facts about the places — the same reasoning that keeps the stamp artwork's
/// place-to-artwork table out of `Place`.
enum StoryMarkedPhrases {

    static func phrases(for placeID: String, language: ContentLanguage) -> [String] {
        switch (placeID, language) {
        case ("badung-pura-maospahit", _):
            ["Kebo Iwa"]
        case ("badung-pasar-kumbasari", _):
            ["Pasar Badung"]
        case ("badung-catur-muka", .en):
            ["Catur Muka statue"]
        case ("badung-catur-muka", .id):
            ["Patung Catur Muka"]
        case ("badung-museum-bali", .en):
            ["Museum Bali,", "opened in 1932,"]
        case ("badung-museum-bali", .id):
            ["Museum Bali,", "dibuka pada 1932,"]
        default:
            []
        }
    }
}
