import Foundation

/// Which seal a badge is cast in, when the design gives that badge a seal of its own.
///
/// The table lives here, in the app target, and not on `Quest` — the same reason
/// `StampArtworkResolver.slugsByPlaceID` and `MapLandmarkCatalog` do. A seal is part of the visual
/// direction and is replaced with it; a `ContentKit` field for it would make the artwork a content
/// decision that has to survive a content update with nothing to say about it (`AD-4`).
///
/// It is keyed on the **badge id** — `Award.sourceID`, which every badge award snapshots — rather
/// than on a quest id. That is what makes it work for a collection's badge (`FR-SIDE-09`) as well
/// as a walk's, and what keeps a withdrawn quest's badge resolving to its own seal (`FR-DONE-05`).
///
/// A badge with no entry falls back to the four coloured waxes cycled by position, which is what
/// every badge did before this table existed. That is the honest fallback and also the debt: a
/// third authored quest gets a blank wax until this file is edited.
enum BadgeSealCatalog {

    /// The Journal envelope's own seal — crimson wax with the candi bentar struck into it
    /// (`511:1430`) — is what both Badung walks are marked with. It is the same object the letter
    /// they earned is closed with, which is the point: the badge and the letter come from one walk.
    private static let byBadgeID: [String: String] = [
        "badge-badung-empat-wajah": "wax-seal",
        "badge-mini-badung": "wax-seal",
    ]

    /// `nil` when the design casts no seal for this badge, which the card reads as "use the wax for
    /// its position".
    static func artworkName(forBadgeID id: String) -> String? { byBadgeID[id] }
}
