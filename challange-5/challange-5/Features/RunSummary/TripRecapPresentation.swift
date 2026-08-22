import Foundation

/// One place stamped into the "You explored N historic places" collage (`205:205`) — resolved
/// against the walker's own records the same way the Explorer's Card resolves its stamps
/// (`StampArtworkResolver`), so the drawing shown here is never out of step with the one shown
/// there for the same walk.
///
/// **Built outside the screen, not inside it.** `RunSummaryViewModel` deliberately holds no
/// `ContentRepository` (`FR-DONE-04`/`FR-DONE-05` — see its own header), and place artwork needs
/// one to resolve a region and a slug. So this is assembled once, where `KultaraRootView` already
/// has both a repository and a run store in scope, and handed to the carousel as plain data.
struct TripRecapStampPresentation: Identifiable, Equatable {
    let id: String
    let placeName: String
    let region: String
    let artworkName: String?
}
